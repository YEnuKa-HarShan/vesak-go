import 'dart:ui';
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
import 'event_details_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Glass helper  (mirrors HomeScreen._Glass)
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
//  Screen
// ─────────────────────────────────────────────────────────────

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

  // ── Search focus ──
  final FocusNode _searchFocus = FocusNode();
  bool _searchFocused = false;

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
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
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
    setState(() => _isLoading = true);
    final allEvents = await _supabaseService.getAllEvents();
    setState(() {
      _allEvents = allEvents;
      if (_sessionService.isLoggedIn) {
        _myEvents = allEvents
            .where((e) => e.userId == _sessionService.currentUser?.id)
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
    setState(() => _bookmarkedEvents = bookmarked);
  }

  void _buildEventsMap() {
    _eventsMap = {};
    for (var event in _filteredAllEvents) {
      try {
        final date = DateTime.parse(event.date);
        final key = DateTime(date.year, date.month, date.day);
        _eventsMap.containsKey(key)
            ? _eventsMap[key]!.add(event)
            : _eventsMap[key] = [event];
      } catch (_) {}
    }
  }

  void _applyFilters() {
    List<EventModel> filteredMy = List.from(_myEvents);
    List<EventModel> filteredAll = List.from(_allEvents);

    if (_searchQuery.isNotEmpty) {
      filteredMy = filteredMy
          .where((e) =>
              e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              e.location.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
      filteredAll = filteredAll
          .where((e) =>
              e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              e.location.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_selectedStatus != null) {
      filteredMy = filteredMy.where(_checkStatusFilter).toList();
      filteredAll = filteredAll.where(_checkStatusFilter).toList();
    }

    if (_selectedCategory != null) {
      filteredMy =
          filteredMy.where((e) => e.category == _selectedCategory).toList();
      filteredAll =
          filteredAll.where((e) => e.category == _selectedCategory).toList();
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
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      switch (_selectedStatus) {
        case 'active':
          if (eventDate.year == now.year &&
              eventDate.month == now.month &&
              eventDate.day == now.day) {
            try {
              final ts = event.time.toLowerCase();
              final isPM = ts.contains('pm');
              final parts =
                  ts.replaceAll(RegExp(r'[apm]'), '').trim().split(':');
              int h = int.parse(parts[0]);
              final m = int.parse(parts[1]);
              if (isPM && h != 12) h += 12;
              if (!isPM && h == 12) h = 0;
              return DateTime(
                      eventDate.year, eventDate.month, eventDate.day, h, m)
                  .isAfter(now);
            } catch (_) {
              return false;
            }
          }
          return false;
        case 'today':
          return eventDate.year == now.year &&
              eventDate.month == now.month &&
              eventDate.day == now.day;
        case 'tomorrow':
          return eventDate.year == tomorrow.year &&
              eventDate.month == tomorrow.month &&
              eventDate.day == tomorrow.day;
        default:
          return true;
      }
    } catch (_) {
      return false;
    }
  }

  void _applyStatusFilter(String? status) {
    setState(() {
      _selectedStatus = _selectedStatus == status ? null : status;
      _applyFilters();
    });
  }

  void _applyCategoryFilter(String? category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
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

  List<EventModel> _getEventsForDay(DateTime day) =>
      _eventsMap[DateTime(day.year, day.month, day.day)] ?? [];

  Future<void> _editEvent(EventModel event) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEventScreen(
          userId: _sessionService.currentUser!.id,
          userFirstName: _sessionService.currentUser!.firstName,
          editEvent: event,
        ),
      ),
    );
    if (result == true) {
      _loadEvents();
      if (_tabController.index == 2) _loadBookmarkedEvents();
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.90),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _supabaseService.deleteEvent(eventId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                ok ? 'Event deleted successfully' : 'Failed to delete event')),
      );
      if (ok) {
        _loadEvents();
        if (_tabController.index == 2) _loadBookmarkedEvents();
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

  bool get _hasActiveFilters =>
      _selectedCategory != null ||
      _selectedStatus != null ||
      _searchQuery.isNotEmpty;

  // ─────────────────────────────────────────────
  // BUILD ROOT
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Ambient blobs (same as HomeScreen) ──
          _buildAmbientBlobs(),

          SafeArea(
            child: Column(
              children: [
                // ── Glass header ──
                _buildGlassHeader(),

                // ── Search + filters ──
                _buildSearchBar(),
                _buildStatusFilterChips(),
                _buildCategoryFilterChips(),

                // ── Content ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEventsList(_filteredMyEvents, isMyEvents: true),
                      _isCalendarView
                          ? _buildCalendarView()
                          : _buildEventsList(_filteredAllEvents,
                              isMyEvents: false),
                      _buildBookmarksList(),
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
  // AMBIENT BLOBS
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
  // GLASS HEADER  (mirrors HomeScreen._buildHeader)
  // ─────────────────────────────────────────────

  Widget _buildGlassHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.35),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Title row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    // Back button
                    _Glass(
                      borderRadius: BorderRadius.circular(14),
                      opacity: 0.55,
                      tint: Colors.white,
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18),
                          color: AppTheme.primary,
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title
                    const Expanded(
                      child: Text(
                        'Events',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),

                    // Calendar toggle (tab 1 only)
                    AnimatedOpacity(
                      opacity: _tabController.index == 1 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: _Glass(
                        borderRadius: BorderRadius.circular(14),
                        opacity: 0.55,
                        tint: Colors.white,
                        padding: EdgeInsets.zero,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            icon: Icon(
                              _isCalendarView
                                  ? Icons.view_list_rounded
                                  : Icons.calendar_month_rounded,
                              size: 20,
                            ),
                            color: AppTheme.primary,
                            padding: EdgeInsets.zero,
                            onPressed: _tabController.index == 1
                                ? () => setState(
                                    () => _isCalendarView = !_isCalendarView)
                                : null,
                          ),
                        ),
                      ),
                    ),

                    // Clear filters
                    if (_hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _clearAllFilters,
                        child: _Glass(
                          borderRadius: BorderRadius.circular(20),
                          opacity: 0.55,
                          tint: AppTheme.error,
                          border: Border.all(
                              color: AppTheme.error.withOpacity(0.20),
                              width: 1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Tab bar ──
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primary,
                dividerColor: Colors.transparent,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'My Events'),
                  Tab(text: 'All Events'),
                  Tab(text: 'Bookmarks'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SEARCH BAR
  // ─────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.72),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _searchFocused
                      ? AppTheme.primary.withOpacity(0.45)
                      : Colors.white.withOpacity(0.70),
                  width: _searchFocused ? 1.5 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary
                        .withOpacity(_searchFocused ? 0.08 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilters();
                  });
                },
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search events by title or location…',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.65),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: _searchFocused
                          ? AppTheme.primary
                          : AppTheme.textSecondary.withOpacity(0.6),
                      size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.cancel_rounded,
                              color: AppTheme.textSecondary.withOpacity(0.6),
                              size: 18),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                              _applyFilters();
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FILTER CHIPS (glass style)
  // ─────────────────────────────────────────────

  Widget _buildStatusFilterChips() {
    const statuses = [
      {'label': 'All', 'value': null},
      {'label': 'Active', 'value': 'active'},
      {'label': 'Today', 'value': 'today'},
      {'label': 'Tomorrow', 'value': 'tomorrow'},
    ];

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: statuses.map((s) {
          final val = s['value'] as String?;
          final selected = _selectedStatus == val;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildGlassChip(
              label: s['label'] as String,
              selected: selected,
              onTap: () => _applyStatusFilter(val),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildGlassChip(
              label: 'All',
              selected: _selectedCategory == null,
              onTap: () => _applyCategoryFilter(null),
            ),
          ),
          ...AppConstants.eventCategories.map((cat) {
            final selected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildGlassChip(
                label: '${AppConstants.getCategoryIcon(cat)} $cat',
                selected: selected,
                onTap: () => _applyCategoryFilter(cat),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGlassChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withOpacity(0.88)
                  : Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppTheme.primary.withOpacity(0.40)
                    : Colors.white.withOpacity(0.70),
                width: 1.2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.20),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CALENDAR VIEW
  // ─────────────────────────────────────────────

  Widget _buildCalendarView() {
    if (_isLoading) return _buildLoader();

    return Column(
      children: [
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withOpacity(0.70), width: 1.2),
              ),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) =>
                    _selectedDay != null &&
                    day.year == _selectedDay!.year &&
                    day.month == _selectedDay!.month &&
                    day.day == _selectedDay!.day,
                onDaySelected: _onDaySelected,
                calendarFormat: CalendarFormat.month,
                eventLoader: _getEventsForDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: const TextStyle(color: AppTheme.error),
                  markerDecoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  leftChevronIcon:
                      const Icon(Icons.chevron_left, color: AppTheme.primary),
                  rightChevronIcon:
                      const Icon(Icons.chevron_right, color: AppTheme.primary),
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: const TextStyle(color: AppTheme.textSecondary),
                  weekendStyle: const TextStyle(color: AppTheme.error),
                ),
              ),
            ),
          ),
        ),
        if (_selectedDay != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.event_rounded,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMMM d, yyyy').format(_selectedDay!),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildEventsList(_getEventsForDay(_selectedDay!),
                isMyEvents: false),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────
  // EVENTS LIST
  // ─────────────────────────────────────────────

  Widget _buildEventsList(List<EventModel> events, {required bool isMyEvents}) {
    if (_isLoading) return _buildLoader();

    if (!_sessionService.isLoggedIn && isMyEvents) {
      return _buildAuthPrompt(
        icon: Icons.lock_outline_rounded,
        message: 'Login to view your events',
        onLogin: () async {
          await Navigator.pushNamed(context, '/login');
          _loadEvents();
        },
      );
    }

    if (events.isEmpty) {
      final message = _buildEmptyMessage(isMyEvents: isMyEvents);
      return _buildEmptyState(
        icon: Icons.event_busy_rounded,
        message: message,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: AppTheme.accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
                    builder: (_) => EventDetailsScreen(event: event)),
              ).then((_) {
                if (_tabController.index == 2) _loadBookmarkedEvents();
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

  // ─────────────────────────────────────────────
  // BOOKMARKS LIST
  // ─────────────────────────────────────────────

  Widget _buildBookmarksList() {
    if (!_sessionService.isLoggedIn) {
      return _buildAuthPrompt(
        icon: Icons.bookmark_border_rounded,
        message: 'Login to bookmark events',
        onLogin: () async {
          await Navigator.pushNamed(context, '/login');
          _loadBookmarkedEvents();
        },
      );
    }

    if (_bookmarkedEvents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_border_rounded,
        message: 'No bookmarked events yet',
        subtitle: 'Tap the bookmark icon on any event to save it here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookmarkedEvents,
      color: AppTheme.accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
                    builder: (_) => EventDetailsScreen(event: event)),
              ).then((_) => _loadBookmarkedEvents());
            },
            onEdit: () => _editEvent(event),
            onDelete: () => _deleteEvent(event.id),
            onShare: () => _shareEvent(event),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SHARED EMPTY / LOADING HELPERS
  // ─────────────────────────────────────────────

  Widget _buildLoader() {
    return Center(
      child: _Glass(
        borderRadius: BorderRadius.circular(20),
        opacity: 0.55,
        tint: Colors.white,
        padding: const EdgeInsets.all(24),
        child: const CircularProgressIndicator(
          color: AppTheme.primary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.62),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withOpacity(0.70), width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon,
                        size: 36, color: AppTheme.primary.withOpacity(0.45)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withOpacity(0.65),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthPrompt({
    required IconData icon,
    required String message,
    required VoidCallback onLogin,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.62),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withOpacity(0.70), width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon,
                        size: 36, color: AppTheme.primary.withOpacity(0.45)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: onLogin,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 13),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppTheme.primary.withOpacity(0.40),
                                width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.22),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Login Now',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // EMPTY MESSAGE BUILDER
  // ─────────────────────────────────────────────

  String _buildEmptyMessage({required bool isMyEvents}) {
    if (_selectedCategory != null && _selectedStatus != null) {
      return 'No events found for $_selectedCategory and ${_selectedStatus!.toUpperCase()}';
    } else if (_selectedCategory != null) {
      return 'No events found in "$_selectedCategory"';
    } else if (_selectedStatus != null) {
      return 'No ${_selectedStatus!.toUpperCase()} events found';
    } else if (_searchQuery.isNotEmpty) {
      return 'No events found for "$_searchQuery"';
    }
    return isMyEvents ? 'No events created yet' : 'No events available';
  }
}
