import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import '../services/supabase_service.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  LatLng? _currentLocation;
  double _currentZoom = AppConstants.mapInitialZoom;
  bool _isLoading = true;
  final MapController _mapController = MapController();

  List<EventModel> _allEvents = [];
  List<EventModel> _filteredEvents = [];
  String? _selectedCategory;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadEvents();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final events = await _supabaseService.getEventsForMap();
    setState(() {
      _allEvents = events;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<EventModel> filtered = List.from(_allEvents);

    if (_selectedStatus != null) {
      filtered = filtered.where((event) => _checkStatusFilter(event)).toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered
          .where((event) => event.category == _selectedCategory)
          .toList();
    }

    setState(() {
      _filteredEvents = filtered;
    });
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
            } catch (e) {
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
    } catch (e) {
      return false;
    }
  }

  void _applyStatusFilter(String? status) {
    setState(() {
      if (_selectedStatus == status) {
        _selectedStatus = null;
      } else {
        _selectedStatus = status;
      }
      _applyFilters();
    });
  }

  void _applyCategoryFilter(String? category) {
    setState(() {
      if (_selectedCategory == category) {
        _selectedCategory = null;
      } else {
        _selectedCategory = category;
      }
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
    } catch (e) {
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
      setState(() {
        _currentZoom = AppConstants.mapFocusZoom;
      });
    }
  }

  void _zoomIn() {
    if (_currentZoom < AppConstants.mapMaxZoom) {
      double newZoom = _currentZoom + AppConstants.mapZoomStep;
      setState(() {
        _currentZoom = newZoom;
      });
      _mapController.move(_mapController.center, _currentZoom);
    }
  }

  void _zoomOut() {
    if (_currentZoom > AppConstants.mapMinZoom) {
      double newZoom = _currentZoom - AppConstants.mapZoomStep;
      setState(() {
        _currentZoom = newZoom;
      });
      _mapController.move(_mapController.center, _currentZoom);
    }
  }

  Widget _buildEventMarker(EventModel event, double zoom) {
    final icon = event.getMarkerIcon();
    final color = AppConstants.getCategoryColor(event.category);

    // Zoom < 12: Color dot only (no emoji)
    if (zoom < 12) {
      return GestureDetector(
        onTap: () => _showEventDetails(event),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
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
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Zoom 12-14: Colored dot with small emoji inside
    else if (zoom < 14) {
      return GestureDetector(
        onTap: () => _showEventDetails(event),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 10, color: AppTheme.white),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Zoom 14-16: Emoji only (medium)
    else if (zoom < 16) {
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
                fontSize: 20,
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

    // Zoom >= 16: Emoji only (large)
    else {
      return GestureDetector(
        onTap: () => _showEventDetails(event),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Text(
              icon,
              style: const TextStyle(
                fontSize: 26,
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
  }

  void _showLegend() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.sand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Map Legend',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal),
                ),
                const Divider(color: AppTheme.sand, height: 24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // User Location
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.sand,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.my_location,
                                    size: 20, color: AppTheme.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your Location',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.charcoal),
                                  ),
                                  Text(
                                    'Blue dot - Your current position',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            AppTheme.charcoal.withOpacity(0.6)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Zoom Level Legend
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.sand,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Zoom Level Guide',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoal),
                            ),
                            const SizedBox(height: 12),
                            _buildLegendZoomItem(
                              'Zoom Out (< 12)',
                              'Colored dots only',
                              'Shows event density',
                            ),
                            const SizedBox(height: 8),
                            _buildLegendZoomItem(
                              'Medium Zoom (12-14)',
                              'Colored dots + small emojis',
                              'Shows category type',
                            ),
                            const SizedBox(height: 8),
                            _buildLegendZoomItem(
                              'Zoom In (14-16)',
                              'Medium emojis only',
                              'Clear category identification',
                            ),
                            const SizedBox(height: 8),
                            _buildLegendZoomItem(
                              'Max Zoom (> 16)',
                              'Large emojis only',
                              'Easy to tap and read',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Event Categories',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoal),
                      ),
                      const SizedBox(height: 12),

                      ...AppConstants.eventCategories.map((category) {
                        final color = AppConstants.getCategoryColor(category);
                        final icon = AppConstants.getCategoryIcon(category);
                        final name = AppConstants.getCategoryName(category);

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.sand,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    icon,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.charcoal),
                                    ),
                                    Text(
                                      name,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.charcoal
                                              .withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendZoomItem(
      String title, String subtitle, String description) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.saffron,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal),
              ),
              Text(
                subtitle,
                style: TextStyle(
                    fontSize: 11, color: AppTheme.charcoal.withOpacity(0.7)),
              ),
              Text(
                description,
                style: TextStyle(
                    fontSize: 10, color: AppTheme.charcoal.withOpacity(0.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEventDetails(EventModel event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  event.getMarkerIcon(),
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.charcoal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.getCategoryColor(event.category)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                event.getCategoryDisplayName(),
                style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.getCategoryColor(event.category)),
              ),
            ),
            if (event.category == 'දන්සල' && event.foodType != 'none')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant,
                        size: 14, color: AppTheme.charcoal),
                    const SizedBox(width: 8),
                    Text(
                      'Food: ${event.foodType}',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.charcoal.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.calendar_today, event.date),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.access_time, event.time),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.location_on, event.location,
                isMultiline: true),
            if (event.description != null && event.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildDetailRow(Icons.description, event.description!,
                    isMultiline: true),
              ),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.person, 'Created by: ${event.createdBy}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.saffron,
                  foregroundColor: AppTheme.white,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
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
        Icon(icon, size: 16, color: AppTheme.charcoal.withOpacity(0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.charcoal.withOpacity(0.7),
            ),
            maxLines: isMultiline ? 3 : 1,
            overflow:
                isMultiline ? TextOverflow.ellipsis : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.sand,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.sand,
      appBar: AppBar(
        title: const Text(
          'Map',
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedCategory != null || _selectedStatus != null)
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text(
                'Clear All',
                style: TextStyle(color: AppTheme.gold),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.white),
            onPressed: _showLegend,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Filter Chips
          Container(
            height: 45,
            margin: const EdgeInsets.only(top: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedStatus == null,
                  onSelected: (_) => _applyStatusFilter(null),
                  backgroundColor: AppTheme.white,
                  selectedColor: AppTheme.saffron,
                  labelStyle: TextStyle(
                    color: _selectedStatus == null
                        ? AppTheme.white
                        : AppTheme.charcoal,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: AppTheme.sand,
                    width: _selectedStatus == null ? 0 : 1,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Active'),
                  selected: _selectedStatus == 'active',
                  onSelected: (_) => _applyStatusFilter('active'),
                  backgroundColor: AppTheme.white,
                  selectedColor: AppTheme.saffron,
                  labelStyle: TextStyle(
                    color: _selectedStatus == 'active'
                        ? AppTheme.white
                        : AppTheme.charcoal,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: AppTheme.sand,
                    width: _selectedStatus == 'active' ? 0 : 1,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Today'),
                  selected: _selectedStatus == 'today',
                  onSelected: (_) => _applyStatusFilter('today'),
                  backgroundColor: AppTheme.white,
                  selectedColor: AppTheme.saffron,
                  labelStyle: TextStyle(
                    color: _selectedStatus == 'today'
                        ? AppTheme.white
                        : AppTheme.charcoal,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: AppTheme.sand,
                    width: _selectedStatus == 'today' ? 0 : 1,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Tomorrow'),
                  selected: _selectedStatus == 'tomorrow',
                  onSelected: (_) => _applyStatusFilter('tomorrow'),
                  backgroundColor: AppTheme.white,
                  selectedColor: AppTheme.saffron,
                  labelStyle: TextStyle(
                    color: _selectedStatus == 'tomorrow'
                        ? AppTheme.white
                        : AppTheme.charcoal,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: AppTheme.sand,
                    width: _selectedStatus == 'tomorrow' ? 0 : 1,
                  ),
                ),
              ],
            ),
          ),
          // Category Filter Chips
          Container(
            height: 45,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => _applyCategoryFilter(null),
                  backgroundColor: AppTheme.white,
                  selectedColor: AppTheme.saffron,
                  labelStyle: TextStyle(
                    color: _selectedCategory == null
                        ? AppTheme.white
                        : AppTheme.charcoal,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: AppTheme.sand,
                    width: _selectedCategory == null ? 0 : 1,
                  ),
                ),
                const SizedBox(width: 8),
                ...AppConstants.eventCategories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppConstants.getCategoryIcon(category),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(category),
                        ],
                      ),
                      selected: _selectedCategory == category,
                      onSelected: (_) => _applyCategoryFilter(category),
                      backgroundColor: AppTheme.white,
                      selectedColor: AppTheme.saffron,
                      labelStyle: TextStyle(
                        color: _selectedCategory == category
                            ? AppTheme.white
                            : AppTheme.charcoal,
                        fontWeight: FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: AppTheme.sand,
                        width: _selectedCategory == category ? 0 : 1,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation!,
                    initialZoom: AppConstants.mapInitialZoom,
                    minZoom: AppConstants.mapMinZoom,
                    maxZoom: AppConstants.mapMaxZoom,
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture && position.zoom != null) {
                        setState(() {
                          _currentZoom = position.zoom!;
                        });
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
                            width: 44,
                            height: 44,
                            point: _currentLocation!,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppTheme.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Event markers with dynamic zoom-based styling
                    if (_filteredEvents.isNotEmpty)
                      MarkerLayer(
                        markers: _filteredEvents.map((event) {
                          return Marker(
                            width: 48,
                            height: 48,
                            point: LatLng(event.latitude, event.longitude),
                            child: _buildEventMarker(event, _currentZoom),
                          );
                        }).toList(),
                      ),
                    if (_filteredEvents.isEmpty && !_isLoading)
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy,
                                size: 48, color: AppTheme.charcoal),
                            SizedBox(height: 16),
                            Text(
                              'No events to display',
                              style: TextStyle(color: AppTheme.charcoal),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'zoomIn',
                        onPressed: _zoomIn,
                        mini: true,
                        backgroundColor: AppTheme.saffron,
                        foregroundColor: AppTheme.white,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        heroTag: 'zoomOut',
                        onPressed: _zoomOut,
                        mini: true,
                        backgroundColor: AppTheme.saffron,
                        foregroundColor: AppTheme.white,
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        heroTag: 'center',
                        onPressed: _centerOnUser,
                        mini: true,
                        backgroundColor: AppTheme.saffron,
                        foregroundColor: AppTheme.white,
                        child: const Icon(Icons.my_location),
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
}
