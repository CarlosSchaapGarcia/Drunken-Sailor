import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../providers/providers.dart';

class CompassView extends ConsumerStatefulWidget {
  const CompassView({Key? key}) : super(key: key);

  @override
  ConsumerState<CompassView> createState() => _CompassViewState();
}

class _CompassViewState extends ConsumerState<CompassView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  double _targetRotation = 0;
  double _currentRotation = 0;
  bool _isInitialized = false;
  bool _isSensorActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize heading service on first build
    Future.microtask(() {
      if (mounted) {
        _initializeHeading();
      }
    });
  }

  void _initializeHeading() async {
    final headingService = ref.read(headingServiceProvider);
    try {
      await headingService.start();
      if (mounted) {
        setState(() => _isSensorActive = true);
      }
    } catch (e) {
      debugPrint('Error initializing heading service: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final headingService = ref.read(headingServiceProvider);
    if (state == AppLifecycleState.resumed && !_isSensorActive) {
      headingService.start();
      setState(() => _isSensorActive = true);
    } else if (state == AppLifecycleState.paused) {
      headingService.stop();
      setState(() => _isSensorActive = false);
    }
  }

  void _updateRotation(double newRotation) {
    if (!mounted) return;

    // Calculate shortest rotation path
    double delta = (newRotation - _currentRotation + 180) % 360 - 180;
    if (delta.isNaN) delta = 0;

    _targetRotation = _currentRotation + delta;

    _rotationAnimation = Tween<double>(
      begin: _currentRotation,
      end: _targetRotation,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward(from: 0.0);

    _rotationAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _currentRotation = _rotationAnimation.value % 360;
        });
      }
    });

    if (!_isInitialized) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    final headingService = ref.read(headingServiceProvider);
    headingService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the compass needle rotation stream
    final needleAsync = ref.watch(compassNeedleProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 400,
          child: needleAsync.when(
            data: (rotation) {
              // Update animation when bearing changes
              if (_isInitialized) {
                _updateRotation(rotation);
              }

              return CustomPaint(
                painter: CompassPainter(rotation: _currentRotation),
              );
            },
            loading: () => CustomPaint(
              painter: CompassPainter(rotation: 0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFFfbbf24)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSensorActive ? 'Acquiring heading...' : 'Initializing sensors...',
                      style: const TextStyle(
                        color: Color(0xFFfbbf24),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            error: (error, stack) => CustomPaint(
              painter: CompassPainter(rotation: 0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFef4444),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Heading unavailable',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFef4444),
                          ),
                    ),
                  ],
                ),
              ),
            ),
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

    // Draw compass needle pointing to target bearing
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
    // Needle points to the rotation angle (0° = north/up)
    final angle = (rotation - 90) * math.pi / 180;

    // Red needle pointing to target bar (top)
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

    // Light needle (back opposite side)
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
