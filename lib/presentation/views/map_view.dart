import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../providers/providers.dart';

class MapView extends ConsumerStatefulWidget {
  const MapView({Key? key, required this.onGoToGeiger}) : super(key: key);

  final VoidCallback onGoToGeiger;

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  final _mapController = MapController();
  bool _centeredOnUser = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _resetView() {
    final pos = ref.read(currentPositionProvider).valueOrNull;
    if (pos != null) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(currentPositionProvider);
    final barsAsync = ref.watch(nearbyBarsForMapProvider);
    final nearestAsync = ref.watch(nearestBarProvider);

    // Move camera to user on first GPS fix
    ref.listen(currentPositionProvider, (_, next) {
      final pos = next.valueOrNull;
      if (pos != null && !_centeredOnUser) {
        _centeredOnUser = true;
        _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
      }
    });

    final now = DateTime.now();
    final nearestBar = nearestAsync.valueOrNull?.bar;
    final bars = barsAsync.valueOrNull ?? [];
    final userPos = positionAsync.valueOrNull;

    final initialCenter = userPos != null
        ? LatLng(userPos.latitude, userPos.longitude)
        : const LatLng(51.4416, 5.4697); // fallback: Eindhoven

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 15,
            backgroundColor: const Color(0xFF0f172a),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.drunken_sailor',
              tileBuilder: _darkTileBuilder,
            ),
            MarkerLayer(
              markers: [
                // User position marker
                if (userPos != null)
                  Marker(
                    point: LatLng(userPos.latitude, userPos.longitude),
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF3b82f6),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                // Bar markers
                ...bars.map((bar) {
                  final isNearest = bar.id == nearestBar?.id;
                  final isOpen = bar.isOpenAt(now);
                  final color = isNearest
                      ? const Color(0xFF10b981)
                      : isOpen
                          ? const Color(0xFFf97316)
                          : const Color(0xFFef4444);

                  return Marker(
                    point: LatLng(bar.latitude, bar.longitude),
                    width: isNearest ? 120 : 100,
                    height: isNearest ? 52 : 44,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1e293b),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color, width: isNearest ? 2 : 1),
                          ),
                          child: Text(
                            bar.name,
                            style: TextStyle(
                              color: color,
                              fontSize: isNearest ? 11 : 10,
                              fontWeight: isNearest ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        CustomPaint(
                          size: const Size(10, 6),
                          painter: _TrianglePainter(color: color),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
        // Overlay buttons — positioned inside the map corners
        Positioned(
          top: 12,
          left: 12,
          child: _MapButton(
            icon: Icons.radiation,
            tooltip: 'Geiger Counter',
            onTap: widget.onGoToGeiger,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _MapButton(
            icon: Icons.my_location,
            tooltip: 'Reset view',
            onTap: _resetView,
          ),
        ),
      ],
    );
  }

  Widget _darkTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.25, 0, 0, 0, 0,
        0, 0.30, 0, 0, 0,
        0, 0, 0.40, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1e293b),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
