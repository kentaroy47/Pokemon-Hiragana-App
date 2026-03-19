import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/math_data.dart';
import '../data/pokemon_data.dart';
import '../services/pokemon_repository.dart';
import '../services/storage_service.dart';
import '../services/sound_service.dart';
import '../widgets/pokemon_widgets.dart';

// ─── さんすう画面 ────────────────────────────────────────────────────────────

class MathScreen extends StatefulWidget {
  const MathScreen({super.key});

  @override
  State<MathScreen> createState() => _MathScreenState();
}

class _MathScreenState extends State<MathScreen> {
  static const _questionsPerRound = 5;
  static const _passingScore = 3;

  final _random = math.Random();

  MathLevel _level = MathLevel.addSimple;
  int _questionIndex = 0;
  int _correctCount = 0;

  late List<MathProblem> _problems;
  late List<int> _choices;
  int? _selectedAnswer; // null = 未回答

  bool _showRoundResult = false;
  PokemonEntry? _rewardPokemon;
  int _prevPokemonIndex = -1;

  final List<PokemonEntry> _caughtPokemon = [];

  MathProblem get _current => _problems[_questionIndex];
  bool get _passed => _correctCount >= _passingScore;

  @override
  void initState() {
    super.initState();
    // ゲット済みポケモンをストレージから復元（pokemon_screen と共有）
    final lookup = {for (final p in PokemonRepository.all) p.katakana: p};
    for (final name in StorageService.loadCaughtNames()) {
      final entry = lookup[name];
      if (entry != null) _caughtPokemon.add(entry);
    }
    _startRound();
  }

  void _startRound() {
    _problems = MathData.generateSet(_level, _random);
    _loadQuestion(0);
  }

  void _loadQuestion(int index) {
    _questionIndex = index;
    _choices = MathData.generateChoices(_current.answer, _random);
    _selectedAnswer = null;
  }

  void _onAnswerTap(int choice) {
    if (_selectedAnswer != null) return;
    final correct = choice == _current.answer;
    setState(() {
      _selectedAnswer = choice;
      if (correct) _correctCount++;
    });
    if (correct) SoundService.playStrokeComplete();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_questionIndex + 1 < _questionsPerRound) {
        setState(() => _loadQuestion(_questionIndex + 1));
      } else {
        _endRound();
      }
    });
  }

  void _endRound() {
    PokemonEntry? reward;
    if (_passed) {
      final pool = PokemonRepository.all;
      int idx;
      do {
        idx = _random.nextInt(pool.length);
      } while (idx == _prevPokemonIndex && pool.length > 1);
      _prevPokemonIndex = idx;
      reward = pool[idx];
      _caughtPokemon.add(reward);
      StorageService.saveCaughtNames(
          _caughtPokemon.map((p) => p.katakana).toList());
      SoundService.playCatch();
    }
    setState(() {
      _rewardPokemon = reward;
      _showRoundResult = true;
    });
  }

  void _nextRound() {
    setState(() {
      if (_passed) _level = _level.next;
      _correctCount = 0;
      _showRoundResult = false;
      _rewardPokemon = null;
      _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // ─── 左パネル ───
          SizedBox(
            width: 260,
            child: _LeftPanel(
              level: _level,
              questionIndex: _questionIndex,
              correctCount: _correctCount,
              showResult: _showRoundResult,
              caughtCount: _caughtPokemon.length,
              onBack: () => Navigator.pop(context),
            ),
          ),
          // ─── 右パネル ───
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                  child: _showRoundResult
                      ? const SizedBox.shrink()
                      : _QuestionPanel(
                          level: _level,
                          problem: _current,
                          choices: _choices,
                          selectedAnswer: _selectedAnswer,
                          questionIndex: _questionIndex,
                          onAnswerTap: _onAnswerTap,
                        ),
                ),
                if (_showRoundResult)
                  _RoundResultOverlay(
                    correctCount: _correctCount,
                    total: _questionsPerRound,
                    passed: _passed,
                    rewardPokemon: _rewardPokemon,
                    onNext: _nextRound,
                  ),
                if (_showRoundResult && _passed && _rewardPokemon != null)
                  Positioned.fill(
                    child: ConfettiOverlay(
                        baseColor: _rewardPokemon!.color),
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
  final int questionIndex;
  final int correctCount;
  final bool showResult;
  final int caughtCount;
  final VoidCallback onBack;

  const _LeftPanel({
    required this.level,
    required this.questionIndex,
    required this.correctCount,
    required this.showResult,
    required this.caughtCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 戻るボタン
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.home_outlined, size: 16),
                label:
                    const Text('もどる', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.darkText,
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // レベルバッジ
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _levelColor(level),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Lv.${level.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    level.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 問題進捗（5つの丸）
          Center(
            child: Text(
              'もんだい',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textGray,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final done = i < (showResult ? 5 : questionIndex);
              final current = !showResult && i == questionIndex;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: done
                      ? AppTheme.greenStroke
                      : current
                          ? _levelColor(level).withValues(alpha: 0.2)
                          : const Color(0xFFEEEEEE),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: current
                        ? _levelColor(level)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check,
                        size: 18, color: Colors.white)
                    : current
                        ? Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _levelColor(level),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textGray,
                              ),
                            ),
                          ),
              );
            }),
          ),

          const Spacer(),

          // ゲット済みポケモン数
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
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

