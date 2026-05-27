import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'services/location_service.dart';
import 'widgets/location_permission_dialog.dart';
import 'widgets/location_debug_overlay.dart';
import 'views/compass_view.dart';
import 'views/radar_view.dart';
import 'views/geiger_view.dart';

enum ViewMode { compass, radar, geiger }

class DrunkenSailorApp extends StatefulWidget {
  const DrunkenSailorApp({Key? key}) : super(key: key);

  @override
  State<DrunkenSailorApp> createState() => _DrunkenSailorAppState();
}

class _DrunkenSailorAppState extends State<DrunkenSailorApp> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  ViewMode currentView = ViewMode.compass;
  bool showMenu = false;
  late PageController _pageController;

  final Map<ViewMode, String> viewTitles = {
    ViewMode.compass: 'Pirate Compass',
    ViewMode.radar: 'Submarine Radar',
    ViewMode.geiger: 'Nuclear Counter',
  };

  final List<ViewMode> views = [ViewMode.compass, ViewMode.radar, ViewMode.geiger];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    // observe app lifecycle to pause/resume location updates
    WidgetsBinding.instance.addObserver(this);
    // kick off permission check and start location updates while app is active
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final status = await Permission.locationWhenInUse.status;
      if (status.isGranted) {
        await _startLocation();
        return;
      }

      final result = await Permission.locationWhenInUse.request();
      if (result.isGranted) {
        await _startLocation();
        return;
      }

      // If denied once, show rationale dialog when appropriate
      if (result.isDenied && await Permission.locationWhenInUse.shouldShowRequestRationale) {
        await showLocationDeniedDialog(context, _themeForView(currentView));
      }

      // If permanently denied, offer settings link
      if (result.isPermanentlyDenied) {
        await showLocationDeniedDialog(context, _themeForView(currentView));
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _startLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      // Prompt user to open location settings
      await Geolocator.openLocationSettings();
      // give user a moment; do not crash
      return;
    }

    await LocationService().start();
    // Optionally listen to positions for UI updates
    LocationService().positionStream.listen((pos) {
      // Position received; could update UI or store last-known location
      // For now, we just print to log for debugging
      // ignore: avoid_print
      print('Location: ${pos.latitude}, ${pos.longitude} (accuracy ${pos.accuracy}m)');
    });
  }

  String _themeForView(ViewMode view) {
    switch (view) {
      case ViewMode.compass:
        return 'pirate';
      case ViewMode.radar:
        return 'submarine';
      case ViewMode.geiger:
        return 'nuclear';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // App no longer in foreground — stop location polling to save battery
      LocationService().stop();
    } else if (state == AppLifecycleState.resumed) {
      // App returned to foreground — restart if permission still granted
      Permission.locationWhenInUse.status.then((status) {
        if (status.isGranted) {
          _startLocation();
        }
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      currentView = views[index];
    });
  }

  void _swipeToView(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      drawer: _buildMenu(),
      body: Column(
        children: [
          // Top Navigation Bar
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1e293b),
              border: Border(
                bottom: BorderSide(color: Color(0xFF334155), width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, size: 24),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                Text(
                  viewTitles[currentView]!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.location_on, size: 24),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.list, size: 24),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Distance Indicator
          Container(
            color: const Color(0xFF1e293b).withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Destination in',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94a3b8),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  '500m',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10b981),
                  ),
                ),
              ],
            ),
          ),

          // Views Container
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                Center(child: CompassView()),
                Center(child: RadarView()),
                Center(child: GeigerView()),
              ],
            ),
          ),

          // Navigation Dots
          Container(
            color: const Color(0xFF1e293b).withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                views.length,
                (index) => GestureDetector(
                  onTap: () => _swipeToView(index),
                  child: Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentView == views[index]
                          ? const Color(0xFF10b981)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        scaffold,
        const LocationDebugOverlay(),
      ],
    );
  }

  @override
  Widget buildStacked(BuildContext context) {
    return Stack(
      children: [
        build(context),
        const LocationDebugOverlay(),
      ],
    );
  }

  Widget _buildMenu() {
    return Drawer(
      child: Container(
        color: const Color(0xFF1e293b),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF0f172a),
              ),
              child: Text(
                'Drunken Sailor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.compass_calibration, color: Color(0xFFfbbf24)),
              title: const Text(
                'Compass',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _swipeToView(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.radar, color: Color(0xFF10b981)),
              title: const Text(
                'Radar',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _swipeToView(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart, color: Color(0xFFef4444)),
              title: const Text(
                'Geiger Counter',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _swipeToView(2);
              },
            ),
            const Divider(color: Color(0xFF334155)),
            ListTile(
              leading: const Icon(Icons.map, color: Color(0xFF64748b)),
              title: const Text(
                'Map',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Color(0xFF64748b)),
              title: const Text(
                'Blacklist',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
