import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../../data/services/bearing_utils.dart';
import 'target_dial_painter.dart';

/// Compass that points at the current nearest bar (from [nearestBarProvider])
/// instead of true north.
///
/// Deliberately does NOT own its own Geolocator subscription. The app
/// already has one location pipeline (`locationServiceProvider` ->
/// `nearestBarProvider`, wired up in DrunkenSailorApp), and running a
/// second independent one here would mean two concurrent location
/// subscriptions, two permission flows, and a target that could disagree
/// with the distance indicator shown above the page view. Instead this
/// widget:
///  - reads the target bar's latitude/longitude from `nearestBarProvider`
///  - reads the device's current position from `currentPositionProvider`
///    (a thin wrapper around locationServiceProvider's position stream,
///    see providers.dart)
///  - reads device heading from `deviceHeadingProvider` (a thin wrapper
///    around flutter_compass, since nothing in the existing providers
///    exposes heading)
/// and combines those into a rotation angle itself.
class CompassView extends ConsumerStatefulWidget {
  const CompassView({
    Key? key,
    this.targetLabel = '🍺',
    this.size = 300,
    this.backgroundColor = const Color(0xFF3d2817), // dark wood-ish brown
    this.markerColor = const Color(0xFFfbbf24), // amber
    this.ringColor = const Color(0xFFfbbf24),
    this.tickColor = const Color(0x80fbbf24),
    this.textStyle = const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: Color(0xFFfbbf24),
    ),
  }) : super(key: key);

  final String targetLabel;
  final double size;
  final Color backgroundColor;
  final Color markerColor;
  final Color ringColor;
  final Color tickColor;
  final TextStyle textStyle;

  @override
  ConsumerState<CompassView> createState() => _CompassViewState();
}

class _CompassViewState extends ConsumerState<CompassView> {
  // Unwrapped rotation in degrees — NOT normalized to [0, 360). Needed
  // even without animation: Transform.rotate just applies whatever angle
  // it's given immediately, so on its own it wouldn't spin. The earlier
  // spin came from AnimatedRotation tweening between old/new `turns`
  // with no concept of angle wraparound (359° -> 1° animated as +362°
  // instead of the short +2° hop). Switching to Transform.rotate (no
  // animation, snaps instantly to each sensor reading) removes that
  // specific bug by construction. We keep the unwrap/running-value logic
  // anyway, partly for harmless continuity, and so re-introducing any
  // animation later doesn't reintroduce the spin.
  double? _lastRotation;

  @override
  Widget build(BuildContext context) {
    final nearestAsync = ref.watch(nearestBarProvider);
    final positionAsync = ref.watch(currentPositionProvider);
    final headingAsync = ref.watch(deviceHeadingProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: TargetDialPainter(
                        backgroundColor: widget.backgroundColor,
                        ringColor: widget.ringColor,
                        tickColor: widget.tickColor,
                      ),
                    ),
                    _buildMarker(nearestAsync, positionAsync, headingAsync),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(
    AsyncValue<dynamic> nearestAsync,
    AsyncValue<dynamic> positionAsync,
    AsyncValue<double> headingAsync,
  ) {
    final info = nearestAsync.valueOrNull;
    final position = positionAsync.valueOrNull;
    final heading = headingAsync.valueOrNull; // null only while loading/error

    final hasFix = info != null && position != null && heading != null;

    if (!hasFix) {
      return SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2, color: widget.markerColor),
      );
    }

    final bearingToTarget = bearingBetween(
      fromLat: position.latitude,
      fromLng: position.longitude,
      toLat: info.bar.latitude,
      toLng: info.bar.longitude,
    );
    // hasFix guarantees heading != null
    final normalizedRotation = (bearingToTarget - heading! + 360) % 360;

    final rotation = _unwrap(normalizedRotation);
    _lastRotation = rotation;

    return Transform.rotate(
      angle: rotation * (pi / 180),
      child: _Marker(
        label: widget.targetLabel,
        color: widget.markerColor,
        textStyle: widget.textStyle,
        dialSize: widget.size,
      ),
    );
  }

  /// Picks whichever of {normalized, normalized + 360, normalized - 360}
  /// is closest to the previous rotation. With Transform.rotate (no
  /// animation) this mainly keeps the value continuous frame to frame
  /// rather than jumping discontinuously at the 0/360 boundary; it also
  /// means any future animated transition would take the short way round.
  double _unwrap(double normalized) {
    final last = _lastRotation;
    if (last == null) return normalized;

    final candidates = [normalized - 360, normalized, normalized + 360];
    candidates.sort((a, b) => (a - last).abs().compareTo((b - last).abs()));
    return candidates.first;
  }

}

class _Marker extends StatelessWidget {
  const _Marker({
    required this.label,
    required this.color,
    required this.textStyle,
    required this.dialSize,
  });

  final String label;
  final Color color;
  final TextStyle textStyle;
  final double dialSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: dialSize,
      height: dialSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(dialSize, dialSize),
            painter: _NeedlePainter(color: color),
          ),
          Positioned(
            top: dialSize * 0.08,
            child: Text(label, style: textStyle),
          ),
        ],
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  _NeedlePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tip = Offset(size.width / 2, size.height * 0.12);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, paint);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) =>
      oldDelegate.color != color;
}