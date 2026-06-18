import 'dart:math' as math;

/// Computes the initial great-circle bearing (in degrees, 0-360, 0 = true
/// north) from [from] to [to]. Standard forward-azimuth formula.
double bearingBetween({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  final lat1 = _deg2rad(fromLat);
  final lat2 = _deg2rad(toLat);
  final dLng = _deg2rad(toLng - fromLng);

  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

  final bearingRad = math.atan2(y, x);
  final bearingDeg = _rad2deg(bearingRad);
  return (bearingDeg + 360) % 360;
}

/// Great-circle distance in metres (haversine), handy for showing
/// "120 m to The Anchor" alongside the dial.
double distanceBetweenMeters({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  const earthRadiusM = 6371000.0;
  final lat1 = _deg2rad(fromLat);
  final lat2 = _deg2rad(toLat);
  final dLat = _deg2rad(toLat - fromLat);
  final dLng = _deg2rad(toLng - fromLng);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusM * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);
double _rad2deg(double rad) => rad * (180.0 / math.pi);