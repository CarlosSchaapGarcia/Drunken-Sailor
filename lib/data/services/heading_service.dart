import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';

/// Service for reading device heading using magnetometer + accelerometer.
/// Provides smooth, filtered heading updates with jitter suppression (< 5°).
/// Works in portrait and landscape modes—sensors are in device physical frame.
class HeadingService {
  static final HeadingService _instance = HeadingService._internal();

  factory HeadingService() => _instance;

  HeadingService._internal();

  final StreamController<double> _headingController = StreamController.broadcast();
  Stream<double> get headingStream => _headingController.stream;

  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Jitter filtering: ignore heading changes < 5 degrees
  static const double _jitterThresholdDegrees = 5.0;

  // Smoothing window: average heading over last 500ms for < 500ms lag
  static const Duration _smoothingWindow = Duration(milliseconds: 250);

  double? _lastHeading;
  double? _lastAccelX, _lastAccelY, _lastAccelZ;
  double? _lastMagX, _lastMagY, _lastMagZ;

  // For smoothing: keep a rolling buffer of recent headings
  final List<double> _headingBuffer = [];
  final List<int> _headingTimestamps = [];

  double? _currentHeading;

  double? get currentHeading => _currentHeading;

  /// Start reading magnetometer + accelerometer
  Future<void> start() async {
    await stop();

    // Try to get initial position heading (GPS-based) as fallback
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (pos.heading.isFinite && pos.heading >= 0) {
        _lastHeading = pos.heading;
        _currentHeading = pos.heading;
        _headingController.add(pos.heading);
      }
    } catch (_) {}

    // Subscribe to accelerometer (gravity vector)
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      _lastAccelX = event.x;
      _lastAccelY = event.y;
      _lastAccelZ = event.z;
      _updateHeading();
    });

    // Subscribe to magnetometer (magnetic field)
    _magnetometerSubscription = magnetometerEvents.listen((event) {
      _lastMagX = event.x;
      _lastMagY = event.y;
      _lastMagZ = event.z;
      _updateHeading();
    });
  }

  Future<void> stop() async {
    await _magnetometerSubscription?.cancel();
    await _accelerometerSubscription?.cancel();
    _magnetometerSubscription = null;
    _accelerometerSubscription = null;
    _headingBuffer.clear();
    _headingTimestamps.clear();
  }

  void dispose() {
    stop();
    _headingController.close();
  }

  /// Calculate heading from accelerometer + magnetometer using rotation matrix
  void _updateHeading() {
    if (_lastAccelX == null ||
        _lastAccelY == null ||
        _lastAccelZ == null ||
        _lastMagX == null ||
        _lastMagY == null ||
        _lastMagZ == null) {
      return;
    }

    // Normalize accelerometer (gravity)
    final ax = _lastAccelX!;
    final ay = _lastAccelY!;
    final az = _lastAccelZ!;
    final aMag = math.sqrt(ax * ax + ay * ay + az * az);
    if (aMag == 0) return;
    final axn = ax / aMag;
    final ayn = ay / aMag;
    final azn = az / aMag;

    // Normalize magnetometer
    final mx = _lastMagX!;
    final my = _lastMagY!;
    final mz = _lastMagZ!;
    final mMag = math.sqrt(mx * mx + my * my + mz * mz);
    if (mMag == 0) return;
    final mxn = mx / mMag;
    final myn = my / mMag;
    final mzn = mz / mMag;

    // Cross product: east = mag × accel
    final ex = ayn * mzn - azn * myn;
    final ey = azn * mxn - axn * mzn;
    final ez = axn * myn - ayn * mxn;

    // Normalize east vector
    final eMag = math.sqrt(ex * ex + ey * ey + ez * ez);
    if (eMag == 0) return;
    final exn = ex / eMag;
    final eyn = ey / eMag;
    final ezn = ez / eMag;

    // North = accel × east
    final nx = ayn * ezn - azn * eyn;
    // ny and nz are part of the rotation matrix but not used for heading calculation
    // They're kept for mathematical completeness of the rotation matrix

    // Heading = atan2(east_x, north_x) in phone coordinates
    // atan2 gives angle in phone frame; convert to compass heading
    var heading = math.atan2(exn, nx) * 180 / math.pi;

    // Normalize to 0-360
    heading = (heading + 360) % 360;

    // Apply jitter filtering
    if (_lastHeading != null) {
      final delta = (heading - _lastHeading!).abs();
      if (delta > 180) {
        // Shortest path around 0/360
        if ((heading - _lastHeading! + 360) % 360 < 180) {
          // heading is actually ahead
          if (((heading - _lastHeading! + 360) % 360) < _jitterThresholdDegrees) {
            return;
          }
        } else {
          // heading is actually behind
          if (((heading - _lastHeading! + 360) % 360 - 360).abs() < _jitterThresholdDegrees) {
            return;
          }
        }
      } else if (delta < _jitterThresholdDegrees) {
        return;
      }
    }

    _lastHeading = heading;

    // Add to smoothing buffer
    final now = DateTime.now().millisecondsSinceEpoch;
    _headingBuffer.add(heading);
    _headingTimestamps.add(now);

    // Remove old entries outside smoothing window
    while (_headingTimestamps.isNotEmpty &&
        (now - _headingTimestamps.first) > _smoothingWindow.inMilliseconds) {
      _headingBuffer.removeAt(0);
      _headingTimestamps.removeAt(0);
    }

    // Compute average heading with circular mean
    if (_headingBuffer.isNotEmpty) {
      final smoothedHeading = _circularMean(_headingBuffer);
      _currentHeading = smoothedHeading;
      _headingController.add(smoothedHeading);
    }
  }

  /// Compute circular mean of angles (handles 0/360 boundary correctly)
  double _circularMean(List<double> angles) {
    if (angles.isEmpty) return 0;
    if (angles.length == 1) return angles[0];

    double sinSum = 0;
    double cosSum = 0;

    for (final angle in angles) {
      final rad = angle * math.pi / 180;
      sinSum += math.sin(rad);
      cosSum += math.cos(rad);
    }

    var meanRad = math.atan2(sinSum / angles.length, cosSum / angles.length);
    var meanDeg = meanRad * 180 / math.pi;
    return (meanDeg + 360) % 360;
  }
}
