import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/hiragana_data.dart';
import '../data/katakana_data.dart';
import 'practice_screen.dart';
import 'map_screen.dart';
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
            'たのしくかこうね！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 28),

          // ひらがな button
          _MenuButton(
            emoji: '🌸',
            label: 'ひらがな',
            isActive: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PracticeScreen(
                    rows: hiraganaRows,
                    title: 'ひらがな',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // カタカナ button
          _MenuButton(
            emoji: '🌼',
            label: 'カタカナ',
            isActive: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PracticeScreen(
                    rows: katakanaRows,
                    title: 'カタカナ',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // さんすう button
          _MenuButton(
            emoji: '🔢',
            label: 'さんすう',
            isActive: true,
            isMath: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MathScreen()),
              );
            },
          ),
          const SizedBox(height: 12),

          // ポケモン button
          _MenuButton(
            emoji: '🎯',
            label: 'ポケモン',
            isActive: true,
            isPokemon: true,
            onTap: () async {
              final mode = await showDialog<PokemonPlayMode>(
                context: context,
                builder: (_) => const _PokemonModeDialog(),
              );
              if (mode == null) return;
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PokemonScreen(mode: mode),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Level card
          _LevelCard(),
          const SizedBox(height: 20),

          // 50音マップ button
          OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MapScreen(
                    rows: hiraganaRows,
                    title: 'ひらがな',
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.pinkAccent,
              side: const BorderSide(color: AppTheme.pinkAccent, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              '50おんマップ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isActive;
  final bool isPokemon;
  final bool isMath;
  final VoidCallback? onTap;

  const _MenuButton({
    required this.emoji,
    required this.label,
    required this.isActive,
    this.isPokemon = false,
    this.isMath = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = !isActive
        ? const Color(0xFFEEEAE0)
        : isPokemon
            ? AppTheme.levelGold
            : isMath
                ? const Color(0xFF5CAD5C)
                : AppTheme.blueAccent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppTheme.textGray,
              ),
            ),
            if (isPokemon) ...[
              const Spacer(),
              const Text('🎮', style: TextStyle(fontSize: 18)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.levelGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Lv.1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'ひらがなのたまご',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0,
              minHeight: 6,
              backgroundColor: Color(0xFFEEEEEE),
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.levelGold),
            ),
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              '0pt / 100pt',
              style: TextStyle(fontSize: 12, color: AppTheme.textGray),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ポケモンモード選択ダイアログ ───────────────────────────────────────────────

class _PokemonModeDialog extends StatelessWidget {
  const _PokemonModeDialog();

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
            emoji: '🔤',
            label: 'カタカナ',
            description: 'カタカナでなぞる',
            color: AppTheme.blueAccent,
            onTap: () => Navigator.pop(context, PokemonPlayMode.katakana),
          ),
          const SizedBox(height: 8),
          _ModeOption(
            emoji: '💪',
            label: 'カタカナ むずかしい',
            description: 'よみかくし・いろちがいあり',
            color: const Color(0xFFE65100),
            onTap: () => Navigator.pop(context, PokemonPlayMode.katakanaHard),
          ),
          const SizedBox(height: 8),
          _ModeOption(
            emoji: '📝',
            label: 'ひらがな',
            description: 'ひらがなでなぞる',
            color: AppTheme.pinkAccent,
            onTap: () => Navigator.pop(context, PokemonPlayMode.hiragana),
          ),
          const SizedBox(height: 8),
          _ModeOption(
            emoji: '🔥',
            label: 'ひらがな むずかしい',
            description: 'よみかくし・いろちがいあり',
            color: const Color(0xFF6A1B9A),
            onTap: () => Navigator.pop(context, PokemonPlayMode.hiraganaHard),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
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
