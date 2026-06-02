import 'dart:math';
import 'opening_hours.dart';

class Bar {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final bool gayFriendly;
  final Map<String, OpeningHours> hours;
  final bool isBlacklisted;

  const Bar({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.gayFriendly = false,
    required this.hours,
    this.isBlacklisted = false,
  });

  factory Bar.fromJson(Map<dynamic, dynamic> json) => Bar(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        latitude: (json['latitude'] ?? 0).toDouble(),
        longitude: (json['longitude'] ?? 0).toDouble(),
        gayFriendly: json['gay_friendly'] as bool? ?? false,
        hours: Map<String, OpeningHours>.from(
          (json['hours'] as Map? ?? {}).map(
            (k, v) => MapEntry(
              (k as String).toLowerCase(),
              OpeningHours.fromJson(v as Map),
            ),
          ),
        ),
        isBlacklisted: json['isBlacklisted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'gay_friendly': gayFriendly,
        'hours': hours.map((k, v) => MapEntry(k, v.toJson())),
        'isBlacklisted': isBlacklisted,
      };

  // Returns distance in meters.
  int distanceTo(double userLat, double userLon) {
    const earthRadiusM = 6371000;
    final dLat = _toRad(userLat - latitude);
    final dLon = _toRad(userLon - longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(latitude)) * cos(_toRad(userLat)) * sin(dLon / 2) * sin(dLon / 2);
    return (earthRadiusM * 2 * atan2(sqrt(a), sqrt(1 - a))).round();
  }

  bool isOpenAt(DateTime time) {
    final currentMinutes = time.hour * 60 + time.minute;

    final todayHours = hours[_dayName(time.weekday)];
    if (todayHours != null) {
      if (todayHours.closes > todayHours.opens) {
        if (currentMinutes >= todayHours.opens && currentMinutes < todayHours.closes) return true;
      } else {
        if (currentMinutes >= todayHours.opens) return true;
      }
    }

    final yesterday = time.subtract(const Duration(days: 1));
    final yesterdayHours = hours[_dayName(yesterday.weekday)];
    if (yesterdayHours != null && yesterdayHours.closes <= yesterdayHours.opens) {
      if (currentMinutes < yesterdayHours.closes) return true;
    }

    return false;
  }

  static String _dayName(int weekday) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[weekday - 1];
  }

  double _toRad(double deg) => deg * (pi / 180);

  @override
  bool operator ==(Object other) => other is Bar && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
