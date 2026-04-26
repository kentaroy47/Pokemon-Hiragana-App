import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../widgets/pokemon_widgets.dart';
import '../widgets/pokedex_dialog.dart';

// ─── 報酬ポケモンプレビュー ───────────────────────────────────────────────────
/// ラウンド中に左パネルで表示する「ゲットのチャンス！」ブロック

class DrillPokemonRewardPreview extends StatelessWidget {
  final PokemonEntry pokemon;
  final bool isShiny;

  const DrillPokemonRewardPreview({
    super.key,
    required this.pokemon,
    required this.isShiny,
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
              color: pokemon.color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: PokemonImage(
            pokemon: pokemon,
            size: 100,
            isShiny: isShiny,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            pokemon.katakana,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
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

// ─── ゲット済みポケモンバー ───────────────────────────────────────────────────
/// 左パネル下部の「🎯 ゲット: count + 図鑑ボタン」行

class DrillCaughtBar extends StatelessWidget {
  final int caughtCount;
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;

  const DrillCaughtBar({
    super.key,
    required this.caughtCount,
    required this.caughtPokemon,
    required this.shinyCaughtNames,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        ],
      ),
    );
  }
}

// ─── 4択ボタン ───────────────────────────────────────────────────────────────
/// ドリル画面共通の選択肢ボタン（正解/不正解の色変え付き）

class DrillChoiceButton extends StatelessWidget {
  final String choice;
  final String correct;
  final String? selected;
  final ValueChanged<String> onTap;
  final double fontSize;

  const DrillChoiceButton({
    super.key,
    required this.choice,
    required this.correct,
    required this.selected,
    required this.onTap,
    this.fontSize = 18,
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
          child: Icon(Icons.cancel_rounded,
              color: Color(0xFFEF9A9A), size: 22),
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
                  fontSize: fontSize,
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

// ─── ラウンド結果オーバーレイ ─────────────────────────────────────────────────
/// ドリル共通のラウンド終了アニメーション＋ポケモンゲット演出

class DrillRoundResultOverlay extends StatefulWidget {
  /// 結果テキスト（例: "5 もんで クリア！" / "5 / 5 もんだい せいかい！"）
  final String scoreLabel;
  final int starsTotal;
  final int starsFilled;
  final bool passed;
  final PokemonEntry? rewardPokemon;
  final bool isShiny;
  final VoidCallback onNext;

  const DrillRoundResultOverlay({
    super.key,
    required this.scoreLabel,
    required this.starsTotal,
    required this.starsFilled,
    required this.passed,
    required this.rewardPokemon,
    required this.isShiny,
    required this.onNext,
  });

  @override
  State<DrillRoundResultOverlay> createState() =>
      _DrillRoundResultOverlayState();
}

class _DrillRoundResultOverlayState extends State<DrillRoundResultOverlay>
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
                      children: List.generate(widget.starsTotal, (i) {
                        final filled = i < widget.starsFilled;
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
                      widget.scoreLabel,
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
                                child: Pokeball(
                                    color: pokemon.color, size: 36),
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
                              color:
                                  AppTheme.pinkAccent.withValues(alpha: 0.25),
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
