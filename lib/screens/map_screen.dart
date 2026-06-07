import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import '../services/supabase_service.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────
//  Glass helper  (identical to HomeScreen / ProfileScreen)
// ─────────────────────────────────────────────────────────────

class _Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final double blur;
  final double opacity;
  final Border? border;

  const _Glass({
    required this.child,
    this.borderRadius,
    this.padding,
    this.tint = Colors.white,
    this.blur = 18,
    this.opacity = 0.10,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withOpacity(opacity),
            borderRadius: br,
            border: border ??
                Border.all(color: Colors.white.withOpacity(0.18), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MapScreen
// ─────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();

  LatLng? _currentLocation;
  double _currentZoom = AppConstants.mapInitialZoom;
  bool _isLoading = true;
  final MapController _mapController = MapController();

  List<EventModel> _allEvents = [];
  List<EventModel> _filteredEvents = [];
  String? _selectedCategory;
  String? _selectedStatus;

  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _getCurrentLocation();
    _loadEvents();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  Data & filter logic  (unchanged)
  // ─────────────────────────────────────────────

  Future<void> _loadEvents() async {
    final events = await _supabaseService.getEventsForMap();
    setState(() {
      _allEvents = events;
      _applyFilters();
    });
    _fadeCtrl.forward(from: 0);
  }

  void _applyFilters() {
    List<EventModel> filtered = List.from(_allEvents);
    if (_selectedStatus != null) {
      filtered = filtered.where((e) => _checkStatusFilter(e)).toList();
    }
    if (_selectedCategory != null) {
      filtered =
          filtered.where((e) => e.category == _selectedCategory).toList();
    }
    setState(() => _filteredEvents = filtered);
  }

  bool _checkStatusFilter(EventModel event) {
    try {
      final eventDate = DateTime.parse(event.date);
      final currentDate = DateTime.now();
      final nextDay = currentDate.add(const Duration(days: 1));

      switch (_selectedStatus) {
        case 'active':
          if (eventDate.year == currentDate.year &&
              eventDate.month == currentDate.month &&
              eventDate.day == currentDate.day) {
            try {
              final timeStr = event.time.toLowerCase();
              bool isPM = timeStr.contains('pm');
              final timeParts =
                  timeStr.replaceAll(RegExp(r'[apm]'), '').trim().split(':');
              int hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              if (isPM && hour != 12) hour += 12;
              if (!isPM && hour == 12) hour = 0;
              final eventDateTime = DateTime(
                  eventDate.year, eventDate.month, eventDate.day, hour, minute);
              return eventDateTime.isAfter(DateTime.now());
            } catch (_) {
              return false;
            }
          }
          return false;

        case 'today':
          return eventDate.year == currentDate.year &&
              eventDate.month == currentDate.month &&
              eventDate.day == currentDate.day;

        case 'tomorrow':
          return eventDate.year == nextDay.year &&
              eventDate.month == nextDay.month &&
              eventDate.day == nextDay.day;

        default:
          return true;
      }
    } catch (_) {
      return false;
    }
  }

  void _applyStatusFilter(String? status) {
    setState(() {
      _selectedStatus = (_selectedStatus == status) ? null : status;
      _applyFilters();
    });
  }

  void _applyCategoryFilter(String? category) {
    setState(() {
      _selectedCategory = (_selectedCategory == category) ? null : category;
      _applyFilters();
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedStatus = null;
      _applyFilters();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentLocation = const LatLng(7.8731, 80.7718);
        });
      }
    }
  }

  void _centerOnUser() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, AppConstants.mapFocusZoom);
      setState(() => _currentZoom = AppConstants.mapFocusZoom);
    }
  }

  void _zoomIn() {
    if (_currentZoom < AppConstants.mapMaxZoom) {
      final newZoom = _currentZoom + AppConstants.mapZoomStep;
      setState(() => _currentZoom = newZoom);
      _mapController.move(_mapController.center, _currentZoom);
    }
  }

  void _zoomOut() {
    if (_currentZoom > AppConstants.mapMinZoom) {
      final newZoom = _currentZoom - AppConstants.mapZoomStep;
      setState(() => _currentZoom = newZoom);
      _mapController.move(_mapController.center, _currentZoom);
    }
  }

  // ─────────────────────────────────────────────
  //  Marker builder  (unchanged)
  // ─────────────────────────────────────────────

  Widget _buildEventMarker(EventModel event, double zoom) {
    final icon = event.getMarkerIcon();
    final color = AppConstants.getCategoryColor(event.category);

    if (zoom < 14) {
      return GestureDetector(
        onTap: () => _showEventDetails(event),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showEventDetails(event),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Text(
            icon,
            style: const TextStyle(
              fontSize: 22,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD ROOT
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Loading state — blobs + glass spinner
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            _buildAmbientBlobs(),
            const Center(
              child: _Glass(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                opacity: 0.55,
                tint: Colors.white,
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Ambient blobs (behind everything) ──
          _buildAmbientBlobs(),

          // ── Safe area content ──
          SafeArea(
            child: Column(
              children: [
                // ── Glass header ──
                _buildHeader(),

                // ── Glass status filter bar ──
                _buildStatusFilterBar(),

                // ── Glass category filter bar ──
                _buildCategoryFilterBar(),

                // ── Map + overlays ──
                Expanded(
                  child: Stack(
                    children: [
                      // Map
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentLocation!,
                          initialZoom: AppConstants.mapInitialZoom,
                          minZoom: AppConstants.mapMinZoom,
                          maxZoom: AppConstants.mapMaxZoom,
                          onPositionChanged: (position, hasGesture) {
                            if (hasGesture && position.zoom != null) {
                              setState(() => _currentZoom = position.zoom!);
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: AppConstants.mapTileUrl,
                            userAgentPackageName: 'com.example.vesak_go',
                          ),

                          // User location marker
                          if (_currentLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: _currentLocation!,
                                  child: Center(
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.4),
                                            blurRadius: 6,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          // Event markers
                          if (_filteredEvents.isNotEmpty)
                            MarkerLayer(
                              markers: _filteredEvents.map((event) {
                                return Marker(
                                  width: 48,
                                  height: 48,
                                  point:
                                      LatLng(event.latitude, event.longitude),
                                  child: _buildEventMarker(event, _currentZoom),
                                );
                              }).toList(),
                            ),
                        ],
                      ),

                      // Empty state overlay
                      if (_filteredEvents.isEmpty)
                        Center(
                          child: _Glass(
                            borderRadius: BorderRadius.circular(20),
                            opacity: 0.75,
                            tint: Colors.white,
                            blur: 16,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_busy_rounded,
                                    size: 40,
                                    color: AppTheme.textSecondary
                                        .withOpacity(0.6)),
                                const SizedBox(height: 10),
                                Text(
                                  'No events to display',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary
                                          .withOpacity(0.8)),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── Glass zoom / locate FABs ──
                      Positioned(
                        bottom: 20,
                        right: 16,
                        child: Column(
                          children: [
                            _buildGlassFab(
                              heroTag: 'zoomIn',
                              icon: Icons.add_rounded,
                              onPressed: _zoomIn,
                            ),
                            const SizedBox(height: 10),
                            _buildGlassFab(
                              heroTag: 'zoomOut',
                              icon: Icons.remove_rounded,
                              onPressed: _zoomOut,
                            ),
                            const SizedBox(height: 10),
                            _buildGlassFab(
                              heroTag: 'center',
                              icon: Icons.my_location_rounded,
                              onPressed: _centerOnUser,
                              accent: Colors.blue,
                            ),
                          ],
                        ),
                      ),

                      // ── Active filter count badge ──
                      if (_selectedCategory != null || _selectedStatus != null)
                        Positioned(
                          bottom: 20,
                          left: 16,
                          child: GestureDetector(
                            onTap: _clearAllFilters,
                            child: _Glass(
                              borderRadius: BorderRadius.circular(20),
                              opacity: 0.80,
                              tint: AppTheme.error,
                              blur: 14,
                              border: Border.all(
                                  color: AppTheme.error.withOpacity(0.40),
                                  width: 1),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.filter_list_off_rounded,
                                      size: 14, color: Colors.white),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Clear filters',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  AMBIENT BLOBS  (same as HomeScreen)
  // ─────────────────────────────────────────────

  Widget _buildAmbientBlobs() {
    return Stack(
      children: [
        Positioned(
          top: -60,
          left: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withOpacity(0.12),
            ),
          ),
        ),
        Positioned(
          top: 100,
          right: -80,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withOpacity(0.10),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: 60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.blobEmerald.withOpacity(0.08),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  GLASS HEADER  (matches HomeScreen exactly)
  // ─────────────────────────────────────────────

  Widget _buildHeader() {
    final hasFilters = _selectedCategory != null || _selectedStatus != null;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            border: Border(
              bottom:
                  BorderSide(color: Colors.white.withOpacity(0.35), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Back button
              _buildGlassIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 14),

              // Title + event count pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vesak Map',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _Glass(
                          borderRadius: BorderRadius.circular(20),
                          opacity: 0.55,
                          tint: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 11,
                                  color: AppTheme.primary.withOpacity(0.8)),
                              const SizedBox(width: 4),
                              Text(
                                '${_filteredEvents.length} event${_filteredEvents.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      AppTheme.textSecondary.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasFilters) ...[
                          const SizedBox(width: 6),
                          _Glass(
                            borderRadius: BorderRadius.circular(20),
                            opacity: 0.15,
                            tint: AppTheme.accent,
                            blur: 10,
                            border: Border.all(
                                color: AppTheme.accent.withOpacity(0.35),
                                width: 1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            child: const Text(
                              'Filtered',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Legend button
              _buildGlassIconButton(
                icon: Icons.info_outline_rounded,
                onPressed: _showLegend,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return _Glass(
      borderRadius: BorderRadius.circular(14),
      opacity: 0.55,
      tint: Colors.white,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          icon: Icon(icon, size: 20),
          color: AppTheme.primary,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  GLASS FILTER BARS
  // ─────────────────────────────────────────────

  Widget _buildStatusFilterBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.45),
            border: Border(
              bottom:
                  BorderSide(color: Colors.white.withOpacity(0.25), width: 1),
            ),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildGlassChip(
                label: 'All',
                selected: _selectedStatus == null,
                onTap: () => _applyStatusFilter(null),
              ),
              const SizedBox(width: 8),
              _buildGlassChip(
                label: 'Active',
                selected: _selectedStatus == 'active',
                onTap: () => _applyStatusFilter('active'),
                accent: AppTheme.success,
              ),
              const SizedBox(width: 8),
              _buildGlassChip(
                label: 'Today',
                selected: _selectedStatus == 'today',
                onTap: () => _applyStatusFilter('today'),
                accent: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              _buildGlassChip(
                label: 'Tomorrow',
                selected: _selectedStatus == 'tomorrow',
                onTap: () => _applyStatusFilter('tomorrow'),
                accent: AppTheme.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.38),
            border: Border(
              bottom:
                  BorderSide(color: Colors.white.withOpacity(0.22), width: 1),
            ),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildGlassChip(
                label: 'All',
                selected: _selectedCategory == null,
                onTap: () => _applyCategoryFilter(null),
              ),
              const SizedBox(width: 8),
              ...AppConstants.eventCategories.map((category) {
                final catColor = AppConstants.getCategoryColor(category);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildGlassChip(
                    label:
                        '${AppConstants.getCategoryIcon(category)} $category',
                    selected: _selectedCategory == category,
                    onTap: () => _applyCategoryFilter(category),
                    accent: catColor,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Glass chip — replaces plain Material FilterChip
  Widget _buildGlassChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color accent = AppTheme.primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withOpacity(0.18)
                    : Colors.white.withOpacity(0.60),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? accent.withOpacity(0.55)
                      : Colors.white.withOpacity(0.70),
                  width: 1.2,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? accent : AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  GLASS FAB  (replaces solid FloatingActionButton)
  // ─────────────────────────────────────────────

  Widget _buildGlassFab({
    required String heroTag,
    required IconData icon,
    required VoidCallback onPressed,
    Color accent = AppTheme.primary,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withOpacity(0.70), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EVENT DETAILS BOTTOM SHEET  (glass)
  // ─────────────────────────────────────────────

  void _showEventDetails(EventModel event) {
    final catColor = AppConstants.getCategoryColor(event.category);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top:
                    BorderSide(color: Colors.white.withOpacity(0.55), width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.timelineInactive,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title row
                Row(
                  children: [
                    _Glass(
                      borderRadius: BorderRadius.circular(14),
                      opacity: 0.15,
                      tint: catColor,
                      blur: 10,
                      border: Border.all(
                          color: catColor.withOpacity(0.30), width: 1),
                      padding: const EdgeInsets.all(10),
                      child: Text(event.getMarkerIcon(),
                          style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Category pill
                Row(
                  children: [
                    _Glass(
                      borderRadius: BorderRadius.circular(20),
                      opacity: 0.14,
                      tint: catColor,
                      blur: 10,
                      border: Border.all(
                          color: catColor.withOpacity(0.35), width: 1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      child: Text(
                        event.getCategoryDisplayName(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: catColor,
                        ),
                      ),
                    ),
                    if (event.category == 'දන්සල' &&
                        event.foodType != 'none') ...[
                      const SizedBox(width: 8),
                      _Glass(
                        borderRadius: BorderRadius.circular(20),
                        opacity: 0.55,
                        tint: Colors.white,
                        blur: 10,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restaurant_rounded,
                                size: 12,
                                color: AppTheme.textSecondary.withOpacity(0.8)),
                            const SizedBox(width: 5),
                            Text(
                              event.foodType,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Detail rows inside a glass panel
                _Glass(
                  borderRadius: BorderRadius.circular(18),
                  opacity: 0.50,
                  tint: Colors.white,
                  blur: 10,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _buildDetailRow(Icons.calendar_today_rounded, event.date),
                      const SizedBox(height: 10),
                      _buildDetailRow(Icons.access_time_rounded, event.time),
                      const SizedBox(height: 10),
                      _buildDetailRow(Icons.location_on_rounded, event.location,
                          isMultiline: true),
                      if (event.description != null &&
                          event.description!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildDetailRow(Icons.notes_rounded, event.description!,
                            isMultiline: true),
                      ],
                      const SizedBox(height: 10),
                      _buildDetailRow(Icons.person_outline_rounded,
                          'Created by: ${event.createdBy}'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Close',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text,
      {bool isMultiline = false}) {
    return Row(
      crossAxisAlignment:
          isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary.withOpacity(0.9),
              height: 1.4,
            ),
            maxLines: isMultiline ? 3 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  LEGEND BOTTOM SHEET  (glass)
  // ─────────────────────────────────────────────

  void _showLegend() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.82),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.55), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle + title (fixed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.timelineInactive,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Map Legend',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Divider(
                              color: Colors.grey.withOpacity(0.18),
                              height: 1,
                              thickness: 1),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),

                    // Scrollable body
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        children: [
                          // Your location item
                          _buildLegendCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.my_location_rounded,
                                      size: 20, color: Colors.white),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Your Location',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textPrimary)),
                                      Text('Blue dot — your current position',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary
                                                  .withOpacity(0.8))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Zoom level guide
                          _buildLegendCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color:
                                            AppTheme.primary.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.zoom_in_rounded,
                                          size: 16, color: AppTheme.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Zoom Level Guide',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary)),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _buildLegendZoomItem(
                                  'Zoom Out (< 14)',
                                  '🔴 Colored dots only',
                                  'Shows event locations and density',
                                ),
                                const SizedBox(height: 10),
                                _buildLegendZoomItem(
                                  'Zoom In (≥ 14)',
                                  '🎡 Category emojis',
                                  'Clear category identification',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Category header
                          const Text(
                            'Event Categories',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Category entries
                          ...AppConstants.eventCategories.map((category) {
                            final color =
                                AppConstants.getCategoryColor(category);
                            final icon = AppConstants.getCategoryIcon(category);
                            final name = AppConstants.getCategoryName(category);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildLegendCard(
                                tint: color,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: color.withOpacity(0.35),
                                            width: 1),
                                      ),
                                      child: Center(
                                        child: Text(icon,
                                            style:
                                                const TextStyle(fontSize: 18)),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(category,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textPrimary)),
                                          Text(name,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary
                                                      .withOpacity(0.8))),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendCard({required Widget child, Color tint = Colors.white}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tint == Colors.white
                ? Colors.white.withOpacity(0.55)
                : tint.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.60), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLegendZoomItem(
      String title, String subtitle, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary.withOpacity(0.85))),
              Text(description,
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary.withOpacity(0.6))),
            ],
          ),
        ),
      ],
    );
  }
}
