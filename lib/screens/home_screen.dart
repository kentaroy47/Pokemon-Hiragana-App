import 'package:flutter/material.dart';
import '../app_palette.dart';
import '../app_theme.dart';
import 'math_screen.dart';
import 'pokemon_screen.dart' show PokemonPlayMode, PokemonScreen, PokedexDialog;
import '../services/analytics_service.dart';
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

class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: 40),
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🧒', style: TextStyle(fontSize: 80)),
          ),
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
          const SizedBox(height: 32),

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
          const SizedBox(height: 16),

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
