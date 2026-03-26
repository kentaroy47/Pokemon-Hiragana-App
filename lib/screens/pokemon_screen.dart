import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/pokemon_repository.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/pokemon_widgets.dart';

enum PokemonPlayMode { katakana, katakanaHard, hiragana, hiraganaHard }

extension PokemonPlayModeX on PokemonPlayMode {
  bool get isHiragana =>
      this == PokemonPlayMode.hiragana || this == PokemonPlayMode.hiraganaHard;
  bool get isHard =>
      this == PokemonPlayMode.katakanaHard ||
      this == PokemonPlayMode.hiraganaHard;
}

class PokemonScreen extends StatefulWidget {
  final PokemonPlayMode mode;
  const PokemonScreen({super.key, this.mode = PokemonPlayMode.katakana});

  @override
  State<PokemonScreen> createState() => _PokemonScreenState();
}

class _PokemonScreenState extends State<PokemonScreen> {
  late PokemonEntry _pokemon;
  int _charIndex = 0;
  final List<int> _scores = [];
  bool _showCatchOverlay = false;
  final List<PokemonEntry> _caughtPokemon = [];
  bool _advancing = false;
  int _sessionId = 0;
  bool _showHint = false;
  int _streak = 0;
  bool _isShiny = false;
  final Set<String> _shinyCaughtNames = {};

  final _random = math.Random();
  int _prevPokemonIndex = -1;

  List<String> get _currentChars =>
      widget.mode.isHiragana ? _pokemon.hiraganaChars : _pokemon.chars;

  @override
  void initState() {
    super.initState();
    final lookup = {for (final p in PokemonRepository.all) p.katakana: p};
    final saved = StorageService.loadCaughtNames();
    for (final name in saved) {
      final entry = lookup[name];
      if (entry != null) _caughtPokemon.add(entry);
    }
    _shinyCaughtNames.addAll(StorageService.loadShinyCaughtNames());

    final idx = _random.nextInt(PokemonRepository.all.length);
    _prevPokemonIndex = idx;
    _pokemon = PokemonRepository.all[idx];
    _isShiny = widget.mode.isHard && _random.nextDouble() < 0.1;
  }

  void _pickNewPokemon() {
    int idx;
    do {
      idx = _random.nextInt(PokemonRepository.all.length);
    } while (idx == _prevPokemonIndex && PokemonRepository.all.length > 1);
    _prevPokemonIndex = idx;
    setState(() {
      _sessionId++;
      _pokemon = PokemonRepository.all[idx];
      _isShiny = widget.mode.isHard && _random.nextDouble() < 0.1;
      _charIndex = 0;
      _scores.clear();
      _showCatchOverlay = false;
      _advancing = false;
    });
  }

  void _retrySamePokemon() {
    setState(() {
      _sessionId++;
      _charIndex = 0;
      _scores.clear();
      _showCatchOverlay = false;
      _advancing = false;
      _streak = 0;
    });
  }

