import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';
import '../models/event_model.dart';
import '../constants.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _supabaseService = SupabaseService();
  final SessionService _sessionService = SessionService();

  List<EventModel> _myEvents = [];
  List<EventModel> _allEvents = [];
  List<EventModel> _filteredMyEvents = [];
  List<EventModel> _filteredAllEvents = [];
  bool _isLoading = true;
  String? _selectedCategory;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    final allEvents = await _supabaseService.getAllEvents();

    setState(() {
      _allEvents = allEvents;
      if (_sessionService.isLoggedIn) {
        _myEvents = allEvents
            .where((event) => event.userId == _sessionService.currentUser?.id)
            .toList();
      } else {
        _myEvents = [];
      }
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    List<EventModel> filteredMy = List.from(_myEvents);
    List<EventModel> filteredAll = List.from(_allEvents);

    // Apply status filter
    if (_selectedStatus != null) {
      filteredMy =
          filteredMy.where((event) => _checkStatusFilter(event)).toList();
      filteredAll =
          filteredAll.where((event) => _checkStatusFilter(event)).toList();
    }

    // Apply category filter
    if (_selectedCategory != null) {
      filteredMy = filteredMy
          .where((event) => event.category == _selectedCategory)
          .toList();
      filteredAll = filteredAll
          .where((event) => event.category == _selectedCategory)
          .toList();
    }

    setState(() {
      _filteredMyEvents = filteredMy;
      _filteredAllEvents = filteredAll;
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
            // Parse event time and compare with current time
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

  Future<void> _editEvent(EventModel event) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEventScreen(event: event),
      ),
    );

    if (result == true) {
      _loadEvents();
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            const Text('Delete Event', style: TextStyle(color: Colors.black)),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _supabaseService.deleteEvent(eventId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted successfully')),
        );
        _loadEvents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete event')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Events',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: 'My Events'),
            Tab(text: 'All Events'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedCategory != null || _selectedStatus != null)
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.black),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilterChips(),
          _buildCategoryFilterChips(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEventsList(_filteredMyEvents, isMyEvents: true),
                _buildEventsList(_filteredAllEvents, isMyEvents: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    return Container(
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
            backgroundColor: Colors.white,
            selectedColor: Colors.black,
            labelStyle: TextStyle(
              color: _selectedStatus == null ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
            side: BorderSide(
              color: Colors.black,
              width: _selectedStatus == null ? 0 : 1,
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Active'),
            selected: _selectedStatus == 'active',
            onSelected: (_) => _applyStatusFilter('active'),
            backgroundColor: Colors.white,
            selectedColor: Colors.black,
            labelStyle: TextStyle(
              color: _selectedStatus == 'active' ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
            side: BorderSide(
              color: Colors.black,
              width: _selectedStatus == 'active' ? 0 : 1,
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Today'),
            selected: _selectedStatus == 'today',
            onSelected: (_) => _applyStatusFilter('today'),
            backgroundColor: Colors.white,
            selectedColor: Colors.black,
            labelStyle: TextStyle(
              color: _selectedStatus == 'today' ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
            side: BorderSide(
              color: Colors.black,
              width: _selectedStatus == 'today' ? 0 : 1,
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Tomorrow'),
            selected: _selectedStatus == 'tomorrow',
            onSelected: (_) => _applyStatusFilter('tomorrow'),
            backgroundColor: Colors.white,
            selectedColor: Colors.black,
            labelStyle: TextStyle(
              color:
                  _selectedStatus == 'tomorrow' ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
            side: BorderSide(
              color: Colors.black,
              width: _selectedStatus == 'tomorrow' ? 0 : 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChips() {
    return Container(
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
            backgroundColor: Colors.white,
            selectedColor: Colors.black,
            labelStyle: TextStyle(
              color: _selectedCategory == null ? Colors.white : Colors.black,
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
                onSelected: (_) => _applyCategoryFilter(category),
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
    );
  }

  Widget _buildEventsList(List<EventModel> events, {required bool isMyEvents}) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_sessionService.isLoggedIn && isMyEvents) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Login to view your events',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/login');
                _loadEvents();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Login Now'),
            ),
          ],
        ),
      );
    }

    if (events.isEmpty) {
      String message;
      if (isMyEvents) {
        if (_selectedCategory != null && _selectedStatus != null) {
          message =
              'No events found for $_selectedCategory category and ${_selectedStatus!.toUpperCase()} status';
        } else if (_selectedCategory != null) {
          message = 'No events found in "$_selectedCategory" category';
        } else if (_selectedStatus != null) {
          message = 'No ${_selectedStatus!.toUpperCase()} events found';
        } else {
          message = 'No events created yet';
        }
      } else {
        if (_selectedCategory != null && _selectedStatus != null) {
          message =
              'No events found for $_selectedCategory category and ${_selectedStatus!.toUpperCase()} status';
        } else if (_selectedCategory != null) {
          message = 'No events found in "$_selectedCategory" category';
        } else if (_selectedStatus != null) {
          message = 'No ${_selectedStatus!.toUpperCase()} events found';
        } else {
          message = 'No events available';
        }
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            if (isMyEvents &&
                _sessionService.isLoggedIn &&
                _selectedCategory == null &&
                _selectedStatus == null)
              const SizedBox(height: 20),
            if (isMyEvents &&
                _sessionService.isLoggedIn &&
                _selectedCategory == null &&
                _selectedStatus == null)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create Event'),
              ),
            if (_selectedCategory != null || _selectedStatus != null)
              const SizedBox(height: 20),
            if (_selectedCategory != null || _selectedStatus != null)
              OutlinedButton(
                onPressed: _clearAllFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                ),
                child: const Text('Clear Filters'),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final isOwner = _sessionService.isLoggedIn &&
              event.userId == _sessionService.currentUser?.id;
          return _buildEventCard(event, isOwner: isOwner);
        },
      ),
    );
  }

  Widget _buildEventCard(EventModel event, {required bool isOwner}) {
    final categoryColor = AppConstants.getCategoryColor(event.category);
    final displayIcon = event.getMarkerIcon();
    final displayName = event.getCategoryDisplayName();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayIcon,
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _editEvent(event);
                      } else if (value == 'delete') {
                        await _deleteEvent(event.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.description != null && event.description!.isNotEmpty)
                  Column(
                    children: [
                      Text(
                        event.description!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      event.date,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 16, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      event.time,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 16, color: Colors.black54),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      'Created by: ${event.createdBy}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Created: ${_formatDate(event.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

// EditEventScreen remains the same
class EditEventScreen extends StatefulWidget {
  final EventModel event;

  const EditEventScreen({super.key, required this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  late String _selectedCategory;
  late String _selectedFoodType;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.event.category;
    _selectedFoodType = widget.event.foodType;
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController =
        TextEditingController(text: widget.event.description ?? '');
    _locationController = TextEditingController(text: widget.event.location);
    _dateController = TextEditingController(text: widget.event.date);
    _timeController = TextEditingController(text: widget.event.time);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateEvent() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter event title')),
      );
      return;
    }

    if (_locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter event location')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    double latitude = widget.event.latitude;
    double longitude = widget.event.longitude;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }
    } catch (e) {
      print('Could not get coordinates: $e');
    }

    final success = await _supabaseService.updateEvent(
      eventId: widget.event.id,
      category: _selectedCategory,
      title: _titleController.text,
      description: _descriptionController.text.isEmpty
          ? ''
          : _descriptionController.text,
      date: _dateController.text,
      time: _timeController.text,
      location: _locationController.text,
      latitude: latitude,
      longitude: longitude,
      foodType: _selectedCategory == 'දන්සල' ? _selectedFoodType : 'none',
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated successfully!')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update event')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Event', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Icon(
                Icons.edit,
                size: 80,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Edit Event Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category *',
                labelStyle: const TextStyle(color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              items: AppConstants.eventCategories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Text(
                        AppConstants.getCategoryIcon(category),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(category),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                  if (value != 'දන්සල') {
                    _selectedFoodType = 'none';
                  }
                });
              },
              style: const TextStyle(color: Colors.black),
              dropdownColor: Colors.white,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
            ),
            const SizedBox(height: 20),
            if (_selectedCategory == 'දන්සල')
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    value:
                        _selectedFoodType == 'none' ? null : _selectedFoodType,
                    decoration: InputDecoration(
                      labelText: 'Food Type *',
                      labelStyle: const TextStyle(color: Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                    items: AppConstants.foodTypes.map((food) {
                      return DropdownMenuItem(
                        value: food['sinhala'],
                        child: Row(
                          children: [
                            Text(
                              food['emoji']!,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(food['sinhala']!),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFoodType = value!;
                      });
                    },
                    style: const TextStyle(color: Colors.black),
                    dropdownColor: Colors.white,
                    icon:
                        const Icon(Icons.arrow_drop_down, color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Event Title *',
                labelStyle: const TextStyle(color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: const TextStyle(color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Date *',
                labelStyle: const TextStyle(color: Colors.black),
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _timeController,
              decoration: InputDecoration(
                labelText: 'Time *',
                labelStyle: const TextStyle(color: Colors.black),
                hintText: 'HH:MM AM/PM',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location *',
                labelStyle: const TextStyle(color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleUpdateEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Update Event',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
