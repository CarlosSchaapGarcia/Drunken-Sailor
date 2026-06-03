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

final nearestBarProvider = FutureProvider.autoDispose<int?>((ref) async {
  // Waits for the first GPS position — keeps provider in loading state until then.
  final pos = await ref.watch(locationStreamProvider.future);

  final repo = ref.read(barRepositoryProvider);
  // findNearbyBars falls back to getAllBars when geohash returns empty,
  // which throws BarServiceException when truly offline with no cache.
  final nearby = await repo.findNearbyBars(pos.latitude, pos.longitude);
  if (nearby.isEmpty) return null;

  final now = DateTime.now();
  final open = nearby.where((b) => b.isOpenAt(now)).toList();
  if (open.isNotEmpty) return open.first.distanceTo(pos.latitude, pos.longitude);
  return -nearby.first.distanceTo(pos.latitude, pos.longitude);
});

// -- Vibration trigger on distance change --
final vibrationTriggerProvider = StreamProvider.autoDispose<void>((ref) {
  final nearestBarAsync = ref.watch(nearestBarProvider);
  final vibrationService = ref.watch(vibrationServiceProvider);

  return nearestBarAsync.maybeWhen(
    data: (distance) {
      if (distance == null) {
        vibrationService.stop();
        return Stream.value(null);
      }

      final absDistance = distance.abs();
      
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
    final nearby = await repo.findNearbyBars(
      pos.latitude,
      pos.longitude,
      radiusKm: 2.0,
      limit: null,
    );

    final now = DateTime.now();
    final heading = pos.heading.isFinite ? pos.heading : 0.0;

    return nearby
        .where((bar) => bar.isOpenAt(now))
        .map((bar) => BarRelativePosition.fromBar(
              bar,
              pos.latitude,
              pos.longitude,
              heading,
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
