import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/pokemon_repository.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../services/sound_service.dart';
import '../widgets/pokemon_widgets.dart';
import '../widgets/drill_widgets.dart';
import 'drill_round_mixin.dart';

// ─── データ定義 ───────────────────────────────────────────────────────────────

typedef _KanaPair = (String hira, String kata);

const List<_KanaPair> _kanaPairs = [
  ('あ', 'ア'), ('い', 'イ'), ('う', 'ウ'), ('え', 'エ'), ('お', 'オ'),
  ('か', 'カ'), ('き', 'キ'), ('く', 'ク'), ('け', 'ケ'), ('こ', 'コ'),
  ('さ', 'サ'), ('し', 'シ'), ('す', 'ス'), ('せ', 'セ'), ('そ', 'ソ'),
  ('た', 'タ'), ('ち', 'チ'), ('つ', 'ツ'), ('て', 'テ'), ('と', 'ト'),
  ('な', 'ナ'), ('に', 'ニ'), ('ぬ', 'ヌ'), ('ね', 'ネ'), ('の', 'ノ'),
  ('は', 'ハ'), ('ひ', 'ヒ'), ('ふ', 'フ'), ('へ', 'ヘ'), ('ほ', 'ホ'),
  ('ま', 'マ'), ('み', 'ミ'), ('む', 'ム'), ('め', 'メ'), ('も', 'モ'),
  ('や', 'ヤ'), ('ゆ', 'ユ'), ('よ', 'ヨ'),
  ('ら', 'ラ'), ('り', 'リ'), ('る', 'ル'), ('れ', 'レ'), ('ろ', 'ロ'),
  ('わ', 'ワ'), ('を', 'ヲ'), ('ん', 'ン'),
];

// 3匹のHP（1+2+2=5回わざ、3問×5=計15問想定）
const _kEnemyHps = [1, 2, 2];

// 伝説・幻ポケモン 図鑑ID → 種族値合計
const Map<int, int> _legendaryBst = {
  // Gen 1
  144: 580, 145: 580, 146: 580, 150: 680, 151: 600,
  // Gen 2
  243: 580, 244: 580, 245: 580, 249: 680, 250: 680, 251: 600,
  // Gen 3
  377: 580, 378: 580, 379: 580, 380: 600, 381: 600,
  382: 670, 383: 670, 384: 680, 385: 600, 386: 600,
  // Gen 4
  480: 580, 481: 580, 482: 580, 483: 680, 484: 680,
  485: 600, 486: 670, 487: 680, 488: 600, 490: 600,
  491: 600, 492: 600, 493: 720,
  // Gen 5
  494: 600, 638: 580, 639: 580, 640: 580, 641: 580,
  642: 580, 643: 680, 644: 680, 645: 600, 646: 660,
  647: 580, 648: 600, 649: 600,
  // Gen 6
  716: 680, 717: 680, 718: 600, 719: 600, 720: 600, 721: 600,
  // Gen 7
  785: 570, 786: 570, 787: 570, 788: 570,
  791: 680, 792: 680, 800: 600, 801: 600, 802: 600, 807: 600, 809: 600,
  // Gen 8
  888: 670, 889: 670, 890: 690, 893: 600, 894: 580, 895: 580,
  896: 580, 897: 580, 898: 680,
  // Gen 9
  1001: 570, 1002: 570, 1003: 570, 1004: 570,
  1007: 670, 1008: 670, 1017: 550, 1024: 700,
};

