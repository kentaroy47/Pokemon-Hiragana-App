import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/pokemon_repository.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../services/sound_service.dart';
import '../widgets/drill_suggestion_dialog.dart';
import '../widgets/pokemon_widgets.dart';
import 'pokemon_screen.dart' show PokedexDialog;

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
  final List<String> choices; // 4択（シャッフル済み）

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

class _ClockScreenState extends State<ClockScreen> {
  static const _passingScore = 5;

  final _random = math.Random();

  ClockLevel _level = ClockLevel.exact;
  int _totalAsked = 0;
  int _correctCount = 0;

  late _ClockQuestion _current;
  String? _selectedAnswer;

  bool _showRoundResult = false;
  PokemonEntry? _rewardPokemon;
  bool _rewardIsShiny = false;
  int _prevPokemonIndex = -1;
  bool _levelExhausted = false;

  PokemonEntry? _pendingRewardPokemon;
  bool _pendingIsShiny = false;

  final List<PokemonEntry> _caughtPokemon = [];
  final Set<String> _shinyCaughtNames = {};

  @override
  void initState() {
    super.initState();
    final lookup = {for (final p in PokemonRepository.all) p.katakana: p};
    for (final name in StorageService.loadCaughtNames()) {
      final entry = lookup[name];
      if (entry != null) _caughtPokemon.add(entry);
    }
    _shinyCaughtNames.addAll(StorageService.loadShinyCaughtNames());
    _startRound();
    if (_isExhausted(_level)) {
      _levelExhausted = true;
      _pendingRewardPokemon = null;
    }
    AnalyticsService.logScreenView('clock');
  }

  bool _isExhausted(ClockLevel level) {
    if (!StorageService.loadDailyLimitEnabled()) return false;
    final limit = StorageService.loadDailyLimitCount();
    return StorageService.loadDailyPlays('clock_${level.name}') >= limit;
  }

  void _startRound() {
    _totalAsked = 0;
    _correctCount = 0;
    _current = _generateQuestion(_level);
    _selectedAnswer = null;
    final pool = PokemonRepository.all;
    int idx;
    do {
      idx = _random.nextInt(pool.length);
    } while (idx == _prevPokemonIndex && pool.length > 1);
    _prevPokemonIndex = idx;
    _pendingRewardPokemon = pool[idx];
    _pendingIsShiny = _random.nextDouble() < 0.2;
  }

  _ClockQuestion _generateQuestion(ClockLevel level) {
    final h = _random.nextInt(12) + 1;
    final m = level.randomMinute(_random);
    final correct = _timeLabel(h, m);
    final wrongs = <String>{};
    while (wrongs.length < 3) {
      final wh = _random.nextInt(12) + 1;
      final wm = level.randomMinute(_random);
      final w = _timeLabel(wh, wm);
      if (w != correct) wrongs.add(w);
    }
    final choices = [correct, ...wrongs]..shuffle(_random);
    return _ClockQuestion(hour: h, minute: m, choices: choices);
  }

