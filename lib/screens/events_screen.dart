import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../models/event_model.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import 'create_event_screen.dart';
import 'event_details_screen.dart';

// Glass helper
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

class EventsScreen extends StatefulWidget {
  final int initialTab;

  const EventsScreen({super.key, this.initialTab = 0});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with TickerProviderStateMixin {
  // ← Changed from SingleTickerProviderStateMixin
  // Tab state
  int _selectedTabIndex = 0;
  final List<int> _previousTabIndexes = [0, 0, 0];

  // Data lists
  List<EventModel> _myEvents = [];
  List<EventModel> _allEvents = [];
  List<EventModel> _bookmarkedEvents = [];
  Set<String> _bookmarkedEventIds = {};

  // Filtered lists
  List<EventModel> _filteredMyEvents = [];
  List<EventModel> _filteredAllEvents = [];
  List<EventModel> _filteredBookmarkedEvents = [];

  // UI state
  bool _isLoading = true;
  String? _selectedStatus;
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Filter sidebar
  bool _isFilterSidebarOpen = false;
  String? _tempStatus;
  String? _tempCategory;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _sidebarController;

  // Keys for animated list
  final GlobalKey<AnimatedListState> _myEventsListKey =
      GlobalKey<AnimatedListState>();
  final GlobalKey<AnimatedListState> _allEventsListKey =
      GlobalKey<AnimatedListState>();
  final GlobalKey<AnimatedListState> _bookmarksListKey =
      GlobalKey<AnimatedListState>();

  // Search focus
  final FocusNode _searchFocus = FocusNode();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTab;
    _fadeController = AnimationController(
      vsync: this, // Now works with TickerProviderStateMixin
      duration: const Duration(milliseconds: 400),
    );
    _sidebarController = AnimationController(
      vsync: this, // Now works with TickerProviderStateMixin
      duration: const Duration(milliseconds: 300),
    );
    _loadEvents();
    _loadBookmarkedEvents();
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _sidebarController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    final allEvents = await ApiService.getAllEvents();

    setState(() {
      _allEvents = allEvents;
      if (SessionService().isLoggedIn) {
        _myEvents = allEvents
            .where((e) => e.userId == SessionService().currentUser?.id)
            .toList();
      } else {
        _myEvents = [];
      }
      _applyFilters();
      _isLoading = false;
    });
  }

  Future<void> _loadBookmarkedEvents() async {
    if (!SessionService().isLoggedIn) {
      setState(() {
        _bookmarkedEvents = [];
        _bookmarkedEventIds = {};
      });
      return;
    }

    final bookmarked = await ApiService.getBookmarkedEvents();
    setState(() {
      _bookmarkedEvents = bookmarked;
      _bookmarkedEventIds = bookmarked.map((e) => e.id).toSet();
      _applyFilters();
    });
  }

