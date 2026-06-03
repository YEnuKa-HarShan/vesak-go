import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import '../services/supabase_service.dart';
import '../models/event_model.dart';
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

  List<EventModel> _allEvents = [];
  List<EventModel> _filteredEvents = [];
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
          .where((event) => event.category == _selectedCategory)
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

  double _getEmojiSize() {
    if (_currentZoom < 12) return 18;
    if (_currentZoom < 14) return 22;
    if (_currentZoom < 16) return 26;
    return 30;
  }

  void _showLegend() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Map Legend',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                const Divider(color: Colors.black, height: 24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
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
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
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
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
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
                                    category == 'දන්සල' ? '🍛' : icon,
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
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEventDetails(EventModel event) {
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
                  event.getMarkerIcon(),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.title,
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
              event.getCategoryDisplayName(),
              style: TextStyle(
                  fontSize: 14,
                  color: AppConstants.getCategoryColor(event.category)),
            ),
            if (event.category == 'දන්සල' && event.foodType != 'none')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Food: ${event.foodType}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  event.date,
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
                  event.time,
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
                    event.location,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ],
            ),
            if (event.description != null && event.description!.isNotEmpty)
              Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.description,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.description!,
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Created by: ${event.createdBy}',
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
                    // User location marker
                    if (_currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 30,
                            height: 30,
                            point: _currentLocation!,
                            child: const PulseDot(
                              size: 15,
                              color: Colors.blue,
                              duration: 2,
                            ),
                          ),
                        ],
                      ),
                    // Event markers - Emoji only, decreased size
                    if (_filteredEvents.isNotEmpty)
                      MarkerLayer(
                        markers: _filteredEvents.map((event) {
                          final emojiSize = _getEmojiSize();

                          return Marker(
                            width: emojiSize + 6,
                            height: emojiSize + 6,
                            point: LatLng(event.latitude, event.longitude),
                            child: GestureDetector(
                              onTap: () => _showEventDetails(event),
                              child: Center(
                                child: Text(
                                  event.getMarkerIcon(),
                                  style: TextStyle(
                                    fontSize: emojiSize,
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
                          );
                        }).toList(),
                      ),
                    // Show message when no events
                    if (_filteredEvents.isEmpty && !_isLoading)
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No events to display',
                              style: TextStyle(color: Colors.grey),
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
