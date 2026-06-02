import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bar.dart';
import '../utils/geohash_util.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final CollectionReference _bars = FirebaseFirestore.instance.collection('bars');

  // Fetches all bars — use only for admin/debug, not in the main flow.
  Future<List<Bar>> getAllBars() async {
    try {
      final snapshot = await _bars.get();
      return _parseDocs(snapshot.docs);
    } catch (e) {
      return [];
    }
  }

  // Main query: finds bars within radiusKm using geohash tile queries.
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

    final seen = <String>{};
    final bars = <Bar>[];
    for (final list in results) {
      for (final bar in list) {
        if (seen.add(bar.id) && bar.distanceTo(lat, lng) <= radiusKm) {
          bars.add(bar);
        }
      }
    }
    bars.sort((a, b) => a.distanceTo(lat, lng).compareTo(b.distanceTo(lat, lng)));
    return bars;
  }

  Future<Bar?> findClosestOpenBar(
    double userLat,
    double userLon, {
    bool gayFriendlyOnly = false,
  }) async {
    final nearby = await findNearbyBars(userLat, userLon, gayFriendlyOnly: gayFriendlyOnly);
    final now = DateTime.now();
    // Already sorted by distance — return first open one.
    return nearby.firstWhere((b) => b.isOpenAt(now), orElse: () => throw StateError('none'));
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
        // Uses composite index: gay_friendly ASC, geohash ASC
        query = _bars
            .where('gay_friendly', isEqualTo: true)
            .where('geohash', isGreaterThanOrEqualTo: tile)
            .where('geohash', isLessThanOrEqualTo: '$tile~');
      } else {
        // Uses auto single-field index on geohash
        query = _bars
            .where('geohash', isGreaterThanOrEqualTo: tile)
            .where('geohash', isLessThanOrEqualTo: '$tile~');
      }
      final snapshot = await query.get();
      return _parseDocs(snapshot.docs);
    } catch (e) {
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
