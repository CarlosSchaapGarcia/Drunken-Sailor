import 'package:flutter/material.dart';
import 'dart:math' as math;

class RadarView extends StatefulWidget {
  const RadarView({Key? key}) : super(key: key);

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
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
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: RadarPainter(sweepAngle: _controller.value * 360),
              );
            },
          ),
        ),
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double sweepAngle;

  RadarPainter({required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF064e3b),
            const Color(0xFF0f172a),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF047857)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );

    // Concentric Circles
    for (int i = 1; i <= 3; i++) {
      final circleRadius = radius * (0.6 + (i * 0.1));
      canvas.drawCircle(
        center,
        circleRadius,
        Paint()
          ..color = const Color(0xFF047857).withOpacity(0.3)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }

    // Grid Lines (Cross)
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      Paint()
        ..color = const Color(0xFF047857).withOpacity(0.3)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      Paint()
        ..color = const Color(0xFF047857).withOpacity(0.3)
        ..strokeWidth = 1,
    );

    // Sweep Line
    final sweepRad = (sweepAngle - 90) * math.pi / 180;
    final sweepEndX = center.dx + radius * math.cos(sweepRad);
    final sweepEndY = center.dy + radius * math.sin(sweepRad);

    canvas.drawLine(
      center,
      Offset(sweepEndX, sweepEndY),
      Paint()
        ..color = const Color(0xFF10b981).withOpacity(0.8)
        ..strokeWidth = 2,
    );

    // Sweep Gradient
    _drawSweepGradient(canvas, center, radius, sweepAngle);

    // Target Blips
    _drawBlip(canvas, center, radius, 0.35, 0.60, 3, true); // Larger blip with ping
    _drawBlip(canvas, center, radius, 0.65, 0.40, 2, false); // Smaller blip

    // Center Dot
    canvas.drawCircle(
      center,
      3,
      Paint()
        ..color = const Color(0xFF10b981)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      3,
      Paint()
        ..color = const Color(0xFF10b981)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Submarine Periscope Icon
    _drawText(canvas, '🔭', center.translate(radius - 25, -radius + 20), 20);

    // Wave Icon
    _drawText(canvas, '🌊', center.translate(-radius + 20, radius - 20), 18);

    // Scanline effect (drawn on top)
    _drawScanlines(canvas, size);
  }

  void _drawBlip(Canvas canvas, Offset center, double radius, double relativeRadius,
      double angle, double size, bool withPing) {
    final rad = (angle * 360 - 90) * math.pi / 180;
    final x = center.dx + (radius * relativeRadius) * math.cos(rad);
    final y = center.dy + (radius * relativeRadius) * math.sin(rad);

    canvas.drawCircle(
      Offset(x, y),
      size,
      Paint()
        ..color = const Color(0xFF10b981)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(x, y),
      size,
      Paint()
        ..color = const Color(0xFF10b981)
        ..style = PaintingStyle.fill,
    );

    if (withPing) {
      // Draw pulsing circle
      canvas.drawCircle(
        Offset(x, y),
        size * 2,
        Paint()
          ..color = const Color(0xFF10b981).withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _drawSweepGradient(Canvas canvas, Offset center, double radius, double angle) {
    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: (angle - 90) * math.pi / 180,
        endAngle: (angle - 90 + 60) * math.pi / 180,
        colors: [
          const Color(0xFF10b981).withOpacity(0),
          const Color(0xFF10b981).withOpacity(0.4),
          const Color(0xFF10b981).withOpacity(0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  void _drawScanlines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..strokeWidth = 0;

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset position, double fontSize) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize),
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
  bool shouldRepaint(RadarPainter oldDelegate) => oldDelegate.sweepAngle != sweepAngle;
}
