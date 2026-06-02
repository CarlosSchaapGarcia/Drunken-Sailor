import '../models/bar.dart';

abstract class BarRepository {
  Future<List<Bar>> getAllBars({bool forceRefresh = false});

  Future<List<Bar>> findNearbyBars(
    double lat,
    double lng, {
    bool gayFriendlyOnly = false,
    double radiusKm = 5.0,
  });

  Future<Bar?> findClosestOpenBar(
    double lat,
    double lng, {
    bool gayFriendlyOnly = false,
  });

  Stream<List<Bar>> streamOpenBars();
}