// ─── 問題パネル ───────────────────────────────────────────────────────────────

class _QuestionPanel extends StatelessWidget {
  final MathLevel level;
  final MathProblem problem;
  final List<int> choices;
  final int? selectedAnswer;
  final int questionIndex;
  final ValueChanged<int> onAnswerTap;

  const _QuestionPanel({
    required this.level,
    required this.problem,
    required this.choices,
    required this.selectedAnswer,
    required this.questionIndex,
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
        // 問題番号
        Text(
          'もんだい ${questionIndex + 1} / 5',
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.textGray,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // 問題表示
        Expanded(
          flex: 4,
          child: Center(
            child: _buildQuestion(),
          ),
        ),

        // 4択ボタン
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
          // ドット表示
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
          // 数字表示
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

  Widget _buildButton(int c) {
    Color bg = Colors.white;
    Color border = const Color(0xFFDDDDDD);
    Color textColor = AppTheme.darkText;
    Widget? overlay;

    if (selectedAnswer != null) {
      if (c == correctAnswer) {
        bg = const Color(0xFFE8F5E9);
        border = const Color(0xFF66BB6A);
        textColor = const Color(0xFF2E7D32);
        overlay = const Positioned(
          top: 8,
          right: 8,
          child: Icon(Icons.check_circle_rounded,
              color: Color(0xFF66BB6A), size: 22),
        );
      } else if (c == selectedAnswer) {
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
      onTap: selectedAnswer == null ? () => onTap(c) : null,
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
                '$c',
                style: TextStyle(
                  fontSize: 52,
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
}

// ─── ラウンド結果オーバーレイ ──────────────────────────────────────────────────

class _RoundResultOverlay extends StatefulWidget {
  final int correctCount;
  final int total;
  final bool passed;
  final PokemonEntry? rewardPokemon;
  final VoidCallback onNext;

  const _RoundResultOverlay({
    required this.correctCount,
    required this.total,
    required this.passed,
    required this.rewardPokemon,
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
                    // スコア表示
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
                      // ポケモンゲット演出
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: Stack(
                          children: [
                            PokemonImage(pokemon: pokemon, size: 130),
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
                      Text(
                        'ゲット！',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.pinkAccent,
                          shadows: [
                            Shadow(
                              color: AppTheme.pinkAccent
                                  .withValues(alpha: 0.25),
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
                      // 不合格
                      const Text('😢',
                          style: TextStyle(fontSize: 56)),
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
