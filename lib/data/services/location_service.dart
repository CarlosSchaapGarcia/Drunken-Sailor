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

    // Emit last known position immediately so the UI isn't blank while
    // waiting for a fresh fix.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      _lastKnown = last;
      _controller.add(last);
    }

    if (_lastKnown == null) {
      try {
        final current = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        _lastKnown = current;
        _controller.add(current);
      } catch (_) {}
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen((position) {
      _lastKnown = position;
      _controller.add(position);
    }, onError: (_) {});
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