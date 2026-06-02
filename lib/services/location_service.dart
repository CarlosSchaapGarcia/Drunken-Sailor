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

  Timer? _timer;

  Future<void> start() async {
    _timer?.cancel();

    // Emit last known position immediately so the UI isn't blank while waiting for a fresh fix.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      _lastKnown = last;
      _controller.add(last);
    }

    await _fetchAndEmit();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _fetchAndEmit();
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetchAndEmit() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      // First attempt: fast, accepts any accuracy — emits quickly so UI updates.
      try {
        final quick = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 3),
        );
        if (_lastKnown == null || quick.accuracy < (_lastKnown!.accuracy * 1.5)) {
          _lastKnown = quick;
          _controller.add(quick);
        }
        if (quick.accuracy <= 20) return; // good enough, skip refine pass
      } catch (_) {}

      // Refine pass: try for a high-accuracy fix if the quick one wasn't precise enough.
      try {
        final precise = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 8),
        );
        if (_lastKnown == null || precise.accuracy < _lastKnown!.accuracy) {
          _lastKnown = precise;
          _controller.add(precise);
        }
      } catch (_) {}
    } catch (_) {}
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
