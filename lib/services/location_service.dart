import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Simple foreground-only location service for use while the app is active.
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
    // Ensure permissions and services are ready are handled by caller.
    _timer?.cancel();
    // Immediately fetch once and then every 5 seconds
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
      if (!enabled) {
        // nothing emitted; caller should handle prompting to open settings
        return;
      }

      // Try to obtain a reasonably accurate fix (<= 20m). Retry a few times before giving up.
      const int maxAttempts = 3;
      Position? best;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          final p = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 8),
          );
          if (best == null || (p.accuracy < best.accuracy)) best = p;
          if (p.accuracy <= 20) {
            best = p;
            break;
          }
        } catch (_) {}
        // small delay between attempts
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (best != null) {
        _lastKnown = best;
        _controller.add(best);
      }
    } catch (e) {
      // ignore errors here; caller can listen to stream/errors if needed
    }
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
