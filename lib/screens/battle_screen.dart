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

// 3匹のHP（合計10問）
const _kEnemyHps = [3, 3, 4];

class _Quiz {
  final String displayBig;
  final String prompt;
  final List<String> choices;
  final int correctIndex;

  const _Quiz({
    required this.displayBig,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
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

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    drillPickPendingPokemon();
    _enemies = _pickEnemies();
    _currentQuiz = _generateQuiz(0);
    if (drillIsExhausted('battle')) {
      _exhausted = true;
      drillPendingRewardPokemon = null;
    }
    AnalyticsService.logScreenView('battle');
  }

  List<PokemonEntry> _pickEnemies() {
    final all = List<PokemonEntry>.from(PokemonRepository.all)
      ..shuffle(drillRandom);
    return all.take(3).toList();
  }

  // Zone 0 (battle 1): hiraToKata, add, sub (3 types)
  // Zone 1 (battle 2): +kataToHira (4 types)
  // Zone 2 (battle 3): +clock (5 types)
  _Quiz _generateQuiz(int zone) {
    final typeCount = zone == 0 ? 3 : zone == 1 ? 4 : 5;
    final type = drillRandom.nextInt(typeCount);
    return switch (type) {
      0 => _generateHiraToKata(),
      1 => _generateAddition(zone),
      2 => _generateSubtraction(zone),
      3 => _generateKataToHira(),
      _ => _generateClock(),
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

  _Quiz _generateClock() {
    final hour = drillRandom.nextInt(12) + 1;
    const minuteOpts = [0, 15, 30, 45];
    final minute = minuteOpts[drillRandom.nextInt(minuteOpts.length)];
    String label(int h, int m) => m == 0 ? '$h じ' : '$h じ $m ふん';
    final correct = label(hour, minute);
    final wrongs = <String>{};
    var attempts = 0;
    while (wrongs.length < 3 && attempts < 50) {
      attempts++;
      final h = drillRandom.nextInt(12) + 1;
      final m = minuteOpts[drillRandom.nextInt(minuteOpts.length)];
      final w = label(h, m);
      if (w != correct) wrongs.add(w);
    }
    final choices = [correct, ...wrongs.take(3)]..shuffle(drillRandom);
    return _Quiz(
      displayBig: '$hour:${minute.toString().padLeft(2, '0')}',
      prompt: 'なんじ なんぷん？',
      choices: choices,
      correctIndex: choices.indexOf(correct),
    );
  }

  void _onAnswerTap(String choice) {
    if (_selectedChoice != null || _enemyFainting) return;
    final correct = choice == _currentQuiz.choices[_currentQuiz.correctIndex];
    setState(() {
      _selectedChoice = choice;
      _feedbackCorrect = correct;
    });
    if (correct) {
      SoundService.playStrokeComplete();
      drillCorrectCount++;
      _totalCorrect++;
      _triggerHit();
      Future.delayed(const Duration(milliseconds: 700), _applyDamage);
    } else {
      Future.delayed(const Duration(milliseconds: 900), _nextQuestion);
    }
  }

  Future<void> _triggerHit() async {
    setState(() => _enemyHit = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() => _enemyHit = false);
  }

  void _applyDamage() {
    if (!mounted) return;
    final newHp = _enemyHp - 1;
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
        _currentQuiz = _generateQuiz(next);
      });
    }
  }

  void _nextQuestion() {
    if (!mounted) return;
    setState(() {
      _selectedChoice = null;
      _feedbackCorrect = false;
      _currentQuiz = _generateQuiz(_battleIndex);
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
      _enemyFainting = false;
      _enemyHit = false;
      _battleIndex = 0;
      _enemyHp = _kEnemyHps[0];
      _selectedChoice = null;
      _feedbackCorrect = false;
      _currentQuiz = _generateQuiz(0);
    });
    drillPickPendingPokemon();
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
                                isFainting: _enemyFainting,
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: Padding(
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
  final PokemonEntry? pendingRewardPokemon;
  final bool pendingIsShiny;

  const _LeftPanel({
    required this.battleIndex,
    required this.showResult,
    required this.caughtCount,
    required this.caughtPokemon,
    required this.shinyCaughtNames,
    required this.onBack,
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
                if (!showResult && pendingRewardPokemon != null)
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

  const _BattleScene({
    required this.enemy,
    required this.hp,
    required this.maxHp,
    required this.battleIndex,
    required this.isHit,
    required this.isFainting,
  });

  @override
  Widget build(BuildContext context) {
    final hpRatio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final hpColor = hpRatio > 0.5
        ? const Color(0xFF2ECC71)
        : hpRatio > 0.25
            ? const Color(0xFFF39C12)
            : const Color(0xFFE74C3C);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5DA0D0), Color(0xFF8EC8F0)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // HP情報（左）
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enemy.katakana,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'てきポケモン ${battleIndex + 1} / 3',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'HP ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: hpRatio,
                          backgroundColor: Colors.white30,
                          valueColor: AlwaysStoppedAnimation(hpColor),
                          minHeight: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '$hp / $maxHp',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // ポケモン画像（右）
          AnimatedOpacity(
            opacity: isFainting ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 700),
            child: Stack(
              alignment: Alignment.center,
              children: [
                PokemonImage(pokemon: enemy, size: 130, isShiny: false),
                if (isHit)
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
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
                          fontSize: 36,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DrillChoiceButton(
                          choice: quiz.choices[1],
                          correct: quiz.choices[quiz.correctIndex],
                          selected: selected,
                          onTap: onAnswerTap,
                          fontSize: 36,
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
                          fontSize: 36,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DrillChoiceButton(
                          choice: quiz.choices[3],
                          correct: quiz.choices[quiz.correctIndex],
                          selected: selected,
                          onTap: onAnswerTap,
                          fontSize: 36,
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
