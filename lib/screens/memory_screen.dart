import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../services/sound_service.dart';
import '../widgets/pokemon_widgets.dart';
import '../widgets/drill_widgets.dart';
import 'drill_round_mixin.dart';

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

// ─── モデル ───────────────────────────────────────────────────────────────────

enum _CardType { hiragana, katakana }

class _Card {
  final String pairId;
  final String display;
  final _CardType type;
  bool isFlipped = false;
  bool isMatched = false;

  _Card({
    required this.pairId,
    required this.display,
    required this.type,
  });
}

// ─── メイン画面 ───────────────────────────────────────────────────────────────

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> with DrillRoundMixin {
  static const _totalPairs = 6;

  List<_Card> _cards = [];
  final List<int> _flippedIndices = [];
  int _matchedPairs = 0;
  bool _isLocked = false;
  bool _exhausted = false;

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    _startRound();
    if (drillIsExhausted('memory')) {
      _exhausted = true;
      drillPendingRewardPokemon = null;
    }
    AnalyticsService.logScreenView('memory');
  }

  void _startRound() {
    final shuffled = List<_Pair>.from(_allPairs)..shuffle(drillRandom);
    final selected = shuffled.take(_totalPairs).toList();
    final cards = <_Card>[];
    for (final (hira, kata) in selected) {
      cards.add(_Card(pairId: hira, display: hira, type: _CardType.hiragana));
      cards.add(_Card(pairId: hira, display: kata, type: _CardType.katakana));
    }
    cards.shuffle(drillRandom);
    _cards = cards;
    _flippedIndices.clear();
    _matchedPairs = 0;
    _isLocked = false;
    drillCorrectCount = 0;
    drillPickPendingPokemon();
  }

  void _onCardTap(int index) {
    if (_isLocked) return;
    final card = _cards[index];
    if (card.isFlipped || card.isMatched) return;
    if (_flippedIndices.length >= 2) return;

    setState(() {
      _cards[index].isFlipped = true;
      _flippedIndices.add(index);
    });

    if (_flippedIndices.length == 2) {
      _checkMatch();
    }
  }

  void _checkMatch() {
    _isLocked = true;
    final i1 = _flippedIndices[0];
    final i2 = _flippedIndices[1];
    final c1 = _cards[i1];
    final c2 = _cards[i2];

    if (c1.pairId == c2.pairId && c1.type != c2.type) {
      SoundService.playStrokeComplete();
      setState(() {
        _cards[i1].isMatched = true;
        _cards[i2].isMatched = true;
        _flippedIndices.clear();
        _matchedPairs++;
        drillCorrectCount = _matchedPairs;
      });
      _isLocked = false;
      if (_matchedPairs >= _totalPairs) {
        Future.delayed(const Duration(milliseconds: 400), _endRound);
      }
    } else {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _cards[i1].isFlipped = false;
          _cards[i2].isFlipped = false;
          _flippedIndices.clear();
        });
        _isLocked = false;
      });
    }
  }

  void _endRound() {
    final reward = drillSaveRewardPokemon();
    final shiny = drillPendingIsShiny;
    StorageService.incrementDailyPlays('memory');
    AnalyticsService.logMemoryRoundComplete(score: _matchedPairs, isShiny: shiny);
    if (reward != null) {
      AnalyticsService.logPokemonCaught(
        pokemonName: reward.katakana,
        isShiny: shiny,
        source: 'memory',
      );
      DailyStatsService.incrementCaught();
    }
    DailyStatsService.incrementDrillSessions('memory');
    setState(() {
      drillRewardPokemon = reward;
      drillRewardIsShiny = shiny;
      drillShowRoundResult = true;
    });
  }

  void _nextRound() {
    if (drillIsExhausted('memory')) {
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
      drillPendingRewardPokemon = null;
      drillPendingIsShiny = false;
    });
    _startRound();
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
              matchedPairs: _matchedPairs,
              totalPairs: _totalPairs,
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
                          ? _ExhaustedPanel(onBack: () => Navigator.pop(context))
                          : _CardGrid(
                              cards: _cards,
                              onCardTap: _onCardTap,
                            ),
                ),
                if (drillShowRoundResult)
                  DrillRoundResultOverlay(
                    scoreLabel: '$_matchedPairs / $_totalPairs ペア マッチ！',
                    starsTotal: _totalPairs,
                    starsFilled: _matchedPairs,
                    passed: true,
                    rewardPokemon: drillRewardPokemon,
                    isShiny: drillRewardIsShiny,
                    onNext: _nextRound,
                  ),
                if (drillShowRoundResult && drillRewardPokemon != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ConfettiOverlay(baseColor: drillRewardPokemon!.color),
                    ),
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
  final int matchedPairs;
  final int totalPairs;
  final bool showResult;
  final int caughtCount;
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;
  final VoidCallback onBack;
  final PokemonEntry? pendingRewardPokemon;
  final bool pendingIsShiny;

  const _LeftPanel({
    required this.matchedPairs,
    required this.totalPairs,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'カードあわせ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '$matchedPairs / $totalPairs ペア',
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
                  children: List.generate(totalPairs, (i) {
                    final filled = i < matchedPairs;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 28,
                        color: filled
                            ? const Color(0xFF6C5CE7)
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
                const Spacer(),
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

// ─── カードグリッド ─────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  final List<_Card> cards;
  final ValueChanged<int> onCardTap;

  const _CardGrid({required this.cards, required this.onCardTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.3,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return _CardTile(
          card: cards[index],
          onTap: () => onCardTap(index),
        );
      },
    );
  }
}

// ─── カードタイル ─────────────────────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final _Card card;
  final VoidCallback onTap;

  const _CardTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final flipped = card.isFlipped || card.isMatched;
    return GestureDetector(
      onTap: card.isMatched ? null : onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: flipped
            ? _FaceUp(
                key: ValueKey('f_${card.pairId}_${card.type.name}'),
                card: card)
            : _FaceDown(key: ValueKey('b_${card.pairId}_${card.type.name}')),
      ),
    );
  }
}

class _FaceDown extends StatelessWidget {
  const _FaceDown({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C6BC0), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Text('🎴', style: TextStyle(fontSize: 34)),
      ),
    );
  }
}

class _FaceUp extends StatelessWidget {
  final _Card card;

  const _FaceUp({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final isHira = card.type == _CardType.hiragana;
    final Color bgColor;
    final Color textColor;
    final Color borderColor;

    if (card.isMatched) {
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
      borderColor = const Color(0xFF66BB6A);
    } else if (isHira) {
      bgColor = const Color(0xFFE3F2FD);
      textColor = const Color(0xFF1565C0);
      borderColor = const Color(0xFF90CAF9);
    } else {
      bgColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFE65100);
      borderColor = const Color(0xFFFFCC80);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          card.display,
          style: TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.0,
          ),
        ),
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