  void _applyFilters() {
    // Filter My Events
    List<EventModel> filteredMy = List.from(_myEvents);
    if (_searchQuery.isNotEmpty) {
      filteredMy = filteredMy
          .where((e) =>
              e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              e.location.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_selectedStatus != null) {
      filteredMy = filteredMy.where(_checkStatusFilter).toList();
    }
    if (_selectedCategory != null) {
      filteredMy =
          filteredMy.where((e) => e.category == _selectedCategory).toList();
    }

    // Filter All Events - Exclude own created events AND bookmarked events
    List<EventModel> filteredAll = List.from(_allEvents);
    filteredAll = filteredAll.where((e) {
      // Exclude own created events
      if (SessionService().isLoggedIn &&
          e.userId == SessionService().currentUser?.id) {
        return false;
      }
      // Exclude bookmarked events
      if (_bookmarkedEventIds.contains(e.id)) {
        return false;
      }
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      filteredAll = filteredAll
          .where((e) =>
              e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              e.location.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_selectedStatus != null) {
      filteredAll = filteredAll.where(_checkStatusFilter).toList();
    }
    if (_selectedCategory != null) {
      filteredAll =
          filteredAll.where((e) => e.category == _selectedCategory).toList();
    }

    // Filter Bookmarked Events
    List<EventModel> filteredBookmarked = List.from(_bookmarkedEvents);
    if (_searchQuery.isNotEmpty) {
      filteredBookmarked = filteredBookmarked
          .where((e) =>
              e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              e.location.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_selectedStatus != null) {
      filteredBookmarked =
          filteredBookmarked.where(_checkStatusFilter).toList();
    }
    if (_selectedCategory != null) {
      filteredBookmarked = filteredBookmarked
          .where((e) => e.category == _selectedCategory)
          .toList();
    }

    // Animate list updates
    _animateListUpdate(_filteredMyEvents, filteredMy, _myEventsListKey);
    _animateListUpdate(_filteredAllEvents, filteredAll, _allEventsListKey);
    _animateListUpdate(
        _filteredBookmarkedEvents, filteredBookmarked, _bookmarksListKey);

    setState(() {
      _filteredMyEvents = filteredMy;
      _filteredAllEvents = filteredAll;
      _filteredBookmarkedEvents = filteredBookmarked;
    });
  }

  void _animateListUpdate(List<EventModel> oldList, List<EventModel> newList,
      GlobalKey<AnimatedListState>? listKey) {
    if (listKey?.currentState == null) return;

    // Remove items that are no longer in the list
    for (int i = oldList.length - 1; i >= 0; i--) {
      if (!newList.contains(oldList[i])) {
        listKey!.currentState!
            .removeItem(i, (context, animation) => const SizedBox.shrink());
      }
    }

    // Add new items
    for (int i = 0; i < newList.length; i++) {
      if (i >= oldList.length || oldList[i] != newList[i]) {
        listKey!.currentState!.insertItem(i);
      }
    }
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
      _selectedStatus = status;
      _applyFilters();
    });
  }

  void _applyCategoryFilter(String? category) {
    setState(() {
      _selectedCategory = category;
      _applyFilters();
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedCategory = null;
      _searchQuery = '';
      _searchController.clear();
      _applyFilters();
    });
    _showSnackBar('All filters cleared', Icons.filter_alt_off);
  }

  bool get _hasActiveFilters {
    return _selectedStatus != null ||
        _selectedCategory != null ||
        _searchQuery.isNotEmpty;
  }

  void _openFilterSidebar() {
    _tempStatus = _selectedStatus;
    _tempCategory = _selectedCategory;
    setState(() {
      _isFilterSidebarOpen = true;
    });
    _sidebarController.forward();
  }

  void _closeFilterSidebar() {
    _sidebarController.reverse();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isFilterSidebarOpen = false;
        });
      }
    });
  }

  void _applyFiltersFromSidebar() {
    _applyStatusFilter(_tempStatus);
    _applyCategoryFilter(_tempCategory);
    _closeFilterSidebar();
  }

  void _showSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_isFilterSidebarOpen) {
      _closeFilterSidebar();
      return false;
    }

    if (_hasActiveFilters) {
      final shouldClear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Clear Filters?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'You have active filters. Do you want to clear them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      );

      if (shouldClear == true) {
        _clearAllFilters();
      }
      return false;
    }

    return true;
  }

  Future<void> _editEvent(EventModel event) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEventScreen(
          userId: SessionService().currentUser!.id,
          userFirstName: SessionService().currentUser!.firstName,
          editEvent: event,
        ),
      ),
    );
    if (result == true) {
      _loadEvents();
      _loadBookmarkedEvents();
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
      final ok = await ApiService.deleteEvent(eventId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                ok ? 'Event deleted successfully' : 'Failed to delete event')),
      );
      if (ok) {
        _loadEvents();
        _loadBookmarkedEvents();
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

  Widget _getCurrentTabWidget() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildEventsList(_filteredMyEvents,
            isMyEvents: true, listKey: _myEventsListKey);
      case 1:
        return _buildEventsList(_filteredAllEvents,
            isMyEvents: false, listKey: _allEventsListKey);
      case 2:
        return _buildBookmarksList();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            _buildAmbientBlobs(),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildSearchBar(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeInOutCubic,
                      switchOutCurve: Curves.easeInOutCubic,
                      child: _getCurrentTabWidget(),
                    ),
                  ),
                  _buildBottomNavigationBar(),
                ],
              ),
            ),
            // Filter Sidebar with smooth animation
            if (_isFilterSidebarOpen)
              AnimatedBuilder(
                animation: _sidebarController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      MediaQuery.of(context).size.width *
                          (1 - _sidebarController.value),
                      0,
                    ),
                    child: Opacity(
                      opacity: _sidebarController.value,
                      child: _buildFilterSidebar(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textSecondary,
          currentIndex: _selectedTabIndex,
          elevation: 0,
          onTap: (index) {
            setState(() {
              _previousTabIndexes[_selectedTabIndex] = _selectedTabIndex;
              _selectedTabIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note_rounded),
              label: 'My Events',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.public_rounded),
              label: 'All Events',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_rounded),
              label: 'Saved',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSidebar() {
    return GestureDetector(
      onTap: _closeFilterSidebar,
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 8,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              bottomLeft: Radius.circular(24),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  _buildFilterSidebarHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusFilterGroup(),
                          const SizedBox(height: 28),
                          _buildCategoryFilterGroup(),
                        ],
                      ),
                    ),
                  ),
                  _buildFilterSidebarFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSidebarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Filters',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: _closeFilterSidebar,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.tune_rounded,
                  size: 16, color: AppTheme.primary),
            ),
            const SizedBox(width: 8),
            const Text(
              'STATUS',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RadioListTile<String?>(
          title: const Text('All Events', style: TextStyle(fontSize: 14)),
          value: null,
          groupValue: _tempStatus,
          onChanged: (value) => setState(() => _tempStatus = value),
          activeColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        RadioListTile<String?>(
          title: const Text('Active Now', style: TextStyle(fontSize: 14)),
          value: 'active',
          groupValue: _tempStatus,
          onChanged: (value) => setState(() => _tempStatus = value),
          activeColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        RadioListTile<String?>(
          title: const Text('Today', style: TextStyle(fontSize: 14)),
          value: 'today',
          groupValue: _tempStatus,
          onChanged: (value) => setState(() => _tempStatus = value),
          activeColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        RadioListTile<String?>(
          title: const Text('Tomorrow', style: TextStyle(fontSize: 14)),
          value: 'tomorrow',
          groupValue: _tempStatus,
          onChanged: (value) => setState(() => _tempStatus = value),
          activeColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildCategoryFilterGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.category_rounded,
                  size: 16, color: AppTheme.accent),
            ),
            const SizedBox(width: 8),
            const Text(
              'CATEGORY',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RadioListTile<String?>(
          title: const Text('All Categories', style: TextStyle(fontSize: 14)),
          value: null,
          groupValue: _tempCategory,
          onChanged: (value) => setState(() => _tempCategory = value),
          activeColor: AppTheme.primary,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        ...AppConstants.eventCategories.map((category) {
          final icon = AppConstants.getCategoryIcon(category);
          final catColor = AppConstants.getCategoryColor(category);
          return RadioListTile<String?>(
            title: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            value: category,
            groupValue: _tempCategory,
            onChanged: (value) => setState(() => _tempCategory = value),
            activeColor: catColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          );
        }),
      ],
    );
  }

  Widget _buildFilterSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _tempStatus = null;
                  _tempCategory = null;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reset'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _applyFiltersFromSidebar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildHeader() {
    final hasFilters = _hasActiveFilters;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.35),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildGlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () => _onWillPop(),
              ),
              const SizedBox(width: 14),
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
              Stack(
                children: [
                  _buildGlassIconButton(
                    icon: Icons.filter_list_rounded,
                    onPressed: _openFilterSidebar,
                  ),
                  if (hasFilters)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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

  Widget _buildEventsList(List<EventModel> events,
      {required bool isMyEvents,
      required GlobalKey<AnimatedListState> listKey}) {
    if (_isLoading) return _buildLoader();

    if (!SessionService().isLoggedIn && isMyEvents) {
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
      onRefresh: () async {
        await _loadEvents();
        await _loadBookmarkedEvents();
      },
      color: AppTheme.accent,
      child: AnimatedList(
        key: listKey,
        initialItemCount: events.length,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemBuilder: (context, index, animation) {
          final event = events[index];
          final isOwner = SessionService().isLoggedIn &&
              event.userId == SessionService().currentUser?.id;

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: animation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EventCard(
                  event: event,
                  showActions: isOwner,
                  height: 200,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => EventDetailsScreen(event: event)),
                    ).then((_) {
                      _loadBookmarkedEvents();
                      _loadEvents();
                    });
                  },
                  onEdit: () => _editEvent(event),
                  onDelete: () => _deleteEvent(event.id),
                  onShare: () => _shareEvent(event),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookmarksList() {
    if (!SessionService().isLoggedIn) {
      return _buildAuthPrompt(
        icon: Icons.bookmark_border_rounded,
        message: 'Login to bookmark events',
        onLogin: () async {
          await Navigator.pushNamed(context, '/login');
          _loadBookmarkedEvents();
        },
      );
    }

    if (_filteredBookmarkedEvents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_border_rounded,
        message: 'No bookmarked events found',
        subtitle: _hasActiveFilters
            ? 'Try changing your filters'
            : 'Tap the bookmark icon on any event to save it here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookmarkedEvents,
      color: AppTheme.accent,
      child: AnimatedList(
        key: _bookmarksListKey,
        initialItemCount: _filteredBookmarkedEvents.length,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemBuilder: (context, index, animation) {
          final event = _filteredBookmarkedEvents[index];
          final isOwner = SessionService().isLoggedIn &&
              event.userId == SessionService().currentUser?.id;

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: animation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EventCard(
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }

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
