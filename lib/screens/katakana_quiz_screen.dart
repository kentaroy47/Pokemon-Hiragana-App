import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../services/sound_service.dart';
import '../widgets/drill_suggestion_dialog.dart';
import '../widgets/pokemon_widgets.dart';
import '../widgets/drill_widgets.dart';
import 'drill_round_mixin.dart';

// ─── データ ───────────────────────────────────────────────────────────────────

typedef _Pair = (String hira, String kata);

const List<_Pair> _allPairs = [
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

// ─── 問題データ ───────────────────────────────────────────────────────────────

class _Question {
  final String hira;
  final String correctKata;
  final List<String> choices;

  const _Question({
    required this.hira,
    required this.correctKata,
    required this.choices,
  });
}

// ─── メイン画面 ───────────────────────────────────────────────────────────────

class KatakanaQuizScreen extends StatefulWidget {
  const KatakanaQuizScreen({super.key});

  @override
  State<KatakanaQuizScreen> createState() => _KatakanaQuizScreenState();
}

class _KatakanaQuizScreenState extends State<KatakanaQuizScreen>
    with DrillRoundMixin {
  static const _passingScore = 5;

  int _totalAsked = 0;

  late _Question _current;
  String? _selectedAnswer;

  bool _exhausted = false;

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    _startRound();
    if (drillIsExhausted('katakana_quiz')) {
      _exhausted = true;
      drillPendingRewardPokemon = null;
    }
    AnalyticsService.logScreenView('katakana_quiz');
  }

  void _startRound() {
    _totalAsked = 0;
    drillCorrectCount = 0;
    _current = _generateQuestion();
    _selectedAnswer = null;
    drillPickPendingPokemon();
  }

  _Question _generateQuestion() {
    final pair = _allPairs[drillRandom.nextInt(_allPairs.length)];
    final correct = pair.$2;
    final wrongs = (List<_Pair>.from(_allPairs)
          ..removeWhere((p) => p.$2 == correct)
          ..shuffle(drillRandom))
        .take(3)
        .map((p) => p.$2)
        .toList();
    final choices = [correct, ...wrongs]..shuffle(drillRandom);
    return _Question(hira: pair.$1, correctKata: correct, choices: choices);
  }

  void _onAnswerTap(String choice) {
    if (_selectedAnswer != null) return;
    final correct = choice == _current.correctKata;
    setState(() {
      _selectedAnswer = choice;
      if (correct) drillCorrectCount++;
      _totalAsked++;
    });
    if (correct) SoundService.playStrokeComplete();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (drillCorrectCount >= _passingScore) {
        _endRound();
      } else {
        setState(() {
          _current = _generateQuestion();
          _selectedAnswer = null;
        });
      }
    });
  }

  void _endRound() {
    final reward = drillSaveRewardPokemon();
    final shiny = drillPendingIsShiny;
    StorageService.incrementDailyPlays('katakana_quiz');
    AnalyticsService.logKatakanaRoundComplete(
      score: drillCorrectCount,
      passed: true,
      isShiny: shiny,
    );
    if (reward != null) {
      AnalyticsService.logPokemonCaught(
        pokemonName: reward.katakana,
        isShiny: shiny,
        source: 'katakana_quiz',
      );
      DailyStatsService.incrementCaught();
    }
    final sessions =
        DailyStatsService.incrementDrillSessions('katakana_quiz');
    setState(() {
      drillRewardPokemon = reward;
      drillRewardIsShiny = shiny;
      drillShowRoundResult = true;
    });
    if (sessions > 0 && sessions % 5 == 0) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          showDrillSuggestionDialog(context, 'katakana_quiz', sessions);
        }
      });
    }
  }

  void _nextRound() {
    if (drillIsExhausted('katakana_quiz')) {
      setState(() {
        drillShowRoundResult = false;
        _exhausted = true;
        drillPendingRewardPokemon = null;
      });
      return;
    }
    setState(() {
      drillCorrectCount = 0;
      drillShowRoundResult = false;
      _exhausted = false;
      drillRewardPokemon = null;
      drillRewardIsShiny = false;
      drillPendingRewardPokemon = null;
      drillPendingIsShiny = false;
      _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 220,
            child: _LeftPanel(
              totalAsked: _totalAsked,
              correctCount: drillCorrectCount,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                  child: drillShowRoundResult
                      ? const SizedBox.shrink()
                      : _exhausted
                          ? _KatakanaExhaustedPanel(
                              onBack: () => Navigator.pop(context))
                          : _QuestionPanel(
                              question: _current,
                              totalAsked: _totalAsked,
                              selectedAnswer: _selectedAnswer,
                              onAnswerTap: _onAnswerTap,
                            ),
                ),
                if (drillShowRoundResult)
                  DrillRoundResultOverlay(
                    scoreLabel: '$drillCorrectCount / $_passingScore もんだい せいかい！',
                    starsTotal: _passingScore,
                    starsFilled: drillCorrectCount,
                    passed: true,
                    rewardPokemon: drillRewardPokemon,
                    isShiny: drillRewardIsShiny,
                    onNext: _nextRound,
                  ),
                if (drillShowRoundResult && drillRewardPokemon != null)
                  Positioned.fill(
                    child: ConfettiOverlay(baseColor: drillRewardPokemon!.color),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 今日おしまいパネル ──────────────────────────────────────────────────────────

class _KatakanaExhaustedPanel extends StatelessWidget {
  final VoidCallback onBack;

  const _KatakanaExhaustedPanel({required this.onBack});

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

// ─── 左パネル ─────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final int totalAsked;
  final int correctCount;
  final bool showResult;
  final int caughtCount;
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;
  final VoidCallback onBack;
  final PokemonEntry? pendingRewardPokemon;
  final bool pendingIsShiny;

  const _LeftPanel({
    required this.totalAsked,
    required this.correctCount,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 16),

                // タイトル
                const Center(
                  child: Text(
                    'カタカナをよもう！',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9F43),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 正解数プログレス
                Center(
                  child: Text(
                    'もんだい ${totalAsked + 1} もんめ',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGray,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < correctCount;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 36,
                        color: filled
                            ? const Color(0xFFFF9F43)
                            : const Color(0xFFDDDDDD),
                      ),
                    );
                  }),
                ),
                Center(
                  child: Text(
                    '$correctCount / 5 せいかい',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textGray,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 報酬ポケモンプレビュー
                if (!showResult && pendingRewardPokemon != null)
                  DrillPokemonRewardPreview(
                    pokemon: pendingRewardPokemon!,
                    isShiny: pendingIsShiny,
                  ),

                const Spacer(flex: 1),

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

// ─── 問題パネル ───────────────────────────────────────────────────────────────

class _QuestionPanel extends StatelessWidget {
  final _Question question;
  final int totalAsked;
  final String? selectedAnswer;
  final ValueChanged<String> onAnswerTap;

  const _QuestionPanel({
    required this.question,
    required this.totalAsked,
    required this.selectedAnswer,
    required this.onAnswerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'もんだい ${totalAsked + 1} もんめ',
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.textGray,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'この ひらがなの カタカナは どれ？',
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(height: 8),

        // ひらがな表示
        Expanded(
          flex: 4,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                question.hira,
                style: const TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),

        // 4択グリッド
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: DrillChoiceButton(
                              choice: question.choices[0],
                              correct: question.correctKata,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 60)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: DrillChoiceButton(
                              choice: question.choices[1],
                              correct: question.correctKata,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 60)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: DrillChoiceButton(
                              choice: question.choices[2],
                              correct: question.correctKata,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 60)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: DrillChoiceButton(
                              choice: question.choices[3],
                              correct: question.correctKata,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 60)),
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
