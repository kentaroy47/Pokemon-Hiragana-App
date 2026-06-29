import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/kanji_data.dart';
import '../data/pokemon_data.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../services/sound_service.dart';
import '../widgets/drill_suggestion_dialog.dart';
import '../widgets/pokemon_widgets.dart';
import '../widgets/drill_widgets.dart';
import 'drill_round_mixin.dart';

// ─── 問題データ ───────────────────────────────────────────────────────────────

class _Question {
  final KanjiEntry entry;
  final List<String> choices;
  final String correct;

  const _Question({
    required this.entry,
    required this.choices,
    required this.correct,
  });
}

// ─── メイン画面 ───────────────────────────────────────────────────────────────

class KanjiReadingQuizScreen extends StatefulWidget {
  const KanjiReadingQuizScreen({super.key});

  @override
  State<KanjiReadingQuizScreen> createState() => _KanjiReadingQuizScreenState();
}

class _KanjiReadingQuizScreenState extends State<KanjiReadingQuizScreen>
    with DrillRoundMixin {
  static const _passingScore = 5;

  int _totalAsked = 0;
  late _Question _current;
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    _startRound();
    AnalyticsService.logScreenView('kanji_read');
  }

  void _startRound() {
    _totalAsked = 0;
    drillCorrectCount = 0;
    _current = _generateQuestion();
    _selectedAnswer = null;
    drillPickPendingPokemon();
  }

  _Question _generateQuestion() {
    final idx = drillRandom.nextInt(kanjiList1.length);
    final entry = kanjiList1[idx];
    final correct = entry.reading;

    final pool = List<KanjiEntry>.from(kanjiList1)
      ..removeWhere((e) => e.reading == correct)
      ..shuffle(drillRandom);

    final choices = [correct, ...pool.take(3).map((e) => e.reading)]
      ..shuffle(drillRandom);

    return _Question(entry: entry, choices: choices, correct: correct);
  }

  void _onAnswerTap(String choice) {
    if (_selectedAnswer != null) return;
    final isCorrect = choice == _current.correct;
    setState(() {
      _selectedAnswer = choice;
      if (isCorrect) drillCorrectCount++;
      _totalAsked++;
    });
    if (isCorrect) SoundService.playStrokeComplete();

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
    StorageService.incrementDailyPlays('kanji_read');
    if (reward != null) {
      AnalyticsService.logPokemonCaught(
        pokemonName: reward.katakana,
        isShiny: shiny,
        source: 'kanji_read',
      );
      DailyStatsService.incrementCaught();
    }
    final sessions = DailyStatsService.incrementDrillSessions('kanji_read');
    setState(() {
      drillRewardPokemon = reward;
      drillRewardIsShiny = shiny;
      drillShowRoundResult = true;
    });
    if (sessions > 0 && sessions % 5 == 0) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) showDrillSuggestionDialog(context, 'kanji_read', sessions);
      });
    }
  }

  void _nextRound() {
    setState(() {
      drillCorrectCount = 0;
      drillShowRoundResult = false;
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
          constraints:
              BoxConstraints(minHeight: MediaQuery.of(context).size.height - 16),
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
                    'かんじをよもう！',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Center(
                  child: Text(
                    'もんだい ${totalAsked + 1} もんめ',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textGray,
                      fontWeight: FontWeight.bold,
                    ),
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
                            ? const Color(0xFF2E7D32)
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
        const SizedBox(height: 6),
        const Text(
          'この かんじの よみかたは どれ？',
          style: TextStyle(fontSize: 15, color: AppTheme.darkText),
        ),
        const SizedBox(height: 8),

        // 漢字表示
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
                question.entry.kanji,
                style: const TextStyle(
                  fontSize: 100,
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
                          correct: question.correct,
                          selected: selectedAnswer,
                          onTap: onAnswerTap,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DrillChoiceButton(
                          choice: question.choices[1],
                          correct: question.correct,
                          selected: selectedAnswer,
                          onTap: onAnswerTap,
                          fontSize: 28,
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
                          choice: question.choices[2],
                          correct: question.correct,
                          selected: selectedAnswer,
                          onTap: onAnswerTap,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DrillChoiceButton(
                          choice: question.choices[3],
                          correct: question.correct,
                          selected: selectedAnswer,
                          onTap: onAnswerTap,
                          fontSize: 28,
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
