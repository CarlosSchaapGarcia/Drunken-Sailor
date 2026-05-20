import 'package:firebase_database/firebase_database.dart';
import '../models/bar.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  final DatabaseReference _barsRef = FirebaseDatabase.instance.ref().child('bars');

  /// Get all bars from Firebase
  Future<List<Bar>> getAllBars() async {
    try {
      final snapshot = await _barsRef.get();
      if (!snapshot.exists) {
        return [];
      }

      final List<Bar> bars = [];
      final data = snapshot.value as Map<dynamic, dynamic>;

      data.forEach((key, value) {
        try {
          bars.add(Bar.fromJson({...value as Map<dynamic, dynamic>, 'id': key}));
        } catch (e) {
          print('Error parsing bar: $e');
        }
      });

      return bars;
    } catch (e) {
      print('Error fetching bars: $e');
      return [];
    }
  }

  /// Get bars that are currently open
  Future<List<Bar>> getOpenBars() async {
    try {
      final allBars = await getAllBars();
      final now = DateTime.now();
      return allBars.where((bar) => bar.isOpenAt(now)).toList();
    } catch (e) {
      print('Error getting open bars: $e');
      return [];
    }
  }

  /// Find the closest open bar
  Future<Bar?> findClosestOpenBar(double userLat, double userLon) async {
    try {
      final openBars = await getOpenBars();
      if (openBars.isEmpty) return null;

      openBars.sort((a, b) {
        final distA = a.distanceTo(userLat, userLon);
        final distB = b.distanceTo(userLat, userLon);
        return distA.compareTo(distB);
      });

      return openBars.first;
    } catch (e) {
      print('Error finding closest bar: $e');
      return null;
    }
  }

  /// Add a bar to blacklist
  Future<void> blacklistBar(String barId) async {
    try {
      await _barsRef.child(barId).child('isBlacklisted').set(true);
    } catch (e) {
      print('Error blacklisting bar: $e');
    }
  }

  /// Remove a bar from blacklist
  Future<void> removeFromBlacklist(String barId) async {
    try {
      await _barsRef.child(barId).child('isBlacklisted').set(false);
    } catch (e) {
      print('Error removing from blacklist: $e');
    }
  }

  /// Stream of open bars
  Stream<List<Bar>> streamOpenBars() {
    return _barsRef.onValue.asyncMap((_) async {
      return await getOpenBars();
    });
  }
}
