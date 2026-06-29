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
import '../widgets/drawing_canvas.dart';
import 'drill_round_mixin.dart';

class KanjiWritingScreen extends StatefulWidget {
  const KanjiWritingScreen({super.key});

  @override
  State<KanjiWritingScreen> createState() => _KanjiWritingScreenState();
}

class _KanjiWritingScreenState extends State<KanjiWritingScreen>
    with DrillRoundMixin {
  static const _roundSize = 5;

  int _doneInRound = 0;
  int _sessionId = 0;
  late KanjiEntry _current;
  int _prevIndex = -1;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    _startRound();
    AnalyticsService.logScreenView('kanji_write');
  }

  void _startRound() {
    _doneInRound = 0;
    _showCompleted = false;
    drillCorrectCount = 0;
    drillPickPendingPokemon();
    _nextKanji();
  }

  void _nextKanji() {
    int idx;
    do {
      idx = drillRandom.nextInt(kanjiList1.length);
    } while (idx == _prevIndex && kanjiList1.length > 1);
    _prevIndex = idx;
    _sessionId++;
    _current = kanjiList1[idx];
  }

  void _onCanvasComplete(int score) {
    if (!mounted) return;
    SoundService.playStrokeComplete();
    setState(() {
      _doneInRound++;
      _showCompleted = true;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_doneInRound >= _roundSize) {
        _endRound();
      } else {
        setState(() {
          _showCompleted = false;
          _nextKanji();
        });
      }
    });
  }

  void _endRound() {
    final reward = drillSaveRewardPokemon();
    final shiny = drillPendingIsShiny;
    StorageService.incrementDailyPlays('kanji_write');
    if (reward != null) {
      AnalyticsService.logPokemonCaught(
        pokemonName: reward.katakana,
        isShiny: shiny,
        source: 'kanji_write',
      );
      DailyStatsService.incrementCaught();
    }
    final sessions = DailyStatsService.incrementDrillSessions('kanji_write');
    setState(() {
      drillRewardPokemon = reward;
      drillRewardIsShiny = shiny;
      drillShowRoundResult = true;
      _showCompleted = false;
    });
    if (sessions > 0 && sessions % 5 == 0) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) showDrillSuggestionDialog(context, 'kanji_write', sessions);
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
              doneInRound: _doneInRound,
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
                      : _WritingPanel(
                          entry: _current,
                          sessionId: _sessionId,
                          showCompleted: _showCompleted,
                          onComplete: _onCanvasComplete,
                        ),
                ),
                if (drillShowRoundResult)
                  DrillRoundResultOverlay(
                    scoreLabel: '$_roundSize まいの かんじを かけた！',
                    starsTotal: _roundSize,
                    starsFilled: _roundSize,
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
  final int doneInRound;
  final bool showResult;
  final int caughtCount;
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;
  final VoidCallback onBack;
  final PokemonEntry? pendingRewardPokemon;
  final bool pendingIsShiny;

  const _LeftPanel({
    required this.doneInRound,
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
                    'かんじをかこう！',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Center(
                  child: Text(
                    '$doneInRound / 5 まい かいた',
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
                    final done = i < doneInRound;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 32,
                        color: done
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFDDDDDD),
                      ),
                    );
                  }),
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

// ─── 書き練習パネル ────────────────────────────────────────────────────────────

class _WritingPanel extends StatelessWidget {
  final KanjiEntry entry;
  final int sessionId;
  final bool showCompleted;
  final void Function(int score) onComplete;

  const _WritingPanel({
    required this.entry,
    required this.sessionId,
    required this.showCompleted,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          entry.reading,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'なぞってかいてみよう！',
          style: TextStyle(fontSize: 14, color: AppTheme.textGray),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: showCompleted
                  ? _CompletedOverlay()
                  : DrawingCanvas(
                      key: ValueKey('kanji_$sessionId'),
                      character: entry.kanji,
                      totalStrokes: entry.strokeCount,
                      onComplete: onComplete,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompletedOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
      ),
      child: const Center(
        child: Text('⭕', style: TextStyle(fontSize: 80)),
      ),
    );
  }
}
