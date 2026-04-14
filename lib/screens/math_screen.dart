import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/math_data.dart';
import '../data/pokemon_data.dart';
import '../services/storage_service.dart';
import '../services/sound_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../widgets/drill_suggestion_dialog.dart';
import '../widgets/pokemon_widgets.dart';
import '../widgets/drill_widgets.dart';
import 'drill_round_mixin.dart';

// ─── さんすう画面 ────────────────────────────────────────────────────────────

class MathScreen extends StatefulWidget {
  const MathScreen({super.key});

  @override
  State<MathScreen> createState() => _MathScreenState();
}

class _MathScreenState extends State<MathScreen> with DrillRoundMixin {
  static const _correctsNeeded = 5;

  MathLevel _level = MathLevel.addSimple;
  int _totalAsked = 0;

  late MathProblem _current;
  late List<int> _choices;
  int? _selectedAnswer;

  bool _levelExhausted = false;

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    _startRound();
    if (drillIsExhausted('math_${_level.name}')) {
      _levelExhausted = true;
      drillPendingRewardPokemon = null;
    }
    AnalyticsService.logScreenView('math');
  }

  void _startRound() {
    drillCorrectCount = 0;
    _totalAsked = 0;
    drillPickPendingPokemon();
    _current = MathData.generate(_level, drillRandom);
    _choices = MathData.generateChoices(_current.answer, drillRandom);
    _selectedAnswer = null;
  }

  void _loadNextQuestion() {
    _current = MathData.generate(_level, drillRandom);
    _choices = MathData.generateChoices(_current.answer, drillRandom);
    _selectedAnswer = null;
  }

  void _onAnswerTap(int choice) {
    if (_selectedAnswer != null) return;
    final correct = choice == _current.answer;
    setState(() {
      _selectedAnswer = choice;
      _totalAsked++;
      if (correct) drillCorrectCount++;
    });
    if (correct) SoundService.playStrokeComplete();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (drillCorrectCount >= _correctsNeeded) {
        _endRound();
      } else {
        setState(() => _loadNextQuestion());
      }
    });
  }

  void _endRound() {
    final reward = drillSaveRewardPokemon();
    final shiny = drillPendingIsShiny;
    StorageService.incrementDailyPlays('math_${_level.name}');
    final rounds = StorageService.loadMathRoundsCompleted() + 1;
    StorageService.saveMathRoundsCompleted(rounds);
    AnalyticsService.logMathRoundComplete(
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
        source: 'math',
      );
      DailyStatsService.incrementCaught();
    }
    final sessions = DailyStatsService.incrementDrillSessions('math');
    setState(() {
      drillRewardPokemon = reward;
      drillRewardIsShiny = shiny;
      drillShowRoundResult = true;
    });
    if (sessions > 0 && sessions % 5 == 0) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) showDrillSuggestionDialog(context, 'math', sessions);
      });
    }
  }

  void _nextRound() {
    if (drillIsExhausted('math_${_level.name}')) {
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

  void _selectLevel(MathLevel newLevel) {
    if (drillIsExhausted('math_${newLevel.name}')) return;
    setState(() {
      _level = newLevel;
      drillCorrectCount = 0;
      drillShowRoundResult = false;
      drillRewardPokemon = null;
      _levelExhausted = false;
      _totalAsked = 0;
      _current = MathData.generate(newLevel, drillRandom);
      _choices = MathData.generateChoices(_current.answer, drillRandom);
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
          // ─── 左パネル ───
          SizedBox(
            width: 260,
            child: _LeftPanel(
              level: _level,
              correctCount: drillCorrectCount,
              showResult: drillShowRoundResult,
              caughtCount: drillCaughtPokemon.length,
              onBack: () => Navigator.pop(context),
              onLevelSelect: _selectLevel,
              caughtPokemon: drillCaughtPokemon,
              shinyCaughtNames: drillShinyCaughtNames,
              pendingRewardPokemon: drillPendingRewardPokemon,
              pendingIsShiny: drillPendingIsShiny,
            ),
          ),
          // ─── 右パネル ───
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                  child: drillShowRoundResult
                      ? const SizedBox.shrink()
                      : _levelExhausted
                          ? _MathExhaustedPanel(levelLabel: _level.label)
                          : _QuestionPanel(
                              level: _level,
                              problem: _current,
                              choices: _choices,
                              selectedAnswer: _selectedAnswer,
                              correctCount: drillCorrectCount,
                              totalAsked: _totalAsked,
                              onAnswerTap: _onAnswerTap,
                            ),
                ),
                if (drillShowRoundResult)
                  DrillRoundResultOverlay(
                    scoreLabel: '$_totalAsked もんで クリア！',
                    starsTotal: 5,
                    starsFilled: 5,
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
  final MathLevel level;
  final int correctCount;
  final bool showResult;
  final int caughtCount;
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;
  final VoidCallback onBack;
  final ValueChanged<MathLevel> onLevelSelect;
  final PokemonEntry? pendingRewardPokemon;
  final bool pendingIsShiny;

  const _LeftPanel({
    required this.level,
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
                // 戻るボタン
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
                const SizedBox(height: 8),

                // レベル選択リスト
                Builder(builder: (context) {
                  final limitEnabled = StorageService.loadDailyLimitEnabled();
                  final limitCount = limitEnabled ? StorageService.loadDailyLimitCount() : 0;
                  return Column(
                    children: MathLevel.values.map((l) {
                      final selected = l == level;
                      final color = _levelColor(l);
                      final plays = limitEnabled ? StorageService.loadDailyPlays('math_${l.name}') : 0;
                      final exhausted = limitEnabled && plays >= limitCount;
                      final remaining = limitEnabled ? (limitCount - plays).clamp(0, limitCount) : -1;
                      return GestureDetector(
                        onTap: exhausted || selected ? null : () => onLevelSelect(l),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: exhausted
                                ? const Color(0xFFF0F0F0)
                                : selected ? color : color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: exhausted
                                  ? const Color(0xFFCCCCCC)
                                  : selected ? color : color.withValues(alpha: 0.3),
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
                                  color: exhausted ? AppTheme.textGray : selected ? Colors.white : color,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: exhausted ? AppTheme.textGray : selected ? Colors.white : AppTheme.darkText,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              if (exhausted)
                                const Icon(Icons.lock_rounded, color: AppTheme.textGray, size: 13)
                              else if (selected)
                                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14)
                              else if (remaining >= 0)
                                Text(
                                  'あと$remaining',
                                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
                const SizedBox(height: 8),

                // 正解進捗（5つの星）
                Center(
                  child: Text(
                    'せいかい',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGray,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = showResult || i < correctCount;
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled
                          ? const Color(0xFFF5C518)
                          : const Color(0xFFCCCCCC),
                      size: 34,
                    );
                  }),
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

  Color _levelColor(MathLevel l) {
    switch (l) {
      case MathLevel.addSimple:
        return AppTheme.blueAccent;
      case MathLevel.subSimple:
        return AppTheme.pinkAccent;
      case MathLevel.addCarry:
        return const Color(0xFF5CAD5C);
      case MathLevel.subBorrow:
        return const Color(0xFFE67E22);
      case MathLevel.mixed:
        return const Color(0xFF9C27B0);
    }
  }
}

// ─── 今日おしまいパネル ──────────────────────────────────────────────────────────

class _MathExhaustedPanel extends StatelessWidget {
  final String levelLabel;

  const _MathExhaustedPanel({required this.levelLabel});

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
  final MathLevel level;
  final MathProblem problem;
  final List<int> choices;
  final int? selectedAnswer;
  final int correctCount;
  final int totalAsked;
  final ValueChanged<int> onAnswerTap;

  const _QuestionPanel({
    required this.level,
    required this.problem,
    required this.choices,
    required this.selectedAnswer,
    required this.correctCount,
    required this.totalAsked,
    required this.onAnswerTap,
  });

  Color get _accentColor {
    switch (level) {
      case MathLevel.addSimple:
        return AppTheme.blueAccent;
      case MathLevel.subSimple:
        return AppTheme.pinkAccent;
      case MathLevel.addCarry:
        return const Color(0xFF5CAD5C);
      case MathLevel.subBorrow:
        return const Color(0xFFE67E22);
      case MathLevel.mixed:
        return const Color(0xFF9C27B0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'せいかい $correctCount / 5　（もんだい $totalAsked もん め）',
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.textGray,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 4,
          child: Center(child: _buildQuestion()),
        ),
        Expanded(
          flex: 5,
          child: _ChoiceGrid(
            choices: choices,
            correctAnswer: problem.answer,
            selectedAnswer: selectedAnswer,
            accentColor: _accentColor,
            onTap: onAnswerTap,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion() {
    if (level.showDots) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DotGroup(count: problem.a, color: AppTheme.blueAccent),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  problem.op,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
              _DotGroup(count: problem.b, color: AppTheme.pinkAccent),
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text(
                  '= ?',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${problem.a} ${problem.op} ${problem.b} = ?',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
        ],
      );
    } else {
      return Text(
        '${problem.a} ${problem.op} ${problem.b} = ?',
        style: const TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          color: AppTheme.darkText,
        ),
      );
    }
  }
}

// ─── ドット表示 ───────────────────────────────────────────────────────────────

class _DotGroup extends StatelessWidget {
  final int count;
  final Color color;

  const _DotGroup({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: List.generate(
        count,
        (_) => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// ─── 4択グリッド ──────────────────────────────────────────────────────────────

class _ChoiceGrid extends StatelessWidget {
  final List<int> choices;
  final int correctAnswer;
  final int? selectedAnswer;
  final Color accentColor;
  final ValueChanged<int> onTap;

  const _ChoiceGrid({
    required this.choices,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildButton(choices[0])),
                const SizedBox(width: 12),
                Expanded(child: _buildButton(choices[1])),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildButton(choices[2])),
                const SizedBox(width: 12),
                Expanded(child: _buildButton(choices[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(int c) {
    return DrillChoiceButton(
      choice: '$c',
      correct: '$correctAnswer',
      selected: selectedAnswer?.toString(),
      onTap: (s) => onTap(int.parse(s)),
      fontSize: 52,
    );
  }
}
