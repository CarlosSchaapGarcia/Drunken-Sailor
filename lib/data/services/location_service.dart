import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final StreamController<Position> _controller = StreamController.broadcast();
  Stream<Position> get positionStream => _controller.stream;

  Position? _lastKnown;
  Position? get lastKnown => _lastKnown;

  StreamSubscription<Position>? _positionSubscription;

  // Reference count of active callers. Mirrors HeadingService's pattern so
  // that if two CompassView instances are briefly alive at once (e.g.
  // during a navigation transition), one instance's dispose()/stop() can't
  // tear down GPS out from under the other instance that's still using it.
  int _activeUsers = 0;

  /// Start listening to location updates. Safe to call multiple times
  /// concurrently — only actually starts the underlying subscription on
  /// the transition from 0 to 1 active users.
  Future<void> start() async {
    _activeUsers++;
    if (_activeUsers > 1) {
      // Already started for another active caller.
      return;
    }

    // Start the continuous stream first so we never miss a position event.
    // distanceFilter: 0 ensures Android delivers the very first fix
    // immediately rather than waiting until the device has moved 10m.
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen((position) {
      _lastKnown = position;
      _controller.add(position);
    }, onError: (_) {});

    // Fire-and-forget: seed the stream with a cached position so the UI
    // isn't blank while the GPS warms up. We do NOT await this — awaiting
    // getCurrentPosition() before setting up getPositionStream() was the
    // original bug: if getCurrentPosition() hangs, the stream subscription
    // was never created and no positions ever arrived.
    _seedPosition();
  }

  Future<void> _seedPosition() async {
    // Try the fast path: last known position (immediate on most devices).
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && _lastKnown == null && _activeUsers > 0) {
        _lastKnown = last;
        _controller.add(last);
        return;
      }
    } catch (_) {}
  }

  /// Stop listening. Safe to call multiple times concurrently — only
  /// actually cancels the subscription once every active caller (every
  /// matching start() call) has also called stop().
  Future<void> stop() async {
    if (_activeUsers > 0) {
      _activeUsers--;
    }
    if (_activeUsers > 0) {
      return;
    }

    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Force-stops regardless of outstanding start() calls. Use only for
  /// hard resets (e.g. app shutdown via dispose()).
  Future<void> _forceStop() async {
    _activeUsers = 0;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    _forceStop();
    _controller.close();
  }
}