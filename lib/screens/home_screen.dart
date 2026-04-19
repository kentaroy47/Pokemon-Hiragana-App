import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_palette.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../widgets/pokemon_widgets.dart';
import 'clock_screen.dart';
import 'katakana_quiz_screen.dart';
import 'memory_screen.dart';
import 'sugoroku_screen.dart';
import 'settings_screen.dart';
import 'math_screen.dart';
import 'pokemon_screen.dart' show PokemonPlayMode, PokemonScreen;
import 'pokemon_reading_quiz_screen.dart';
import '../widgets/pokedex_dialog.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../services/storage_service.dart';
import '../services/pokemon_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Scaffold(
      body: Row(
        children: [
          // Left: colored panel
          Expanded(
            flex: 5,
            child: Container(
              color: palette.leftPanel,
              child: const _LeftPanel(),
            ),
          ),
          // Right: background panel
          Expanded(
            flex: 7,
            child: Container(
              color: palette.background,
              child: const _RightPanel(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftPanel extends StatefulWidget {
  const _LeftPanel();

  @override
  State<_LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<_LeftPanel> {
  PokemonEntry? _pokemon;
  bool _isShiny = false;

  @override
  void initState() {
    super.initState();
    final pool = PokemonRepository.all;
    if (pool.isNotEmpty) {
      final rng = math.Random();
      _pokemon = pool[rng.nextInt(pool.length)];
      _isShiny = rng.nextDouble() < 0.2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pokemon = _pokemon;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'ひらがな',
          style: TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: AppTheme.blueAccent,
            height: 1.1,
          ),
        ),
        const Text(
          'れんしゅう',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.pinkAccent,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 24),
        if (pokemon != null) ...[
          PokemonImage(pokemon: pokemon, size: 140, isShiny: _isShiny),
          const SizedBox(height: 8),
          Text(
            pokemon.katakana,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 2,
            ),
          ),
          if (_isShiny)
            const Text(
              '✨ いろちがい！',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
              ),
            ),
        ] else
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🧒', style: TextStyle(fontSize: 80)),
            ),
          ),
        const SizedBox(height: 20),
        // 今日捕まえたポケモン数バッジ
        ValueListenableBuilder<int>(
          valueListenable: DailyStatsService.todayCaughtNotifier,
          builder: (context, count, _) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(
                    count == 0
                        ? 'きょうはまだ\nゲットしてないよ'
                        : 'きょう $count ひき\nゲット！',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel();

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'たのしくまなぼう！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 16),

          // こくご button
          _MenuButton(
            emoji: '📖',
            label: 'こくご',
            color: palette.primary,
            onTap: () async {
              final result = await showDialog<_KokugoMode>(
                context: context,
                builder: (_) => const _KokugoModeDialog(),
              );
              if (result == null) return;
              if (!context.mounted) return;
              AnalyticsService.logKokugoModeSelected(result.name);
              switch (result) {
                case _KokugoMode.hiragana:
                  AnalyticsService.logScreenView('hiragana');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PokemonScreen(mode: PokemonPlayMode.hiragana),
                    ),
                  );
                case _KokugoMode.hiraganaHard:
                  AnalyticsService.logScreenView('hiragana_hard');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PokemonScreen(mode: PokemonPlayMode.hiraganaHard),
                    ),
                  );
                case _KokugoMode.katakana:
                  AnalyticsService.logScreenView('katakana');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PokemonScreen(mode: PokemonPlayMode.katakana),
                    ),
                  );
                case _KokugoMode.katakanaHard:
                  AnalyticsService.logScreenView('katakana_hard');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PokemonScreen(mode: PokemonPlayMode.katakanaHard),
                    ),
                  );
              }
            },
          ),
          const SizedBox(height: 12),

          // さんすう button
          _MenuButton(
            emoji: '🔢',
            label: 'さんすう',
            color: palette.secondary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MathScreen()),
              );
            },
          ),
          const SizedBox(height: 12),

          // カタカナをよもう！ button
          _MenuButton(
            emoji: '🌼',
            label: 'カタカナをよもう！',
            color: const Color(0xFFFF9F43),
            onTap: () async {
              final result = await showDialog<_KatakanaMode>(
                context: context,
                builder: (_) => const _KatakanaModeDialog(),
              );
              if (result == null) return;
              if (!context.mounted) return;
              switch (result) {
                case _KatakanaMode.random:
                  AnalyticsService.logScreenView('katakana_quiz');
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const KatakanaQuizScreen()));
                case _KatakanaMode.pokemonHiragana:
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const PokemonReadingQuizScreen(
                              mode: PokemonReadingMode.hiragana)));
                case _KatakanaMode.pokemonKatakana:
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const PokemonReadingQuizScreen(
                              mode: PokemonReadingMode.katakana)));
              }
            },
          ),
          const SizedBox(height: 12),

          // 時計をよもう！ button
          _MenuButton(
            emoji: '🕐',
            label: 'とけいをよもう！',
            color: const Color(0xFF48BEFF),
            onTap: () {
              AnalyticsService.logScreenView('clock');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClockScreen()),
              );
            },
          ),
          const SizedBox(height: 8),

          // カードあわせ button
          _MenuButton(
            emoji: '🃏',
            label: 'カードあわせ',
            color: const Color(0xFF6C5CE7),
            onTap: () {
              AnalyticsService.logScreenView('memory');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemoryScreen()),
              );
            },
          ),
          const SizedBox(height: 8),

          // スゴロク button
          _MenuButton(
            emoji: '🎲',
            label: 'スゴロク',
            color: const Color(0xFF00B894),
            onTap: () {
              AnalyticsService.logScreenView('sugoroku');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SugorokuScreen()),
              );
            },
          ),

          const SizedBox(height: 8),
          const _TodayStatsRow(),
          const Spacer(),

          // 下段：図鑑 + パレット選択
          Row(
            children: [
              // 図鑑ボタン
              GestureDetector(
                onTap: () {
                  final lookup = {
                    for (final p in PokemonRepository.all) p.katakana: p
                  };
                  final caught = StorageService.loadCaughtNames()
                      .map((n) => lookup[n])
                      .whereType<Object>()
                      .cast<dynamic>()
                      .toList();
                  final shinyNames =
                      StorageService.loadShinyCaughtNames().toSet();
                  if (caught.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('まだポケモンをゲットしていないよ！'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (_) => PokedexDialog(
                      caughtPokemon: List.unmodifiable(
                          caught.cast()),
                      shinyCaughtNames: shinyNames,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.blueAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 16, color: AppTheme.blueAccent),
                      SizedBox(width: 6),
                      Text(
                        'ずかん',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.blueAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.textGray.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.textGray.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.settings_rounded,
                      size: 16, color: AppTheme.textGray),
                ),
              ),
              const SizedBox(width: 8),
              _PalettePicker(currentId: palette.id),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _MenuButton({
    required this.emoji,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── こくごモード ──────────────────────────────────────────────────────────────

enum _KokugoMode { hiragana, hiraganaHard, katakana, katakanaHard }

enum _KatakanaMode { random, pokemonHiragana, pokemonKatakana }

class _KokugoModeDialog extends StatelessWidget {
  const _KokugoModeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'モードをえらんでね',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeOption(
            emoji: '🌸',
            label: 'ひらがな',
            description: 'ポケモンのなまえをなぞる',
            color: AppTheme.pinkAccent,
            onTap: () => Navigator.pop(context, _KokugoMode.hiragana),
          ),
          const SizedBox(height: 8),
          _ModeOption(
            emoji: '🔥',
            label: 'むずかしいひらがな',
            description: 'ポケモンのなまえをなぞる',
            color: const Color(0xFF6A1B9A),
            onTap: () => Navigator.pop(context, _KokugoMode.hiraganaHard),
          ),
          const SizedBox(height: 8),
          _ModeOption(
            emoji: '🌼',
            label: 'カタカナ',
            description: 'ポケモンのなまえをなぞる',
            color: AppTheme.blueAccent,
            onTap: () => Navigator.pop(context, _KokugoMode.katakana),
          ),
          const SizedBox(height: 8),
          _ModeOption(
            emoji: '💪',
            label: 'むずかしいカタカナ',
            description: 'ポケモンのなまえをなぞる',
            color: const Color(0xFFE65100),
            onTap: () => Navigator.pop(context, _KokugoMode.katakanaHard),
          ),
        ],
      ),
    );
  }
}

// ─── カタカナモードダイアログ ──────────────────────────────────────────────────

class _KatakanaModeDialog extends StatelessWidget {
  const _KatakanaModeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'モードをえらんでね',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeOption(
            emoji: '🌼',
            label: 'ランダムもじクイズ',
            description: 'ひらがなに対応するカタカナをえらぶ',
            color: const Color(0xFFFF9F43),
            onTap: () => Navigator.pop(context, _KatakanaMode.random),
          ),
          const SizedBox(height: 8),
          _ModeOption(
            emoji: '🐾',
            label: 'ポケモンのなまえ（ひらがな）',
            description: 'ポケモンのなまえを1もじずつひらがなでえらぶ',
            color: AppTheme.pinkAccent,
            onTap: () => Navigator.pop(context, _KatakanaMode.pokemonHiragana),
          ),
          const SizedBox(height: 8),
          _ModeOption(
            emoji: '🐾',
            label: 'ポケモンのなまえ（カタカナ）',
            description: 'ポケモンのなまえを1もじずつカタカナでえらぶ',
            color: AppTheme.blueAccent,
            onTap: () => Navigator.pop(context, _KatakanaMode.pokemonKatakana),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String emoji;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ModeOption({
    required this.emoji,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── パレット選択スウォッチ ────────────────────────────────────────────────────

class _PalettePicker extends StatelessWidget {
  final String currentId;
  const _PalettePicker({required this.currentId});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          'いろ：',
          style: TextStyle(fontSize: 12, color: AppTheme.textGray),
        ),
        const SizedBox(width: 6),
        ...AppPalettes.all.map((p) {
          final selected = p.id == currentId;
          return GestureDetector(
            onTap: () {
              paletteNotifier.value = p;
              StorageService.savePaletteId(p.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(left: 8),
              width: selected ? 28 : 22,
              height: selected ? 28 : 22,
              decoration: BoxDecoration(
                color: p.leftPanel,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppTheme.darkText : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─── きょうのきろく ────────────────────────────────────────────────────────────

class _TodayStatsRow extends StatelessWidget {
  const _TodayStatsRow();

  @override
  Widget build(BuildContext context) {
    const drills = [
      ('hiragana', '📖', 'こくご'),
      ('math', '🔢', 'さんすう'),
      ('katakana_quiz', '🌼', 'カタカナ'),
      ('clock', '🕐', 'とけい'),
      ('memory', '🃏', 'カード'),
      ('sugoroku', '🎲', 'スゴロク'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'きょうのきろく',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textGray,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: drills.map((d) {
            final (key, emoji, label) = d;
            return Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: DailyStatsService.drillNotifier(key),
                builder: (context, count, _) {
                  final done = count > 0;
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: done
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: done
                            ? const Color(0xFF81C784)
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: done
                                ? const Color(0xFF2E7D32)
                                : AppTheme.textGray,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          done ? '$countかい' : '-',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: done
                                ? const Color(0xFF388E3C)
                                : const Color(0xFFBBBBBB),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
