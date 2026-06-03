import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import '../services/supabase_service.dart';
import '../widgets/pulse_dot.dart';

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

  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  String? _selectedCategory;

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
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_selectedCategory == null) {
      _filteredEvents = List.from(_allEvents);
    } else {
      _filteredEvents = _allEvents
          .where((event) => event['category'] == _selectedCategory)
          .toList();
    }
    setState(() {});
  }

  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _applyFilter();
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

  double _getMarkerSize() {
    // Smaller markers at low zoom, larger at high zoom
    if (_currentZoom < 12) return 20;
    if (_currentZoom < 14) return 24;
    if (_currentZoom < 16) return 28;
    return 32;
  }

  double _getIconSize() {
    if (_currentZoom < 12) return 12;
    if (_currentZoom < 14) return 14;
    if (_currentZoom < 16) return 16;
    return 18;
  }

  void _showLegend() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Map Legend',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const Divider(color: Colors.black, height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    child: const PulseDot(
                        size: 20, color: Colors.blue, duration: 2),
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
                              color: Colors.black),
                        ),
                        const Text(
                          'Blue pulsing dot - Your current position',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Event Markers',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 8),
            ...AppConstants.eventCategories.map((category) {
              final color = AppConstants.getCategoryColor(category);
              final icon = AppConstants.getCategoryIcon(category);
              final name = AppConstants.getCategoryName(category);

              return Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          icon,
                          style: const TextStyle(fontSize: 12),
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
                                color: Colors.black),
                          ),
                          Text(
                            name,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
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
    );
  }

  void _showEventDetails(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                  AppConstants.getCategoryIcon(event['category']),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event['title'] ?? 'Event',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event['category'] ?? 'Uncategorized',
              style: TextStyle(
                  fontSize: 14,
                  color: AppConstants.getCategoryColor(event['category'])),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  event['date'] ?? 'Date not set',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  event['time'] ?? 'Time not set',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event['location'] ?? 'Location not set',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Created by: ${event['created_by'] ?? 'Unknown'}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Map',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black),
            onPressed: _showLegend,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => _filterByCategory(null),
                  backgroundColor: Colors.white,
                  selectedColor: Colors.black,
                  labelStyle: TextStyle(
                    color:
                        _selectedCategory == null ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: Colors.black,
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
                      onSelected: (_) => _filterByCategory(category),
                      backgroundColor: Colors.white,
                      selectedColor: Colors.black,
                      labelStyle: TextStyle(
                        color: _selectedCategory == category
                            ? Colors.white
                            : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: Colors.black,
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
                    MarkerLayer(
                      markers: [
                        // User location - Pulse dot
                        if (_currentLocation != null)
                          Marker(
                            width: 40,
                            height: 40,
                            point: _currentLocation!,
                            child: const PulseDot(
                              size: 20,
                              color: Colors.blue,
                              duration: 2,
                            ),
                          ),
                        // Event markers - Colored dot with icon (no border)
                        ..._filteredEvents.map((event) {
                          final markerSize = _getMarkerSize();
                          final iconSize = _getIconSize();

                          return Marker(
                            width: markerSize,
                            height: markerSize,
                            point: LatLng(
                              event['latitude'] as double,
                              event['longitude'] as double,
                            ),
                            child: GestureDetector(
                              onTap: () => _showEventDetails(event),
                              child: Container(
                                width: markerSize,
                                height: markerSize,
                                decoration: BoxDecoration(
                                  color: AppConstants.getCategoryColor(
                                      event['category']),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    AppConstants.getCategoryIcon(
                                        event['category']),
                                    style: TextStyle(
                                      fontSize: iconSize,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
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
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        heroTag: 'zoomOut',
                        onPressed: _zoomOut,
                        mini: true,
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        heroTag: 'center',
                        onPressed: _centerOnUser,
                        mini: true,
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
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