// 伝説ポケモン 図鑑ID → タイプ
const Map<int, String> _legendaryTypes = {
  144: 'こおり', 145: 'でんき', 146: 'ほのお',
  150: 'エスパー', 151: 'エスパー',
  243: 'でんき', 244: 'ほのお', 245: 'みず',
  249: 'エスパー', 250: 'ほのお', 251: 'くさ',
  377: 'いわ', 378: 'こおり', 379: 'はがね',
  380: 'ドラゴン', 381: 'ドラゴン',
  382: 'みず', 383: 'じめん', 384: 'ドラゴン',
  385: 'はがね', 386: 'エスパー',
  480: 'エスパー', 481: 'エスパー', 482: 'エスパー',
  483: 'ドラゴン', 484: 'ドラゴン',
  485: 'ほのお', 486: 'ノーマル', 487: 'ゴースト',
  488: 'エスパー', 490: 'みず', 491: 'あく',
  492: 'くさ', 493: 'ノーマル', 494: 'ほのお',
  638: 'はがね', 639: 'いわ', 640: 'くさ',
  641: 'ひこう', 642: 'でんき',
  643: 'ほのお', 644: 'でんき',
  645: 'じめん', 646: 'こおり',
  647: 'みず', 648: 'エスパー', 649: 'はがね',
  716: 'フェアリー', 717: 'あく', 718: 'ドラゴン',
  719: 'フェアリー', 720: 'エスパー', 721: 'ほのお',
  785: 'でんき', 786: 'エスパー', 787: 'くさ', 788: 'みず',
  791: 'はがね', 792: 'ゴースト',
  800: 'エスパー', 801: 'フェアリー', 802: 'ゴースト',
  807: 'でんき', 809: 'はがね',
  888: 'フェアリー', 889: 'かくとう',
  890: 'ドラゴン', 893: 'あく',
  894: 'でんき', 895: 'ドラゴン',
  896: 'こおり', 897: 'ゴースト', 898: 'エスパー',
  1001: 'あく', 1002: 'あく', 1003: 'あく', 1004: 'あく',
  1007: 'ドラゴン', 1008: 'ドラゴン',
  1017: 'くさ', 1024: 'ノーマル',
};

// タイプ → わざ名
const Map<String, String> _typeMoves = {
  'ほのお':   'かえんほうしゃ',
  'みず':     'なみのり',
  'くさ':     'ソーラービーム',
  'でんき':   'かみなり',
  'こおり':   'れいとうビーム',
  'かくとう': 'インファイト',
  'エスパー': 'サイコキネシス',
  'ドラゴン': 'りゅうせいぐん',
  'あく':     'あくのはどう',
  'はがね':   'アイアンテール',
  'フェアリー':'ムーンフォース',
  'ノーマル': 'はかいこうせん',
  'いわ':     'ストーンエッジ',
  'じめん':   'じしん',
  'ひこう':   'ぼうふう',
  'ゴースト': 'シャドーボール',
};

// タイプ → カラー
const Map<String, Color> _typeColors = {
  'ほのお':   Color(0xFFFF6B35),
  'みず':     Color(0xFF4488FF),
  'くさ':     Color(0xFF4CAF50),
  'でんき':   Color(0xFFF1C40F),
  'こおり':   Color(0xFF7FC8E8),
  'かくとう': Color(0xFFBF360C),
  'エスパー': Color(0xFFE91E8C),
  'ドラゴン': Color(0xFF4527A0),
  'あく':     Color(0xFF424242),
  'はがね':   Color(0xFF78909C),
  'フェアリー':Color(0xFFE91E63),
  'ノーマル': Color(0xFF9E9E9E),
  'いわ':     Color(0xFF8D6E63),
  'じめん':   Color(0xFFB8860B),
  'ひこう':   Color(0xFF64B5F6),
  'ゴースト': Color(0xFF7B1FA2),
};

// こくご問題データ ─────────────────────────────────────────────────────────────

// 反対語: (もとのことば, はんたい)
const List<(String, String)> _hantaigoData = [
  ('おおきい', 'ちいさい'), ('ながい', 'みじかい'), ('はやい', 'おそい'),
  ('あかるい', 'くらい'),  ('あつい', 'さむい'),   ('あたらしい', 'ふるい'),
  ('たかい', 'ひくい'),   ('かるい', 'おもい'),   ('おおい', 'すくない'),
  ('うえ', 'した'),       ('みぎ', 'ひだり'),     ('まえ', 'うしろ'),
  ('すき', 'きらい'),     ('いい', 'わるい'),     ('ひろい', 'せまい'),
];

// なかまはずれ: ([仲間3つ], はずれ)
const List<(List<String>, String)> _nakamahazureData = [
  (['りんご', 'みかん', 'もも'], 'いぬ'),
  (['いぬ', 'ねこ', 'うし'], 'もも'),
  (['あか', 'あお', 'きいろ'], 'ねこ'),
  (['はる', 'なつ', 'あき'], 'いぬ'),
  (['ぱん', 'すし', 'うどん'], 'いぬ'),
  (['て', 'あし', 'め'], 'りんご'),
  (['でんしゃ', 'バス', 'くるま'], 'もも'),
  (['まる', 'さんかく', 'しかく'], 'いぬ'),
  (['いち', 'に', 'さん'], 'いぬ'),
  (['えんぴつ', 'けしゴム', 'ノート'], 'いぬ'),
  (['ぞう', 'きりん', 'らいおん'], 'りんご'),
  (['つくえ', 'いす', 'たな'], 'ねこ'),
];

