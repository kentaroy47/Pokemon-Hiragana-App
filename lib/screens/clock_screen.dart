import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../services/sound_service.dart';
import '../widgets/drill_suggestion_dialog.dart';
import '../widgets/pokemon_widgets.dart';
import '../widgets/clock_face.dart';
import '../widgets/drill_widgets.dart';
import 'drill_round_mixin.dart';

// ─── レベル定義 ───────────────────────────────────────────────────────────────

enum ClockLevel { exact, half, quarter }

extension _ClockLevelX on ClockLevel {
  int get number => index + 1;

  String get label {
    switch (this) {
      case ClockLevel.exact:
        return 'ちょうど';
      case ClockLevel.half:
        return 'ちょうど・はん';
      case ClockLevel.quarter:
        return '15ふん きざみ';
    }
  }

  int randomMinute(math.Random rng) {
    switch (this) {
      case ClockLevel.exact:
        return 0;
      case ClockLevel.half:
        return [0, 30][rng.nextInt(2)];
      case ClockLevel.quarter:
        return [0, 15, 30, 45][rng.nextInt(4)];
    }
  }
}

// ─── 問題データ ───────────────────────────────────────────────────────────────

class _ClockQuestion {
  final int hour;
  final int minute;
  final List<String> choices;

  const _ClockQuestion({
    required this.hour,
    required this.minute,
    required this.choices,
  });

  String get correctAnswer => _timeLabel(hour, minute);
}

String _timeLabel(int h, int m) {
  if (m == 0) return '$h じ ちょうど';
  if (m == 30) return '$h じ はん';
  return '$h じ $m ふん';
}

