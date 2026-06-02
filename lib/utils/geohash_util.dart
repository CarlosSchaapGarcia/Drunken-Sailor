const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

String encodeGeohash(double lat, double lng, int precision) {
  var minLat = -90.0, maxLat = 90.0;
  var minLng = -180.0, maxLng = 180.0;
  var isEven = true;
  var bit = 0, ch = 0;
  final hash = StringBuffer();

  while (hash.length < precision) {
    final double mid;
    if (isEven) {
      mid = (minLng + maxLng) / 2;
      if (lng > mid) { ch |= (1 << (4 - bit)); minLng = mid; }
      else maxLng = mid;
    } else {
      mid = (minLat + maxLat) / 2;
      if (lat > mid) { ch |= (1 << (4 - bit)); minLat = mid; }
      else maxLat = mid;
    }
    isEven = !isEven;
    if (bit < 4) { bit++; } else { hash.write(_base32[ch]); bit = 0; ch = 0; }
  }
  return hash.toString();
}

({double lat, double lng, double latErr, double lngErr}) _decode(String hash) {
  var minLat = -90.0, maxLat = 90.0;
  var minLng = -180.0, maxLng = 180.0;
  var isEven = true;

  for (final c in hash.split('')) {
    final idx = _base32.indexOf(c);
    for (var bits = 4; bits >= 0; bits--) {
      final bitN = (idx >> bits) & 1;
      if (isEven) {
        final mid = (minLng + maxLng) / 2;
        if (bitN == 1) minLng = mid; else maxLng = mid;
      } else {
        final mid = (minLat + maxLat) / 2;
        if (bitN == 1) minLat = mid; else maxLat = mid;
      }
      isEven = !isEven;
    }
  }
  return (
    lat: (minLat + maxLat) / 2,
    lng: (minLng + maxLng) / 2,
    latErr: (maxLat - minLat) / 2,
    lngErr: (maxLng - minLng) / 2,
  );
}

// Returns the 8 surrounding geohash cells at the same precision.
List<String> geohashNeighbors(String hash) {
  final d = _decode(hash);
  final precision = hash.length;
  final result = <String>{};
  for (final dlat in [-1, 0, 1]) {
    for (final dlng in [-1, 0, 1]) {
      if (dlat == 0 && dlng == 0) continue;
      final newLat = (d.lat + dlat * d.latErr * 2.5).clamp(-90.0, 90.0);
      final newLng = ((d.lng + dlng * d.lngErr * 2.5) + 540) % 360 - 180;
      result.add(encodeGeohash(newLat, newLng, precision));
    }
  }
  return result.toList();
}

// Precision 5 ≈ 5km cells, 6 ≈ 1km, 4 ≈ 20km.
int precisionForRadius(double radiusKm) {
  if (radiusKm <= 1) return 6;
  if (radiusKm <= 5) return 5;
  if (radiusKm <= 20) return 4;
  return 3;
}
