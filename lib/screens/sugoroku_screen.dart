import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../services/sound_service.dart';
import '../widgets/pokemon_widgets.dart';
import '../widgets/drill_widgets.dart';
import 'drill_round_mixin.dart';

// ─── ボードデータ ─────────────────────────────────────────────────────────────

enum _SquareType { start, quiz, lucky, goal }

// 30マス・5列×6行スネーク型ボード
const _squareTypes = <_SquareType>[
  _SquareType.start,  // 0
  _SquareType.quiz,   // 1
  _SquareType.quiz,   // 2
  _SquareType.quiz,   // 3
  _SquareType.lucky,  // 4  ★
  _SquareType.quiz,   // 5
  _SquareType.quiz,   // 6
  _SquareType.quiz,   // 7
  _SquareType.quiz,   // 8
  _SquareType.quiz,   // 9
  _SquareType.lucky,  // 10 ★
  _SquareType.quiz,   // 11
  _SquareType.quiz,   // 12
  _SquareType.quiz,   // 13
  _SquareType.quiz,   // 14
  _SquareType.quiz,   // 15
  _SquareType.lucky,  // 16 ★
  _SquareType.quiz,   // 17
  _SquareType.quiz,   // 18
  _SquareType.quiz,   // 19
  _SquareType.quiz,   // 20
  _SquareType.lucky,  // 21 ★
  _SquareType.quiz,   // 22
  _SquareType.quiz,   // 23
  _SquareType.quiz,   // 24
  _SquareType.quiz,   // 25
  _SquareType.lucky,  // 26 ★
  _SquareType.quiz,   // 27
  _SquareType.quiz,   // 28
  _SquareType.goal,   // 29 🏆
];

// 視覚(rowIdx=0:上, colIdx=0:左) → ポジション番号（5列×6行）
int? _gridToPos(int rowIdx, int colIdx) {
  final posGroup = 5 - rowIdx; // 上row=posGroup5, 下row=posGroup0
  final isEvenGroup = posGroup % 2 == 0;
  final posInGroup = isEvenGroup ? colIdx : (4 - colIdx);
  final pos = posGroup * 5 + posInGroup;
  return (pos >= 0 && pos < 30) ? pos : null;
}

// ─── クイズデータ ─────────────────────────────────────────────────────────────

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

class _Quiz {
  final String displayBig; // 大きく表示する文字/式
  final String prompt;     // 問題文
  final List<String> choices;
  final int correctIndex;
  final bool isMath;

  const _Quiz({
    required this.displayBig,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    this.isMath = false,
  });
}

// ─── メイン画面 ───────────────────────────────────────────────────────────────

class SugorokuScreen extends StatefulWidget {
  const SugorokuScreen({super.key});

  @override
  State<SugorokuScreen> createState() => _SugorokuScreenState();
}