  void _onAnswerTap(String choice) {
    if (_selectedAnswer != null) return;
    final correct = choice == _current.correctAnswer;
    setState(() {
      _selectedAnswer = choice;
      if (correct) _correctCount++;
      _totalAsked++;
    });
    if (correct) SoundService.playStrokeComplete();

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_correctCount >= _passingScore) {
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
    PokemonEntry? reward;
    final shiny = _pendingIsShiny;
    if (_pendingRewardPokemon != null) {
      reward = _pendingRewardPokemon;
      _caughtPokemon.add(reward!);
      StorageService.saveCaughtNames(
          _caughtPokemon.map((p) => p.katakana).toList());
      if (shiny) {
        _shinyCaughtNames.add(reward.katakana);
        StorageService.saveShinyCaughtNames(_shinyCaughtNames);
      }
      SoundService.playCatch();
    }
    StorageService.incrementDailyPlays('clock_${_level.name}');
    final rounds = StorageService.loadClockRoundsCompleted() + 1;
    StorageService.saveClockRoundsCompleted(rounds);
    AnalyticsService.logClockRoundComplete(
      level: _level.name,
      score: _correctCount,
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
      _rewardPokemon = reward;
      _rewardIsShiny = shiny;
      _showRoundResult = true;
    });
    if (sessions > 0 && sessions % 5 == 0) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          showDrillSuggestionDialog(context, 'clock', sessions);
        }
      });
    }
  }

  void _nextRound() {
    if (_isExhausted(_level)) {
      setState(() {
        _showRoundResult = false;
        _levelExhausted = true;
        _pendingRewardPokemon = null;
      });
      return;
    }
    setState(() {
      _correctCount = 0;
      _showRoundResult = false;
      _rewardPokemon = null;
      _rewardIsShiny = false;
      _pendingRewardPokemon = null;
      _pendingIsShiny = false;
      _startRound();
    });
  }

  void _selectLevel(ClockLevel newLevel) {
    if (_isExhausted(newLevel)) return;
    setState(() {
      _level = newLevel;
      _totalAsked = 0;
      _correctCount = 0;
      _showRoundResult = false;
      _rewardPokemon = null;
      _levelExhausted = false;
      _current = _generateQuestion(newLevel);
      _selectedAnswer = null;
      // _pendingRewardPokemon and _pendingIsShiny are kept unchanged
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
              correctCount: _correctCount,
              showResult: _showRoundResult,
              caughtCount: _caughtPokemon.length,
              caughtPokemon: _caughtPokemon,
              shinyCaughtNames: _shinyCaughtNames,
              onBack: () => Navigator.pop(context),
              onLevelSelect: _selectLevel,
              pendingRewardPokemon: _pendingRewardPokemon,
              pendingIsShiny: _pendingIsShiny,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                  child: _showRoundResult
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
                if (_showRoundResult)
                  _RoundResultOverlay(
                    correctCount: _correctCount,
                    total: _passingScore,
                    passed: true,
                    rewardPokemon: _rewardPokemon,
                    isShiny: _rewardIsShiny,
                    onNext: _nextRound,
                  ),
                if (_showRoundResult && _rewardPokemon != null)
                  Positioned.fill(
                    child: ConfettiOverlay(baseColor: _rewardPokemon!.color),
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
                                  style: TextStyle(
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
                if (!showResult && pendingRewardPokemon != null) ...[
                  Center(
                    child: Text(
                      'ゲットのチャンス！',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: pendingRewardPokemon!.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: PokemonImage(
                      pokemon: pendingRewardPokemon!,
                      size: 100,
                      isShiny: pendingIsShiny,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      pendingRewardPokemon!.katakana,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),
                  if (pendingIsShiny)
                    const Center(
                      child: Text(
                        '✨ いろちがい！',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],

                const Spacer(flex: 1),

                // ゲット済みポケモン数
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        'ゲット：$caughtCount',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: caughtPokemon.isEmpty
                            ? null
                            : () => showDialog(
                                  context: context,
                                  builder: (_) => PokedexDialog(
                                    caughtPokemon:
                                        List.unmodifiable(caughtPokemon),
                                    shinyCaughtNames: shinyCaughtNames,
                                  ),
                                ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: caughtPokemon.isEmpty
                                ? const Color(0xFFEEEEEE)
                                : AppTheme.blueAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 22,
                            color: caughtPokemon.isEmpty
                                ? AppTheme.textGray
                                : AppTheme.blueAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
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

        // 時計の文字盤
        Expanded(
          flex: 5,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: _ClockFace(
                  hour: question.hour, minute: question.minute),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 4択ボタン
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                        child: _ChoiceButton(
                            choice: question.choices[0],
                            correct: question.correctAnswer,
                            selected: selectedAnswer,
                            onTap: onAnswerTap)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _ChoiceButton(
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
                        child: _ChoiceButton(
                            choice: question.choices[2],
                            correct: question.correctAnswer,
                            selected: selectedAnswer,
                            onTap: onAnswerTap)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _ChoiceButton(
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

class _ChoiceButton extends StatelessWidget {
  final String choice;
  final String correct;
  final String? selected;
  final ValueChanged<String> onTap;

  const _ChoiceButton({
    required this.choice,
    required this.correct,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white;
    Color border = const Color(0xFFDDDDDD);
    Color textColor = AppTheme.darkText;
    Widget? overlay;

    if (selected != null) {
      if (choice == correct) {
        bg = const Color(0xFFE8F5E9);
        border = const Color(0xFF66BB6A);
        textColor = const Color(0xFF2E7D32);
        overlay = const Positioned(
          top: 8,
          right: 8,
          child: Icon(Icons.check_circle_rounded,
              color: Color(0xFF66BB6A), size: 22),
        );
      } else if (choice == selected) {
        bg = const Color(0xFFFFEBEE);
        border = const Color(0xFFEF9A9A);
        textColor = const Color(0xFFC62828);
        overlay = const Positioned(
          top: 8,
          right: 8,
          child: Icon(Icons.cancel_rounded,
              color: Color(0xFFEF9A9A), size: 22),
        );
      }
    }

    return GestureDetector(
      onTap: selected == null ? () => onTap(choice) : null,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                choice,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
          if (overlay != null) overlay,
        ],
      ),
    );
  }
}

// ─── 時計の文字盤 ─────────────────────────────────────────────────────────────

class _ClockFace extends StatelessWidget {
  final int hour;
  final int minute;

  const _ClockFace({required this.hour, required this.minute});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _ClockPainter(hour: hour, minute: minute),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final int hour;
  final int minute;

  const _ClockPainter({required this.hour, required this.minute});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 背景
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    // 外枠
    canvas.drawCircle(
      center,
      radius - 3,
      Paint()
        ..color = const Color(0xFF2D3436)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke,
    );

    // 数字
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 1; i <= 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final pos = Offset(
        center.dx + (radius - 26) * math.cos(angle),
        center.dy + (radius - 26) * math.sin(angle),
      );
      tp.text = TextSpan(
        text: '$i',
        style: TextStyle(
          fontSize: radius * 0.16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2D3436),
        ),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // 目盛り
    for (int i = 0; i < 60; i++) {
      final angle = i * 6 * math.pi / 180;
      final inner = i % 5 == 0 ? radius - 16 : radius - 8;
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(angle),
            center.dy + inner * math.sin(angle)),
        Offset(center.dx + (radius - 4) * math.cos(angle),
            center.dy + (radius - 4) * math.sin(angle)),
        Paint()
          ..color = const Color(0xFF636E72)
          ..strokeWidth = i % 5 == 0 ? 2.5 : 1,
      );
    }

    // 分針
    final minuteAngle = (minute * 6 - 90) * math.pi / 180;
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius - 18) * math.cos(minuteAngle),
        center.dy + (radius - 18) * math.sin(minuteAngle),
      ),
      Paint()
        ..color = const Color(0xFF2D3436)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // 時針
    final hourAngle =
        ((hour % 12 + minute / 60) * 30 - 90) * math.pi / 180;
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.52) * math.cos(hourAngle),
        center.dy + (radius * 0.52) * math.sin(hourAngle),
      ),
      Paint()
        ..color = const Color(0xFF2D3436)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    // 中心点
    canvas.drawCircle(center, 7, Paint()..color = const Color(0xFFFF6B6B));
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.hour != hour || old.minute != minute;
}

// ─── ラウンド結果オーバーレイ ──────────────────────────────────────────────────

class _RoundResultOverlay extends StatefulWidget {
  final int correctCount;
  final int total;
  final bool passed;
  final PokemonEntry? rewardPokemon;
  final bool isShiny;
  final VoidCallback onNext;

  const _RoundResultOverlay({
    required this.correctCount,
    required this.total,
    required this.passed,
    required this.rewardPokemon,
    required this.isShiny,
    required this.onNext,
  });

  @override
  State<_RoundResultOverlay> createState() => _RoundResultOverlayState();
}

class _RoundResultOverlayState extends State<_RoundResultOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<double> _spin;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0, 0.3, curve: Curves.easeIn)),
    );
    _scale = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _spin = Tween<double>(begin: 0, end: math.pi * 6).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0, 0.55, curve: Curves.easeOut)),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pokemon = widget.rewardPokemon;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _fade.value,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Transform.scale(
                scale: _scale.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(widget.total, (i) {
                        final filled = i < widget.correctCount;
                        return Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: filled
                              ? const Color(0xFFF5C518)
                              : const Color(0xFFCCCCCC),
                          size: 40,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.correctCount} / ${widget.total} もんだい せいかい！',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (widget.passed && pokemon != null) ...[
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: Stack(
                          children: [
                            PokemonImage(
                                pokemon: pokemon,
                                size: 130,
                                isShiny: widget.isShiny),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Transform.rotate(
                                angle: _spin.value,
                                child: Pokeball(
                                    color: pokemon.color, size: 36),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${pokemon.katakana}を',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: pokemon.color,
                        ),
                      ),
                      if (widget.isShiny)
                        const Text(
                          '✨ いろちがい！ ✨',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      Text(
                        'ゲット！',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.pinkAccent,
                          shadows: [
                            Shadow(
                              color:
                                  AppTheme.pinkAccent.withValues(alpha: 0.25),
                              offset: const Offset(0, 5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        pokemon.hiragana,
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppTheme.textGray,
                          letterSpacing: 4,
                        ),
                      ),
                    ] else if (!widget.passed) ...[
                      const Text('😢', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 8),
                      const Text(
                        'もう すこし！\nもう いちど やってみよう',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                          height: 1.5,
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    ElevatedButton.icon(
                      onPressed: widget.onNext,
                      icon: Text(
                        widget.passed ? 'つぎへ' : 'もういちど',
                        style: const TextStyle(fontSize: 18),
                      ),
                      label: const Icon(Icons.arrow_forward, size: 20),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.passed
                            ? AppTheme.pinkAccent
                            : AppTheme.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
