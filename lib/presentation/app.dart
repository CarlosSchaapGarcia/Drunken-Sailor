import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../domain/models/nearest_bar_result.dart';
import 'providers/providers.dart';
import 'views/compass_view.dart';
import 'views/radar_view.dart';
import 'views/geiger_view.dart';
import 'widgets/error_display.dart';
import 'widgets/loading_spinner.dart';
import 'widgets/location_debug_overlay.dart';
import 'widgets/location_permission_dialog.dart';

enum ViewMode { compass, radar, geiger }

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

  static const _longPressDuration = Duration(seconds: 5);
  static const _movementThresholdM = 10.0;

  final _views = [ViewMode.compass, ViewMode.radar, ViewMode.geiger];
  final _viewTitles = {
    ViewMode.compass: 'Pirate Compass',
    ViewMode.radar: 'Submarine Radar',
    ViewMode.geiger: 'Nuclear Counter',
  };
  final _viewThemes = {
    ViewMode.compass: 'pirate',
    ViewMode.radar: 'submarine',
    ViewMode.geiger: 'nuclear',
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
    if (state == AppLifecycleState.paused) {
      service.stop();
    } else if (state == AppLifecycleState.resumed) {
      Permission.locationWhenInUse.status.then((s) {
        if (s.isGranted) service.start();
      });
    }
  }

  Future<void> _checkFirebase() async {
    try {
      final bars = await ref.read(barRepositoryProvider).getAllBars();
      // ignore: avoid_print
      print('[Firebase] Connected — ${bars.length} bars loaded');
    } catch (e) {
      // ignore: avoid_print
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
    service.positionStream.listen((pos) {
      final last = ref.read(queryPositionProvider);
      final movedFar = last == null ||
          Geolocator.distanceBetween(
                last.latitude, last.longitude,
                pos.latitude, pos.longitude,
              ) >
              _movementThresholdM;
      if (movedFar) {
        ref.read(queryPositionProvider.notifier).state = pos;
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
    final AsyncValue<NearestBarResult?> nearestAsync = ref.watch(nearestBarProvider);

    final scaffold = Scaffold(
      drawer: _buildMenu(),
      body: Column(
        children: [
          _buildNavBar(),
          _buildDistanceIndicator(nearestAsync),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: const [
                Center(child: CompassView()),
                Center(child: RadarView()),
                Center(child: GeigerView()),
              ],
            ),
          ),
          _buildDots(),
        ],
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
          Row(
            children: [
              IconButton(icon: const Icon(Icons.location_on, size: 24), onPressed: () {}),
              IconButton(icon: const Icon(Icons.list, size: 24), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceIndicator(AsyncValue<NearestBarResult?> nearestAsync) {
    final themeColor = _themeAccent(_viewThemes[_currentView]!);
    return Container(
      color: const Color(0xFF1e293b).withOpacity(0.5),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: nearestAsync.when(
        loading: () => const LoadingSpinner(),
        error: (_, __) => ErrorDisplay(
          message: 'Could not reach Firestore',
          onRetry: () => ref.invalidate(nearestBarProvider),
        ),
        data: (result) {
          if (result == null) {
            return Center(
              child: Text(
                'No bars found nearby',
                style: TextStyle(fontSize: 15, color: themeColor.withOpacity(0.6)),
              ),
            );
          }
          final dist = result.distanceM;
          final distLabel = dist < 1000
              ? '${dist}m'
              : '${(dist / 1000).toStringAsFixed(1)}km';
          final nameColor = result.isOpen ? themeColor : const Color(0xFF64748b);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  result.bar.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: nameColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                distLabel,
                style: const TextStyle(fontSize: 15, color: Color(0xFF94a3b8)),
              ),
              if (!result.isOpen) ...[
                const SizedBox(width: 6),
                const Text(
                  'closed',
                  style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Color _themeAccent(String theme) {
    switch (theme) {
      case 'pirate': return const Color(0xFFfbbf24);
      case 'nuclear': return const Color(0xFFef4444);
      case 'submarine': return const Color(0xFF10b981);
      default: return const Color(0xFF10b981);
    }
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
            const Divider(color: Color(0xFF334155)),
            _menuTile(Icons.map, 'Map', const Color(0xFF64748b), -1),
            _menuTile(Icons.block, 'Blacklist', const Color(0xFF64748b), -1),
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