  void _activateHint() {
    if (_showHint) return;
    setState(() => _showHint = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  void _onCharComplete(int score) {
    if (_advancing) return;
    _advancing = true;

    _scores.add(score);
    SoundService.playStrokeComplete();
    setState(() {}); // キャラ進捗行の緑チェックを即時表示

    final isLast = _scores.length >= _currentChars.length;

    if (!isLast) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _charIndex++;
          _advancing = false;
        });
      });
    } else {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        SoundService.playCatch();
        setState(() {
          _caughtPokemon.add(_pokemon);
          if (_isShiny) _shinyCaughtNames.add(_pokemon.katakana);
          _showCatchOverlay = true;
          _advancing = false;
          _streak++;
        });
        StorageService.saveCaughtNames(
            _caughtPokemon.map((p) => p.katakana).toList());
        if (_isShiny) {
          StorageService.saveShinyCaughtNames(_shinyCaughtNames);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chars = _currentChars;
    final currentChar = chars[_charIndex];
    final strokeCount = widget.mode.isHiragana
        ? hiraganaStrokeCountFor(currentChar)
        : strokeCountFor(currentChar);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // ─── 左パネル ───
          SizedBox(
            width: 280,
            child: _LeftPanel(
              pokemon: _pokemon,
              caughtPokemon: _caughtPokemon,
              shinyCaughtNames: _shinyCaughtNames,
              streak: _streak,
              isShiny: _isShiny,
              onBack: () => Navigator.pop(context),
            ),
          ),
          // ─── 右パネル ───
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
                  child: Column(
                    children: [
                      // 文字進捗チップ
                      _CharProgressRow(
                        chars: chars,
                        currentIndex: _charIndex,
                        completedCount: _scores.length,
                        pokemonColor: _pokemon.color,
                      ),
                      const SizedBox(height: 6),
                      // ふりがな ＋ ヒントボタン
                      // ハードモードでは非表示（ヒント中のみ表示）
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedOpacity(
                            opacity: widget.mode.isHard && !_showHint ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              widget.mode.isHiragana
                                  ? _pokemon.katakana
                                  : _pokemon.hiragana,
                              style: const TextStyle(
                                fontSize: 20,
                                color: AppTheme.textGray,
                                letterSpacing: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _HintButton(
                            onPressed: _activateHint,
                            active: _showHint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // お絵かきキャンバス
                      Expanded(
                        child: DrawingCanvas(
                          key: ValueKey('$_sessionId-$_charIndex'),
                          character: currentChar,
                          totalStrokes: strokeCount,
                          onComplete: _onCharComplete,
                          showHint: _showHint,
                          hideChar: widget.mode.isHard,
                        ),
                      ),
                    ],
                  ),
                ),
                // ゲットオーバーレイ
                if (_showCatchOverlay)
                  _CatchOverlay(
                    pokemon: _pokemon,
                    scores: List.unmodifiable(_scores),
                    streak: _streak,
                    isShiny: _isShiny,
                    onNext: _pickNewPokemon,
                    onRetry: _retrySamePokemon,
                  ),
                // キラキラエフェクト（ゲット時）
                if (_showCatchOverlay)
                  Positioned.fill(
                    child: ConfettiOverlay(baseColor: _pokemon.color),
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
  final PokemonEntry pokemon;
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;
  final int streak;
  final bool isShiny;
  final VoidCallback onBack;

  const _LeftPanel({
    required this.pokemon,
    required this.caughtPokemon,
    required this.shinyCaughtNames,
    required this.streak,
    required this.isShiny,
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
          // 上部バー
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.home_outlined, size: 16),
                label: const Text('もどる', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.darkText,
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
              const Spacer(),
              const _MusicToggleButton(),
            ],
          ),
          const SizedBox(height: 20),

          // ポケモン画像（色違いバッジ付き）
          Center(
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                PokemonImage(pokemon: pokemon, size: 130, isShiny: isShiny),
                if (isShiny)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('✨いろちがい',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Text(
            isShiny ? 'いろちがいが\nあらわれた！' : 'ポケモンのなまえを\nなぞろう！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
              height: 1.5,
            ),
          ),

          const Spacer(),

          // ゲット数 ＋ ずかんボタン
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'ゲット：${caughtPokemon.length}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
                const Spacer(),
                // ずかんボタン
                Tooltip(
                  message: 'ゲットずかん',
                  child: InkWell(
                    onTap: caughtPokemon.isEmpty
                        ? null
                        : () => showDialog(
                              context: context,
                              builder: (_) => PokedexDialog(
                                caughtPokemon: List.unmodifiable(caughtPokemon),
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
                ),
              ],
            ),
          ),
          // れんぞくゲット表示
          if (streak >= 2) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text(
                    '$streakれんぞく！',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6D00),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── BGM トグルボタン ──────────────────────────────────────────────────────────

class _MusicToggleButton extends StatefulWidget {
  const _MusicToggleButton();

  @override
  State<_MusicToggleButton> createState() => _MusicToggleButtonState();
}

class _MusicToggleButtonState extends State<_MusicToggleButton> {
  @override
  Widget build(BuildContext context) {
    final playing = SoundService.bgmPlaying;
    return IconButton(
      tooltip: playing ? 'BGMをとめる' : 'BGMをながす',
      icon: Icon(playing ? Icons.music_note : Icons.music_off_outlined),
      color: playing ? AppTheme.blueAccent : AppTheme.textGray,
      onPressed: () {
        SoundService.toggleBgm();
        setState(() {});
      },
    );
  }
}

// ─── 文字進捗チップ ────────────────────────────────────────────────────────────

class _CharProgressRow extends StatelessWidget {
  final List<String> chars;
  final int currentIndex;
  final int completedCount;
  final Color pokemonColor;

  const _CharProgressRow({
    required this.chars,
    required this.currentIndex,
    required this.completedCount,
    required this.pokemonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(chars.length, (i) {
        final isDone = i < completedCount;
        final isCurrent = i == currentIndex && !isDone;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 58,
          height: 68,
          decoration: BoxDecoration(
            color: isDone
                ? AppTheme.greenStroke.withValues(alpha: 0.15)
                : isCurrent
                    ? pokemonColor.withValues(alpha: 0.12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDone
                  ? AppTheme.greenStroke
                  : isCurrent
                      ? pokemonColor
                      : const Color(0xFFDDDDDD),
              width: isCurrent ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                chars[i],
                style: TextStyle(
                  fontSize: 30,
                  fontWeight:
                      isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isDone
                      ? AppTheme.greenStroke
                      : isCurrent
                          ? pokemonColor
                          : AppTheme.textGray,
                  height: 1.0,
                ),
              ),
              if (isDone)
                const Icon(Icons.check_circle,
                    size: 13, color: AppTheme.greenStroke),
            ],
          ),
        );
      }),
    );
  }
}

// ─── ゲットオーバーレイ ────────────────────────────────────────────────────────

class _CatchOverlay extends StatefulWidget {
  final PokemonEntry pokemon;
  final List<int> scores;
  final int streak;
  final bool isShiny;
  final VoidCallback onNext;
  final VoidCallback onRetry;

  const _CatchOverlay({
    required this.pokemon,
    required this.scores,
    required this.streak,
    required this.isShiny,
    required this.onNext,
    required this.onRetry,
  });

  @override
  State<_CatchOverlay> createState() => _CatchOverlayState();
}

class _CatchOverlayState extends State<_CatchOverlay>
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
          parent: _ctrl, curve: const Interval(0, 0.3, curve: Curves.easeIn)),
    );
    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
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

  int get _starCount {
    if (widget.scores.isEmpty) return 1;
    final avg = widget.scores.reduce((a, b) => a + b) / widget.scores.length;
    return avg.round().clamp(1, 3);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.pokemon.color;

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
                    // 星評価
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final filled = i < _starCount;
                        return Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: filled
                              ? const Color(0xFFF5C518)
                              : const Color(0xFFCCCCCC),
                          size: 46,
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    // ポケモン画像（コーナーに回転ポケボール）
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        children: [
                          PokemonImage(
                              pokemon: widget.pokemon,
                              size: 150,
                              isShiny: widget.isShiny),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Transform.rotate(
                              angle: _spin.value,
                              child: Pokeball(color: color, size: 40),
                            ),
                          ),
                          if (widget.isShiny)
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD700),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('✨いろちがい',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 「〇〇をゲット！」
                    Text(
                      '${widget.pokemon.katakana}を',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      'ゲット！',
                      style: TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.pinkAccent,
                        shadows: [
                          Shadow(
                            color: AppTheme.pinkAccent.withValues(alpha: 0.25),
                            offset: const Offset(0, 6),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      widget.pokemon.hiragana,
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppTheme.textGray,
                        letterSpacing: 5,
                      ),
                    ),

                    // れんぞくゲットバッジ
                    if (widget.streak >= 2) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6D00),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          '🔥 ${widget.streak}れんぞくゲット！',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),

                    // ボタン行
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('もういちど',
                              style: TextStyle(fontSize: 16)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.darkText,
                            side: const BorderSide(color: Color(0xFFCCCCCC)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: widget.onNext,
                          icon: const Text('つぎのポケモン',
                              style: TextStyle(fontSize: 16)),
                          label: const Icon(Icons.arrow_forward, size: 18),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.pinkAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ],
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

// ─── ゲットずかん ダイアログ ──────────────────────────────────────────────────

class PokedexDialog extends StatefulWidget {
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;

  const PokedexDialog({
    required this.caughtPokemon,
    required this.shinyCaughtNames,
  });

  @override
  State<PokedexDialog> createState() => _PokedexDialogState();
}

class _PokedexDialogState extends State<PokedexDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  late final Map<String, int> _counts;
  late final List<PokemonEntry> _normal;
  late final List<PokemonEntry> _mega;
  late final List<PokemonEntry> _shiny;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _counts = {};
    final uniqueAll = <PokemonEntry>[];
    for (final p in widget.caughtPokemon) {
      if (!_counts.containsKey(p.katakana)) uniqueAll.add(p);
      _counts[p.katakana] = (_counts[p.katakana] ?? 0) + 1;
    }
    _normal = uniqueAll.where((p) => p.pokedexId < 10000).toList();
    _mega   = uniqueAll.where((p) => p.pokedexId >= 10000).toList();
    _shiny  = uniqueAll.where((p) => widget.shinyCaughtNames.contains(p.katakana)).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 680,
        height: 500,
        child: Column(
          children: [
            // ヘッダー
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 12, 12),
              child: Row(
                children: [
                  const Text('📖', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  const Text(
                    'ゲットずかん',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // タブバー
            TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 14),
              labelColor: AppTheme.blueAccent,
              unselectedLabelColor: AppTheme.textGray,
              indicatorColor: AppTheme.blueAccent,
              tabs: [
                Tab(text: 'ポケモン  ${_normal.length}ひき'),
                Tab(text: 'メガシンカ  ${_mega.length}ひき'),
                Tab(text: '✨いろちがい  ${_shiny.length}ひき'),
              ],
            ),
            const Divider(height: 1),

            // タブコンテンツ
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _PokedexGrid(entries: _normal, counts: _counts,
                      shinyCaughtNames: widget.shinyCaughtNames),
                  _PokedexGrid(entries: _mega,   counts: _counts,
                      shinyCaughtNames: widget.shinyCaughtNames),
                  _PokedexGrid(entries: _shiny,  counts: _counts,
                      shinyCaughtNames: widget.shinyCaughtNames, forceShiny: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PokedexGrid extends StatelessWidget {
  final List<PokemonEntry> entries;
  final Map<String, int> counts;
  final Set<String> shinyCaughtNames;
  final bool forceShiny;

  const _PokedexGrid({
    required this.entries,
    required this.counts,
    required this.shinyCaughtNames,
    this.forceShiny = false,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔍', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'まだゲットしていないよ！',
              style: TextStyle(fontSize: 18, color: AppTheme.textGray),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final p = entries[i];
        return _PokedexCard(
          pokemon: p,
          count: counts[p.katakana]!,
          isShiny: forceShiny || shinyCaughtNames.contains(p.katakana),
        );
      },
    );
  }
}

// ─── ずかん1枚カード ──────────────────────────────────────────────────────────

class _PokedexCard extends StatelessWidget {
  final PokemonEntry pokemon;
  final int count;
  final bool isShiny;

  const _PokedexCard({
    required this.pokemon,
    required this.count,
    this.isShiny = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _PokedexDetailDialog(pokemon: pokemon),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: pokemon.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: pokemon.color.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PokemonImage(pokemon: pokemon, size: 72, isShiny: isShiny),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    pokemon.katakana,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: pokemon.color,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  pokemon.hiragana,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textGray,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 色違いバッジ
          if (isShiny)
            const Positioned(
              top: 4,
              left: 4,
              child: Text('✨', style: TextStyle(fontSize: 12)),
            ),
          // 複数回ゲットしたときのバッジ
          if (count > 1)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.pinkAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '×$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── ポケモン詳細ダイアログ ───────────────────────────────────────────────────

const _typeJa = {
  'normal': 'ノーマル', 'fire': 'ほのお',    'water': 'みず',
  'grass': 'くさ',     'electric': 'でんき', 'ice': 'こおり',
  'fighting': 'かくとう', 'poison': 'どく',  'ground': 'じめん',
  'flying': 'ひこう',  'psychic': 'エスパー','bug': 'むし',
  'rock': 'いわ',      'ghost': 'ゴースト',  'dragon': 'ドラゴン',
  'dark': 'あく',      'steel': 'はがね',    'fairy': 'フェアリー',
};

const _typeColors = {
  'normal':   Color(0xFFA8A878), 'fire':     Color(0xFFF08030),
  'water':    Color(0xFF6890F0), 'grass':    Color(0xFF78C850),
  'electric': Color(0xFFF8D030), 'ice':      Color(0xFF98D8D8),
  'fighting': Color(0xFFC03028), 'poison':   Color(0xFFA040A0),
  'ground':   Color(0xFFE0C068), 'flying':   Color(0xFFA890F0),
  'psychic':  Color(0xFFF85888), 'bug':      Color(0xFFA8B820),
  'rock':     Color(0xFFB8A038), 'ghost':    Color(0xFF705898),
  'dragon':   Color(0xFF7038F8), 'dark':     Color(0xFF705848),
  'steel':    Color(0xFFB8B8D0), 'fairy':    Color(0xFFEE99AC),
};

const _statJa = {
  'hp': 'HP', 'attack': 'こうげき', 'defense': 'ぼうぎょ',
  'special-attack': 'とくこう', 'special-defense': 'とくぼう',
  'speed': 'すばやさ',
};

class _PokedexDetailDialog extends StatefulWidget {
  final PokemonEntry pokemon;
  const _PokedexDetailDialog({required this.pokemon});

  @override
  State<_PokedexDetailDialog> createState() => _PokedexDetailDialogState();
}

class _PokedexDetailDialogState extends State<_PokedexDetailDialog> {
  Map<String, dynamic>? _data;
  String? _flavorText;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final pokemonRes = await http.get(
        Uri.parse(
            'https://pokeapi.co/api/v2/pokemon/${widget.pokemon.pokedexId}/'),
      );
      final pokemonData =
          jsonDecode(pokemonRes.body) as Map<String, dynamic>;

      final speciesUrl = (pokemonData['species'] as Map)['url'] as String;
      final speciesRes = await http.get(Uri.parse(speciesUrl));
      final speciesData =
          jsonDecode(speciesRes.body) as Map<String, dynamic>;

      final entries = speciesData['flavor_text_entries'] as List;
      // ひらがな・カタカナのみ（ja-Hrkt）。複数バージョンある場合は最新を使用。
      final kanaEntries =
          entries.where((e) => e['language']['name'] == 'ja-Hrkt').toList();
      final jaEntry = kanaEntries.isNotEmpty ? kanaEntries.last : null;

      if (!mounted) return;
      setState(() {
        _data = pokemonData;
        _flavorText = jaEntry != null
            ? (jaEntry['flavor_text'] as String)
                .replaceAll('\n', ' ')
                .replaceAll('\f', ' ')
            : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.pokemon.color;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 700,
        height: 440,
        child: _loading
            ? Center(
                child: CircularProgressIndicator(color: color),
              )
            : _error
                ? const Center(
                    child: Text('データをよみこめませんでした',
                        style: TextStyle(color: AppTheme.textGray)),
                  )
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final data = _data!;
    final types = (data['types'] as List)
        .map((t) => t['type']['name'] as String)
        .toList();
    final stats = (data['stats'] as List)
        .map((s) =>
            MapEntry(s['stat']['name'] as String, s['base_stat'] as int))
        .toList();
    final height = ((data['height'] as int) / 10).toStringAsFixed(1);
    final weight = ((data['weight'] as int) / 10).toStringAsFixed(1);
    final color = widget.pokemon.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 左：画像・名前・タイプ ──
        Container(
          width: 230,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              PokemonImage(pokemon: widget.pokemon, size: 130),
              const SizedBox(height: 8),
              Text(
                widget.pokemon.katakana,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                widget.pokemon.hiragana,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textGray),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: types
                    .map((t) => _TypeChip(type: t))
                    .toList(),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InfoItem(label: 'たかさ', value: '${height}m'),
                  _InfoItem(label: 'おもさ', value: '${weight}kg'),
                ],
              ),
            ],
          ),
        ),
        // ── 右：説明・ステータス ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_flavorText != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _flavorText!,
                      style: const TextStyle(
                          fontSize: 13, height: 1.8,
                          color: AppTheme.darkText),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const Text(
                  'きほんステータス',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                ...stats.map((e) =>
                    _StatBar(name: e.key, value: e.value, color: color)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _typeColors[type] ?? Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _typeJa[type] ?? type,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textGray)),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold,
                color: AppTheme.darkText)),
      ],
    );
  }
}

class _StatBar extends StatelessWidget {
  final String name;
  final int value;
  final Color color;
  const _StatBar(
      {required this.name, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              _statJa[name] ?? name,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textGray),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 255,
                minHeight: 8,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── なぞりヒントボタン ────────────────────────────────────────────────────────

class _HintButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool active;

  const _HintButton({required this.onPressed, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFFFE082).withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? const Color(0xFFFFA000) : const Color(0xFFCCCCCC),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: active ? null : onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👋', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                'ヒント',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: active
                      ? const Color(0xFFFFA000)
                      : AppTheme.textGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
