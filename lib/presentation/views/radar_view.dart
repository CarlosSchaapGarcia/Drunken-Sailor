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

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: RepaintBoundary(
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
        );
      },
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

  Color _opacity(Color color, double opacity) =>
      color.withValues(alpha: opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final gaugeWidth = size.width < 420 ? 38.0 : 56.0;
    final sonarWidth = math.max(0.0, size.width - gaugeWidth);
    final center = Offset(sonarWidth / 2, size.height * 0.48);
    final radius = math.max(
      0.0,
      math.min(sonarWidth, size.height) * 0.42,
    );

    _drawWaterBackground(canvas, size);
    _drawDepthGauge(canvas, size, gaugeWidth);
    _drawAmbientRipples(canvas, center, radius, sweepAngle);
    // _drawBackground(canvas, center, radius);
    _drawGrid(canvas, center, radius);
    _drawSweepGradient(canvas, center, radius, sweepAngle);
    _drawSweepLine(canvas, center, radius, sweepAngle);

    for (final target in targets) {
      _drawTarget(canvas, center, radius, target);
      final progress = pingProgress[target.bar.id];
      if (progress != null) {
        _drawPingRing(canvas, center, radius, target, progress);
      }
    }

    _drawCenterDot(canvas, center);
    _drawStatusText(canvas, center.translate(0, radius + 28));
    _drawScanlines(canvas, center, radius);
  }

  void _drawWaterBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF00111D),
            Color(0xFF002344),
            Color(0xFF00182F),
          ],
          stops: [0.0, 0.58, 1.0],
        ).createShader(Offset.zero & size),
    );

    final bandPaint = Paint()..isAntiAlias = true;
    const bands = [
      (0.14, 0.07, Color(0x0B4DD9FF)),
      (0.36, 0.04, Color(0x0820BFFF)),
      (0.56, 0.07, Color(0x0740C8FF)),
      (0.75, 0.04, Color(0x0A2DB8FF)),
      (0.92, 0.06, Color(0x0618A0E0)),
    ];

    for (final (position, width, color) in bands) {
      final x = size.width * position;
      final w = size.width * width;
      final path = Path()
        ..moveTo(x - size.height * 0.30, 0)
        ..lineTo(x - size.height * 0.30 + w, 0)
        ..lineTo(x + w, size.height)
        ..lineTo(x, size.height)
        ..close();

      canvas.drawPath(path, bandPaint..color = color);
    }
  }

  void _drawBackground(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x3314F1D9),
            const Color(0x1A00A7C7),
            const Color(0x08001424),
          ],
          stops: const [0.0, 0.54, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _opacity(const Color(0xFF18D5C3), 0.38)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      center,
      radius + 7,
      Paint()
        ..color = _opacity(const Color(0xFF00B7CF), 0.08)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawGrid(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = _opacity(const Color(0xFF20D9D0), 0.18)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final ringFractions = [0.34, 0.54, 0.66, 0.78];
    for (final fraction in ringFractions) {
      canvas.drawCircle(center, radius * fraction, paint);
    }

    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), paint);
  }

  void _drawSweepLine(
      Canvas canvas, Offset center, double radius, double angle) {
    final rad = (angle - 90) * math.pi / 180;
    canvas.drawLine(
      center,
      Offset(center.dx + radius * math.cos(rad),
          center.dy + radius * math.sin(rad)),
      Paint()
        ..color = _opacity(const Color(0xFF20FDE0), 0.9)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawLine(
      center,
      Offset(center.dx + radius * math.cos(rad),
          center.dy + radius * math.sin(rad)),
      Paint()
        ..color = _opacity(const Color(0xFF20FDE0), 0.22)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _drawSweepGradient(
      Canvas canvas, Offset center, double radius, double angle) {
    final sweepRad = (angle - 90) * math.pi / 180;
    const trailDegrees = 38.0;
    const steps = 26;

    for (int i = 0; i < steps; i++) {
      final t = i / steps;
      final opacity = t * 0.18;
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
          ..color = _opacity(const Color(0xFF00D9FF), opacity)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawTarget(
      Canvas canvas, Offset center, double radius, BarRelativePosition target) {
    final distance = radius * target.distanceRatio;
    final rad = (target.angleDegrees - 90) * math.pi / 180;
    final pos = Offset(
      center.dx + distance * math.cos(rad),
      center.dy + distance * math.sin(rad),
    );

    final dotRadius = target.distanceRatio < 0.45 ? 4.0 : 2.4;
    canvas.drawCircle(
      pos,
      dotRadius + 4,
      Paint()
        ..color = _opacity(const Color(0xFF20FDE0), 0.20)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      pos,
      dotRadius,
      Paint()
        ..color = const Color(0xFF22FFE0)
        ..style = PaintingStyle.fill,
    );
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
        ..color = _opacity(const Color(0xFF22FFE0), opacity * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawCenterDot(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = _opacity(const Color(0xFF22FFE0), 0.18)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
        center,
        4,
        Paint()
          ..color = const Color(0xFF22FFE0)
          ..style = PaintingStyle.fill);
  }

  void _drawScanlines(Canvas canvas, Offset center, double radius) {
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    final paint = Paint()
      ..color = _opacity(Colors.black, 0.07)
      ..strokeWidth = 1;

    for (double y = center.dy - radius; y < center.dy + radius; y += 3) {
      canvas.drawLine(
          Offset(center.dx - radius, y), Offset(center.dx + radius, y), paint);
    }

    canvas.restore();
  }

  void _drawAmbientRipples(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
  ) {
    final progress = (angle % 360) / 360;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (int i = 0; i < 4; i++) {
      final phase = (progress + i / 4) % 1.0;
      final ringRadius = phase * radius;
      final opacity = (1.0 - phase) * (phase < 0.20 ? phase / 0.20 : 1.0);

      canvas.drawCircle(
        center,
        ringRadius.clamp(0.1, radius),
        paint
          ..color = _opacity(const Color(0xFF00CCFF), opacity.clamp(0.0, 0.16))
          ..strokeWidth = (1.0 - phase) * 1.4 + 0.4,
      );
    }
  }

  void _drawDepthGauge(Canvas canvas, Size size, double gaugeWidth) {
    const color = Color(0xFF2DD4BF);
    final left = size.width - gaugeWidth;
    final spineX = size.width - 2;
    final paint = Paint()
      ..color = _opacity(color, 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final tickPaint = Paint()
      ..color = _opacity(color, 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(spineX, 0), Offset(spineX, size.height), paint);

    const tickCount = 20;
    for (int i = 0; i <= tickCount; i++) {
      final y = size.height * i / tickCount;
      final major = i % 2 == 0;
      final tickLength = major ? 12.0 : 6.0;
      canvas.drawLine(
        Offset(spineX - tickLength, y),
        Offset(spineX, y),
        major ? paint : tickPaint,
      );
    }

    final markerY = size.height * 0.5;
    canvas.drawLine(
      Offset(spineX - 20, markerY),
      Offset(spineX, markerY),
      Paint()
        ..color = _opacity(color, 0.9)
        ..strokeWidth = 2,
    );

    final arrow = Path()
      ..moveTo(spineX - 22, markerY)
      ..lineTo(spineX - 14, markerY - 4)
      ..lineTo(spineX - 14, markerY + 4)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()
        ..color = _opacity(color, 0.9)
        ..style = PaintingStyle.fill,
    );

    _drawText(
      canvas,
      '50m',
      Offset(math.max(left + 4, spineX - 38), markerY),
      size.width < 420 ? 7 : 9,
      _opacity(color, 0.95),
      FontWeight.w600,
    );
    _drawRotatedText(
      canvas,
      'DEPTH',
      Offset(spineX - 9, 18),
      size.width < 420 ? 6 : 8,
      _opacity(color, 0.52),
    );
  }

  void _drawStatusText(Canvas canvas, Offset position) {
    _drawText(
      canvas,
      'ACTIVE SONAR - 360',
      position,
      8,
      _opacity(const Color(0xFF2DD4BF), 0.58),
      FontWeight.w600,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    double fontSize, [
    Color color = const Color(0xFF10b981),
    FontWeight fontWeight = FontWeight.w500,
  ]) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontFamily: 'monospace',
              fontWeight: fontWeight)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, position.translate(-tp.width / 2, -tp.height / 2));
  }

  void _drawRotatedText(
    Canvas canvas,
    String text,
    Offset position,
    double fontSize,
    Color color,
  ) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(math.pi / 2);
    _drawText(canvas, text, Offset.zero, fontSize, color, FontWeight.w600);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) =>
      oldDelegate.sweepAngle != sweepAngle ||
      oldDelegate.targets != targets ||
      oldDelegate.pingProgress != pingProgress;
}
