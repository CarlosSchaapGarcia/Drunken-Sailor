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

  Future<void> start() async {
    await stop();

    // Emit last known position immediately so the UI isn't blank while waiting for a fresh fix.
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

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    _positionSubscription?.cancel();
    _controller.close();
  }
}
