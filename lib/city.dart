class City {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  City({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory City.fromMap(String id, Map<dynamic, dynamic> map) {
    return City(
      id: id,
      name: map['name'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };
}
