import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/error/exceptions.dart';
import '../../core/utils/geohash_util.dart';
import '../../domain/models/bar.dart';
import '../../domain/repositories/bar_repository.dart';
import '../models/bar_dto.dart';
import '../services/bar_cache.dart';

class FirestoreBarRepository implements BarRepository {
  FirestoreBarRepository({BarCache? cache})
      : _cache = cache ?? BarCache();

  final CollectionReference<Map<String, dynamic>> _bars =
      FirebaseFirestore.instance.collection('bars').withConverter(
            fromFirestore: (snap, _) => snap.data()!,
            toFirestore: (data, _) => data,
          );

  final BarCache _cache;
  static const _timeout = Duration(seconds: 5);

  @override
  Future<List<Bar>> getAllBars({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cache.load();
      if (cached != null) return cached;
    }
    try {
      final snap = await _barsRaw.get().timeout(
            _timeout,
            onTimeout: () => throw BarServiceException('Timed out after ${_timeout.inSeconds}s'),
          );
      final bars = snap.docs.map((d) => BarDto.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
      await _cache.save(bars);
      return bars;
    } on BarServiceException {
      return await _cache.load() ?? (throw const BarServiceException('Offline and no cache available'));
    } catch (e) {
      final fallback = await _cache.load();
      if (fallback != null) return fallback;
      throw BarServiceException('Failed to fetch bars: $e');
    }
  }

  CollectionReference get _barsRaw => FirebaseFirestore.instance.collection('bars');

  @override
  Future<List<Bar>> findNearbyBars(
    double lat,
    double lng, {
    bool gayFriendlyOnly = false,
    double radiusKm = 5.0,
    int? limit = 5,
  }) async {
    final precision = precisionForRadius(radiusKm);
    final center = encodeGeohash(lat, lng, precision);
    final tiles = [center, ...geohashNeighbors(center)];
    final radiusM = (radiusKm * 1000).round();

    final results = await Future.wait(
      tiles.map((t) => _queryTile(t, gayFriendlyOnly: gayFriendlyOnly)),
    );

    final seen = <String>{};
    final bars = <Bar>[];
    for (final list in results) {
      for (final bar in list) {
        if (seen.add(bar.id) && bar.distanceTo(lat, lng) <= radiusM) {
          bars.add(bar);
        }
      }
    }
    if (bars.isEmpty) {
      // Geohash returned nothing — either bars lack the geohash field or we're
      // offline. getAllBars handles caching and throws BarServiceException when
      // truly offline with no cache, which propagates to the error state.
      final all = await getAllBars();
      final nearby = all.where((b) => b.distanceTo(lat, lng) <= radiusM).toList();
      nearby.sort((a, b) => a.distanceTo(lat, lng).compareTo(b.distanceTo(lat, lng)));
      return limit != null ? nearby.take(limit).toList() : nearby;
    }

    bars.sort((a, b) => a.distanceTo(lat, lng).compareTo(b.distanceTo(lat, lng)));
    return limit != null ? bars.take(limit).toList() : bars;
  }

  @override
  Future<Bar?> findClosestOpenBar(
    double lat,
    double lng, {
    bool gayFriendlyOnly = false,
  }) async {
    try {
      final nearby = await findNearbyBars(lat, lng, gayFriendlyOnly: gayFriendlyOnly);
      final now = DateTime.now();
      return nearby.firstWhere((b) => b.isOpenAt(now), orElse: () => throw StateError(''));
    } on StateError {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Bar>> streamOpenBars() {
    return _barsRaw.snapshots().asyncMap((_) async {
      final bars = await getAllBars();
      final now = DateTime.now();
      return bars.where((b) => b.isOpenAt(now)).toList();
    });
  }

  Future<List<Bar>> _queryTile(String tile, {bool gayFriendlyOnly = false}) async {
    try {
      Query query;
      if (gayFriendlyOnly) {
        query = _barsRaw
            .where('gay_friendly', isEqualTo: true)
            .where('geohash', isGreaterThanOrEqualTo: tile)
            .where('geohash', isLessThanOrEqualTo: '$tile~');
      } else {
        query = _barsRaw
            .where('geohash', isGreaterThanOrEqualTo: tile)
            .where('geohash', isLessThanOrEqualTo: '$tile~');
      }
      final snap = await query.get().timeout(_timeout);
      return snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return Bar.fromJson({...data, 'id': d.id});
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearCache() => _cache.clear();
}
