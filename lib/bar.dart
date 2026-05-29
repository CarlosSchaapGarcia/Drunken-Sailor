class Bar {
  final String id;
  final String cityId;
  final String name;
  final double latitude;
  final double longitude;
  final String category;
  final bool isBlacklisted;

  Bar({
    required this.id,
    required this.cityId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.isBlacklisted = false,
  });

  factory Bar.fromMap(String id, Map<dynamic, dynamic> map) {
    return Bar(
      id: id,
      cityId: map['cityId'] ?? '',
      name: map['name'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      category: map['category'] ?? 'regular',
      isBlacklisted: map['isBlacklisted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'cityId': cityId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'isBlacklisted': isBlacklisted,
      };
}
