import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../domain/models/bar.dart';
import '../providers/providers.dart';

class RadarView extends ConsumerStatefulWidget {
  const RadarView({Key? key}) : super(key: key);

  @override
  ConsumerState<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends ConsumerState<RadarView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final Map<String, double> _lastPingAngle = {};
  final Map<String, double> _pingProgress = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  void _checkPings(List<BarRelativePosition> targets) {
    final sweep = _controller.value * 360;

    for (final target in targets) {
      final barAngle = target.angleDegrees;
      final id = target.bar.id;

      final diff = ((sweep - barAngle) + 360) % 360;
      if (diff < 3.0 || diff > 357.0) {
        if (!_lastPingAngle.containsKey(id) ||
            ((_lastPingAngle[id]! - sweep).abs() > 10)) {
          _lastPingAngle[id] = sweep;
          _pingProgress[id] = 0.0;
        }
      }

      if (_pingProgress.containsKey(id)) {
        _pingProgress[id] = _pingProgress[id]! + 0.008;
        if (_pingProgress[id]! >= 1.0) {
          _pingProgress.remove(id);
          _lastPingAngle.remove(id);
        }
      }
    }
  }

  List<BarRelativePosition> _currentTargets = [];

  @override
  void dispose() {
    _controller.removeListener(() => _checkPings(_currentTargets));
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncPositions = ref.watch(openBarPositionsProvider);
    _currentTargets = asyncPositions.maybeWhen(
      data: (bars) => bars,
      orElse: () => const [],
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 400,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              _checkPings(_currentTargets);
              return CustomPaint(
                painter: RadarPainter(
                  sweepAngle: _controller.value * 360,
                  targets: _currentTargets,
                  pingProgress: Map.from(_pingProgress),
                ),
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
  final List<BarRelativePosition> targets;
  final Map<String, double> pingProgress;

  RadarPainter({
    required this.sweepAngle,
    this.targets = const [],
    this.pingProgress = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    _drawBackground(canvas, center, radius);
    _drawGrid(canvas, center, radius);
    _drawText(canvas, 'N', center.translate(0, -radius + 12), 14);
    _drawSweepGradient(canvas, center, radius, sweepAngle);
    _drawSweepLine(canvas, center, radius, sweepAngle);
    _drawScanlines(canvas, size);
    

    for (final target in targets) {
      _drawTarget(canvas, center, radius, target);
      final progress = pingProgress[target.bar.id];
      if (progress != null) {
        _drawPingRing(canvas, center, radius, target, progress);
      }
    }

    _drawCenterDot(canvas, center);
  }

  void _drawBackground(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF064e3b), const Color(0xFF0f172a)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF047857)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawGrid(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFF047857).withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * (0.25 * i), paint);
    }

    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), paint);
  }

  void _drawSweepLine(Canvas canvas, Offset center, double radius, double angle) {
    final rad = (angle - 90) * math.pi / 180;
    canvas.drawLine(
      center,
      Offset(center.dx + radius * math.cos(rad),
          center.dy + radius * math.sin(rad)),
      Paint()
        ..color = const Color(0xFF10b981).withOpacity(0.9)
        ..strokeWidth = 2,
    );
  }

void _drawSweepGradient(Canvas canvas, Offset center, double radius, double angle) {
  final sweepRad = (angle - 90) * math.pi / 180;
  const trailDegrees = 60.0;
  const steps = 20;

  for (int i = 0; i < steps; i++) {
    final t = i / steps;
    final opacity = t * 0.35;
    final startAngle = sweepRad - (trailDegrees * (1.0 - t)) * math.pi / 180;
    final sweepAngle = (trailDegrees / steps) * math.pi / 180;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, startAngle, sweepAngle, false)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF10b981).withOpacity(opacity)
        ..style = PaintingStyle.fill,
    );
  }
}

  void _drawTarget(Canvas canvas, Offset center, double radius, BarRelativePosition target) {
    final distance = radius * target.distanceRatio;
    final rad = (target.angleDegrees - 90) * math.pi / 180;
    final pos = Offset(
      center.dx + distance * math.cos(rad),
      center.dy + distance * math.sin(rad),
    );

    canvas.drawCircle(pos, 2,
        Paint()..color = const Color(0xFF10b981)..style = PaintingStyle.fill);
  }

  void _drawPingRing(Canvas canvas, Offset center, double radius,
      BarRelativePosition target, double progress) {
    final distance = radius * target.distanceRatio;
    final rad = (target.angleDegrees - 90) * math.pi / 180;
    final pos = Offset(
      center.dx + distance * math.cos(rad),
      center.dy + distance * math.sin(rad),
    );

    final ringRadius = 3.0 + progress * 27.0;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    canvas.drawCircle(
      pos,
      ringRadius,
      Paint()
        ..color = const Color(0xFF10b981).withOpacity(opacity * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawCenterDot(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 3,
      Paint()..color = const Color(0xFF10b981)..style = PaintingStyle.fill);
  }

  void _drawScanlines(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    canvas.restore();
  }

  void _drawText(Canvas canvas, String text, Offset position, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: fontSize,
              color: const Color(0xFF10b981),
              fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, position.translate(-tp.width / 2, -tp.height / 2));
  }

  @override
    bool shouldRepaint(RadarPainter oldDelegate) =>
      oldDelegate.sweepAngle != sweepAngle ||
      oldDelegate.targets != targets ||
      oldDelegate.pingProgress != pingProgress;
}