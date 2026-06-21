import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/firestore_bar_repository.dart';
import '../../data/services/heading_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/vibration_service.dart';
import '../../domain/models/bar.dart';
import '../../domain/repositories/bar_repository.dart';

import 'package:flutter_compass/flutter_compass.dart';

/// Device compass heading in degrees (0-360, 0 = true/magnetic north).
/// Filters out null events (sensor warming up / low accuracy) so the
/// provider stays in AsyncLoading until a real heading is available.
final deviceHeadingProvider = StreamProvider<double>((ref) {
  final events = FlutterCompass.events;
  if (events == null) {
    throw Exception('Compass sensor not available on this device.');
  }
  return events
      .where((event) => event.heading != null)
      .map((event) => event.heading!);
});

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

// -- Blacklist (personal, persisted to SharedPreferences) --

class BlacklistNotifier extends StateNotifier<Set<String>> {
  static const _key = 'blacklisted_bar_ids';
  BlacklistNotifier() : super(const {}) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    if (mounted) state = ids.toSet();
  }

  Future<void> toggle(String barId) async {
    final updated = Set<String>.from(state);
    if (updated.contains(barId)) { updated.remove(barId); } else { updated.add(barId); }
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated.toList());
  }
}

final blacklistedBarIdsProvider =
    StateNotifierProvider<BlacklistNotifier, Set<String>>(
  (ref) => BlacklistNotifier(),
);

// -- UI state providers --

final gayFriendlyFilterProvider = StateProvider<bool>((ref) => false);

final selectedBarIndexProvider = StateProvider<int>((ref) => 0);

final currentThemeProvider = StateProvider<String>((ref) => 'pirate');

final selectedBarProvider = StateProvider<Bar?>((ref) => null);

final showDebugOverlayProvider = StateProvider<bool>((ref) => false);

/// TEST MODE: when true, the compass needle points to true north (bearing
/// 0°) instead of the nearest bar. Useful for isolating whether the device
/// heading sensor itself is correct, independent of bar-finding/bearing
/// logic. Toggle this from a debug button/menu, then remove or hardcode to
/// false before shipping.
final compassPointsNorthDebugProvider = StateProvider<bool>((ref) => false);

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

// -- Top 5 nearest bars after applying gay-friendly and blacklist filters --
final top5BarsProvider = FutureProvider.autoDispose<List<NearestBarInfo>>((ref) async {
  // Watches set up before any await so Riverpod tracks them correctly.
  final gayFilter = ref.watch(gayFriendlyFilterProvider);
  final blacklist = ref.watch(blacklistedBarIdsProvider);

  final pos = await ref.read(locationStreamProvider.future);
  final repo = ref.read(barRepositoryProvider);
  final all = await repo.findNearbyBars(
    pos.latitude,
    pos.longitude,
    gayFriendlyOnly: gayFilter,
    radiusKm: 5.0,
    limit: null,
  );

  var pool = all.where((b) =>
    !b.isBlacklisted &&
    !blacklist.contains(b.id)
  ).toList();

  if (pool.isEmpty) return [];

  final now = DateTime.now();
  final open = pool.where((b) => b.isOpenAt(now)).toList();
  final candidates = open.isNotEmpty ? open : pool;

  candidates.sort((a, b) =>
    a.distanceTo(pos.latitude, pos.longitude)
     .compareTo(b.distanceTo(pos.latitude, pos.longitude)));

  return candidates.take(5).map((bar) {
    final dist = bar.distanceTo(pos.latitude, pos.longitude);
    return NearestBarInfo(bar: bar, distanceMeters: open.isNotEmpty ? dist : -dist);
  }).toList();
});

// -- Selected bar from top 5 (index 0 = nearest) --
final nearestBarProvider = FutureProvider.autoDispose<NearestBarInfo?>((ref) async {
  final index = ref.watch(selectedBarIndexProvider);
  final bars = await ref.watch(top5BarsProvider.future);
  if (bars.isEmpty) return null;
  return bars[index.clamp(0, bars.length - 1)];
});

// -- Vibration trigger on distance change --
final vibrationTriggerProvider = Provider.autoDispose<void>((ref) {
  final nearestBarAsync = ref.watch(nearestBarProvider);
  final vibrationService = ref.watch(vibrationServiceProvider);

  nearestBarAsync.maybeWhen(
    data: (info) {
      if (info == null) {
        vibrationService.stop();
        return;
      }
      final absDistance = info.distanceMeters.abs();
      if (absDistance <= 100) {
        vibrationService.updateForDistance(absDistance);
      } else {
        vibrationService.stop();
      }
    },
    orElse: vibrationService.stop,
  );
});

final allBarsProvider = FutureProvider<List<Bar>>((ref) {
  return ref.read(barRepositoryProvider).getAllBars();
});

// Fetches bars within 10 km of the user for the map view.
// Uses the geohash query so only nearby bars are loaded — no full dump.
final nearbyBarsForMapProvider = FutureProvider<List<Bar>>((ref) async {
  final pos = await ref.read(locationStreamProvider.future);
  return ref.read(barRepositoryProvider).findNearbyBars(
    pos.latitude,
    pos.longitude,
    radiusKm: 10.0,
    limit: null,
  );
});

