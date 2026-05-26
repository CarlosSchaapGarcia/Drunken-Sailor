import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Simple foreground-only location service for use while the app is active.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final StreamController<Position> _controller = StreamController.broadcast();
  Stream<Position> get positionStream => _controller.stream;

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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      // Only emit if accuracy is reasonable
      if (pos.accuracy <= 50) {
        _controller.add(pos);
      } else {
        // still emit — consumer can decide to ignore low-accuracy values
        _controller.add(pos);
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