// ─── メイン画面 ───────────────────────────────────────────────────────────────

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> with DrillRoundMixin {
  static const _passingScore = 5;

  ClockLevel _level = ClockLevel.exact;
  int _totalAsked = 0;

  late _ClockQuestion _current;
  String? _selectedAnswer;

  bool _levelExhausted = false;

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    _startRound();
    if (drillIsExhausted('clock_${_level.name}')) {
      _levelExhausted = true;
      drillPendingRewardPokemon = null;
    }
    AnalyticsService.logScreenView('clock');
  }

  void _startRound() {
    _totalAsked = 0;
    drillCorrectCount = 0;
    _current = _generateQuestion(_level);
    _selectedAnswer = null;
    drillPickPendingPokemon();
  }

  _ClockQuestion _generateQuestion(ClockLevel level) {
    final h = drillRandom.nextInt(12) + 1;
    final m = level.randomMinute(drillRandom);
    final correct = _timeLabel(h, m);
    final wrongs = <String>{};
    while (wrongs.length < 3) {
      final wh = drillRandom.nextInt(12) + 1;
      final wm = level.randomMinute(drillRandom);
      final w = _timeLabel(wh, wm);
      if (w != correct) wrongs.add(w);
    }
    final choices = [correct, ...wrongs]..shuffle(drillRandom);
    return _ClockQuestion(hour: h, minute: m, choices: choices);
  }

  void _onAnswerTap(String choice) {
    if (_selectedAnswer != null) return;
    final correct = choice == _current.correctAnswer;
    setState(() {
      _selectedAnswer = choice;
      if (correct) drillCorrectCount++;
      _totalAsked++;
    });
    if (correct) SoundService.playStrokeComplete();

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (drillCorrectCount >= _passingScore) {
        _endRound();
      } else {
        setState(() {
          _current = _generateQuestion(_level);
          _selectedAnswer = null;
        });
      }
    });
  }

  void _endRound() {
    final reward = drillSaveRewardPokemon();
    final shiny = drillPendingIsShiny;
    StorageService.incrementDailyPlays('clock_${_level.name}');
    final rounds = StorageService.loadClockRoundsCompleted() + 1;
    StorageService.saveClockRoundsCompleted(rounds);
    AnalyticsService.logClockRoundComplete(
      level: _level.name,
      score: drillCorrectCount,
      passed: true,
      isShiny: shiny,
      roundsCompleted: rounds,
    );
    if (reward != null) {
      AnalyticsService.logPokemonCaught(
        pokemonName: reward.katakana,
        isShiny: shiny,
        source: 'clock',
      );
      DailyStatsService.incrementCaught();
    }
    final sessions = DailyStatsService.incrementDrillSessions('clock');
    setState(() {
      drillRewardPokemon = reward;
      drillRewardIsShiny = shiny;
      drillShowRoundResult = true;
    });
    if (sessions > 0 && sessions % 5 == 0) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) showDrillSuggestionDialog(context, 'clock', sessions);
      });
    }
  }

  void _nextRound() {
    if (drillIsExhausted('clock_${_level.name}')) {
      setState(() {
        drillShowRoundResult = false;
        _levelExhausted = true;
        drillPendingRewardPokemon = null;
      });
      return;
    }
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

  void _selectLevel(ClockLevel newLevel) {
    if (drillIsExhausted('clock_${newLevel.name}')) return;
    setState(() {
      _level = newLevel;
      _totalAsked = 0;
      drillCorrectCount = 0;
      drillShowRoundResult = false;
      drillRewardPokemon = null;
      _levelExhausted = false;
      _current = _generateQuestion(newLevel);
      _selectedAnswer = null;
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
            width: 260,
            child: _LeftPanel(
              level: _level,
              totalAsked: _totalAsked,
              correctCount: drillCorrectCount,
              showResult: drillShowRoundResult,
              caughtCount: drillCaughtPokemon.length,
              caughtPokemon: drillCaughtPokemon,
              shinyCaughtNames: drillShinyCaughtNames,
              onBack: () => Navigator.pop(context),
              onLevelSelect: _selectLevel,
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
                      : _levelExhausted
                          ? _ExhaustedPanel(levelLabel: _level.label)
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
                    child: ConfettiOverlay(
                        baseColor: drillRewardPokemon!.color),
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
  final ClockLevel level;
  final int totalAsked;
  final int correctCount;
  final bool showResult;
  final int caughtCount;
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;
  final VoidCallback onBack;
  final ValueChanged<ClockLevel> onLevelSelect;
  final PokemonEntry? pendingRewardPokemon;
  final bool pendingIsShiny;

  const _LeftPanel({
    required this.level,
    required this.totalAsked,
    required this.correctCount,
    required this.showResult,
    required this.caughtCount,
    required this.caughtPokemon,
    required this.shinyCaughtNames,
    required this.onBack,
    required this.onLevelSelect,
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
                const SizedBox(height: 8),

                // レベル選択
                Builder(builder: (context) {
                  final limitEnabled = StorageService.loadDailyLimitEnabled();
                  final limitCount = limitEnabled ? StorageService.loadDailyLimitCount() : 0;
                  return Column(
                    children: ClockLevel.values.map((l) {
                      final selected = l == level;
                      const color = Color(0xFF48BEFF);
                      final plays = limitEnabled ? StorageService.loadDailyPlays('clock_${l.name}') : 0;
                      final exhausted = limitEnabled && plays >= limitCount;
                      final remaining = limitEnabled ? (limitCount - plays).clamp(0, limitCount) : -1;
                      return GestureDetector(
                        onTap: exhausted || selected ? null : () => onLevelSelect(l),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: exhausted
                                ? const Color(0xFFF0F0F0)
                                : selected
                                    ? color
                                    : color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: exhausted
                                  ? const Color(0xFFCCCCCC)
                                  : selected
                                      ? color
                                      : color.withValues(alpha: 0.3),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Lv.${l.number}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: exhausted
                                      ? AppTheme.textGray
                                      : selected ? Colors.white : color,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: exhausted
                                        ? AppTheme.textGray
                                        : selected
                                            ? Colors.white
                                            : AppTheme.darkText,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              if (exhausted)
                                const Icon(Icons.lock_rounded,
                                    color: AppTheme.textGray, size: 13)
                              else if (selected)
                                const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 14)
                              else if (remaining >= 0)
                                Text(
                                  'あと$remaining',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
                const SizedBox(height: 8),

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
                            ? const Color(0xFF48BEFF)
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

// ─── 今日おしまいパネル ──────────────────────────────────────────────────────────

class _ExhaustedPanel extends StatelessWidget {
  final String levelLabel;

  const _ExhaustedPanel({required this.levelLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌙', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(
            '「$levelLabel」は\nきょうは おしまい！',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ほかのレベルをえらんでね',
            style: TextStyle(fontSize: 14, color: AppTheme.textGray),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
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

// ─── 問題パネル ───────────────────────────────────────────────────────────────

class _QuestionPanel extends StatelessWidget {
  final _ClockQuestion question;
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
        const SizedBox(height: 4),
        const Text(
          'なんじ？',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 5,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClockFaceWidget(
                  hour: question.hour, minute: question.minute),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                        child: DrillChoiceButton(
                            choice: question.choices[0],
                            correct: question.correctAnswer,
                            selected: selectedAnswer,
                            onTap: onAnswerTap)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: DrillChoiceButton(
                            choice: question.choices[1],
                            correct: question.correctAnswer,
                            selected: selectedAnswer,
                            onTap: onAnswerTap)),
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
                            correct: question.correctAnswer,
                            selected: selectedAnswer,
                            onTap: onAnswerTap)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: DrillChoiceButton(
                            choice: question.choices[3],
                            correct: question.correctAnswer,
                            selected: selectedAnswer,
                            onTap: onAnswerTap)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

