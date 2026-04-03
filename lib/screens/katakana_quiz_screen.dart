import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/pokemon_repository.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/sound_service.dart';
import '../widgets/pokemon_widgets.dart';
import 'pokemon_screen.dart' show PokedexDialog;

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

class _KatakanaQuizScreenState extends State<KatakanaQuizScreen> {
  static const _passingScore = 3;

  final _random = math.Random();

  int _questionIndex = 0;
  int _correctCount = 0;

  late List<_Question> _problems;
  String? _selectedAnswer;

  bool _showRoundResult = false;
  PokemonEntry? _rewardPokemon;
  bool _rewardIsShiny = false;
  int _prevPokemonIndex = -1;

  PokemonEntry? _pendingRewardPokemon;
  bool _pendingIsShiny = false;

  final List<PokemonEntry> _caughtPokemon = [];
  final Set<String> _shinyCaughtNames = {};

  _Question get _current => _problems[_questionIndex];
  bool get _passed => _correctCount >= _passingScore;

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
    AnalyticsService.logScreenView('katakana_quiz');
  }

  void _startRound() {
    _problems = _generateProblems();
    final pool = PokemonRepository.all;
    int idx;
    do {
      idx = _random.nextInt(pool.length);
    } while (idx == _prevPokemonIndex && pool.length > 1);
    _prevPokemonIndex = idx;
    _pendingRewardPokemon = pool[idx];
    _pendingIsShiny = _random.nextDouble() < 0.2;
    _loadQuestion(0);
  }

  List<_Question> _generateProblems() {
    final pool = List<_Pair>.from(_allPairs)..shuffle(_random);
    return pool.take(5).map((pair) {
      final correct = pair.$2;
      final wrongs = (List<_Pair>.from(_allPairs)
            ..removeWhere((p) => p.$2 == correct)
            ..shuffle(_random))
          .take(3)
          .map((p) => p.$2)
          .toList();
      final choices = [correct, ...wrongs]..shuffle(_random);
      return _Question(hira: pair.$1, correctKata: correct, choices: choices);
    }).toList();
  }

  void _loadQuestion(int index) {
    _questionIndex = index;
    _selectedAnswer = null;
  }

  void _onAnswerTap(String choice) {
    if (_selectedAnswer != null) return;
    final correct = choice == _current.correctKata;
    setState(() {
      _selectedAnswer = choice;
      if (correct) _correctCount++;
    });
    if (correct) SoundService.playStrokeComplete();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_correctCount >= _passingScore) {
        _endRound();
      } else {
        if (_questionIndex + 1 >= _problems.length) {
          _problems.addAll(_generateProblems());
        }
        setState(() => _loadQuestion(_questionIndex + 1));
      }
    });
  }

  void _endRound() {
    PokemonEntry? reward;
    final shiny = _passed && _pendingIsShiny;
    if (_passed && _pendingRewardPokemon != null) {
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
    AnalyticsService.logKatakanaRoundComplete(
      score: _correctCount,
      passed: _passed,
      isShiny: shiny,
    );
    if (reward != null) {
      AnalyticsService.logPokemonCaught(
        pokemonName: reward.katakana,
        isShiny: shiny,
        source: 'katakana_quiz',
      );
    }
    setState(() {
      _rewardPokemon = reward;
      _rewardIsShiny = shiny;
      _showRoundResult = true;
    });
  }

  void _nextRound() {
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
              questionIndex: _questionIndex,
              correctCount: _correctCount,
              showResult: _showRoundResult,
              caughtCount: _caughtPokemon.length,
              caughtPokemon: _caughtPokemon,
              shinyCaughtNames: _shinyCaughtNames,
              onBack: () => Navigator.pop(context),
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
                      : _QuestionPanel(
                          question: _current,
                          questionIndex: _questionIndex,
                          selectedAnswer: _selectedAnswer,
                          onAnswerTap: _onAnswerTap,
                        ),
                ),
                if (_showRoundResult)
                  _RoundResultOverlay(
                    correctCount: _correctCount,
                    total: _passingScore,
                    passed: _passed,
                    rewardPokemon: _rewardPokemon,
                    isShiny: _rewardIsShiny,
                    onNext: _nextRound,
                  ),
                if (_showRoundResult && _passed && _rewardPokemon != null)
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
  final int questionIndex;
  final int correctCount;
  final bool showResult;
  final int caughtCount;
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;
  final VoidCallback onBack;
  final PokemonEntry? pendingRewardPokemon;
  final bool pendingIsShiny;

  const _LeftPanel({
    required this.questionIndex,
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
                    'もんだい ${questionIndex + 1} もんめ',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGray,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
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
                    '$correctCount / 3 せいかい',
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

// ─── 問題パネル ───────────────────────────────────────────────────────────────

class _QuestionPanel extends StatelessWidget {
  final _Question question;
  final int questionIndex;
  final String? selectedAnswer;
  final ValueChanged<String> onAnswerTap;

  const _QuestionPanel({
    required this.question,
    required this.questionIndex,
    required this.selectedAnswer,
    required this.onAnswerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'もんだい ${questionIndex + 1} / 5',
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
                          child: _ChoiceButton(
                              choice: question.choices[0],
                              correct: question.correctKata,
                              selected: selectedAnswer,
                              onTap: onAnswerTap)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _ChoiceButton(
                              choice: question.choices[1],
                              correct: question.correctKata,
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
                              correct: question.correctKata,
                              selected: selectedAnswer,
                              onTap: onAnswerTap)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _ChoiceButton(
                              choice: question.choices[3],
                              correct: question.correctKata,
                              selected: selectedAnswer,
                              onTap: onAnswerTap)),
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
          child:
              Icon(Icons.cancel_rounded, color: Color(0xFFEF9A9A), size: 22),
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
                  fontSize: 60,
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
                                child:
                                    Pokeball(color: pokemon.color, size: 36),
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
