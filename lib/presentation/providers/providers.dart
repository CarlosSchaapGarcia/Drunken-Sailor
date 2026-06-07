import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../data/repositories/firestore_bar_repository.dart';
import '../../data/services/heading_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/vibration_service.dart';
import '../../domain/models/bar.dart';
import '../../domain/repositories/bar_repository.dart';

// -- Infrastructure providers --

final barRepositoryProvider = Provider<BarRepository>(
  (ref) => FirestoreBarRepository(),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

final headingServiceProvider = Provider<HeadingService>(
  (ref) => HeadingService(),
);

final vibrationServiceProvider = Provider<VibrationService>(
  (ref) => VibrationService(),
);

// -- UI state providers --

final currentThemeProvider = StateProvider<String>((ref) => 'pirate');

final selectedBarProvider = StateProvider<Bar?>((ref) => null);

final showDebugOverlayProvider = StateProvider<bool>((ref) => false);

// -- Location stream --

final locationStreamProvider = StreamProvider<Position>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.positionStream;
});

// -- Nearest bar distance (meters; null = no bars nearby, negative = all closed) --
class NearestBarInfo {
  final Bar bar;
  // Positive = open distance in meters; Negative = closed (distance negative)
  final int distanceMeters;

  NearestBarInfo({required this.bar, required this.distanceMeters});
}

// -- Nearest bar info (bar + distance meters; null = no bars nearby) --
final nearestBarProvider = FutureProvider.autoDispose<NearestBarInfo?>((ref) async {
  // Waits for the first GPS position — keeps provider in loading state until then.
  final pos = await ref.watch(locationStreamProvider.future);

  final repo = ref.read(barRepositoryProvider);
  // Fetch all bars (uses cache when available) and compute nearest locally.
  final all = await repo.getAllBars();
  if (all.isEmpty) return null;

  final now = DateTime.now();
  // Prefer open bars; fall back to any bar if none open
  final open = all.where((b) => b.isOpenAt(now)).toList();
  final candidates = open.isNotEmpty ? open : all;

  // Find nearest candidate
  Bar nearest = candidates.first;
  var bestDist = nearest.distanceTo(pos.latitude, pos.longitude);
  for (final b in candidates.skip(1)) {
    final d = b.distanceTo(pos.latitude, pos.longitude);
    if (d < bestDist) {
      nearest = b;
      bestDist = d;
    }
  }

  return NearestBarInfo(bar: nearest, distanceMeters: open.isNotEmpty ? bestDist : -bestDist);
});

// -- Vibration trigger on distance change --
final vibrationTriggerProvider = StreamProvider.autoDispose<void>((ref) {
  final nearestBarAsync = ref.watch(nearestBarProvider);
  final vibrationService = ref.watch(vibrationServiceProvider);

  return nearestBarAsync.maybeWhen(
    data: (info) {
      if (info == null) {
        vibrationService.stop();
        return Stream.value(null);
      }

      final absDistance = info.distanceMeters.abs();

      // Update vibration based on distance
      if (absDistance <= 50000) {
        vibrationService.updateForDistance(absDistance);
      } else {
        vibrationService.stop();
      }

      return Stream.value(null);
    },
    orElse: () {
      vibrationService.stop();
      return Stream.value(null);
    },
  );
});

final openBarPositionsProvider = StreamProvider.autoDispose<List<BarRelativePosition>>((ref) {
  final locationStream = ref.watch(locationStreamProvider.stream);

  return locationStream.asyncMap((pos) async {
    final repo = ref.read(barRepositoryProvider);
    // Fetch all bars (uses cache) and compute positions locally so radar shows
    // the same dataset as other views even if geohash tiles are missing.
    final all = await repo.getAllBars();

    final now = DateTime.now();
    final heading = pos.heading.isFinite ? pos.heading : 0.0;

    // Debug log counts
    // ignore: avoid_print
    print('[Radar] position=${pos.latitude},${pos.longitude} — totalBars=${all.length}');

    // Use a larger maxRangeMeters so radar shows bars a few km away
    const maxRangeMeters = 5000.0;

    return all
        .where((bar) => bar.isOpenAt(now))
        .map((bar) => BarRelativePosition.fromBar(
              bar,
              pos.latitude,
              pos.longitude,
              heading,
              maxRangeMeters: maxRangeMeters,
            ))
        .where((position) => position.visible)
        .toList();
  });
});

// -- Compass Heading (magnetometer + accelerometer) --

final headingStreamProvider = StreamProvider<double>((ref) {
  final service = ref.watch(headingServiceProvider);
  // Start reading sensors when this provider is watched
  ref.onDispose(() => service.stop());
  // Return stream (service.start() is called by compass_view on first build)
  return service.headingStream;
});

// -- Nearest bar true bearing (for compass needle) --

/// Provides bearing to nearest open bar from user's current location
/// Returns null if no nearby bars or all closed; bearing is true north (0-360°)
final nearestBarBearingProvider = StreamProvider.autoDispose<double?>((ref) async* {
  final locationStream = ref.watch(locationStreamProvider.stream);
  final repo = ref.read(barRepositoryProvider);

  await for (final pos in locationStream) {
    final nearby = await repo.findNearbyBars(
      pos.latitude,
      pos.longitude,
      radiusKm: 5.0,
      limit: 10,
    );

    final now = DateTime.now();
    final openBars = nearby.where((b) => b.isOpenAt(now)).toList();

    if (openBars.isEmpty) {
      yield null;
    } else {
      // Sort by distance and get nearest
      openBars.sort((a, b) {
        final distA = a.distanceTo(pos.latitude, pos.longitude);
        final distB = b.distanceTo(pos.latitude, pos.longitude);
        return distA.compareTo(distB);
      });

      final nearest = openBars.first;
      final bearing = nearest.bearingTo(pos.latitude, pos.longitude);
      yield bearing;
    }
  }
});

// -- Compass needle rotation (smooth animation target) --

/// Combines device heading + target bearing to nearest bar
/// Emits the needle rotation angle (0-360°)
/// Updates smoothly with jitter filtering and < 500ms lag
final compassNeedleProvider = StreamProvider.autoDispose<double>((ref) {
  final headingStream = ref.watch(headingStreamProvider.stream);
  final bearingStream = ref.watch(nearestBarBearingProvider.stream);

  // Combine both streams: update whenever either changes
  return _combineHeadingAndBearing(headingStream, bearingStream);
});

/// Helper to combine two streams
Stream<double> _combineHeadingAndBearing(
  Stream<double> headingStream,
  Stream<double?> bearingStream,
) {
  final controller = StreamController<double>();
  double? lastHeading;
  double? lastBearing;

  // Listen to heading stream
  final headingSub = headingStream.listen((heading) {
    lastHeading = heading;
    if (lastHeading != null) {
      final bearing = lastBearing;
      if (bearing == null) {
        controller.add(0.0);
      } else {
        final angle = (bearing - lastHeading! + 360) % 360;
        controller.add(angle);
      }
    }
  }, onError: (e) => controller.addError(e));

  // Listen to bearing stream
  final bearingSub = bearingStream.listen((bearing) {
    lastBearing = bearing;
    if (lastHeading != null) {
      if (bearing == null) {
        controller.add(0.0);
      } else {
        final angle = (bearing - lastHeading! + 360) % 360;
        controller.add(angle);
      }
    }
  }, onError: (e) => controller.addError(e));

  controller.onCancel = () {
    headingSub.cancel();
    bearingSub.cancel();
  };

  return controller.stream;
}
