import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';
import '../models/event_model.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import 'create_event_screen.dart';
// Import EventDetailsScreen at the top (add this import)
import 'event_details_screen.dart';

class EventsScreen extends StatefulWidget {
  final int initialTab;

  const EventsScreen({super.key, this.initialTab = 0});

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
  List<EventModel> _bookmarkedEvents = [];

  bool _isLoading = true;
  String? _selectedCategory;
  String? _selectedStatus;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _isCalendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<EventModel>> _eventsMap = {};

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(_onTabChanged);
    _loadEvents();
    if (_sessionService.isLoggedIn) {
      _loadBookmarkedEvents();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 2) {
      _loadBookmarkedEvents();
    }
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
      _buildEventsMap();
      _isLoading = false;
    });
  }

  Future<void> _loadBookmarkedEvents() async {
    if (!_sessionService.isLoggedIn) return;

    final bookmarked = await _supabaseService
        .getBookmarkedEvents(_sessionService.currentUser!.id);
    setState(() {
      _bookmarkedEvents = bookmarked;
    });
  }

  void _buildEventsMap() {
    _eventsMap = {};
    for (var event in _filteredAllEvents) {
      try {
        final date = DateTime.parse(event.date);
        final key = DateTime(date.year, date.month, date.day);
        if (_eventsMap.containsKey(key)) {
          _eventsMap[key]!.add(event);
        } else {
          _eventsMap[key] = [event];
        }
      } catch (e) {
        print('Error parsing date for event: ${event.title}');
      }
    }
  }

  void _applyFilters() {
    List<EventModel> filteredMy = List.from(_myEvents);
    List<EventModel> filteredAll = List.from(_allEvents);

    if (_searchQuery.isNotEmpty) {
      filteredMy = filteredMy
          .where((event) =>
              event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              event.location.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
      filteredAll = filteredAll
          .where((event) =>
              event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              event.location.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_selectedStatus != null) {
      filteredMy =
          filteredMy.where((event) => _checkStatusFilter(event)).toList();
      filteredAll =
          filteredAll.where((event) => _checkStatusFilter(event)).toList();
    }

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
    _buildEventsMap();
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
      _searchQuery = '';
      _searchController.clear();
      _applyFilters();
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  List<EventModel> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventsMap[key] ?? [];
  }

  Future<void> _editEvent(EventModel event) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventScreen(
          userId: _sessionService.currentUser!.id,
          userFirstName: _sessionService.currentUser!.firstName,
          editEvent: event,
        ),
      ),
    );

    if (result == true) {
      _loadEvents();
      if (_tabController.index == 2) {
        _loadBookmarkedEvents();
      }
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event',
            style: TextStyle(color: AppTheme.charcoal)),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.charcoal)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: AppTheme.maroon)),
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
        if (_tabController.index == 2) {
          _loadBookmarkedEvents();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete event')),
        );
      }
    }
  }

  void _shareEvent(EventModel event) {
    Share.share(
      '🎉 ${event.title}\n\n'
      '📅 Date: ${event.date}\n'
      '⏰ Time: ${event.time}\n'
      '📍 Location: ${event.location}\n'
      '📂 Category: ${event.category}\n\n'
      'Check out this event on VesakGO!',
      subject: 'VesakGO Event: ${event.title}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sand,
      appBar: AppBar(
        title: const Text(
          'Events',
          style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.navy,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.white.withOpacity(0.6),
          indicatorColor: AppTheme.gold,
          tabs: const [
            Tab(text: 'My Events'),
            Tab(text: 'All Events'),
            Tab(text: 'Bookmarks'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_tabController.index == 1)
            IconButton(
              icon: Icon(
                _isCalendarView ? Icons.view_list : Icons.calendar_month,
                color: AppTheme.white,
              ),
              onPressed: () {
                setState(() {
                  _isCalendarView = !_isCalendarView;
                });
              },
            ),
          if (_selectedCategory != null ||
              _selectedStatus != null ||
              _searchQuery.isNotEmpty)
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text(
                'Clear All',
                style: TextStyle(color: AppTheme.gold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.charcoal.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilters();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search events by title or location...',
                  hintStyle:
                      TextStyle(color: AppTheme.charcoal.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: AppTheme.saffron),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: AppTheme.charcoal.withOpacity(0.5)),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                              _applyFilters();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppTheme.white,
                ),
              ),
            ),
          ),
          _buildStatusFilterChips(),
          _buildCategoryFilterChips(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEventsList(_filteredMyEvents, isMyEvents: true),
                _isCalendarView
                    ? _buildCalendarView()
                    : _buildEventsList(_filteredAllEvents, isMyEvents: false),
                _buildBookmarksList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) {
            return _selectedDay != null &&
                day.year == _selectedDay!.year &&
                day.month == _selectedDay!.month &&
                day.day == _selectedDay!.day;
          },
          onDaySelected: _onDaySelected,
          calendarFormat: CalendarFormat.month,
          eventLoader: _getEventsForDay,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: AppTheme.saffron.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppTheme.saffron,
              shape: BoxShape.circle,
            ),
            weekendTextStyle: const TextStyle(color: AppTheme.maroon),
            markerDecoration: BoxDecoration(
              color: AppTheme.gold,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: const TextStyle(
              color: AppTheme.charcoal,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.saffron),
            rightChevronIcon:
                Icon(Icons.chevron_right, color: AppTheme.saffron),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: AppTheme.charcoal.withOpacity(0.6)),
            weekendStyle: TextStyle(color: AppTheme.maroon),
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedDay != null)
          Expanded(
            child: _buildEventsList(_getEventsForDay(_selectedDay!),
                isMyEvents: false),
          ),
      ],
    );
  }

  Widget _buildEventsList(List<EventModel> events, {required bool isMyEvents}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_sessionService.isLoggedIn && isMyEvents) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: AppTheme.charcoal.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Login to view your events',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.charcoal.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/login');
                _loadEvents();
              },
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
        } else if (_searchQuery.isNotEmpty) {
          message = 'No events found for "$_searchQuery"';
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
        } else if (_searchQuery.isNotEmpty) {
          message = 'No events found for "$_searchQuery"';
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
              color: AppTheme.charcoal.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.charcoal.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: AppTheme.gold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final isOwner = _sessionService.isLoggedIn &&
              event.userId == _sessionService.currentUser?.id;
          return EventCard(
            event: event,
            showActions: isOwner,
            height: 200,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailsScreen(event: event),
                ),
              ).then((_) {
                if (_tabController.index == 2) {
                  _loadBookmarkedEvents();
                }
              });
            },
            onEdit: () => _editEvent(event),
            onDelete: () => _deleteEvent(event.id),
            onShare: () => _shareEvent(event),
          );
        },
      ),
    );
  }

  Widget _buildBookmarksList() {
    if (!_sessionService.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: AppTheme.charcoal.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Login to bookmark events',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.charcoal.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/login');
                _loadBookmarkedEvents();
              },
              child: const Text('Login Now'),
            ),
          ],
        ),
      );
    }

    if (_bookmarkedEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: AppTheme.charcoal.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No bookmarked events yet',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.charcoal.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on any event to save it here',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.charcoal.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookmarkedEvents,
      color: AppTheme.gold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookmarkedEvents.length,
        itemBuilder: (context, index) {
          final event = _bookmarkedEvents[index];
          final isOwner = _sessionService.isLoggedIn &&
              event.userId == _sessionService.currentUser?.id;
          return EventCard(
            event: event,
            showActions: isOwner,
            height: 200,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailsScreen(event: event),
                ),
              ).then((_) {
                if (_tabController.index == 2) {
                  _loadBookmarkedEvents();
                }
              });
            },
            onEdit: () => _editEvent(event),
            onDelete: () => _deleteEvent(event.id),
            onShare: () => _shareEvent(event),
          );
        },
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
            backgroundColor: AppTheme.white,
            selectedColor: AppTheme.saffron,
            labelStyle: TextStyle(
              color:
                  _selectedStatus == null ? AppTheme.white : AppTheme.charcoal,
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
    );
  }
}
