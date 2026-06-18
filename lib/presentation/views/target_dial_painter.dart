import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Paints a static dial: outer ring, degree ticks, and an optional label
/// (e.g. "BAR") drawn at the top, which then gets rotated by wrapping this
/// painter's CustomPaint in a Transform.rotate driven by the live bearing.
///
/// Splitting "draw the dial" (this painter, static) from "rotate it"
/// (the parent widget, driven by the stream) keeps repaints cheap — we
/// only rebuild the Transform, not repaint ticks/ring every frame.
class TargetDialPainter extends CustomPainter {
  TargetDialPainter({
    required this.backgroundColor,
    required this.ringColor,
    required this.tickColor,
  });

  final Color backgroundColor;
  final Color ringColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawCircle(center, radius, bgPaint);

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 2, ringPaint);

    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 2;

    // 36 ticks (every 10°), longer tick every 30°.
    for (int i = 0; i < 36; i++) {
      final angle = (i * 10) * math.pi / 180;
      final isMajor = i % 3 == 0;
      final outer = radius - 6;
      final inner = isMajor ? radius - 18 : radius - 12;

      final p1 = Offset(
        center.dx + outer * math.sin(angle),
        center.dy - outer * math.cos(angle),
      );
      final p2 = Offset(
        center.dx + inner * math.sin(angle),
        center.dy - inner * math.cos(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TargetDialPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.tickColor != tickColor;
  }
}