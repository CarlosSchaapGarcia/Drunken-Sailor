import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class GeigerView extends ConsumerStatefulWidget {
  const GeigerView({Key? key}) : super(key: key);

  @override
  ConsumerState<GeigerView> createState() => _GeigerViewState();
}

class _GeigerViewState extends ConsumerState<GeigerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late double intensity;
  double _targetIntensity = 10;
  Timer? _animationTimer;
  Timer? _clickTimer;
  bool isClicking = false;

  @override
  void initState() {
    super.initState();
    intensity = 10;
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _scheduleIntensityAnimation();
    _scheduleClick();
  }

  void _scheduleIntensityAnimation() {
    _animationTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final jitter = (math.Random().nextDouble() - 0.5) * 2.2;
      final next = intensity + ((_targetIntensity + jitter) - intensity) * 0.22;
      setState(() {
        intensity = next.clamp(4, 99);
      });
      _scheduleIntensityAnimation();
    });
  }

  void _scheduleClick() {
    final clickInterval = (1050 - (intensity * 8.2)).clamp(160, 900).toInt();
    _clickTimer = Timer(Duration(milliseconds: clickInterval), () {
      if (!mounted) return;
      setState(() => isClicking = true);
      Timer(const Duration(milliseconds: 90), () {
        if (mounted) setState(() => isClicking = false);
      });
      _scheduleClick();
    });
  }

  Color get _levelColor {
    if (intensity < 32) return const Color(0xFF22c55e);
    if (intensity < 62) return const Color(0xFFFACC15);
    return const Color(0xFFFF4545);
  }

  String get _status {
    if (intensity < 32) return 'SAFE';
    if (intensity < 62) return 'ELEVATED';
    return 'DANGER';
  }

  double _intensityForDistance(int distanceMeters) {
    const maxHotRangeMeters = 5000.0;
    final normalizedDistance =
        (distanceMeters.abs() / maxHotRangeMeters).clamp(0.0, 1.0);
    final falloff = math.pow(normalizedDistance, 0.58).toDouble();
    return 96 - (falloff * 88);
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _clickTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(vibrationTriggerProvider);
    final nearestBarAsync = ref.watch(nearestBarProvider);
    _targetIntensity = nearestBarAsync.maybeWhen(
      data: (info) =>
          info == null ? 6 : _intensityForDistance(info.distanceMeters.abs()),
      loading: () => 10,
      orElse: () => 6,
    );

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final stripeHeight = (size.height * 0.12).clamp(54.0, 92.0);
          final gaugeWidth = (size.width * 0.34).clamp(230.0, 360.0);
          final trefoilSize = (size.shortestSide * 0.04).clamp(18.0, 28.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF12080B)),
              Positioned.fill(
                child: CustomPaint(
                  painter: _RadiationFieldPainter(
                    color: _levelColor.withValues(
                      alpha: isClicking ? 0.12 : 0.055,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: stripeHeight,
                  child: const CustomPaint(painter: HazardStripePainter()),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: stripeHeight,
                  child:
                      const CustomPaint(painter: HazardStripeBottomPainter()),
                ),
              ),
              Positioned(
                top: stripeHeight + 10,
                left: 14,
                child: _TrefoilBolt(size: trefoilSize),
              ),
              Positioned(
                top: stripeHeight + 10,
                right: 14,
                child: _TrefoilBolt(size: trefoilSize),
              ),
              Positioned(
                top: stripeHeight + 10,
                right: 44,
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.35, end: 1).animate(
                    CurvedAnimation(
                      parent: _pulseController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isClicking
                          ? const Color(0xFFFF4545)
                          : const Color(0xFF7F1D1D),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFF4545,
                          ).withValues(alpha: 0.42),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const SizedBox(width: 9, height: 9),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, stripeHeight * 0.18),
                  child: SizedBox(
                    width: gaugeWidth,
                    child: _GeigerInstrument(
                      intensity: intensity,
                      levelColor: _levelColor,
                      status: _status,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GeigerInstrument extends StatelessWidget {
  const _GeigerInstrument({
    required this.intensity,
    required this.levelColor,
    required this.status,
  });

  final double intensity;
  final Color levelColor;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1.55,
          child: CustomPaint(
            painter: GaugePainter(intensity: intensity, color: levelColor),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                intensity.round().toString(),
                style: TextStyle(
                  color: levelColor,
                  fontFamily: 'monospace',
                  fontSize: 48,
                  height: 0.95,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: levelColor.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 7, bottom: 5),
                child: Text(
                  'uSv/h',
                  style: TextStyle(
                    color: levelColor.withValues(alpha: 0.9),
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          status,
          style: TextStyle(
            color: levelColor.withValues(alpha: 0.78),
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 20),
        _RadiationBar(value: intensity / 100, color: levelColor),
      ],
    );
  }
}

class _RadiationBar extends StatelessWidget {
  const _RadiationBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.white.withValues(alpha: 0.13)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value.clamp(0, 1),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ScaleLabel('0', color),
            _ScaleLabel('RADIATION LEVEL', color.withValues(alpha: 0.42)),
            _ScaleLabel('100', color),
          ],
        ),
      ],
    );
  }
}

class _ScaleLabel extends StatelessWidget {
  const _ScaleLabel(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color.withValues(alpha: 0.65),
        fontFamily: 'monospace',
        fontSize: 8,
        fontWeight: FontWeight.w700,
        letterSpacing: text.length > 3 ? 1.1 : 0,
      ),
    );
  }
}

