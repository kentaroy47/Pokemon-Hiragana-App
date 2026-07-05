import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/pokemon_repository.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../services/sound_service.dart';
import '../widgets/pokemon_widgets.dart';
import 'drill_round_mixin.dart';

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

const Set<int> _kLegendaryIds = {
  144, 145, 146, 150, 151,
  243, 244, 245, 249, 250, 251,
  377, 378, 379, 380, 381, 382, 383, 384, 385,
  483, 484, 485, 486, 487, 488, 490, 491, 492, 493,
  643, 644, 645, 646,
  716, 717, 718,
  791, 792, 800,
  888, 889, 890, 898,
  1007, 1008, 1024,
};

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

// ─── フェーズ ─────────────────────────────────────────────────────────────────

enum _Phase { answering, ballReady, throwing, caught, missed, stageResult, gameOver }

// ─── メイン画面 ───────────────────────────────────────────────────────────────

class PokemonCatchScreen extends StatefulWidget {
  const PokemonCatchScreen({super.key});

  @override
  State<PokemonCatchScreen> createState() => _PokemonCatchScreenState();
}

class _PokemonCatchScreenState extends State<PokemonCatchScreen>
    with DrillRoundMixin, TickerProviderStateMixin {
  static const _questionsPerBall = 3;

  int _stage = 0;
  _Phase _phase = _Phase.answering;
  int _correctInBall = 0;
  int _missCount = 0;

  late _Quiz _currentQuiz;
  String? _selectedAnswer;

  // ── ポケモン ──
  late PokemonEntry _stageA;
  late PokemonEntry _stageB;
  late PokemonEntry _stageC;
  bool _stageCIsShiny = false;
  bool _stageCRevealed = false;
  final List<(PokemonEntry, bool)> _caught = [];

  // ── アニメーション ──
  late AnimationController _throwCtrl;
  late Animation<double> _throwT;
  bool _showThrowBall = false;

  // ── 投げ方向（外れ時に斜めに飛ばす） ──
  double _throwOffsetX = 0;

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    _initPokemon();
    _currentQuiz = _generateQuiz();
    _throwCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _throwT = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _throwCtrl, curve: Curves.easeOut),
    );
    AnalyticsService.logScreenView('pokemon_catch');
  }

  @override
  void dispose() {
    _throwCtrl.dispose();
    super.dispose();
  }

  void _initPokemon() {
    final all = List<PokemonEntry>.from(PokemonRepository.all)..shuffle(drillRandom);
    _stageA = all[0];
    _stageB = all[1];
    final legendaries = PokemonRepository.all
        .where((p) => _kLegendaryIds.contains(p.pokedexId))
        .toList()
      ..shuffle(drillRandom);
    if (legendaries.isNotEmpty && drillRandom.nextBool()) {
      _stageC = legendaries.first;
      _stageCIsShiny = drillRollShiny();
    } else {
      _stageC = all[2];
      _stageCIsShiny = true;
    }
  }

  PokemonEntry get _currentPokemon => [_stageA, _stageB, _stageC][_stage];
  bool get _isSecretStage => _stage == 2;

  double get _catchRate => switch (_missCount) {
        0 => 0.70,
        1 => 0.85,
        _ => 1.00,
      };

  // ── 問題生成 ──

  _Quiz _generateQuiz() {
    final type = drillRandom.nextInt(3);
    return switch (type) {
      0 => _generateHiraToKata(),
      1 => _generateAddition(),
      _ => _generateSubtraction(),
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
      prompt: 'カタカナは どれ？',
      choices: choices,
      correctIndex: choices.indexOf(correct),
    );
  }

  _Quiz _generateAddition() {
    final a = drillRandom.nextInt(8) + 2;
    final b = drillRandom.nextInt(8) + 1;
    final answer = a + b;
    final wrongs = <int>{};
    var t = 0;
    while (wrongs.length < 3 && t++ < 40) {
      final w = answer + drillRandom.nextInt(5) - 2;
      if (w > 0 && w != answer) wrongs.add(w);
    }
    final choices = ([answer, ...wrongs.take(3)]..shuffle(drillRandom))
        .map((n) => '$n')
        .toList();
    return _Quiz(
      displayBig: '$a＋$b',
      prompt: 'こたえは？',
      choices: choices,
      correctIndex: choices.indexOf('$answer'),
    );
  }

  _Quiz _generateSubtraction() {
    final a = drillRandom.nextInt(10) + 5;
    final b = drillRandom.nextInt(a - 1) + 1;
    final answer = a - b;
    final wrongs = <int>{};
    var t = 0;
    while (wrongs.length < 3 && t++ < 40) {
      final w = answer + drillRandom.nextInt(5) - 2;
      if (w >= 0 && w != answer) wrongs.add(w);
    }
    final choices = ([answer, ...wrongs.take(3)]..shuffle(drillRandom))
        .map((n) => '$n')
        .toList();
    return _Quiz(
      displayBig: '$a－$b',
      prompt: 'こたえは？',
      choices: choices,
      correctIndex: choices.indexOf('$answer'),
    );
  }

  // ── 回答処理 ──

  void _onAnswer(String choice) {
    if (_selectedAnswer != null || _phase != _Phase.answering) return;
    final isCorrect = choice == _currentQuiz.choices[_currentQuiz.correctIndex];
    if (isCorrect) SoundService.playStrokeComplete();
    setState(() => _selectedAnswer = choice);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (isCorrect && _correctInBall + 1 >= _questionsPerBall) {
        setState(() {
          _correctInBall = 0;
          _phase = _Phase.ballReady;
          _showThrowBall = true;
          _selectedAnswer = null;
        });
      } else {
        setState(() {
          if (isCorrect) _correctInBall++;
          _selectedAnswer = null;
          _currentQuiz = _generateQuiz();
        });
      }
    });
  }

  // ── ボール投げ ──

  void _onThrow() {
    if (_phase != _Phase.ballReady) return;
    final caught = drillRandom.nextDouble() < _catchRate;
    // 外れた場合はボールが斜めに飛ぶ
    _throwOffsetX = caught ? 0 : (drillRandom.nextBool() ? 0.25 : -0.25);
    setState(() => _phase = _Phase.throwing);
    _throwCtrl.reset();
    _throwCtrl.forward().then((_) {
      if (!mounted) return;
      if (caught) {
        SoundService.playCatch();
        setState(() {
          _phase = _Phase.caught;
          _showThrowBall = false;
        });
        Future.delayed(const Duration(milliseconds: 1400), _registerCatch);
      } else {
        setState(() {
          _phase = _Phase.missed;
          _showThrowBall = false;
          _missCount++;
        });
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          setState(() {
            _phase = _Phase.answering;
            _selectedAnswer = null;
            _currentQuiz = _generateQuiz();
          });
        });
      }
    });
  }

  void _registerCatch() {
    if (!mounted) return;
    final pokemon = _currentPokemon;
    final isShiny = _isSecretStage ? _stageCIsShiny : false;
    _caught.add((pokemon, isShiny));
    drillCaughtPokemon.add(pokemon);
    StorageService.saveCaughtNames(
        drillCaughtPokemon.map((p) => p.katakana).toList());
    StorageService.addTodayCaughtName(pokemon.katakana);
    if (isShiny) {
      drillShinyCaughtNames.add(pokemon.katakana);
      StorageService.saveShinyCaughtNames(drillShinyCaughtNames);
    }
    DailyStatsService.incrementCaught();
    AnalyticsService.logPokemonCaught(
      pokemonName: pokemon.katakana,
      isShiny: isShiny,
      source: 'pokemon_catch',
    );
    if (_isSecretStage) setState(() => _stageCRevealed = true);
    setState(() => _phase = _Phase.stageResult);
  }

  void _nextStage() {
    if (_stage + 1 >= 3) {
      StorageService.incrementDailyPlays('pokemon_catch');
      DailyStatsService.incrementDrillSessions('pokemon_catch');
      DailyStatsService.recordStreak();
      setState(() => _phase = _Phase.gameOver);
    } else {
      setState(() {
        _stage++;
        _phase = _Phase.answering;
        _missCount = 0;
        _correctInBall = 0;
        _selectedAnswer = null;
        _showThrowBall = false;
        _currentQuiz = _generateQuiz();
      });
      _throwCtrl.reset();
    }
  }

  void _restart() {
    setState(() {
      _stage = 0;
      _phase = _Phase.answering;
      _missCount = 0;
      _correctInBall = 0;
      _selectedAnswer = null;
      _showThrowBall = false;
      _caught.clear();
      _stageCRevealed = false;
    });
    _throwCtrl.reset();
    _initPokemon();
    _currentQuiz = _generateQuiz();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 240,
            child: _LeftPanel(
              stage: _stage,
              phase: _phase,
              correctInBall: _correctInBall,
              quiz: _currentQuiz,
              selectedAnswer: _selectedAnswer,
              onAnswer: _onAnswer,
              onBack: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: _RightPanel(
              stage: _stage,
              phase: _phase,
              pokemon: _currentPokemon,
              isSecretStage: _isSecretStage,
              isRevealed: _stageCRevealed,
              isShiny: _isSecretStage ? _stageCIsShiny : false,
              showBall: _showThrowBall,
              throwT: _throwT,
              throwOffsetX: _throwOffsetX,
              onThrow: _onThrow,
              onNextStage: _nextStage,
              caught: _caught,
              onRestart: _restart,
              onBack: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 左パネル ─────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final int stage;
  final _Phase phase;
  final int correctInBall;
  final _Quiz quiz;
  final String? selectedAnswer;
  final void Function(String) onAnswer;
  final VoidCallback onBack;

  const _LeftPanel({
    required this.stage,
    required this.phase,
    required this.correctInBall,
    required this.quiz,
    required this.selectedAnswer,
    required this.onAnswer,
    required this.onBack,
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
                const SizedBox(height: 12),
                _StageIndicator(stage: stage),
                const SizedBox(height: 16),

                if (phase == _Phase.answering || phase == _Phase.missed) ...[
                  if (phase == _Phase.missed)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Text(
                        'おしい！\nもう一かいチャレンジ！',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF9900),
                        ),
                      ),
                    ),
                  _QuizContent(
                    quiz: quiz,
                    selectedAnswer: selectedAnswer,
                    onAnswer: onAnswer,
                  ),
                ] else if (phase == _Phase.ballReady)
                  const _BallReadyHint()
                else if (phase == _Phase.caught || phase == _Phase.stageResult)
                  const _CaughtHint()
                else if (phase == _Phase.throwing)
                  const _ThrowingHint()
                else
                  const SizedBox.shrink(),

                const Spacer(),

                if (phase == _Phase.answering || phase == _Phase.missed)
                  _BallProgress(correctInBall: correctInBall),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageIndicator extends StatelessWidget {
  final int stage;
  const _StageIndicator({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final done = i < stage;
        final current = i == stage;
        final isSecret = i == 2;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? const Color(0xFF4CAF50)
                      : current
                          ? const Color(0xFFE84B4B)
                          : const Color(0xFFEEEEEE),
                ),
                child: Center(
                  child: Text(
                    done ? '✓' : isSecret && !current ? '？' : '${i + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: (done || current) ? Colors.white : AppTheme.textGray,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isSecret ? 'ひみつ' : 'ステージ${i + 1}',
                style: TextStyle(
                  fontSize: 9,
                  color: current ? const Color(0xFFE84B4B) : AppTheme.textGray,
                  fontWeight: current ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _QuizContent extends StatelessWidget {
  final _Quiz quiz;
  final String? selectedAnswer;
  final void Function(String) onAnswer;

  const _QuizContent({
    required this.quiz,
    required this.selectedAnswer,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 80,
          alignment: Alignment.center,
          child: Text(
            quiz.displayBig,
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
              height: 1.0,
            ),
          ),
        ),
        Text(
          quiz.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppTheme.textGray),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 2.2,
          children: quiz.choices.map((choice) {
            final answered = selectedAnswer != null;
            final isSelected = selectedAnswer == choice;
            final isCorrectChoice =
                choice == quiz.choices[quiz.correctIndex];
            Color? bg;
            Color textColor = AppTheme.darkText;
            if (answered) {
              if (isSelected && isCorrectChoice) {
                bg = const Color(0xFF4CAF50);
                textColor = Colors.white;
              } else if (isSelected) {
                bg = const Color(0xFFE84B4B);
                textColor = Colors.white;
              } else if (isCorrectChoice) {
                bg = const Color(0xFF4CAF50);
                textColor = Colors.white;
              }
            }
            return GestureDetector(
              onTap: () => onAnswer(choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: bg ?? AppTheme.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        bg != null ? Colors.transparent : const Color(0xFFCCCCCC),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    choice,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BallReadyHint extends StatelessWidget {
  const _BallReadyHint();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 12),
        Text('⚾', style: TextStyle(fontSize: 48)),
        SizedBox(height: 8),
        Text(
          'ボールをゲット！',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE84B4B),
          ),
        ),
        SizedBox(height: 4),
        Text(
          '右の画面をスワイプして\nなげてみよう！',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.textGray),
        ),
      ],
    );
  }
}

class _ThrowingHint extends StatelessWidget {
  const _ThrowingHint();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 20),
        Text('🎯', style: TextStyle(fontSize: 48)),
        SizedBox(height: 8),
        Text(
          'なげた！',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
      ],
    );
  }
}

class _CaughtHint extends StatelessWidget {
  const _CaughtHint();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 20),
        Text('✨', style: TextStyle(fontSize: 48)),
        SizedBox(height: 8),
        Text(
          'ゲットできた！',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }
}

class _BallProgress extends StatelessWidget {
  final int correctInBall;
  const _BallProgress({required this.correctInBall});

  @override
  Widget build(BuildContext context) {
    final remaining = 3 - correctInBall;
    return Column(
      children: [
        Text(
          'あと $remaining もん とくと ボールがもらえる',
          style: const TextStyle(fontSize: 10, color: AppTheme.textGray),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final filled = i < correctInBall;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: filled ? 1.0 : 0.25,
                child: const Pokeball(
                  color: Color(0xFFCC2222),
                  size: 20,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── 右パネル ─────────────────────────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final int stage;
  final _Phase phase;
  final PokemonEntry pokemon;
  final bool isSecretStage;
  final bool isRevealed;
  final bool isShiny;
  final bool showBall;
  final Animation<double> throwT;
  final double throwOffsetX;
  final VoidCallback onThrow;
  final VoidCallback onNextStage;
  final List<(PokemonEntry, bool)> caught;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  const _RightPanel({
    required this.stage,
    required this.phase,
    required this.pokemon,
    required this.isSecretStage,
    required this.isRevealed,
    required this.isShiny,
    required this.showBall,
    required this.throwT,
    required this.throwOffsetX,
    required this.onThrow,
    required this.onNextStage,
    required this.caught,
    required this.onRestart,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (phase == _Phase.gameOver) {
      return _GameOverPanel(
          caught: caught, onRestart: onRestart, onBack: onBack);
    }

    final showSilhouette = isSecretStage && !isRevealed;
    final isCaught = phase == _Phase.caught || phase == _Phase.stageResult;
    final showConfetti = isCaught && isSecretStage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanEnd: (details) {
          if (details.velocity.pixelsPerSecond.dy < -250 &&
              phase == _Phase.ballReady) {
            onThrow();
          }
        },
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final pokemonAreaH = h * 0.62;
          final ballAreaH = h * 0.38;

          return Stack(
            children: [
              // ── ポケモン表示エリア ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: pokemonAreaH,
                child: _PokemonDisplay(
                  pokemon: pokemon,
                  showSilhouette: showSilhouette,
                  phase: phase,
                  isShiny: isShiny,
                ),
              ),

              // ── ボール投げエリア ──
              Positioned(
                top: pokemonAreaH,
                left: 0,
                right: 0,
                height: ballAreaH,
                child: _ThrowArea(
                  phase: phase,
                  showBall: showBall && phase != _Phase.throwing,
                  onThrow: onThrow,
                  onNextStage: onNextStage,
                  isSecretStage: isSecretStage,
                  isShiny: isShiny,
                ),
              ),

              // ── ボール飛翔アニメーション ──
              if (phase == _Phase.throwing)
                AnimatedBuilder(
                  animation: throwT,
                  builder: (context, _) {
                    final t = throwT.value;
                    const ballSize = 52.0;
                    final startY = pokemonAreaH + ballAreaH * 0.5 - ballSize / 2;
                    final endY = pokemonAreaH * 0.1 - ballSize / 2;
                    final startX = w / 2 - ballSize / 2;
                    final endX = startX + throwOffsetX * w;
                    final currentY = startY + (endY - startY) * t;
                    final currentX = startX + (endX - startX) * t;
                    final currentSize = ballSize - (ballSize * 0.45 * t);
                    return Positioned(
                      left: currentX + (ballSize - currentSize) / 2,
                      top: currentY + (ballSize - currentSize) / 2,
                      child: Pokeball(
                        color: const Color(0xFFCC2222),
                        size: currentSize,
                      ),
                    );
                  },
                ),

              // ── コンフェッティ（シークレットゲット時） ──
              if (showConfetti)
                Positioned.fill(
                  child: ConfettiOverlay(baseColor: pokemon.color),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _PokemonDisplay extends StatelessWidget {
  final PokemonEntry pokemon;
  final bool showSilhouette;
  final _Phase phase;
  final bool isShiny;

  const _PokemonDisplay({
    required this.pokemon,
    required this.showSilhouette,
    required this.phase,
    required this.isShiny,
  });

  @override
  Widget build(BuildContext context) {
    final isCaught = phase == _Phase.caught || phase == _Phase.stageResult;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isShiny && !showSilhouette)
            const Text('✨', style: TextStyle(fontSize: 20, height: 1.2)),

          // ポケモン画像
          SizedBox(
            width: 180,
            height: 180,
            child: showSilhouette
                ? ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF1A1A2E),
                      BlendMode.srcATop,
                    ),
                    child: PokemonImage(
                        pokemon: pokemon, size: 160, isShiny: false),
                  )
                : PokemonImage(pokemon: pokemon, size: 160, isShiny: isShiny),
          ),

          const SizedBox(height: 6),

          // ポケモン名
          Text(
            showSilhouette ? '？？？？？' : pokemon.hiragana,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: showSilhouette ? AppTheme.textGray : AppTheme.darkText,
              letterSpacing: showSilhouette ? 4 : 0,
            ),
          ),

          if (isCaught && isShiny)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'いろちがい！',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold),
              ),
            ),

          if (isCaught)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ゲット！',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThrowArea extends StatelessWidget {
  final _Phase phase;
  final bool showBall;
  final VoidCallback onThrow;
  final VoidCallback onNextStage;
  final bool isSecretStage;
  final bool isShiny;

  const _ThrowArea({
    required this.phase,
    required this.showBall,
    required this.onThrow,
    required this.onNextStage,
    required this.isSecretStage,
    required this.isShiny,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (phase == _Phase.answering)
          const Text(
            'もんだいを といて\nボールをゲットしよう！',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textGray),
          )
        else if (phase == _Phase.ballReady) ...[
          const Text(
            '↑ スワイプして なげよう！',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE84B4B),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onThrow,
            child: const Pokeball(color: Color(0xFFCC2222), size: 64),
          ),
        ] else if (phase == _Phase.missed) ...[
          const Text(
            'はずれた…',
            style: TextStyle(
                fontSize: 16, color: Color(0xFFFF9900), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'もんだいを ときなおして\nもう一かい なげよう！',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textGray),
          ),
        ] else if (phase == _Phase.stageResult) ...[
          ElevatedButton(
            onPressed: onNextStage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE84B4B),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 3,
            ),
            child: Text(
              phase == _Phase.stageResult ? 'つぎへ →' : 'つぎへ →',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── ゲームオーバー（全ステージ完了） ─────────────────────────────────────────

class _GameOverPanel extends StatelessWidget {
  final List<(PokemonEntry, bool)> caught;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  const _GameOverPanel({
    required this.caught,
    required this.onRestart,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ぜんぶ ゲットできた！',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: caught.map(((PokemonEntry, bool) e) {
                  final (pokemon, isShiny) = e;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (isShiny)
                          const Text('✨',
                              style: TextStyle(fontSize: 20, height: 1.2)),
                        PokemonImage(
                            pokemon: pokemon, size: 110, isShiny: isShiny),
                        const SizedBox(height: 4),
                        Text(pokemon.hiragana,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        if (isShiny)
                          const Text('いろちがい',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFFFFD700))),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: onRestart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE84B4B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('もう一度',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.darkText,
                      side: const BorderSide(color: Color(0xFFCCCCCC)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('もどる', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (caught.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiOverlay(
                  baseColor: caught.last.$1.color),
            ),
          ),
      ],
    );
  }
}