// 語頭文字: (頭文字, 正解ことば, [まちがい3つ])
const List<(String, String, List<String>)> _gotouMojiData = [
  ('か', 'かえる', ['いぬ', 'ねこ', 'うさぎ']),
  ('い', 'いぬ',   ['りんご', 'ねこ', 'もも']),
  ('は', 'はな',   ['ねこ', 'りんご', 'うし']),
  ('さ', 'さかな', ['いぬ', 'ねこ', 'うし']),
  ('み', 'みかん', ['いぬ', 'りんご', 'ねこ']),
  ('り', 'りんご', ['みかん', 'いぬ', 'ねこ']),
  ('つ', 'つき',   ['はな', 'うみ', 'やま']),
  ('く', 'くも',   ['はな', 'つき', 'やま']),
  ('ね', 'ねこ',   ['いぬ', 'はな', 'うし']),
  ('や', 'やま',   ['うみ', 'かわ', 'そら']),
  ('う', 'うみ',   ['やま', 'かわ', 'そら']),
  ('た', 'たこ',   ['いか', 'かに', 'えび']),
  ('わ', 'わに',   ['へび', 'かえる', 'ねこ']),
  ('ひ', 'ひよこ', ['いぬ', 'ねこ', 'うし']),
  ('ほ', 'ほし',   ['つき', 'くも', 'やま']),
];

class _Quiz {
  final String displayBig;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final double choiceFontSize;

  const _Quiz({
    required this.displayBig,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    this.choiceFontSize = 36,
  });
}

