import 'dart:async';
import 'package:drunken_sailor/data/repositories/firestore_bar_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/providers.dart';
import 'views/compass_view.dart';
import 'views/radar_view.dart';
import 'views/geiger_view.dart';
import 'views/map_view.dart';
import 'views/blacklist_view.dart';
import 'widgets/error_display.dart';
import 'widgets/loading_spinner.dart';
import 'widgets/location_debug_overlay.dart';
import 'widgets/location_permission_dialog.dart';

enum ViewMode { compass, radar, geiger, map }

class DrunkenSailorApp extends ConsumerStatefulWidget {
  const DrunkenSailorApp({Key? key}) : super(key: key);

  @override
  ConsumerState<DrunkenSailorApp> createState() => _DrunkenSailorAppState();
}

class _DrunkenSailorAppState extends ConsumerState<DrunkenSailorApp>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  ViewMode _currentView = ViewMode.compass;
  late PageController _pageController;
  Timer? _menuLongPressTimer;
  bool _longPressFired = false;
  DateTime? _lastBarFetch;

  static const _longPressDuration = Duration(seconds: 5);
  static const _barFetchInterval = Duration(seconds: 30);

  final _views = [ViewMode.compass, ViewMode.radar, ViewMode.geiger, ViewMode.map];
  final _viewTitles = {
    ViewMode.compass: 'Pirate Compass',
    ViewMode.radar: 'Submarine Radar',
    ViewMode.geiger: 'Nuclear Counter',
    ViewMode.map: 'Bar Map',
  };
  final _viewThemes = {
    ViewMode.compass: 'pirate',
    ViewMode.radar: 'submarine',
    ViewMode.geiger: 'nuclear',
    ViewMode.map: 'pirate',
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    _initLocation();
    _checkFirebase();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _menuLongPressTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final service = ref.read(locationServiceProvider);
    final vibration = ref.read(vibrationServiceProvider);
    
    if (state == AppLifecycleState.paused) {
      service.stop();
      vibration.stop();
    } else if (state == AppLifecycleState.resumed) {
      Permission.locationWhenInUse.status.then((s) {
        if (s.isGranted) service.start();
      });
    }
  }

  Future<void> _checkFirebase() async {
  try {
    final repo = ref.read(barRepositoryProvider) as FirestoreBarRepository;
    await repo.clearCache(); // ← clear stale cache
    final bars = await repo.getAllBars();
    print('[Firebase] Connected — ${bars.length} bars loaded');
  } catch (e) {
    print('[Firebase] Connection failed: $e');
  }
}

  Future<void> _initLocation() async {
    try {
      var status = await Permission.locationWhenInUse.status;
      if (!status.isGranted) {
        status = await Permission.locationWhenInUse.request();
      }
      if (status.isGranted) {
        await _startLocation();
        return;
      }
      if (status.isDenied && await Permission.locationWhenInUse.shouldShowRequestRationale) {
        await showLocationDeniedDialog(context, _viewThemes[_currentView]!);
      }
      if (status.isPermanentlyDenied) {
        await showLocationDeniedDialog(context, _viewThemes[_currentView]!);
      }
    } catch (_) {}
  }

  Future<void> _startLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    final service = ref.read(locationServiceProvider);
    await service.start();

    ref.read(openBarPositionsProvider);

    service.positionStream.listen((pos) {
      final now = DateTime.now();
      if (_lastBarFetch == null || now.difference(_lastBarFetch!) >= _barFetchInterval) {
        _lastBarFetch = now;
        ref.invalidate(top5BarsProvider);
        ref.invalidate(nearestBarProvider);
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentView = _views[index]);
    ref.read(currentThemeProvider.notifier).state = _viewThemes[_views[index]]!;
  }

  void _swipeToView(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _startMenuPressTimer() {
    _longPressFired = false;
    _menuLongPressTimer?.cancel();
    _menuLongPressTimer = Timer(_longPressDuration, () {
      _longPressFired = true;
      ref.read(showDebugOverlayProvider.notifier).state =
          !ref.read(showDebugOverlayProvider);
    });
  }

  void _cancelMenuPressTimer() {
    _menuLongPressTimer?.cancel();
    _menuLongPressTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final showDebug = ref.watch(showDebugOverlayProvider);
    final nearestAsync = ref.watch(nearestBarProvider);
    
    // Watch vibration trigger to update on distance changes
    ref.watch(vibrationTriggerProvider);

    final scaffold = Scaffold(
      drawer: _buildMenu(),
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(),
            _buildDistanceIndicator(nearestAsync),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  const Center(child: CompassView()),
                  const Center(child: RadarView()),
                  const Center(child: GeigerView()),
                  const MapView(),
                ],
              ),
            ),
            _buildDots(),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        scaffold,
        if (showDebug)
          LocationDebugOverlay(
            onClose: () => ref.read(showDebugOverlayProvider.notifier).state = false,
          ),
      ],
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1e293b),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Builder(
            builder: (ctx) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_longPressFired) { _longPressFired = false; return; }
                Scaffold.of(ctx).openDrawer();
              },
              onTapDown: (_) => _startMenuPressTimer(),
              onTapUp: (_) => _cancelMenuPressTimer(),
              onTapCancel: _cancelMenuPressTimer,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.menu, size: 24),
              ),
            ),
          ),
          Text(
            _viewTitles[_currentView]!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildDistanceIndicator(AsyncValue<dynamic> nearestAsync) {
    final index = ref.watch(selectedBarIndexProvider);
    final total = ref.watch(top5BarsProvider).valueOrNull?.length ?? 1;

    return Container(
      color: const Color(0xFF1e293b).withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: index > 0 ? Colors.white : const Color(0xFF334155)),
            onPressed: index > 0
                ? () => ref.read(selectedBarIndexProvider.notifier).state = index - 1
                : null,
          ),
          Expanded(
            child: nearestAsync.when(
              loading: () => const LoadingSpinner(),
              error: (e, _) => ErrorDisplay(
                message: 'Could not find nearby bars',
                onRetry: () {
                  ref.invalidate(top5BarsProvider);
                  ref.invalidate(nearestBarProvider);
                },
              ),
              data: (info) {
                if (info == null) {
                  return const Center(
                    child: Text('No bars match filters',
                        style: TextStyle(fontSize: 14, color: Color(0xFF94a3b8))),
                  );
                }
                final isOpen = info.distanceMeters >= 0;
                final abs = info.distanceMeters.abs();
                final label = abs < 1000 ? '${abs}m' : '${(abs / 1000).toStringAsFixed(1)}km';
                final title = isOpen ? '${info.bar.name} in' : 'All closed, nearest';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF94a3b8))),
                        const SizedBox(width: 12),
                        Text(
                          isOpen ? label : '-$label',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isOpen ? const Color(0xFF10b981) : const Color(0xFFef4444),
                          ),
                        ),
                      ],
                    ),
                    if (total > 1)
                      Text('${index + 1} / $total',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  ],
                );
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: index < total - 1 ? Colors.white : const Color(0xFF334155)),
            onPressed: index < total - 1
                ? () => ref.read(selectedBarIndexProvider.notifier).state = index + 1
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Container(
      color: const Color(0xFF1e293b).withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _views.length,
          (i) => GestureDetector(
            onTap: () => _swipeToView(i),
            child: Container(
              width: 10, height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentView == _views[i]
                    ? const Color(0xFF10b981)
                    : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
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
              decoration: BoxDecoration(color: Color(0xFF0f172a)),
              child: Text('Drunken Sailor',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            _menuTile(Icons.compass_calibration, 'Compass', const Color(0xFFfbbf24), 0),
            _menuTile(Icons.radar, 'Radar', const Color(0xFF10b981), 1),
            _menuTile(Icons.show_chart, 'Geiger Counter', const Color(0xFFef4444), 2),
            _menuTile(Icons.map, 'Map', const Color(0xFF3b82f6), 3),
            const Divider(color: Color(0xFF334155)),
            SwitchListTile(
              secondary: const Icon(Icons.favorite, color: Color(0xFFec4899)),
              title: const Text('Gay Friendly Only',
                  style: TextStyle(color: Colors.white)),
              value: ref.watch(gayFriendlyFilterProvider),
              activeColor: const Color(0xFFec4899),
              onChanged: (val) {
                ref.read(gayFriendlyFilterProvider.notifier).state = val;
                ref.read(selectedBarIndexProvider.notifier).state = 0;
                ref.invalidate(top5BarsProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Color(0xFFef4444)),
              title: const Text('Blacklist', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BlacklistView()));
              },
            ),
          ],
        ),
      ),
    );
  }

  ListTile _menuTile(IconData icon, String label, Color color, int viewIndex) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        if (viewIndex >= 0) _swipeToView(viewIndex);
      },
    );
  }
}
