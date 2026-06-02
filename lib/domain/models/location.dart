class Location {
  final double latitude;
  final double longitude;

  const Location({required this.latitude, required this.longitude});

  @override
  bool operator ==(Object other) =>
      other is Location && latitude == other.latitude && longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