final openBarPositionsProvider = StreamProvider<List<BarRelativePosition>>((ref) {
  final locationStream = ref.watch(locationStreamProvider.stream);
  // Bars are loaded once via allBarsProvider (cached) rather than re-fetched
  // on every GPS fix. Position geometry is recomputed synchronously per fix.
  final bars = ref.watch(allBarsProvider).valueOrNull ?? [];

  return locationStream.map((pos) => bars
      .map((bar) => BarRelativePosition.fromBar(
            bar,
            pos.latitude,
            pos.longitude,
            0.0,
            maxRangeMeters: 5000,
          ))
      .where((p) => p.visible)
      .toList());
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

/// How strongly to smooth the raw heading signal. 0 = no smoothing (raw),
/// closer to 1 = heavier smoothing (slower to react, but steadier needle).
/// 0.15-0.25 is a good range for magnetometer data sampled at typical
/// sensor rates (~10-60Hz depending on device).
///
/// FIXED: was previously 0.0, which made the circular EMA permanently
/// lock onto the first heading sample it ever received and never update
/// again (alpha=0 means every later sample is multiplied by 0 and
/// discarded). That looked like "the needle tracks rotation" only by
/// coincidence of whatever the first sample happened to be: in practice
/// it meant the *smoothed* heading used for the needle math never moved
/// after that. 0.2 keeps the needle responsive to phone rotation while
/// still damping magnetometer jitter.
const double _headingSmoothingFactor = 0.2;

/// Combines device heading + target bearing to nearest bar.
/// Emits the needle rotation angle (0-360°), where 0° means "needle points
/// straight up the screen towards the target".
///
/// Fixes vs. the naive version:
/// - Does NOT emit a placeholder (e.g. 0.0) before both heading and bearing
///   have produced at least one value. Emitting early caused the needle to
///   visibly snap to "up" for a moment whenever either autoDispose provider
///   was torn down and recreated (e.g. on screen rebuild), which looked like
///   a wrong/incorrect direction.
/// - Smooths the noisy heading signal with a circular (wraparound-safe)
///   exponential moving average before combining it with bearing, so small
///   magnetometer jitter doesn't cause the needle to visibly tremble.
/// - Bearing itself is NOT smoothed — it only updates when GPS position
///   changes (infrequent), so we want the needle to react to bar changes
///   promptly rather than easing into them.
final compassNeedleProvider = StreamProvider.autoDispose<double?>((ref) {
  final headingStream = ref.watch(headingStreamProvider.stream);
  final pointNorth = ref.watch(compassPointsNorthDebugProvider);

  // TEST MODE: feed a constant bearing of 0° (true north) instead of the
  // real bar-bearing stream. This isolates the heading sensor — if the
  // needle correctly tracks north as you rotate the phone in this mode,
  // the sensor/heading pipeline is good and any remaining bug is in the
  // bar-finding or bearing-calculation logic instead.
  final bearingStream = pointNorth
      ? Stream<double?>.value(0.0)
      : ref.watch(nearestBarBearingProvider.stream);

  return _combineHeadingAndBearing(headingStream, bearingStream);
});

/// Tracks a circular (degrees, 0-360) exponential moving average.
/// Plain EMA breaks across the 0°/360° boundary (e.g. averaging 359° and 1°
/// naively yields ~180°, when the correct answer is ~0°). Averaging the
/// sin/cos components instead handles wraparound correctly.
class _CircularEma {
  final double alpha; // smoothing factor, 0..1 (higher = more responsive)
  double? _sin;
  double? _cos;

  _CircularEma(this.alpha);

  double update(double degrees) {
    final rad = degrees * math.pi / 180;
    final s = math.sin(rad);
    final c = math.cos(rad);

    if (_sin == null || _cos == null) {
      _sin = s;
      _cos = c;
    } else {
      _sin = alpha * s + (1 - alpha) * _sin!;
      _cos = alpha * c + (1 - alpha) * _cos!;
    }

    var result = math.atan2(_sin!, _cos!) * 180 / math.pi;
    if (result < 0) result += 360;
    return result;
  }
}

/// Helper to combine two streams into needle rotation angles.
Stream<double?> _combineHeadingAndBearing(
  Stream<double> headingStream,
  Stream<double?> bearingStream,
) {
  final controller = StreamController<double?>();
  final headingFilter = _CircularEma(_headingSmoothingFactor);

  double? lastSmoothedHeading;
  double? lastBearing;
  bool haveHeading = false;
  bool haveBearing = false;

  void emitIfReady() {
    // Wait until we've received at least one value from each stream.
    // This avoids emitting a placeholder rotation (e.g. "0.0 = pointing
    // up") before we actually know both the device heading and the
    // bearing to the target bar — that placeholder was the source of the
    // "sometimes points the wrong way" bug.
    if (!haveHeading || !haveBearing) return;

    if (lastBearing == null) {
      // No bar to point to (e.g. none open/nearby). Emit null explicitly
      // so the UI can show a dedicated "no target" state instead of
      // freezing on the last rotation it happened to receive.
      controller.add(null);
      return;
    }

    final angle = (lastBearing! - lastSmoothedHeading! + 360) % 360;
    controller.add(angle);
  }

  late final StreamSubscription<double> headingSub;
  late final StreamSubscription<double?> bearingSub;

  headingSub = headingStream.listen((heading) {
    lastSmoothedHeading = headingFilter.update(heading);
    haveHeading = true;
    emitIfReady();
  }, onError: (e, st) => controller.addError(e, st));

  bearingSub = bearingStream.listen((bearing) {
    lastBearing = bearing;
    haveBearing = true;
    emitIfReady();
  }, onError: (e, st) => controller.addError(e, st));

  controller.onCancel = () async {
    await headingSub.cancel();
    await bearingSub.cancel();
  };

  return controller.stream;
}