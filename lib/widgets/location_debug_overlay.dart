import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationDebugOverlay extends StatefulWidget {
  final VoidCallback? onClose;
  const LocationDebugOverlay({Key? key, this.onClose}) : super(key: key);

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
    // Always render a compact overlay so users get feedback.
    return Positioned(
      right: 12,
      bottom: 120,
      child: Stack(
        children: [
          // Non-interactive info box so taps pass through to underlying UI.
          IgnorePointer(
            ignoring: true,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pos == null) ...[
                    const Text('GPS: waiting for fix...', style: TextStyle(color: Colors.white)),
                  ] else ...[
                    Text('Lat: ${_pos!.latitude.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white)),
                    Text('Lng: ${_pos!.longitude.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white)),
                    Text('Acc: ${_pos!.accuracy.toStringAsFixed(1)} m', style: const TextStyle(color: Colors.white)),
                    Text('Time: ${DateTime.fromMillisecondsSinceEpoch(_pos!.timestamp?.millisecondsSinceEpoch ?? 0)}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ]
                ],
              ),
            ),
          ),

          // Interactive close button placed above the info box.
          if (widget.onClose != null)
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
