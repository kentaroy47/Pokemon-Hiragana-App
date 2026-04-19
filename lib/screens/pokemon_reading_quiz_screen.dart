import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../services/sound_service.dart';
import '../services/pokemon_repository.dart';
import '../widgets/drill_suggestion_dialog.dart';
import '../widgets/pokemon_widgets.dart';
import '../widgets/drill_widgets.dart';
import 'drill_round_mixin.dart';

// ─── モード ───────────────────────────────────────────────────────────────────

enum PokemonReadingMode { hiragana, katakana }

// ─── 問題データ ───────────────────────────────────────────────────────────────

class _Question {
  final PokemonEntry correct;
  final List<PokemonEntry> choices; // 4 choices including correct
  const _Question({required this.correct, required this.choices});
}

// ─── メイン画面 ───────────────────────────────────────────────────────────────

class PokemonReadingQuizScreen extends StatefulWidget {
  final PokemonReadingMode mode;
  const PokemonReadingQuizScreen({super.key, required this.mode});

  @override
  State<PokemonReadingQuizScreen> createState() =>
      _PokemonReadingQuizScreenState();
}

class _PokemonReadingQuizScreenState extends State<PokemonReadingQuizScreen>
    with DrillRoundMixin {
  static const _passingScore = 5;

  late _Question _current;
  String? _selectedAnswer;
  bool _exhausted = false;

  String get _modeKey => widget.mode == PokemonReadingMode.hiragana
      ? 'pokemon_hira_quiz'
      : 'pokemon_kata_quiz';

  String _nameOf(PokemonEntry p) =>
      widget.mode == PokemonReadingMode.hiragana ? p.hiragana : p.katakana;

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    _startRound();
    if (drillIsExhausted(_modeKey)) {
      _exhausted = true;
      drillPendingRewardPokemon = null;
    }
    AnalyticsService.logScreenView(_modeKey);
  }

  void _startRound() {
    drillCorrectCount = 0;
    _current = _generateQuestion();
    _selectedAnswer = null;
    drillPickPendingPokemon();
  }

  _Question _generateQuestion() {
    final pool = PokemonRepository.all;
    final correctIdx = drillRandom.nextInt(pool.length);
    final correct = pool[correctIdx];
    final wrongs = (List<PokemonEntry>.from(pool)
          ..removeWhere((p) => p.katakana == correct.katakana)
          ..shuffle(drillRandom))
        .take(3)
        .toList();
    final choices = [correct, ...wrongs]..shuffle(drillRandom);
    return _Question(correct: correct, choices: choices);
  }

  void _onAnswerTap(String name) {
    if (_selectedAnswer != null) return;
    final correct = name == _nameOf(_current.correct);
    setState(() {
      _selectedAnswer = name;
      if (correct) drillCorrectCount++;
    });
    if (correct) SoundService.playStrokeComplete();

    Future.delayed(const Duration(milliseconds: 800), () {
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
    StorageService.incrementDailyPlays(_modeKey);
    if (reward != null) {
      AnalyticsService.logPokemonCaught(
        pokemonName: reward.katakana,
        isShiny: shiny,
        source: _modeKey,
      );
      DailyStatsService.incrementCaught();
    }
    final sessions = DailyStatsService.incrementDrillSessions(_modeKey);
    setState(() {
      drillRewardPokemon = reward;
      drillRewardIsShiny = shiny;
      drillShowRoundResult = true;
    });
    if (sessions > 0 && sessions % 5 == 0) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) showDrillSuggestionDialog(context, _modeKey, sessions);
      });
    }
  }

  void _nextRound() {
    if (drillIsExhausted(_modeKey)) {
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
    final isHira = widget.mode == PokemonReadingMode.hiragana;
    final titleColor = isHira ? AppTheme.pinkAccent : AppTheme.blueAccent;
    final title = isHira ? 'ひらがなをよもう！' : 'カタカナをよもう！';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 220,
            child: _LeftPanel(
              title: title,
              titleColor: titleColor,
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
                          ? _ExhaustedPanel(
                              onBack: () => Navigator.pop(context))
                          : _QuestionPanel(
                              question: _current,
                              selectedAnswer: _selectedAnswer,
                              onAnswerTap: _onAnswerTap,
                              nameOf: _nameOf,
                            ),
                ),
                if (drillShowRoundResult)
                  DrillRoundResultOverlay(
                    scoreLabel:
                        '$drillCorrectCount / $_passingScore もんだい せいかい！',
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

// ─── 左パネル ─────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final String title;
  final Color titleColor;
  final int correctCount;
  final bool showResult;
  final int caughtCount;
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;
  final VoidCallback onBack;
  final PokemonEntry? pendingRewardPokemon;
  final bool pendingIsShiny;

  const _LeftPanel({
    required this.title,
    required this.titleColor,
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
                Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < correctCount;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
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
  final String? selectedAnswer;
  final ValueChanged<String> onAnswerTap;
  final String Function(PokemonEntry) nameOf;

  const _QuestionPanel({
    required this.question,
    required this.selectedAnswer,
    required this.onAnswerTap,
    required this.nameOf,
  });

  @override
  Widget build(BuildContext context) {
    final correctName = nameOf(question.correct);
    return Column(
      children: [
        const Text(
          'この ポケモンの なまえは どれ？',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(height: 8),

        // ポケモン画像
        Expanded(
          flex: 4,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
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
              child: PokemonImage(
                pokemon: question.correct,
                size: 160,
                isShiny: false,
              ),
            ),
          ),
        ),

        // 4択グリッド
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: DrillChoiceButton(
                              choice: nameOf(question.choices[0]),
                              correct: correctName,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: DrillChoiceButton(
                              choice: nameOf(question.choices[1]),
                              correct: correctName,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 22)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: DrillChoiceButton(
                              choice: nameOf(question.choices[2]),
                              correct: correctName,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: DrillChoiceButton(
                              choice: nameOf(question.choices[3]),
                              correct: correctName,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 22)),
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