// ─── バトル画面 ───────────────────────────────────────────────────────────────

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with DrillRoundMixin {
  int _battleIndex = 0;
  int _enemyHp = _kEnemyHps[0];
  late List<PokemonEntry> _enemies;
  late _Quiz _currentQuiz;
  String? _selectedChoice;
  bool _feedbackCorrect = false;
  bool _enemyHit = false;
  bool _enemyFainting = false;
  bool _exhausted = false;
  int _totalCorrect = 0;
  int _zonePenalty = 0;
  int _powerLevel = 0;      // 0〜2 チャージ中、3 = とくぎ発動可能
  bool _specialHit = false; // とくぎ発動時の黄色フラッシュ
  bool _rewardVisible = true; // ゲットできるポケモンを表示するか
  PokemonEntry? _playerBattlePokemon; // バトルに出す伝説ポケモン（報酬とは別）

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    _rewardVisible = StorageService.loadBattleRewardVisible();
    drillPickPendingPokemon(); // ゲットできる報酬ポケモン（ランダム）
    _pickPlayerBattlePokemon(); // バトルに出す伝説ポケモン
    _enemies = _pickEnemies();
    _currentQuiz = _generateQuiz(0);
    if (drillIsExhausted('battle')) {
      _exhausted = true;
      drillPendingRewardPokemon = null;
    }
    AnalyticsService.logScreenView('battle');
  }

  List<PokemonEntry> get _legendaryPool => PokemonRepository.all
      .where((p) => _legendaryBst.containsKey(p.pokedexId))
      .toList();

  int get _playerBst => _legendaryBst[_playerBattlePokemon?.pokedexId] ?? 600;
  String get _playerType => _legendaryTypes[_playerBattlePokemon?.pokedexId] ?? 'ノーマル';
  String get _playerMove => _typeMoves[_playerType] ?? 'とくぎ';
  Color get _playerTypeColor => _typeColors[_playerType] ?? const Color(0xFF9E9E9E);

  void _pickPlayerBattlePokemon() {
    final pool = _legendaryPool;
    if (pool.isEmpty) return;
    int idx;
    do {
      idx = drillRandom.nextInt(pool.length);
    } while (pool.length > 1 && pool[idx].katakana == _playerBattlePokemon?.katakana);
    _playerBattlePokemon = pool[idx];
  }

  List<PokemonEntry> _pickEnemies() {
    final all = List<PokemonEntry>.from(PokemonRepository.all)
      ..shuffle(drillRandom);
    return all.take(3).toList();
  }

  // Zone 0 (battle 1): hiraToKata, add, sub (3 types)
  // Zone 1 (battle 2): +kataToHira (4 types)
  // Zone 2 (battle 3): +hardMath, 反対語, なかまはずれ, 語頭文字 (8 types)
  _Quiz _generateQuiz(int zone) {
    final typeCount = zone == 0 ? 3 : zone == 1 ? 4 : 8;
    final type = drillRandom.nextInt(typeCount);
    return switch (type) {
      0 => _generateHiraToKata(),
      1 => _generateAddition(zone),
      2 => _generateSubtraction(zone),
      3 => _generateKataToHira(),
      4 => drillRandom.nextBool() ? _generateAddTens() : _generateAddTriple(),
      5 => _generateHantaigo(),
      6 => _generateNakamahazure(),
      _ => _generateGotouMoji(),
    };
  }

  _Quiz _generateHiraToKata() {
    final pair = _kanaPairs[drillRandom.nextInt(_kanaPairs.length)];
    final correct = pair.$2;
    final wrongs = (List<_KanaPair>.from(_kanaPairs)
          ..removeWhere((p) => p.$2 == correct)
          ..shuffle(drillRandom))
        .take(3)
        .map((p) => p.$2)
        .toList();
    final choices = [correct, ...wrongs]..shuffle(drillRandom);
    return _Quiz(
      displayBig: pair.$1,
      prompt: 'この ひらがなの カタカナは どれ？',
      choices: choices,
      correctIndex: choices.indexOf(correct),
    );
  }

  _Quiz _generateKataToHira() {
    final pair = _kanaPairs[drillRandom.nextInt(_kanaPairs.length)];
    final correct = pair.$1;
    final wrongs = (List<_KanaPair>.from(_kanaPairs)
          ..removeWhere((p) => p.$1 == correct)
          ..shuffle(drillRandom))
        .take(3)
        .map((p) => p.$1)
        .toList();
    final choices = [correct, ...wrongs]..shuffle(drillRandom);
    return _Quiz(
      displayBig: pair.$2,
      prompt: 'この カタカナの ひらがなは どれ？',
      choices: choices,
      correctIndex: choices.indexOf(correct),
    );
  }

  _Quiz _generateAddition(int zone) {
    final (int minA, int maxA, int maxSum, int spread) = switch (zone) {
      1 => (5, 19, 20, 5),
      2 => (10, 29, 30, 8),
      _ => (1, 9, 10, 3),
    };
    final a = drillRandom.nextInt(maxA - minA + 1) + minA;
    final maxB = maxSum - a;
    final b = maxB >= 1 ? drillRandom.nextInt(maxB) + 1 : 1;
    final answer = a + b;
    final wrongs = <int>{};
    var attempts = 0;
    while (wrongs.length < 3 && attempts < 50) {
      attempts++;
      final w = answer + drillRandom.nextInt(spread * 2 + 1) - spread;
      if (w != answer && w > 0) wrongs.add(w);
    }
    final choices = ([answer, ...wrongs.take(3)]..shuffle(drillRandom))
        .map((n) => n.toString())
        .toList();
    return _Quiz(
      displayBig: '$a ＋ $b',
      prompt: 'こたえは いくつ？',
      choices: choices,
      correctIndex: choices.indexOf(answer.toString()),
    );
  }

  _Quiz _generateSubtraction(int zone) {
    final (int minA, int maxA, int spread) = switch (zone) {
      1 => (10, 20, 5),
      2 => (15, 30, 8),
      _ => (2, 10, 3),
    };
    final a = drillRandom.nextInt(maxA - minA + 1) + minA;
    final b = drillRandom.nextInt(a - 1) + 1;
    final answer = a - b;
    final wrongs = <int>{};
    var attempts = 0;
    while (wrongs.length < 3 && attempts < 50) {
      attempts++;
      final w = answer + drillRandom.nextInt(spread * 2 + 1) - spread;
      if (w != answer && w >= 0 && w < a) wrongs.add(w);
    }
    final choices = ([answer, ...wrongs.take(3)]..shuffle(drillRandom))
        .map((n) => n.toString())
        .toList();
    return _Quiz(
      displayBig: '$a － $b',
      prompt: 'こたえは いくつ？',
      choices: choices,
      correctIndex: choices.indexOf(answer.toString()),
    );
  }

  // 二桁同士（一の桁がゼロ）の足し算: 10+20, 30+40 など
  _Quiz _generateAddTens() {
    int a, b;
    do {
      a = (drillRandom.nextInt(8) + 1) * 10; // 10〜80
      b = (drillRandom.nextInt(8) + 1) * 10; // 10〜80
    } while (a + b > 100);
    final answer = a + b;
    final wrongs = <int>{};
    var attempts = 0;
    while (wrongs.length < 3 && attempts < 50) {
      attempts++;
      final w = answer + (drillRandom.nextInt(5) - 2) * 10;
      if (w != answer && w > 0 && w <= 100) wrongs.add(w);
    }
    final choices = ([answer, ...wrongs.take(3)]..shuffle(drillRandom))
        .map((n) => n.toString())
        .toList();
    return _Quiz(
      displayBig: '$a ＋ $b',
      prompt: 'こたえは いくつ？',
      choices: choices,
      correctIndex: choices.indexOf(answer.toString()),
    );
  }

  // 一桁3つの足し算: 1+2+3, 2+4+5 など
  _Quiz _generateAddTriple() {
    final a = drillRandom.nextInt(5) + 1; // 1〜5
    final b = drillRandom.nextInt(5) + 1;
    final c = drillRandom.nextInt(5) + 1;
    final answer = a + b + c;
    final wrongs = <int>{};
    var attempts = 0;
    while (wrongs.length < 3 && attempts < 50) {
      attempts++;
      final w = answer + drillRandom.nextInt(7) - 3;
      if (w != answer && w > 0) wrongs.add(w);
    }
    final choices = ([answer, ...wrongs.take(3)]..shuffle(drillRandom))
        .map((n) => n.toString())
        .toList();
    return _Quiz(
      displayBig: '$a ＋ $b ＋ $c',
      prompt: 'こたえは いくつ？',
      choices: choices,
      correctIndex: choices.indexOf(answer.toString()),
    );
  }

  _Quiz _generateHantaigo() {
    final pair = _hantaigoData[drillRandom.nextInt(_hantaigoData.length)];
    final correct = pair.$2;
    final wrongs = (_hantaigoData.toList()
          ..removeWhere((p) => p.$2 == correct)
          ..shuffle(drillRandom))
        .take(3)
        .map((p) => p.$2)
        .toList();
    final choices = [correct, ...wrongs]..shuffle(drillRandom);
    return _Quiz(
      displayBig: pair.$1,
      prompt: 'はんたいの ことばは どれ？',
      choices: choices,
      correctIndex: choices.indexOf(correct),
      choiceFontSize: 24,
    );
  }

  _Quiz _generateNakamahazure() {
    final data = _nakamahazureData[drillRandom.nextInt(_nakamahazureData.length)];
    final choices = [...data.$1, data.$2]..shuffle(drillRandom);
    return _Quiz(
      displayBig: '？',
      prompt: 'なかまでは ないのは どれ？',
      choices: choices,
      correctIndex: choices.indexOf(data.$2),
      choiceFontSize: 22,
    );
  }

  _Quiz _generateGotouMoji() {
    final data = _gotouMojiData[drillRandom.nextInt(_gotouMojiData.length)];
    final choices = [data.$2, ...data.$3]..shuffle(drillRandom);
    return _Quiz(
      displayBig: data.$1,
      prompt: 'この もじで はじまる ことばは どれ？',
      choices: choices,
      correctIndex: choices.indexOf(data.$2),
      choiceFontSize: 24,
    );
  }

  void _onAnswerTap(String choice) {
    if (_selectedChoice != null || _enemyFainting || _powerLevel >= 3) return;
    final correct = choice == _currentQuiz.choices[_currentQuiz.correctIndex];
    setState(() {
      _selectedChoice = choice;
      _feedbackCorrect = correct;
      if (!correct) _zonePenalty = (_zonePenalty + 1).clamp(0, 2);
    });
    if (correct) {
      SoundService.playStrokeComplete();
      drillCorrectCount++;
      _totalCorrect++;
      setState(() => _powerLevel = (_powerLevel + 1).clamp(0, 3));
      Future.delayed(const Duration(milliseconds: 700), _nextQuestion);
    } else {
      Future.delayed(const Duration(milliseconds: 900), _nextQuestion);
    }
  }

  void _useSpecial() {
    if (_powerLevel < 3 || _enemyFainting) return;
    setState(() => _powerLevel = 0);
    _triggerHit(isSpecial: true);
    Future.delayed(const Duration(milliseconds: 700), _applyDamage);
  }

  Future<void> _triggerHit({bool isSpecial = false}) async {
    setState(() { _enemyHit = true; _specialHit = isSpecial; });
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() { _enemyHit = false; _specialHit = false; });
  }

  void _applyDamage() {
    if (!mounted) return;
    final newHp = (_enemyHp - 1).clamp(0, 99);
    setState(() => _enemyHp = newHp);
    if (newHp <= 0) {
      setState(() => _enemyFainting = true);
      Future.delayed(const Duration(milliseconds: 900), _afterFaint);
    } else {
      _nextQuestion();
    }
  }

  void _afterFaint() {
    if (!mounted) return;
    if (_battleIndex >= 2) {
      _endRound();
    } else {
      final next = _battleIndex + 1;
      setState(() {
        _enemyFainting = false;
        _battleIndex = next;
        _enemyHp = _kEnemyHps[next];
        _selectedChoice = null;
        _feedbackCorrect = false;
        _zonePenalty = 0;
        _currentQuiz = _generateQuiz(next >= 1 ? 2 : 0); // 2匹目から最高難易度
      });
    }
  }

  // 2匹目以降は zone 2 固定、間違えると zone 1→0 に下がる
  int get _effectiveZone =>
      _battleIndex == 0 ? 0 : (2 - _zonePenalty).clamp(0, 2);

  void _nextQuestion() {
    if (!mounted) return;
    setState(() {
      _selectedChoice = null;
      _feedbackCorrect = false;
      _currentQuiz = _generateQuiz(_effectiveZone);
    });
  }

  void _endRound() {
    final reward = drillSaveRewardPokemon();
    final shiny = drillPendingIsShiny;
    StorageService.incrementDailyPlays('battle');
    AnalyticsService.logBattleRoundComplete(score: _totalCorrect, isShiny: shiny);
    if (reward != null) {
      AnalyticsService.logPokemonCaught(
        pokemonName: reward.katakana,
        isShiny: shiny,
        source: 'battle',
      );
      DailyStatsService.incrementCaught();
    }
    DailyStatsService.incrementDrillSessions('battle');
    setState(() {
      drillRewardPokemon = reward;
      drillRewardIsShiny = shiny;
      drillShowRoundResult = true;
    });
  }

  void _nextRound() {
    if (drillIsExhausted('battle')) {
      setState(() {
        drillShowRoundResult = false;
        _exhausted = true;
        drillPendingRewardPokemon = null;
      });
      return;
    }
    setState(() {
      drillShowRoundResult = false;
      _exhausted = false;
      drillRewardPokemon = null;
      drillRewardIsShiny = false;
      drillPendingRewardPokemon = null;
      drillPendingIsShiny = false;
      drillCorrectCount = 0;
      _enemies = _pickEnemies();
      _totalCorrect = 0;
      _powerLevel = 0;
      _enemyFainting = false;
      _enemyHit = false;
      _battleIndex = 0;
      _enemyHp = _kEnemyHps[0];
      _zonePenalty = 0;
      _selectedChoice = null;
      _feedbackCorrect = false;
      _currentQuiz = _generateQuiz(0);
    });
    drillPickPendingPokemon();
    _pickPlayerBattlePokemon();
  }

  @override
  Widget build(BuildContext context) {
    final enemy = _enemies[_battleIndex.clamp(0, 2)];
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 200,
            child: _LeftPanel(
              battleIndex: _battleIndex,
              showResult: drillShowRoundResult,
              caughtCount: drillCaughtPokemon.length,
              caughtPokemon: drillCaughtPokemon,
              shinyCaughtNames: drillShinyCaughtNames,
              onBack: () => Navigator.pop(context),
              rewardVisible: _rewardVisible,
              pendingRewardPokemon: drillPendingRewardPokemon,
              pendingIsShiny: drillPendingIsShiny,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (!drillShowRoundResult)
                  _exhausted
                      ? Center(
                          child: _ExhaustedPanel(
                              onBack: () => Navigator.pop(context)))
                      : Column(
                          children: [
                            Expanded(
                              flex: 4,
                              child: _BattleScene(
                                enemy: enemy,
                                hp: _enemyHp,
                                maxHp: _kEnemyHps[_battleIndex.clamp(0, 2)],
                                battleIndex: _battleIndex,
                                isHit: _enemyHit,
                                isSpecialHit: _specialHit,
                                isFainting: _enemyFainting,
                                playerPokemon: _playerBattlePokemon,
                                playerBst: _playerBst,
                                playerMove: _playerMove,
                                typeColor: _playerTypeColor,
                                powerLevel: _powerLevel,
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: _powerLevel >= 3
                                  ? _SpecialButton(
                                  moveName: _playerMove,
                                  typeColor: _playerTypeColor,
                                  onTap: _useSpecial,
                                )
                                  : Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 24, 16),
                                      child: _QuestionPanel(
                                        quiz: _currentQuiz,
                                        selected: _selectedChoice,
                                        feedbackCorrect: _feedbackCorrect,
                                        onAnswerTap: _onAnswerTap,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                if (drillShowRoundResult)
                  DrillRoundResultOverlay(
                    scoreLabel: '3ひき たおした！ やったね！',
                    starsTotal: 5,
                    starsFilled: 5,
                    passed: true,
                    rewardPokemon: drillRewardPokemon,
                    isShiny: drillRewardIsShiny,
                    onNext: _nextRound,
                  ),
                if (drillShowRoundResult && drillRewardPokemon != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ConfettiOverlay(
                          baseColor: drillRewardPokemon!.color),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 左パネル ─────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final int battleIndex;
  final bool showResult;
  final int caughtCount;
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;
  final VoidCallback onBack;
  final bool rewardVisible;
  final PokemonEntry? pendingRewardPokemon;
  final bool pendingIsShiny;

  const _LeftPanel({
    required this.battleIndex,
    required this.showResult,
    required this.caughtCount,
    required this.caughtPokemon,
    required this.shinyCaughtNames,
    required this.onBack,
    required this.rewardVisible,
    this.pendingRewardPokemon,
    this.pendingIsShiny = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 16,
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.home_outlined, size: 14),
                  label: const Text('もどる',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.darkText,
                    side: const BorderSide(color: Color(0xFFCCCCCC)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'バトル！',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE17055),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '${battleIndex + 1} / 3 ひき め',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final Color color;
                    if (i < battleIndex) {
                      color = AppTheme.textGray;
                    } else if (i == battleIndex) {
                      color = const Color(0xFFE17055);
                    } else {
                      color = const Color(0xFFEEEEEE);
                    }
                    return Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                if (!showResult && rewardVisible && pendingRewardPokemon != null)
                  DrillPokemonRewardPreview(
                    pokemon: pendingRewardPokemon!,
                    isShiny: pendingIsShiny,
                  ),
                const Spacer(),
                DrillCaughtBar(
                  caughtCount: caughtCount,
                  caughtPokemon: caughtPokemon,
                  shinyCaughtNames: shinyCaughtNames,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── バトルシーン ─────────────────────────────────────────────────────────────

class _BattleScene extends StatelessWidget {
  final PokemonEntry enemy;
  final int hp;
  final int maxHp;
  final int battleIndex;
  final bool isHit;
  final bool isFainting;
  final bool isSpecialHit;
  final PokemonEntry? playerPokemon;
  final int playerBst;
  final String playerMove;
  final Color typeColor;
  final int powerLevel; // 0〜3 (3 = とくぎ発動)

  const _BattleScene({
    required this.enemy,
    required this.hp,
    required this.maxHp,
    required this.battleIndex,
    required this.isHit,
    required this.isSpecialHit,
    required this.isFainting,
    this.playerPokemon,
    required this.playerBst,
    required this.playerMove,
    required this.typeColor,
    required this.powerLevel,
  });

  // BST を星1〜5に変換
  static int _bstToStars(int bst) {
    if (bst >= 700) return 5;
    if (bst >= 670) return 4;
    if (bst >= 600) return 3;
    if (bst >= 570) return 2;
    return 1;
  }

  static Widget _label(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hpRatio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final hpColor = hpRatio > 0.5
        ? const Color(0xFF2ECC71)
        : hpRatio > 0.25
            ? const Color(0xFFF39C12)
            : const Color(0xFFE74C3C);
    final stars = _bstToStars(playerBst);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5DA0D0), Color(0xFF8EC8F0), Color(0xFF9DD4A0)],
          stops: [0.0, 0.58, 1.0],
        ),
      ),
      child: Column(
        children: [
          // ─── てき側（上） ─────────────────────────────────────
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('てき ${battleIndex + 1} / 3', const Color(0xFFE74C3C)),
                        const SizedBox(height: 6),
                        Text(
                          enemy.katakana,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('HP ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: hpRatio,
                                  backgroundColor: Colors.white30,
                                  valueColor: AlwaysStoppedAnimation(hpColor),
                                  minHeight: 10,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text('$hp / $maxHp',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedOpacity(
                    opacity: isFainting ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 700),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PokemonImage(pokemon: enemy, size: 100, isShiny: false),
                        if (isHit)
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: isSpecialHit
                                  ? const Color(0xFFF1C40F).withValues(alpha: 0.6)
                                  : Colors.red.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: 2, color: Colors.white30),
          // ─── じぶん側（下） ───────────────────────────────────
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black12,
              padding: const EdgeInsets.fromLTRB(16, 4, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (playerPokemon != null)
                    PokemonImage(pokemon: playerPokemon!, size: 68, isShiny: false)
                  else
                    const SizedBox(width: 68),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('じぶん', const Color(0xFF27AE60)),
                        const SizedBox(height: 4),
                        Text(
                          playerPokemon?.katakana ?? '？？？',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            for (int i = 0; i < 5; i++)
                              Icon(
                                i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 15,
                                color: const Color(0xFFF1C40F),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // ─ とくぎゲージ ─
                        Row(
                          children: [
                            Text(playerMove,
                                style: const TextStyle(fontSize: 10, color: Colors.white70)),
                            const SizedBox(width: 4),
                            for (int i = 0; i < 3; i++)
                              Container(
                                width: 18,
                                height: 12,
                                margin: const EdgeInsets.only(right: 3),
                                decoration: BoxDecoration(
                                  color: i < powerLevel
                                      ? typeColor
                                      : Colors.white30,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            if (powerLevel == 3)
                              const Text(' ⚡', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 問題パネル ───────────────────────────────────────────────────────────────

class _QuestionPanel extends StatelessWidget {
  final _Quiz quiz;
  final String? selected;
  final bool feedbackCorrect;
  final ValueChanged<String> onAnswerTap;

  const _QuestionPanel({
    required this.quiz,
    required this.selected,
    required this.feedbackCorrect,
    required this.onAnswerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          quiz.prompt,
          style: const TextStyle(
            fontSize: 15,
            color: AppTheme.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 3,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                quiz.displayBig,
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: DrillChoiceButton(
                          choice: quiz.choices[0],
                          correct: quiz.choices[quiz.correctIndex],
                          selected: selected,
                          onTap: onAnswerTap,
                          fontSize: quiz.choiceFontSize,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DrillChoiceButton(
                          choice: quiz.choices[1],
                          correct: quiz.choices[quiz.correctIndex],
                          selected: selected,
                          onTap: onAnswerTap,
                          fontSize: quiz.choiceFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: DrillChoiceButton(
                          choice: quiz.choices[2],
                          correct: quiz.choices[quiz.correctIndex],
                          selected: selected,
                          onTap: onAnswerTap,
                          fontSize: quiz.choiceFontSize,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DrillChoiceButton(
                          choice: quiz.choices[3],
                          correct: quiz.choices[quiz.correctIndex],
                          selected: selected,
                          onTap: onAnswerTap,
                          fontSize: quiz.choiceFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── とくぎボタン ─────────────────────────────────────────────────────────────────

class _SpecialButton extends StatelessWidget {
  final String moveName;
  final Color typeColor;
  final VoidCallback onTap;

  const _SpecialButton({
    required this.moveName,
    required this.typeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'とくぎゲージが\nいっぱいになった！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 22),
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.55),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Text(
                '⚡ $moveName！',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 今日おしまいパネル ──────────────────────────────────────────────────────────

class _ExhaustedPanel extends StatelessWidget {
  final VoidCallback onBack;

  const _ExhaustedPanel({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🌙', style: TextStyle(fontSize: 60)),
        const SizedBox(height: 16),
        const Text(
          'きょうは おしまい！',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'また あした ね！',
          style: TextStyle(fontSize: 16, color: AppTheme.textGray),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.home_outlined),
          label: const Text('もどる'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.darkText,
            side: const BorderSide(color: Color(0xFFCCCCCC)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ],
    );
  }
}
