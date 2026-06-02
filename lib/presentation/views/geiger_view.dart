import 'package:flutter/material.dart';
import 'dart:math';

class GeigerView extends StatefulWidget {
  const GeigerView({Key? key}) : super(key: key);

  @override
  State<GeigerView> createState() => _GeigerViewState();
}

class _GeigerViewState extends State<GeigerView> with SingleTickerProviderStateMixin {
  late double intensity;
  late bool isClicking;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    intensity = 65;
    isClicking = false;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    // Simulate varying radiation levels
    Future.delayed(Duration.zero, _updateIntensity);

    // Geiger counter clicking sound simulation
    Future.delayed(Duration.zero, _updateClicking);
  }

  void _updateIntensity() {
    final random = Random();
    final change = (random.nextDouble() - 0.5) * 10;
    setState(() {
      intensity = (intensity + change).clamp(20, 95);
    });
    Future.delayed(const Duration(seconds: 1), _updateIntensity);
  }

  void _updateClicking() {
    final clickInterval = (1000 - (intensity * 8)).toInt();
    setState(() {
      isClicking = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          isClicking = false;
        });
      }
    });
    Future.delayed(Duration(milliseconds: clickInterval), _updateClicking);
  }

  Color _getColor() {
    if (intensity < 30) return const Color(0xFF4ade80);
    if (intensity < 60) return const Color(0xFFfacc15);
    return const Color(0xFFef4444);
  }

  String _getStatus() {
    if (intensity < 30) return 'SAFE';
    if (intensity < 60) return 'ELEVATED';
    return 'DANGER';
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
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Semicircular Gauge
            SizedBox(
              width: 300,
              height: 200,
              child: CustomPaint(
                painter: GaugePainter(intensity: intensity),
              ),
            ),
            const SizedBox(height: 40),

            // Digital Reading
            Text(
              '${intensity.toInt()}',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: _getColor(),
              ),
            ),
            Text(
              'μSv/h',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.normal,
                fontFamily: 'monospace',
                color: _getColor(),
              ),
            ),
            const SizedBox(height: 16),

            // Status Text
            Text(
              _getStatus(),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94a3b8),
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            // Bar Indicator
            SizedBox(
              width: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9999),
                child: LinearProgressIndicator(
                  value: intensity / 100,
                  minHeight: 16,
                  backgroundColor: const Color(0xFF1e293b),
                  valueColor: AlwaysStoppedAnimation<Color>(_getColor()),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Nuclear Symbols
            if (isClicking)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFef4444),
                  ),
                ),
              ),
            Text(
              '☢️',
              style: TextStyle(
                fontSize: 48,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '⚠️',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double intensity;

  GaugePainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 20);
    final radius = 80.0;

    // Background Arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi,
      pi,
      false,
      Paint()
        ..color = const Color(0xFF1e293b)
        ..strokeWidth = 20
        ..style = PaintingStyle.stroke,
    );

    // Colored Arc
    Color arcColor;
    if (intensity < 30) {
      arcColor = const Color(0xFF22c55e);
    } else if (intensity < 60) {
      arcColor = const Color(0xFFeab308);
    } else {
      arcColor = const Color(0xFFef4444);
    }

    final sweepAngle = pi * (intensity / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi,
      sweepAngle,
      false,
      Paint()
        ..color = arcColor
        ..strokeWidth = 20
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Tick Marks
    for (int i = 0; i < 11; i++) {
      final angle = -pi + (i * pi / 10);
      final x1 = center.dx + (radius - 10) * cos(angle);
      final y1 = center.dy + (radius - 10) * sin(angle);
      final x2 = center.dx + (radius - 25) * cos(angle);
      final y2 = center.dy + (radius - 25) * sin(angle);

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = const Color(0xFF64748b)
          ..strokeWidth = 2,
      );
    }

    // Needle
    final needleAngle = -pi + (pi * (intensity / 100));
    final needleLength = radius - 15;
    final needleX = center.dx + needleLength * cos(needleAngle);
    final needleY = center.dy + needleLength * sin(needleAngle);

    canvas.drawLine(
      center,
      Offset(needleX, needleY),
      Paint()
        ..color = const Color(0xFFf1f5f9)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Center Dot
    canvas.drawCircle(
      center,
      5,
      Paint()
        ..color = const Color(0xFF1e293b)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      5,
      Paint()
        ..color = const Color(0xFFf1f5f9)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(GaugePainter oldDelegate) => oldDelegate.intensity != intensity;
}
