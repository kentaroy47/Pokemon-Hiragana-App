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
  late PokemonEntry _currentPokemon;
  int _charIdx = 0;
  String? _selectedAnswer;
  late List<String> _choices;
  late Set<String> _charPool;
  bool _exhausted = false;

  String get _modeKey => widget.mode == PokemonReadingMode.hiragana
      ? 'pokemon_hira_quiz'
      : 'pokemon_kata_quiz';

  List<String> get _nameChars => widget.mode == PokemonReadingMode.hiragana
      ? _currentPokemon.hiragana.split('')
      : _currentPokemon.katakana.split('');

  String get _currentChar => _nameChars[_charIdx];

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    _charPool = PokemonRepository.all
        .expand((p) => widget.mode == PokemonReadingMode.hiragana
            ? p.hiragana.split('')
            : p.katakana.split(''))
        .toSet();
    _startRound();
    if (drillIsExhausted(_modeKey)) {
      _exhausted = true;
      drillPendingRewardPokemon = null;
    }
    AnalyticsService.logScreenView(_modeKey);
  }

  void _startRound() {
    drillCorrectCount = 0;
    _pickPokemon();
    // 今回のポケモン自体が報酬
    drillPendingRewardPokemon = _currentPokemon;
    drillPendingIsShiny = drillRandom.nextDouble() < 0.2;
  }

  void _pickPokemon() {
    final pool = PokemonRepository.all;
    PokemonEntry pick;
    int attempts = 0;
    do {
      pick = pool[drillRandom.nextInt(pool.length)];
      attempts++;
    } while (attempts < 20 &&
        pool.length > 1 &&
        pick.katakana == (drillPendingRewardPokemon?.katakana ?? ''));
    _currentPokemon = pick;
    _charIdx = 0;
    _selectedAnswer = null;
    _choices = _generateChoices(_currentChar);
  }

  List<String> _generateChoices(String correct) {
    final wrongs = (List<String>.from(_charPool)
          ..remove(correct)
          ..shuffle(drillRandom))
        .take(3)
        .toList();
    return [correct, ...wrongs]..shuffle(drillRandom);
  }

  void _onAnswerTap(String choice) {
    if (_selectedAnswer != null) return;
    final correct = choice == _currentChar;
    setState(() => _selectedAnswer = choice);

    if (correct) {
      drillCorrectCount++;
      SoundService.playStrokeComplete();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        if (_charIdx < _nameChars.length - 1) {
          setState(() {
            _charIdx++;
            _selectedAnswer = null;
            _choices = _generateChoices(_currentChar);
          });
        } else {
          _endRound();
        }
      });
    } else {
      // 不正解: 赤フラッシュ後に選択肢をリフレッシュして再挑戦
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _selectedAnswer = null;
          _choices = _generateChoices(_currentChar);
        });
      });
    }
  }

  void _endRound() {
    final reward = drillSaveRewardPokemon();
    final shiny = drillPendingIsShiny;
    StorageService.incrementDailyPlays(_modeKey);
    AnalyticsService.logPokemonReadingRoundComplete(
      mode: widget.mode == PokemonReadingMode.hiragana ? 'hiragana' : 'katakana',
      correctCount: drillCorrectCount,
      isShiny: shiny,
    );
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
      drillShowRoundResult = false;
      _exhausted = false;
      drillRewardPokemon = null;
      drillRewardIsShiny = false;
      drillCorrectCount = 0;
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
              charIdx: _charIdx,
              totalChars: _nameChars.length,
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
                              pokemon: _currentPokemon,
                              nameChars: _nameChars,
                              charIdx: _charIdx,
                              choices: _choices,
                              selectedAnswer: _selectedAnswer,
                              onAnswerTap: _onAnswerTap,
                              isHira: isHira,
                              isShiny: drillPendingIsShiny,
                            ),
                ),
                if (drillShowRoundResult)
                  DrillRoundResultOverlay(
                    scoreLabel: 'よめた！',
                    starsTotal: _nameChars.length,
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
  final int charIdx;
  final int totalChars;
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
    required this.charIdx,
    required this.totalChars,
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
                const SizedBox(height: 16),

                // 文字進捗ドット
                Center(
                  child: const Text(
                    'もじのすすみかた',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textGray,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(totalChars, (i) {
                    final done = i < charIdx;
                    final current = i == charIdx;
                    return Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? titleColor
                            : current
                                ? titleColor.withValues(alpha: 0.4)
                                : const Color(0xFFDDDDDD),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                if (!showResult && pendingRewardPokemon != null)
                  _PokemonPreviewNoName(
                    pokemon: pendingRewardPokemon!,
                    isShiny: pendingIsShiny,
                    accentColor: titleColor,
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

// ─── 名前なしポケモンプレビュー ───────────────────────────────────────────────────

class _PokemonPreviewNoName extends StatelessWidget {
  final PokemonEntry pokemon;
  final bool isShiny;
  final Color accentColor;

  const _PokemonPreviewNoName({
    required this.pokemon,
    required this.isShiny,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Text(
            'ゲットのチャンス！',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: PokemonImage(pokemon: pokemon, size: 100, isShiny: isShiny),
        ),
        if (isShiny)
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
    );
  }
}

// ─── 問題パネル ───────────────────────────────────────────────────────────────

class _QuestionPanel extends StatelessWidget {
  final PokemonEntry pokemon;
  final List<String> nameChars;
  final int charIdx;
  final List<String> choices;
  final String? selectedAnswer;
  final ValueChanged<String> onAnswerTap;
  final bool isHira;
  final bool isShiny;

  const _QuestionPanel({
    required this.pokemon,
    required this.nameChars,
    required this.charIdx,
    required this.choices,
    required this.selectedAnswer,
    required this.onAnswerTap,
    required this.isHira,
    required this.isShiny,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isHira ? AppTheme.pinkAccent : AppTheme.blueAccent;
    final correctChar = nameChars[charIdx];

    return Column(
      children: [
        const Text(
          'この ポケモンの なまえを よもう！',
          style: TextStyle(
            fontSize: 16,
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
              padding: const EdgeInsets.all(12),
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
                pokemon: pokemon,
                size: 140,
                isShiny: isShiny,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 名前の文字ボックス列
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(nameChars.length, (i) {
            final answered = i < charIdx;
            final current = i == charIdx;
            final isCorrect = selectedAnswer == correctChar;

            Color bg = const Color(0xFFF5F5F5);
            Color border = const Color(0xFFDDDDDD);
            String text = '';

            if (answered) {
              bg = const Color(0xFFE8F5E9);
              border = const Color(0xFF81C784);
              text = nameChars[i];
            } else if (current) {
              if (selectedAnswer != null && isCorrect) {
                bg = const Color(0xFFE8F5E9);
                border = const Color(0xFF66BB6A);
                text = correctChar;
              } else if (selectedAnswer != null && !isCorrect) {
                bg = const Color(0xFFFFEBEE);
                border = const Color(0xFFEF9A9A);
                text = '？';
              } else {
                bg = accentColor.withValues(alpha: 0.08);
                border = accentColor;
                text = '？';
              }
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 44,
              height: 48,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border, width: 2),
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: answered || (current && selectedAnswer != null && isCorrect)
                        ? const Color(0xFF2E7D32)
                        : AppTheme.darkText,
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 10),

        // 4択グリッド
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: DrillChoiceButton(
                              choice: choices[0],
                              correct: correctChar,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 52)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: DrillChoiceButton(
                              choice: choices[1],
                              correct: correctChar,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 52)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: DrillChoiceButton(
                              choice: choices[2],
                              correct: correctChar,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 52)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: DrillChoiceButton(
                              choice: choices[3],
                              correct: correctChar,
                              selected: selectedAnswer,
                              onTap: onAnswerTap,
                              fontSize: 52)),
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
