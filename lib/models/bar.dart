import 'dart:math';

class Bar {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final bool gayFriendly;
  final Map<String, OpeningHours> hours;
  final bool isBlacklisted;

  Bar({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.gayFriendly = false,
    required this.hours,
    this.isBlacklisted = false,
  });

  factory Bar.fromJson(Map<dynamic, dynamic> json) {
    return Bar(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      gayFriendly: json['gay_friendly'] ?? false,
      hours: Map<String, OpeningHours>.from(
        (json['hours'] as Map? ?? {}).map(
          (k, v) => MapEntry((k as String).toLowerCase(), OpeningHours.fromJson(v)),
        ),
      ),
      isBlacklisted: json['isBlacklisted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'gay_friendly': gayFriendly,
      'hours': hours.map((k, v) => MapEntry(k, v.toJson())),
      'isBlacklisted': isBlacklisted,
    };
  }

  int distanceTo(double userLat, double userLon) {
    const earthRadiusM = 6371000;
    final dLat = _toRad(userLat - latitude);
    final dLon = _toRad(userLon - longitude);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRad(latitude)) * cos(_toRad(userLat)) * sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return (earthRadiusM * c).round();
  }

  double _toRad(double degree) => degree * (3.141592653589793 / 180);

  bool isOpenAt(DateTime time) {
    final currentMinutes = time.hour * 60 + time.minute;

    // Check today's hours
    final todayHours = hours[_getDayName(time.weekday)];
    if (todayHours != null) {
      if (todayHours.closes > todayHours.opens) {
        // Normal: e.g. 10:00–23:00
        if (currentMinutes >= todayHours.opens && currentMinutes < todayHours.closes) return true;
      } else {
        // Crosses midnight: open part starting today (e.g. 22:00 onward)
        if (currentMinutes >= todayHours.opens) return true;
      }
    }

    // Check yesterday's hours for the past-midnight portion (e.g. still open at 02:00)
    final yesterday = time.subtract(const Duration(days: 1));
    final yesterdayHours = hours[_getDayName(yesterday.weekday)];
    if (yesterdayHours != null && yesterdayHours.closes <= yesterdayHours.opens) {
      if (currentMinutes < yesterdayHours.closes) return true;
    }

    return false;
  }

  String _getDayName(int weekday) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[weekday - 1];
  }
}

class OpeningHours {
  final int opens; // minutes since midnight
  final int closes; // minutes since midnight

  OpeningHours({required this.opens, required this.closes});

  factory OpeningHours.fromJson(Map<dynamic, dynamic> json) {
    return OpeningHours(
      opens: json['opens'] ?? 0,
      closes: json['closes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'opens': opens,
      'closes': closes,
    };
  }
}
