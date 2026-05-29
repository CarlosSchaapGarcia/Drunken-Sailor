import 'dart:math';

class Bar {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? category; // 'regular', 'gay', etc.
  final Map<String, OpeningHours> hours;
  final bool isBlacklisted;

  Bar({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category,
    required this.hours,
    this.isBlacklisted = false,
  });

  factory Bar.fromJson(Map<dynamic, dynamic> json) {
    return Bar(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      category: json['category'],
      hours: Map<String, OpeningHours>.from(
        (json['hours'] as Map? ?? {}).map(
          (k, v) => MapEntry(k, OpeningHours.fromJson(v)),
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
      'category': category,
      'hours': hours.map((k, v) => MapEntry(k, v.toJson())),
      'isBlacklisted': isBlacklisted,
    };
  }

  double distanceTo(double userLat, double userLon) {
    const earthRadiusKm = 6371;
    final dLat = _toRad(userLat - latitude);
    final dLon = _toRad(userLon - longitude);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRad(latitude)) * cos(_toRad(userLat)) * sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRad(double degree) => degree * (3.141592653589793 / 180);

  bool isOpenAt(DateTime time) {
    final dayName = _getDayName(time.weekday);
    final hoursForDay = hours[dayName];
    if (hoursForDay == null) return false;

    final currentTime = time.hour * 60 + time.minute;
    final openTime = hoursForDay.opens;
    final closeTime = hoursForDay.closes;

    return currentTime >= openTime && currentTime < closeTime;
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
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
