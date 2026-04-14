import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── 時計の文字盤 ─────────────────────────────────────────────────────────────

class ClockFaceWidget extends StatelessWidget {
  final int hour;
  final int minute;

  const ClockFaceWidget({super.key, required this.hour, required this.minute});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _ClockPainter(hour: hour, minute: minute),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final int hour;
  final int minute;

  const _ClockPainter({required this.hour, required this.minute});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, Paint()..color = Colors.white);

    canvas.drawCircle(
      center,
      radius - 3,
      Paint()
        ..color = const Color(0xFF2D3436)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke,
    );

    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 1; i <= 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final pos = Offset(
        center.dx + (radius - 26) * math.cos(angle),
        center.dy + (radius - 26) * math.sin(angle),
      );
      tp.text = TextSpan(
        text: '$i',
        style: TextStyle(
          fontSize: radius * 0.16,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2D3436),
        ),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    for (int i = 0; i < 60; i++) {
      final angle = i * 6 * math.pi / 180;
      final inner = i % 5 == 0 ? radius - 16 : radius - 8;
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(angle),
            center.dy + inner * math.sin(angle)),
        Offset(center.dx + (radius - 4) * math.cos(angle),
            center.dy + (radius - 4) * math.sin(angle)),
        Paint()
          ..color = const Color(0xFF636E72)
          ..strokeWidth = i % 5 == 0 ? 2.5 : 1,
      );
    }

    final minuteAngle = (minute * 6 - 90) * math.pi / 180;
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius - 18) * math.cos(minuteAngle),
        center.dy + (radius - 18) * math.sin(minuteAngle),
      ),
      Paint()
        ..color = const Color(0xFF2D3436)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    final hourAngle =
        ((hour % 12 + minute / 60) * 30 - 90) * math.pi / 180;
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.52) * math.cos(hourAngle),
        center.dy + (radius * 0.52) * math.sin(hourAngle),
      ),
      Paint()
        ..color = const Color(0xFF2D3436)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(center, 7, Paint()..color = const Color(0xFFFF6B6B));
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.hour != hour || old.minute != minute;
}
