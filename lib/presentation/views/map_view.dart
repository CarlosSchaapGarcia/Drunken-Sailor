import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/providers.dart';

// Dark map style matching the app's navy/slate colour scheme
const _mapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0f172a"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0f172a"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]},
  {"featureType":"administrative","elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1e293b"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#0f172a"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#475569"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#334155"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#0f172a"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0c1a2e"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#1e3a5f"}]}
]
''';

class MapView extends ConsumerStatefulWidget {
  const MapView({Key? key}) : super(key: key);

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  GoogleMapController? _controller;
  bool _centeredOnUser = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(currentPositionProvider);
    final barsAsync = ref.watch(allBarsProvider);
    final nearestAsync = ref.watch(nearestBarProvider);

    ref.listen(currentPositionProvider, (_, next) {
      final pos = next.valueOrNull;
      if (pos != null && !_centeredOnUser && _controller != null) {
        _centeredOnUser = true;
        _controller!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
        );
      }
    });

    final now = DateTime.now();
    final nearestBar = nearestAsync.valueOrNull?.bar;
    final bars = barsAsync.valueOrNull ?? [];

    final markers = bars.map((bar) {
      final isOpen = bar.isOpenAt(now);
      final isNearest = bar.id == nearestBar?.id;
      return Marker(
        markerId: MarkerId(bar.id),
        position: LatLng(bar.latitude, bar.longitude),
        infoWindow: InfoWindow(
          title: bar.name,
          snippet: isOpen ? 'Open now' : 'Closed',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isNearest
              ? BitmapDescriptor.hueGreen
              : isOpen
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueRed,
        ),
      );
    }).toSet();

    final initialPos = positionAsync.valueOrNull;
    final cameraTarget = initialPos != null
        ? LatLng(initialPos.latitude, initialPos.longitude)
        : const LatLng(51.4416, 5.4697); // fallback: Eindhoven

    return Container(
      color: const Color(0xFF0f172a),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: cameraTarget, zoom: 15),
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        mapType: MapType.normal,
        zoomControlsEnabled: false,
        compassEnabled: false,
        onMapCreated: (controller) {
          _controller = controller;
          controller.setMapStyle(_mapStyle);
          final pos = positionAsync.valueOrNull;
          if (pos != null) {
            _centeredOnUser = true;
            controller.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
            );
          }
        },
      ),
    );
  }
}