class _SugorokuScreenState extends State<SugorokuScreen> with DrillRoundMixin {
  int _position = 0;
  late _Quiz _currentQuiz;
  String? _selectedChoice;
  bool _feedbackCorrect = false;
  int? _diceValue;
  bool _waitingForDiceRoll = false;
  bool _showingLucky = false;
  bool _exhausted = false;
  int _stepsWalked = 0;
  int _mathZonePenalty = 0;

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    drillPickPendingPokemon();
    _currentQuiz = _generateQuiz();
    if (drillIsExhausted('sugoroku')) {
      _exhausted = true;
      drillPendingRewardPokemon = null;
    }
    AnalyticsService.logScreenView('sugoroku');
  }

  _Quiz _generateQuiz() {
    final type = drillRandom.nextInt(3);
    if (type == 0) return _generateHiraToKata();
    if (type == 1) return _generateAddition(_position, _mathZonePenalty);
    return _generateSubtraction(_position, _mathZonePenalty);
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

  _Quiz _generateAddition(int position, int penalty) {
    // Zone 0 (pos 0–9): a+b ≤ 10 / Zone 1 (pos 10–19): a+b ≤ 20 / Zone 2 (pos 20–29): a+b ≤ 30
    final zone = (position ~/ 10 - penalty).clamp(0, 2);
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
      isMath: true,
    );
  }

  _Quiz _generateSubtraction(int position, int penalty) {
    final zone = (position ~/ 10 - penalty).clamp(0, 2);
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
      isMath: true,
    );
  }

  void _onAnswerTap(String choice) {
    if (_selectedChoice != null || _showingLucky) return;
    final correct = choice == _currentQuiz.choices[_currentQuiz.correctIndex];
    setState(() {
      _selectedChoice = choice;
      _feedbackCorrect = correct;
      if (correct) {
        _waitingForDiceRoll = true;
      } else if (_currentQuiz.isMath) {
        _mathZonePenalty = (_mathZonePenalty + 1).clamp(0, 2);
      }
    });
    if (correct) {
      SoundService.playStrokeComplete();
      drillCorrectCount++;
    } else {
      Future.delayed(const Duration(milliseconds: 1000), _nextQuestion);
    }
  }

  void _onDiceRoll() {
    if (!_waitingForDiceRoll) return;
    final dice = drillRandom.nextInt(3) + 1;
    setState(() {
      _diceValue = dice;
      _waitingForDiceRoll = false;
    });
    Future.delayed(const Duration(milliseconds: 900), _movePlayer);
  }

  void _movePlayer() {
    if (!mounted) return;
    final newPos = math.min(_position + _diceValue!, 29);
    final steps = newPos - _position;
    setState(() {
      _position = newPos;
      _stepsWalked += steps;
      _selectedChoice = null;
      _diceValue = null;
      _mathZonePenalty = 0;
    });
    if (newPos >= 29) {
      _endRound();
      return;
    }
    if (_squareTypes[newPos] == _SquareType.lucky) {
      _handleLucky();
    } else {
      _nextQuestion();
    }
  }

  void _handleLucky() {
    setState(() => _showingLucky = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final newPos = math.min(_position + 2, 29);
      setState(() {
        _stepsWalked += newPos - _position;
        _position = newPos;
        _showingLucky = false;
      });
      if (_position >= 29) {
        _endRound();
      } else {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    if (!mounted) return;
    setState(() {
      _selectedChoice = null;
      _diceValue = null;
      _currentQuiz = _generateQuiz();
    });
  }

  void _endRound() {
    final reward = drillSaveRewardPokemon();
    final shiny = drillPendingIsShiny;
    StorageService.incrementDailyPlays('sugoroku');
    AnalyticsService.logSugorokuRoundComplete(
        stepsWalked: _stepsWalked, isShiny: shiny);
    if (reward != null) {
      AnalyticsService.logPokemonCaught(
        pokemonName: reward.katakana,
        isShiny: shiny,
        source: 'sugoroku',
      );
      DailyStatsService.incrementCaught();
    }
    DailyStatsService.incrementDrillSessions('sugoroku');
    setState(() {
      drillRewardPokemon = reward;
      drillRewardIsShiny = shiny;
      drillShowRoundResult = true;
    });
  }

  void _nextRound() {
    if (drillIsExhausted('sugoroku')) {
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
      _position = 0;
      _stepsWalked = 0;
      _selectedChoice = null;
      _diceValue = null;
      _waitingForDiceRoll = false;
      _showingLucky = false;
      _mathZonePenalty = 0;
      _currentQuiz = _generateQuiz();
    });
    drillPickPendingPokemon();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左パネル
          SizedBox(
            width: 200,
            child: _LeftPanel(
              position: _position,
              showResult: drillShowRoundResult,
              caughtCount: drillCaughtPokemon.length,
              caughtPokemon: drillCaughtPokemon,
              shinyCaughtNames: drillShinyCaughtNames,
              onBack: () => Navigator.pop(context),
              pendingRewardPokemon: drillPendingRewardPokemon,
              pendingIsShiny: drillPendingIsShiny,
            ),
          ),
          // ボード
          SizedBox(
            width: 270,
            child: Container(
              color: AppTheme.white,
              padding: const EdgeInsets.all(10),
              child: _BoardView(currentPos: _position),
            ),
          ),
          // 問題エリア
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                  child: drillShowRoundResult
                      ? const SizedBox.shrink()
                      : _exhausted
                          ? _ExhaustedPanel(
                              onBack: () => Navigator.pop(context))
                          : _showingLucky
                              ? _LuckyPanel(newPos: _position)
                              : _QuestionPanel(
                                  quiz: _currentQuiz,
                                  selected: _selectedChoice,
                                  feedbackCorrect: _feedbackCorrect,
                                  diceValue: _diceValue,
                                  waitingForDiceRoll: _waitingForDiceRoll,
                                  onAnswerTap: _onAnswerTap,
                                  onDiceRoll: _onDiceRoll,
                                ),
                ),
                if (drillShowRoundResult)
                  DrillRoundResultOverlay(
                    scoreLabel: 'ゴール！ よくできました！',
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
                      child: ConfettiOverlay(baseColor: drillRewardPokemon!.color),
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
  final int position;
  final bool showResult;
  final int caughtCount;
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;
  final VoidCallback onBack;
  final PokemonEntry? pendingRewardPokemon;
  final bool pendingIsShiny;

  const _LeftPanel({
    required this.position,
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
                  label: const Text('もどる', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.darkText,
                    side: const BorderSide(color: Color(0xFFCCCCCC)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'スゴロク',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00B894),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'いま ${position + 1} マス め',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'ゴールまで ${29 - position} マス',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGray,
                    ),
                  ),
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

// ─── ボードビュー ─────────────────────────────────────────────────────────────
//
// 5行×4列のスネーク型ボード（合計20マス）
// 位置0=スタート(下左)、位置19=ゴール(上右)
// 偶数グループ行(0,2,4): 左→右、奇数グループ行(1,3): 右→左

class _BoardView extends StatelessWidget {
  final int currentPos;

  const _BoardView({required this.currentPos});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (rowIdx) {
        return Padding(
          padding: EdgeInsets.only(bottom: rowIdx < 5 ? 4 : 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (colIdx) {
              final pos = _gridToPos(rowIdx, colIdx);
              if (pos == null) return const SizedBox(width: 50, height: 50);
              return Padding(
                padding: EdgeInsets.only(right: colIdx < 4 ? 4 : 0),
                child: _BoardCell(
                  pos: pos,
                  type: _squareTypes[pos],
                  isActive: pos == currentPos,
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _BoardCell extends StatelessWidget {
  final int pos;
  final _SquareType type;
  final bool isActive;

  const _BoardCell({
    required this.pos,
    required this.type,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final String label;

    switch (type) {
      case _SquareType.start:
        bg = const Color(0xFFE8F5E9);
        border = const Color(0xFF66BB6A);
        label = 'スタート';
      case _SquareType.lucky:
        bg = const Color(0xFFFFFDE7);
        border = const Color(0xFFFFD600);
        label = '★';
      case _SquareType.goal:
        bg = const Color(0xFFFFEBEE);
        border = const Color(0xFFEF5350);
        label = 'GOAL';
      case _SquareType.quiz:
        bg = isActive
            ? const Color(0xFFE3F2FD)
            : const Color(0xFFF5F5F5);
        border = isActive
            ? const Color(0xFF42A5F5)
            : const Color(0xFFE0E0E0);
        label = '${pos + 1}';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? const Color(0xFF1E88E5) : border,
          width: isActive ? 2.5 : 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: type == _SquareType.quiz ? 14 : 10,
              fontWeight: FontWeight.bold,
              color: type == _SquareType.quiz
                  ? (isActive
                      ? const Color(0xFF1565C0)
                      : AppTheme.textGray)
                  : AppTheme.darkText,
            ),
          ),
          if (isActive)
            const Positioned(
              bottom: 2,
              right: 2,
              child: Text('🔴', style: TextStyle(fontSize: 14)),
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
  final int? diceValue;
  final bool waitingForDiceRoll;
  final ValueChanged<String> onAnswerTap;
  final VoidCallback onDiceRoll;

  const _QuestionPanel({
    required this.quiz,
    required this.selected,
    required this.feedbackCorrect,
    required this.diceValue,
    required this.waitingForDiceRoll,
    required this.onAnswerTap,
    required this.onDiceRoll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 問題文
        Text(
          quiz.prompt,
          style: const TextStyle(
            fontSize: 15,
            color: AppTheme.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // 大きな表示（文字 or 計算式）
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
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),

        // サイコロボタン or 結果表示
        if (selected != null && feedbackCorrect)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: waitingForDiceRoll
                ? GestureDetector(
                    onTap: onDiceRoll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B894),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF00B894).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🎲', style: TextStyle(fontSize: 28)),
                          SizedBox(width: 10),
                          Text(
                            'サイコロを ふる！',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎲', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(
                        '+$diceValue マス！',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00B894),
                        ),
                      ),
                    ],
                  ),
          ),

        // 4択ボタン
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
                          fontSize: 46,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DrillChoiceButton(
                          choice: quiz.choices[1],
                          correct: quiz.choices[quiz.correctIndex],
                          selected: selected,
                          onTap: onAnswerTap,
                          fontSize: 46,
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
                          fontSize: 46,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DrillChoiceButton(
                          choice: quiz.choices[3],
                          correct: quiz.choices[quiz.correctIndex],
                          selected: selected,
                          onTap: onAnswerTap,
                          fontSize: 46,
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

// ─── ラッキーパネル ───────────────────────────────────────────────────────────

class _LuckyPanel extends StatelessWidget {
  final int newPos;

  const _LuckyPanel({required this.newPos});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 12),
          const Text(
            'ラッキー！',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF9F43),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '+2 マス すすむよ！',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
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
    return Center(
      child: Column(
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
      ),
    );
  }
}
