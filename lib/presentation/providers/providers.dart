import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/repositories/firestore_bar_repository.dart';
import '../../data/services/location_service.dart';
import '../../domain/models/bar.dart';
import '../../domain/models/nearest_bar_result.dart';
import '../../domain/repositories/bar_repository.dart';

// -- Infrastructure --

final barRepositoryProvider = Provider<BarRepository>(
  (ref) => FirestoreBarRepository(),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

// -- UI state --

final currentThemeProvider = StateProvider<String>((ref) => 'pirate');

final selectedBarProvider = StateProvider<Bar?>((ref) => null);

final showDebugOverlayProvider = StateProvider<bool>((ref) => false);

// -- Location --

final locationStreamProvider = StreamProvider<Position>((ref) {
  return ref.watch(locationServiceProvider).positionStream;
});

// Updated by app.dart whenever the user moves >10 metres.
final queryPositionProvider = StateProvider<Position?>((ref) => null);

// -- Nearest open bar --
// Returns null when no bars are open (displays "No bars open").
// Throws when Firestore is unreachable and cache is empty (displays ErrorDisplay).

final nearestBarProvider = FutureProvider.autoDispose<NearestBarResult?>((ref) async {
  var pos = ref.watch(queryPositionProvider);

  // No manual position yet — wait for first GPS fix to show loading spinner.
  pos ??= await ref.watch(locationStreamProvider.future);

  final repo = ref.read(barRepositoryProvider);
  final nearby = await repo.findNearbyBars(pos.latitude, pos.longitude);
  if (nearby.isEmpty) return null; // → "No bars found"

  final now = DateTime.now();
  final open = nearby.where((b) => b.isOpenAt(now)).toList();

  // Always show nearest bar — open one if available, otherwise closest overall.
  final closest = open.isNotEmpty ? open.first : nearby.first;
  return NearestBarResult(
    bar: closest,
    distanceM: closest.distanceTo(pos.latitude, pos.longitude),
    isOpen: open.isNotEmpty,
  );
});
