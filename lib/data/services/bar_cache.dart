import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/bar.dart';

class BarCache {
  static const _keyBars = 'cached_bars';
  static const _keyTimestamp = 'cached_bars_timestamp';
  static const _ttl = Duration(hours: 1);

  Future<void> save(List<Bar> bars) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(bars.map((b) => b.toJson()).toList());
      if (encoded.length > 100 * 1024) return; // guard: skip if > 100KB
      await prefs.setString(_keyBars, encoded);
      await prefs.setInt(_keyTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<List<Bar>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_keyTimestamp);
      if (timestamp == null) return null;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > _ttl.inMilliseconds) return null; // expired
      final raw = prefs.getString(_keyBars);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return list.map((e) => Bar.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      await clear(); // corrupted cache
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyBars);
      await prefs.remove(_keyTimestamp);
    } catch (_) {}
  }
}
