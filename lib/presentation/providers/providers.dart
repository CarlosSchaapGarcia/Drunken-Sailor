import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/repositories/firestore_bar_repository.dart';
import '../../data/services/location_service.dart';
import '../../domain/models/bar.dart';
import '../../domain/repositories/bar_repository.dart';

// -- Infrastructure providers --

final barRepositoryProvider = Provider<BarRepository>(
  (ref) => FirestoreBarRepository(),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
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
