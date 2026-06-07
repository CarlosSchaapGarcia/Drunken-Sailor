import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  static const platform = MethodChannel('com.example.drunken_sailor/vibration');

  Timer? _vibrationTimer;
  bool _isVibrating = false;
  int _lastAmplitude = 0;

  // Thresholds (meters)
  static const int threshold50m = 50; // 50 meters
  static const int threshold20m = 20; // 20 meters
  static const int threshold10m = 10; // 10 meters
  static const int stopThreshold = 51; // >50m stops vibration

  Future<void> updateForDistance(int distanceMeters) async {
    if (distanceMeters > stopThreshold) {
      await stop();
      return;
    }

    if (distanceMeters < threshold10m) {
      // Under 10m: aggressive 200ms on, 100ms off, amplitude 255
      await _startVibration(
        onDuration: 200,
        offDuration: 100,
        amplitude: 255,
        pattern: const [0, 200, 100], // wait, vibrate, pause (repeat)
      );
    } else if (distanceMeters < threshold20m) {
      // 10m-20m: 300ms on, 200ms off, amplitude scales 128→255
      final ratio = (distanceMeters - threshold10m).toDouble() /
          (threshold20m - threshold10m).toDouble();
      final amplitude = (128 + (127 * (1 - ratio))).toInt();
      await _startVibration(
        onDuration: 300,
        offDuration: 200,
        amplitude: amplitude,
        pattern: const [0, 300, 200],
      );
    } else if (distanceMeters < threshold50m) {
      // 20m-50m: baseline 500ms on, 500ms off, amplitude 128
      await _startVibration(
        onDuration: 500,
        offDuration: 500,
        amplitude: 128,
        pattern: const [0, 500, 500],
      );
    }
  }

  Future<void> _startVibration({
    required int onDuration,
    required int offDuration,
    required int amplitude,
    required List<int> pattern,
  }) async {
    // Skip if already vibrating with same intensity
    if (_isVibrating && _lastAmplitude == amplitude) {
      return;
    }

    await stop();

    _isVibrating = true;
    _lastAmplitude = amplitude;

    if (Platform.isAndroid) {
      try {
        // Try modern VibrationEffect (API 26+)
        await platform.invokeMethod('startVibration', {
          'onDuration': onDuration,
          'offDuration': offDuration,
          'amplitude': amplitude,
        });
      } catch (e) {
        // Fallback: use simple pattern repeat
        _startPatternVibration(pattern, offDuration);
      }
    }
  }

  void _startPatternVibration(List<int> pattern, int pauseBetweenRepeats) {
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(
      Duration(milliseconds: pattern.fold(0, (a, b) => a + b) + pauseBetweenRepeats),
      (_) {
        // Timer handles continuous repetition via periodic callback
      },
    );
  }

  Future<void> stop() async {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _isVibrating = false;
    _lastAmplitude = 0;

    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod('stopVibration');
      } catch (_) {}
    }
  }

  void dispose() {
    _vibrationTimer?.cancel();
  }
}
