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
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    if (_selectedCategory == null) {
      _filteredMyEvents = List.from(_myEvents);
      _filteredAllEvents = List.from(_allEvents);
    } else {
      _filteredMyEvents = _myEvents
          .where((event) => event.category == _selectedCategory)
          .toList();
      _filteredAllEvents = _allEvents
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
      ),
      body: Column(
        children: [
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

  Widget _buildCategoryFilterChips() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _selectedCategory == null,
            onSelected: (_) => _filterByCategory(null),
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
            shape: StadiumBorder(
              side: BorderSide(
                color: Colors.black,
                width: _selectedCategory == null ? 0 : 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ...AppConstants.eventCategories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(category),
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
                shape: StadiumBorder(
                  side: BorderSide(
                    color: Colors.black,
                    width: _selectedCategory == category ? 0 : 1,
                  ),
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
        message = _selectedCategory == null
            ? 'No events created yet'
            : 'No events found in "$_selectedCategory" category';
      } else {
        message = _selectedCategory == null
            ? 'No events available'
            : 'No events found in "$_selectedCategory" category';
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
                _selectedCategory == null)
              const SizedBox(height: 20),
            if (isMyEvents &&
                _sessionService.isLoggedIn &&
                _selectedCategory == null)
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
            if (_selectedCategory != null) const SizedBox(height: 20),
            if (_selectedCategory != null)
              OutlinedButton(
                onPressed: () => _filterByCategory(null),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                ),
                child: const Text('Clear Filter'),
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
