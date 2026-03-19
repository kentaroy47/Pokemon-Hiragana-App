import 'dart:math';

/// 1問の算数問題
class MathProblem {
  final int a;
  final int b;
  final String op; // '+' or '-'
  final int answer;

  const MathProblem({
    required this.a,
    required this.b,
    required this.op,
    required this.answer,
  });

  String get questionText => '$a $op $b = ?';
}

/// レベル定義
enum MathLevel {
  /// レベル1: たし算（繰り上がりなし）  a+b ≤ 9
  addSimple,
  /// レベル2: ひき算（繰り下がりなし）  a ≤ 9, a > b
  subSimple,
  /// レベル3: たし算（繰り上がりあり）  a+b ≥ 10
  addCarry,
  /// レベル4: ひき算（繰り下がりあり）  a ≥ 10, borrowing occurs
  subBorrow,
}

extension MathLevelX on MathLevel {
  int get number => index + 1;

  String get label {
    switch (this) {
      case MathLevel.addSimple:
        return 'たしざん';
      case MathLevel.subSimple:
        return 'ひきざん';
      case MathLevel.addCarry:
        return 'くりあがり\nたしざん';
      case MathLevel.subBorrow:
        return 'くりさがり\nひきざん';
    }
  }

  bool get showDots => this == MathLevel.addSimple;

  MathLevel get next {
    if (index + 1 >= MathLevel.values.length) return MathLevel.subBorrow;
    return MathLevel.values[index + 1];
  }
}

class MathData {
  /// 指定レベルの問題を1問生成する
  static MathProblem generate(MathLevel level, Random random) {
    switch (level) {
      case MathLevel.addSimple:
        // a + b ≤ 9, a,b ≥ 1
        final a = random.nextInt(8) + 1; // 1-8
        final maxB = 9 - a;
        final b = random.nextInt(maxB) + 1; // 1..(9-a)
        return MathProblem(a: a, b: b, op: '+', answer: a + b);

      case MathLevel.subSimple:
        // a - b ≥ 1, a ≤ 9
        final a = random.nextInt(8) + 2; // 2-9
        final b = random.nextInt(a - 1) + 1; // 1..(a-1)
        return MathProblem(a: a, b: b, op: '-', answer: a - b);

      case MathLevel.addCarry:
        // a + b ≥ 10, a+b ≤ 18, a,b ≥ 1
        int a, b;
        do {
          a = random.nextInt(8) + 2; // 2-9
          b = random.nextInt(8) + 2; // 2-9
        } while (a + b < 10 || a + b > 18);
        return MathProblem(a: a, b: b, op: '+', answer: a + b);

      case MathLevel.subBorrow:
        // a ∈ 11-18, b ∈ 2-9, a > b, 一の位に繰り下がりが発生
        int a, b;
        do {
          a = random.nextInt(8) + 11; // 11-18
          b = random.nextInt(8) + 2;  // 2-9
        } while (a <= b || (a % 10) >= b); // 繰り下がりを保証
        return MathProblem(a: a, b: b, op: '-', answer: a - b);
    }
  }

  /// 5問セットを生成する
  static List<MathProblem> generateSet(MathLevel level, Random random) {
    return List.generate(5, (_) => generate(level, random));
  }

  /// 正解 + ダミー3択の計4択リストを返す（シャッフル済み）
  static List<int> generateChoices(int answer, Random random) {
    final choices = <int>{answer};
    var attempts = 0;
    while (choices.length < 4 && attempts < 200) {
      attempts++;
      final offset = random.nextInt(5) + 1; // 1-5
      final candidate = random.nextBool() ? answer + offset : answer - offset;
      if (candidate >= 0 && candidate <= 20) choices.add(candidate);
    }
    // 万が一4択に満たない場合は近傍で補完
    var fill = 1;
    while (choices.length < 4) {
      choices.add(answer + fill);
      choices.add(answer - fill);
      fill++;
    }
    final list = choices.take(4).toList()..shuffle(random);
    return list;
  }
}
