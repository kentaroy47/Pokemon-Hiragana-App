import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/hiragana_data.dart';
import '../data/katakana_data.dart';
import 'practice_screen.dart';
import 'math_screen.dart';
import 'pokemon_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left: yellow panel
          Expanded(
            flex: 5,
            child: Container(
              color: AppTheme.yellowPanel,
              child: const _LeftPanel(),
            ),
          ),
          // Right: cream panel
          Expanded(
            flex: 7,
            child: Container(
              color: AppTheme.background,
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
            color: AppTheme.blueAccent,
            onTap: () async {
              final result = await showDialog<_KokugoMode>(
                context: context,
                builder: (_) => const _KokugoModeDialog(),
              );
              if (result == null) return;
              if (!context.mounted) return;
              switch (result) {
                case _KokugoMode.hiragana:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PracticeScreen(
                        rows: hiraganaRows,
                        title: 'ひらがな',
                      ),
                    ),
                  );
                case _KokugoMode.hiraganaHard:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PokemonScreen(mode: PokemonPlayMode.hiragana),
                    ),
                  );
                case _KokugoMode.katakana:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PracticeScreen(
                        rows: katakanaRows,
                        title: 'カタカナ',
                      ),
                    ),
                  );
                case _KokugoMode.katakanaHard:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PokemonScreen(mode: PokemonPlayMode.katakana),
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
            color: const Color(0xFF5CAD5C),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MathScreen()),
              );
            },
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
            description: '1もじずつれんしゅう',
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
            description: '1もじずつれんしゅう',
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
