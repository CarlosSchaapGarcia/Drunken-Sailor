import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bar.dart';
import '../services/bar_cache.dart';
import '../utils/geohash_util.dart';

class BarServiceException implements Exception {
  final String message;
  const BarServiceException(this.message);
  @override
  String toString() => 'BarServiceException: $message';
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final CollectionReference _bars = FirebaseFirestore.instance.collection('bars');
  final _cache = BarCache();
  static const _timeout = Duration(seconds: 5);

  Future<List<Bar>> getAllBars({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cache.load();
      if (cached != null) return cached;
    }
    try {
      final snapshot = await _bars.get().timeout(
        _timeout,
        onTimeout: () => throw BarServiceException('Firestore timed out after ${_timeout.inSeconds}s'),
      );
      final bars = _parseDocs(snapshot.docs);
      await _cache.save(bars);
      return bars;
    } on BarServiceException {
      final fallback = await _cache.load();
      if (fallback != null) return fallback;
      rethrow;
    } catch (e) {
      final fallback = await _cache.load();
      if (fallback != null) return fallback;
      throw BarServiceException('Failed to fetch bars: $e');
    }
  }

  // Main query: finds bars within radiusKm using geohash tile queries. Returns top 5 by distance.
  Future<List<Bar>> findNearbyBars(
    double lat,
    double lng, {
    bool gayFriendlyOnly = false,
    double radiusKm = 5.0,
  }) async {
    final precision = precisionForRadius(radiusKm);
    final center = encodeGeohash(lat, lng, precision);
    final tiles = [center, ...geohashNeighbors(center)];

    final results = await Future.wait(
      tiles.map((tile) => _queryTile(tile, gayFriendlyOnly: gayFriendlyOnly)),
    );

    final radiusM = (radiusKm * 1000).round();
    final seen = <String>{};
    final bars = <Bar>[];
    for (final list in results) {
      for (final bar in list) {
        if (seen.add(bar.id) && bar.distanceTo(lat, lng) <= radiusM) {
          bars.add(bar);
        }
      }
    }
    bars.sort((a, b) => a.distanceTo(lat, lng).compareTo(b.distanceTo(lat, lng)));
    return bars.take(5).toList();
  }

  // Returns null when no open bar found — never throws.
  Future<Bar?> findClosestOpenBar(
    double userLat,
    double userLon, {
    bool gayFriendlyOnly = false,
  }) async {
    try {
      final nearby = await findNearbyBars(userLat, userLon, gayFriendlyOnly: gayFriendlyOnly);
      final now = DateTime.now();
      return nearby.firstWhere((b) => b.isOpenAt(now), orElse: () => throw StateError(''));
    } on StateError {
      return null;
    } catch (_) {
      return null;
    }
  }

  Stream<List<Bar>> streamOpenBars() {
    return _bars.snapshots().asyncMap((_) async {
      final all = await getAllBars();
      final now = DateTime.now();
      return all.where((b) => b.isOpenAt(now)).toList();
    });
  }

  Future<List<Bar>> _queryTile(String tile, {bool gayFriendlyOnly = false}) async {
    try {
      Query query;
      if (gayFriendlyOnly) {
        query = _bars
            .where('gay_friendly', isEqualTo: true)
            .where('geohash', isGreaterThanOrEqualTo: tile)
            .where('geohash', isLessThanOrEqualTo: '$tile~');
      } else {
        query = _bars
            .where('geohash', isGreaterThanOrEqualTo: tile)
            .where('geohash', isLessThanOrEqualTo: '$tile~');
      }
      final snapshot = await query.get().timeout(_timeout);
      return _parseDocs(snapshot.docs);
    } catch (_) {
      return [];
    }
  }

  List<Bar> _parseDocs(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Bar.fromJson({...data, 'id': doc.id});
    }).toList();
  }
}