class _TrefoilBolt extends StatelessWidget {
  const _TrefoilBolt({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFACC15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFACC15).withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(size * 0.18),
            child: const CustomPaint(
              painter: RadiationTrefoilPainter(color: Color(0xFF1A1012)),
            ),
          ),
        ],
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  const GaugePainter({required this.intensity, required this.color});

  final double intensity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.9);
    final radius = math.min(size.width * 0.43, size.height * 0.77);
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final backgroundPaint = Paint()
      ..color = const Color(0xFF1D242C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.22
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    canvas.drawArc(arcRect, math.pi, math.pi, false, backgroundPaint);

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.22
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    canvas.drawArc(
        arcRect, math.pi, math.pi * (intensity / 100), false, activePaint);

    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = const Color(0xFF6B7280);
    for (int i = 0; i <= 10; i++) {
      final angle = math.pi + (math.pi * i / 10);
      final isMajor = i == 0 || i == 5 || i == 10;
      final outer = radius - (isMajor ? 1 : radius * 0.05);
      final inner = radius - (isMajor ? radius * 0.19 : radius * 0.13);
      canvas.drawLine(
        Offset(center.dx + outer * math.cos(angle),
            center.dy + outer * math.sin(angle)),
        Offset(center.dx + inner * math.cos(angle),
            center.dy + inner * math.sin(angle)),
        tickPaint
          ..color = isMajor ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
      );
    }

    _drawLabel(canvas, '0', Offset(center.dx - radius - 3, center.dy + 12),
        const Color(0xFF22c55e));
    _drawLabel(canvas, '50', Offset(center.dx, center.dy - radius - 20),
        const Color(0xFFFACC15));
    _drawLabel(canvas, '100', Offset(center.dx + radius + 8, center.dy + 12),
        const Color(0xFFFF4545));

    final needleAngle = math.pi + math.pi * (intensity / 100);
    final needleLength = radius * 0.56;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );

    canvas.drawLine(
      center,
      needleEnd,
      Paint()
        ..color = const Color(0xFFE5E7EB)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xFF121820));
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = const Color(0xFFE5E7EB)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(center, 3.5, Paint()..color = color);
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        canvas, offset - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(GaugePainter oldDelegate) =>
      oldDelegate.intensity != intensity || oldDelegate.color != color;
}

class RadiationTrefoilPainter extends CustomPainter {
  const RadiationTrefoilPainter({this.color = const Color(0xFFFACC15)});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide * 0.46;
    final innerRadius = outerRadius / 3;
    final bladeSpan = 60 * math.pi / 180;

    for (int i = 0; i < 3; i++) {
      final bladeCenter = (270 + i * 120) * math.pi / 180;
      final start = bladeCenter - bladeSpan;
      final end = bladeCenter + bladeSpan;
      final path = Path()
        ..moveTo(
          center.dx + innerRadius * math.cos(start),
          center.dy + innerRadius * math.sin(start),
        )
        ..lineTo(
          center.dx + outerRadius * math.cos(start),
          center.dy + outerRadius * math.sin(start),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: outerRadius),
          start,
          bladeSpan * 2,
          false,
        )
        ..lineTo(
          center.dx + innerRadius * math.cos(end),
          center.dy + innerRadius * math.sin(end),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerRadius),
          end,
          -bladeSpan * 2,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }

    canvas.drawCircle(center, innerRadius * 0.72, paint);
  }

  @override
  bool shouldRepaint(RadiationTrefoilPainter oldDelegate) =>
      oldDelegate.color != color;
}

class HazardStripePainter extends CustomPainter {
  const HazardStripePainter({
    this.yellow = const Color(0xFFFACC15),
    this.black = const Color(0xFF1A1012),
    this.stripeWidth = 24,
    this.borderOnTop = false,
  });

  final Color yellow;
  final Color black;
  final double stripeWidth;
  final bool borderOnTop;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final total = stripeWidth * 2;

    canvas.drawRect(Offset.zero & size, paint..color = black);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    paint.color = yellow;

    final count =
        (size.width / total).ceil() + (size.height / total).ceil() + 3;
    for (int i = -count; i < count * 2; i++) {
      final x = i * total - size.height;
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + stripeWidth + size.height, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }

    canvas.restore();
    canvas.drawLine(
      borderOnTop ? Offset.zero : Offset(0, size.height),
      borderOnTop ? Offset(size.width, 0) : Offset(size.width, size.height),
      Paint()
        ..color = yellow
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(HazardStripePainter oldDelegate) =>
      oldDelegate.yellow != yellow ||
      oldDelegate.black != black ||
      oldDelegate.stripeWidth != stripeWidth ||
      oldDelegate.borderOnTop != borderOnTop;
}

class HazardStripeBottomPainter extends HazardStripePainter {
  const HazardStripeBottomPainter({
    super.yellow,
    super.black,
    super.stripeWidth,
  }) : super(borderOnTop: true);
}

class _RadiationFieldPainter extends CustomPainter {
  const _RadiationFieldPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.58);
    for (int i = 0; i < 3; i++) {
      final radius = size.shortestSide * (0.12 + i * 0.12);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: color.a / (i + 1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_RadiationFieldPainter oldDelegate) =>
      oldDelegate.color != color;
}
