import 'dart:async';
import 'package:vibration/vibration.dart';

class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  Timer? _timer;

  void updateForDistance(int distanceMeters) {
    _stop();

    final intervalMs = _intervalForDistance(distanceMeters);

    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) async {
      final hasAmplitude = await Vibration.hasCustomVibrationsSupport() ?? false;
      if (hasAmplitude) {
        Vibration.vibrate(duration: 80, amplitude: _amplitudeForDistance(distanceMeters));
      } else {
        Vibration.vibrate(duration: 80); // iOS fallback
      }
    });
  }

  void stop() => _stop();

  void _stop() {
    _timer?.cancel();
    _timer = null;
    Vibration.cancel();
  }

  // Closer = faster pulses (150ms gap) | Far away = slow pulses (2000ms gap)
  // Range is 0–100 m; caller already stops vibration beyond 100 m.
  int _intervalForDistance(int distanceMeters) {
    final clamped = distanceMeters.clamp(0, 100);
    final ratio = clamped / 100;
    return (150 + ratio * (2000 - 150)).round();
  }

  // Closer = stronger buzz (255) | Far away = weak buzz (32)
  int _amplitudeForDistance(int distanceMeters) {
    final clamped = distanceMeters.clamp(0, 100);
    final ratio = clamped / 100;
    return (255 - ratio * (255 - 32)).round();
  }
}