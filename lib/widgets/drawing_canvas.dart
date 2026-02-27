import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

class DrawingCanvas extends StatefulWidget {
  final String character;
  final int totalStrokes;
  final void Function(int score)? onComplete;

  const DrawingCanvas({
    super.key,
    required this.character,
    required this.totalStrokes,
    this.onComplete,
  });

  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];
  bool _completed = false;
  Size _canvasSize = Size.zero;

  int get strokesDone => _strokes.length;

  void reset() {
    setState(() {
      _strokes.clear();
      _current = [];
      _completed = false;
    });
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_completed) return;
    setState(() => _current = [e.localPosition]);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_completed || _current.isEmpty) return;
    setState(() => _current = [..._current, e.localPosition]);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_completed || _current.isEmpty) return;
    setState(() {
      _strokes.add(List.from(_current));
      _current = [];
      if (_strokes.length >= widget.totalStrokes) {
        _completed = true;
        widget.onComplete?.call(_calculateScore());
      }
    });
  }

  /// Calculates a 1-3 star score based on stroke length and canvas coverage.
  int _calculateScore() {
    if (_strokes.isEmpty || _canvasSize.isEmpty) return 1;

    // Total ink length
    double totalLength = 0;
    for (final stroke in _strokes) {
      for (int i = 1; i < stroke.length; i++) {
        totalLength += (stroke[i] - stroke[i - 1]).distance;
      }
    }

    // Bounding box of all strokes
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final stroke in _strokes) {
      for (final pt in stroke) {
        if (pt.dx < minX) minX = pt.dx;
        if (pt.dy < minY) minY = pt.dy;
        if (pt.dx > maxX) maxX = pt.dx;
        if (pt.dy > maxY) maxY = pt.dy;
      }
    }
    final bboxArea = math.max(0.0, (maxX - minX) * (maxY - minY));
    final canvasArea = _canvasSize.width * _canvasSize.height;

    // Thresholds relative to canvas size
    final minLengthPerStroke = _canvasSize.shortestSide * 0.08;
    final hasLength = totalLength >= minLengthPerStroke * widget.totalStrokes;
    final hasCoverage = canvasArea > 0 && bboxArea >= canvasArea * 0.04;

    if (hasLength && hasCoverage) return 3;
    if (hasLength || hasCoverage) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Canvas area
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
              return Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                child: CustomPaint(
                  painter: _CanvasPainter(
                    character: widget.character,
                    strokes: _strokes,
                    currentStroke: _current,
                    currentStrokeIndex: _strokes.length,
                    completed: _completed,
                  ),
                  child: Container(),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Stroke guide + reset row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  for (int i = 0; i < widget.totalStrokes; i++)
                    _StrokeDot(
                      number: i + 1,
                      isCompleted: i < _strokes.length,
                      isCurrent: i == _strokes.length && !_completed,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    'かくすう：${widget.totalStrokes}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: reset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.darkText,
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                ),
                child: const Text('やりなおす', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}

class _StrokeDot extends StatelessWidget {
  final int number;
  final bool isCompleted;
  final bool isCurrent;

  const _StrokeDot({
    required this.number,
    required this.isCompleted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (isCompleted) {
      bg = AppTheme.greenStroke;
      fg = Colors.white;
    } else if (isCurrent) {
      bg = AppTheme.pinkAccent;
      fg = Colors.white;
    } else {
      bg = const Color(0xFFDDDDDD);
      fg = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final String character;
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final int currentStrokeIndex;
  final bool completed;

  _CanvasPainter({
    required this.character,
    required this.strokes,
    required this.currentStroke,
    required this.currentStrokeIndex,
    required this.completed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawReferenceChar(canvas, size);
    _drawStrokes(canvas, size);
    if (!completed && currentStrokeIndex >= 0) {
      _drawStrokeNumberBadge(canvas, size);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    canvas.drawRRect(rrect, Paint()..color = AppTheme.canvasBg);
    canvas.save();
    canvas.clipRRect(rrect);

    final linePaint = Paint()
      ..color = AppTheme.canvasLine
      ..strokeWidth = 1;
    const lineSpacing = 36.0;
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final dashPaint = Paint()
      ..color = AppTheme.canvasDash
      ..strokeWidth = 1;
    const dashLen = 8.0;
    const gapLen = 6.0;
    final cx = size.width / 2;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(cx, y), Offset(cx, y + dashLen), dashPaint);
      y += dashLen + gapLen;
    }
    canvas.restore();
  }

  void _drawReferenceChar(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: character,
        style: TextStyle(
          fontSize: size.height * 0.72,
          color: AppTheme.refChar,
          fontFamily: 'serif',
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
    );
  }

  void _drawStrokes(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.inkColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
    );
    for (final stroke in strokes) {
      _drawStrokePath(canvas, stroke, paint);
    }
    if (currentStroke.isNotEmpty) {
      _drawStrokePath(canvas, currentStroke, paint);
    }
    canvas.restore();
  }

  void _drawStrokePath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points[0], 2, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
      return;
    }
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawStrokeNumberBadge(Canvas canvas, Size size) {
    final label = '${currentStrokeIndex + 1}';
    const badgeRadius = 16.0;
    final cx = size.width * 0.72;
    final cy = size.height * 0.28;

    canvas.drawCircle(
      Offset(cx, cy),
      badgeRadius,
      Paint()..color = AppTheme.pinkAccent,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_CanvasPainter old) => true;
}
