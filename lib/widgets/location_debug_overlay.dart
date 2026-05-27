import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationDebugOverlay extends StatefulWidget {
  const LocationDebugOverlay({Key? key}) : super(key: key);

  @override
  State<LocationDebugOverlay> createState() => _LocationDebugOverlayState();
}

class _LocationDebugOverlayState extends State<LocationDebugOverlay> {
  Position? _pos;

  @override
  void initState() {
    super.initState();
    LocationService().positionStream.listen((p) {
      setState(() => _pos = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pos == null) return const SizedBox.shrink();
    return Positioned(
      right: 12,
      bottom: 120,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lat: ${_pos!.latitude.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white)),
            Text('Lng: ${_pos!.longitude.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white)),
            Text('Acc: ${_pos!.accuracy.toStringAsFixed(1)} m', style: const TextStyle(color: Colors.white)),
            Text('Time: ${DateTime.fromMillisecondsSinceEpoch(_pos!.timestamp?.millisecondsSinceEpoch ?? 0)}', style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
