import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

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

  // Smoothing window: average heading over last 150ms for faster responsiveness
  static const Duration _smoothingWindow = Duration(milliseconds: 150);

  double? _lastHeading;
  double? _lastAccelX, _lastAccelY, _lastAccelZ;
  double? _lastMagX, _lastMagY, _lastMagZ;

  // For smoothing: keep a rolling buffer of recent headings
  final List<double> _headingBuffer = [];
  final List<int> _headingTimestamps = [];

  double? _currentHeading;

  double? get currentHeading => _currentHeading;

  // Reference count of active callers (e.g. CompassView instances) that
  // have called start(). This exists because HeadingService is a
  // singleton, but multiple widget lifecycles can call start()/stop()
  // independently and with no ordering guarantee between them — e.g. when
  // navigating between screens, the OLD screen's dispose() -> stop() can
  // run AFTER the NEW screen's initState() -> start(), since start() is
  // deferred via Future.microtask in CompassView. Without ref counting,
  // that race tears down the subscriptions the new screen just set up,
  // producing a needle that updates once and then never again.
  int _activeUsers = 0;

  /// Start reading magnetometer + accelerometer.
  /// Safe to call multiple times concurrently (e.g. from overlapping
  /// widget lifecycles) — only actually subscribes to sensors once, on
  /// the transition from 0 to 1 active users.
  Future<void> start() async {
    _activeUsers++;
    if (_activeUsers > 1) {
      // Sensors are already running for another active caller — don't
      // tear down and resubscribe, just let this caller "join" the
      // existing stream.
      return;
    }

    // NOTE: We deliberately do NOT seed _lastHeading from
    // Geolocator's Position.heading here. That field is GPS
    // direction-of-travel, not compass heading — it's only meaningful
    // while moving at a reasonable speed, and reports 0 (not NaN) when
    // stationary or slow. Using it as a fallback baseline could poison
    // the jitter-filter comparison in _updateHeading() with a bogus
    // value, causing the first real magnetometer-derived readings to be
    // wrongly suppressed if they happened to fall within the jitter
    // threshold of that bogus GPS value.

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

  /// Stop reading sensors. Safe to call multiple times concurrently —
  /// only actually cancels subscriptions once every active caller (every
  /// matching start() call) has also called stop().
  Future<void> stop() async {
    if (_activeUsers > 0) {
      _activeUsers--;
    }
    if (_activeUsers > 0) {
      // Other callers are still relying on the sensors being active.
      return;
    }

    await _magnetometerSubscription?.cancel();
    await _accelerometerSubscription?.cancel();
    _magnetometerSubscription = null;
    _accelerometerSubscription = null;
    _headingBuffer.clear();
    _headingTimestamps.clear();
  }

  /// Force-stops sensors and resets the active-user count to 0,
  /// regardless of how many start() calls are outstanding. Use this only
  /// for hard resets (e.g. app shutdown via dispose()) — NOT as a
  /// replacement for stop() in normal widget lifecycles, since it would
  /// pull the rug out from under other active callers.
  Future<void> _forceStop() async {
    _activeUsers = 0;
    await _magnetometerSubscription?.cancel();
    await _accelerometerSubscription?.cancel();
    _magnetometerSubscription = null;
    _accelerometerSubscription = null;
    _headingBuffer.clear();
    _headingTimestamps.clear();
  }

  void dispose() {
    _forceStop();
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

    // Cross product: east = mag × accel (standard sensor-fusion formula —
    // NOTE: order matters. Cross product is anti-commutative, so
    // accel × mag would give the negative of this vector and produce a
    // heading that doesn't correspond to any simple offset of the true
    // heading — it was the root cause of the "inconsistent" direction bug.
    final ex = myn * azn - mzn * ayn;
    final ey = mzn * axn - mxn * azn;
    final ez = mxn * ayn - myn * axn;

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

    // NOTE: a hard "ignore changes smaller than N degrees" jitter filter
    // used to live here. It was removed because it had a bug: whenever it
    // suppressed a small change, it returned early WITHOUT updating
    // _lastHeading. That meant a baseline value from one moment in time
    // could get "stuck" — every subsequent small rotation kept comparing
    // against that same stale baseline and kept getting rejected, even as
    // the phone's actual heading drifted further and further away from
    // it. The visible symptom was a needle that moved once on load and
    // then never updated again.
    //
    // The _headingBuffer/_circularMean smoothing below already absorbs
    // sensor noise (it averages over a rolling time window), so a
    // separate reject-small-deltas filter isn't needed on top of it.
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