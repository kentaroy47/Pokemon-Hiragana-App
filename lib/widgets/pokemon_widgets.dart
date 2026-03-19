import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/pokemon_data.dart';

// ─── ポケモン画像（ネットワーク） ──────────────────────────────────────────────

class PokemonImage extends StatelessWidget {
  final PokemonEntry pokemon;
  final double size;
  final bool isShiny;

  const PokemonImage(
      {super.key,
      required this.pokemon,
      required this.size,
      this.isShiny = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        isShiny ? pokemon.shinyImageUrl : pokemon.imageUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
              child: Pokeball(color: pokemon.color, size: size * 0.75));
        },
        errorBuilder: (context, error, stack) {
          return Center(
              child: Pokeball(color: pokemon.color, size: size * 0.75));
        },
      ),
    );
  }
}

// ─── ポケボール描画 ────────────────────────────────────────────────────────────

class Pokeball extends StatelessWidget {
  final Color color;
  final double size;

  const Pokeball({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PokeballPainter(color: color),
    );
  }
}

class _PokeballPainter extends CustomPainter {
  final Color color;
  const _PokeballPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 1;

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi, math.pi, true, Paint()..color = color);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        0, math.pi, true, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = Colors.black87
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy),
        Paint()
          ..color = Colors.black87
          ..strokeWidth = 2.5);
    canvas.drawCircle(Offset(cx, cy), r * 0.24, Paint()..color = Colors.black87);
    canvas.drawCircle(Offset(cx, cy), r * 0.17, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PokeballPainter old) => old.color != color;
}

// ─── コンフェッティ（キラキラエフェクト） ──────────────────────────────────────

class _Particle {
  final double startX;
  final double speed;
  final double wobble;
  final double rotation;
  final double size;
  final Color color;
  final bool isRect;

  const _Particle({
    required this.startX,
    required this.speed,
    required this.wobble,
    required this.rotation,
    required this.size,
    required this.color,
    required this.isRect,
  });
}

class ConfettiOverlay extends StatefulWidget {
  final Color baseColor;
  const ConfettiOverlay({super.key, required this.baseColor});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;
  final _random = math.Random();

  static const _palette = [
    Color(0xFFFFD700), Color(0xFFFF69B4), Color(0xFF00CED1),
    Color(0xFF98FB98), Color(0xFFFF6347), Color(0xFFDDA0DD),
    Color(0xFFFFFFFF),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    )..forward();

    final colors = [..._palette, widget.baseColor];
    _particles = List.generate(60, (_) {
      return _Particle(
        startX: _random.nextDouble(),
        speed: 0.6 + _random.nextDouble() * 0.6,
        wobble: (_random.nextDouble() - 0.5) * 2,
        rotation: _random.nextDouble() * math.pi * 2,
        size: 6 + _random.nextDouble() * 10,
        color: colors[_random.nextInt(colors.length)],
        isRect: _random.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return IgnorePointer(
          child: CustomPaint(
            painter: _ConfettiPainter(
              particles: _particles,
              progress: _ctrl.value,
            ),
          ),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  const _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final alpha =
          progress < 0.75 ? 1.0 : 1.0 - ((progress - 0.75) / 0.25);
      paint.color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0));
      final y = size.height * progress * p.speed - p.size;
      final x = size.width * p.startX +
          math.sin(progress * math.pi * 4 + p.wobble * math.pi) * 30;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * math.pi * 4 * p.speed);
      if (p.isRect) {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
