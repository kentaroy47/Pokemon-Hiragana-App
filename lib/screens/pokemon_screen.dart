import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/pokemon_repository.dart';
import '../services/daily_stats_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../widgets/drill_suggestion_dialog.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/pokemon_widgets.dart';
import '../widgets/pokedex_dialog.dart';

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
    setState(() {});

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
        StorageService.addTodayCaughtName(_pokemon.katakana);
        if (_isShiny) {
          StorageService.saveShinyCaughtNames(_shinyCaughtNames);
        }
        DailyStatsService.incrementCaught();
        final sessions =
            DailyStatsService.incrementDrillSessions('hiragana');
        if (sessions > 0 && sessions % 5 == 0 && mounted) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              showDrillSuggestionDialog(context, 'hiragana', sessions);
            }
          });
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
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
                  child: Column(
                    children: [
                      _CharProgressRow(
                        chars: chars,
                        currentIndex: _charIndex,
                        completedCount: _scores.length,
                        pokemonColor: _pokemon.color,
                      ),
                      const SizedBox(height: 6),
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
                if (_showCatchOverlay)
                  _CatchOverlay(
                    pokemon: _pokemon,
                    scores: List.unmodifiable(_scores),
                    streak: _streak,
                    isShiny: _isShiny,
                    onNext: _pickNewPokemon,
                    onRetry: _retrySamePokemon,
                  ),
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
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
              height: 1.5,
            ),
          ),

          const Spacer(),

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
                                todayCaughtNames:
                                    StorageService.loadTodayCaughtNamesList(),
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
