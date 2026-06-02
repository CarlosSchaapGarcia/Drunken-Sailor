import 'package:flutter/material.dart';
import 'dart:math' as math;

class CompassView extends StatefulWidget {
  const CompassView({Key? key}) : super(key: key);

  @override
  State<CompassView> createState() => _CompassViewState();
}

class _CompassViewState extends State<CompassView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _currentRotation = 45;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Simulate compass rotation
    _controller.addListener(() {
      setState(() {
        _currentRotation = (45 + (_controller.value * 360)) % 360;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 400,
          child: CustomPaint(
            painter: CompassPainter(rotation: _currentRotation),
          ),
        ),
      ),
    );
  }
}

class CompassPainter extends CustomPainter {
  final double rotation;

  CompassPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Draw outer circle with border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFfbbf24)
        ..style = PaintingStyle.fill,
    );

    // Gradient background
    final paint = Paint()
      ..shader = SweepGradient(
        colors: [const Color(0xFFfcd34d), const Color(0xFFdab122)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);

    // Border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFb45309)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );

    // Draw cardinal directions
    _drawCardinalDirections(canvas, center, radius);

    // Draw tick marks
    _drawTickMarks(canvas, center, radius);

    // Draw compass needle
    _drawNeedle(canvas, center, radius);

    // Draw center dot
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = const Color(0xFF78350f)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = const Color(0xFFFEF3C7)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Draw pirate decorations
    _drawText(canvas, '☠️', center.translate(-radius + 15, -radius + 15), 24);
    _drawText(canvas, '⚓', center.translate(-radius + 10, radius - 20), 18);
  }

  void _drawCardinalDirections(Canvas canvas, Offset center, double radius) {
    const directions = ['N', 'E', 'S', 'W'];
    const angles = [0, 90, 180, 270];

    for (int i = 0; i < directions.length; i++) {
      final angle = angles[i] * math.pi / 180;
      final x = center.dx + (radius - 30) * math.cos(angle - math.pi / 2);
      final y = center.dy + (radius - 30) * math.sin(angle - math.pi / 2);

      _drawText(
        canvas,
        directions[i],
        Offset(x, y),
        28,
        bold: true,
        color: const Color(0xFF78350f),
      );
    }
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final isCardinal = i % 3 == 0;
      final markLength = isCardinal ? 12 : 6;
      final markWidth = isCardinal ? 2.0 : 1.0;

      final x1 = center.dx + (radius - 10) * math.cos(angle);
      final y1 = center.dy + (radius - 10) * math.sin(angle);
      final x2 = center.dx + (radius - 10 - markLength) * math.cos(angle);
      final y2 = center.dy + (radius - 10 - markLength) * math.sin(angle);

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = isCardinal ? const Color(0xFF78350f) : const Color(0xFF92400e)
          ..strokeWidth = markWidth,
      );
    }
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius) {
    final needleLength = radius * 0.6;
    final angle = (rotation - 90) * math.pi / 180;

    // Red needle (pointing)
    final redEnd = Offset(
      center.dx + needleLength * math.cos(angle),
      center.dy + needleLength * math.sin(angle),
    );

    final path1 = Path();
    path1.moveTo(center.dx, center.dy);
    path1.lineTo(
      center.dx + 4 * math.cos(angle + math.pi / 6),
      center.dy + 4 * math.sin(angle + math.pi / 6),
    );
    path1.lineTo(redEnd.dx, redEnd.dy);
    path1.lineTo(
      center.dx + 4 * math.cos(angle - math.pi / 6),
      center.dy + 4 * math.sin(angle - math.pi / 6),
    );
    path1.close();

    canvas.drawPath(
      path1,
      Paint()
        ..color = const Color(0xFFdc2626)
        ..style = PaintingStyle.fill,
    );

    // Light needle (back)
    final angle180 = (rotation - 90 + 180) * math.pi / 180;
    final lightEnd = Offset(
      center.dx + (needleLength * 0.4) * math.cos(angle180),
      center.dy + (needleLength * 0.4) * math.sin(angle180),
    );

    final path2 = Path();
    path2.moveTo(center.dx, center.dy);
    path2.lineTo(
      center.dx + 3 * math.cos(angle180 + math.pi / 6),
      center.dy + 3 * math.sin(angle180 + math.pi / 6),
    );
    path2.lineTo(lightEnd.dx, lightEnd.dy);
    path2.lineTo(
      center.dx + 3 * math.cos(angle180 - math.pi / 6),
      center.dy + 3 * math.sin(angle180 - math.pi / 6),
    );
    path2.close();

    canvas.drawPath(
      path2,
      Paint()
        ..color = const Color(0xFFF1F5F9)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    double fontSize, {
    bool bold = false,
    Color color = const Color(0xFF000000),
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      position.translate(-textPainter.width / 2, -textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(CompassPainter oldDelegate) => oldDelegate.rotation != rotation;
}
