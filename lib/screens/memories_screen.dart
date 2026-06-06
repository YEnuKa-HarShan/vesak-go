import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vesak_go/constants.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';
import 'event_details_screen.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final SessionService _sessionService = SessionService();

  List<EventModel> _myEvents = [];
  List<EventModel> _bookmarkedEvents = [];
  List<EventModel> _allMemories = [];
  List<EventModel> _filteredMemories = [];

  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedType;

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  String _activeYear = '';
  double _scrollProgress = 0.0;

  late AnimationController _progressController;

  final TextEditingController _searchController = TextEditingController();

  final Map<String, Color> _yearColors = {
    '2026': AppTheme.event2026,
    '2025': AppTheme.event2025,
    '2024': AppTheme.event2024,
  };

  @override
  void initState() {
    super.initState();
    _loadMemories();
    _scrollController.addListener(_onScroll);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _progressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _updateActiveYear();
    _updateScrollProgress();
    setState(() {});
  }

  void _updateActiveYear() {
    for (var entry in _sectionKeys.entries) {
      final key = entry.value;
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero).dy;
        if (position < 250 && position > -100) {
          if (_activeYear != entry.key) {
            _activeYear = entry.key;
            _progressController.forward(from: 0.0);
          }
          break;
        }
      }
    }
  }

  void _updateScrollProgress() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      setState(() {
        _scrollProgress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
      });
    }
  }

  Future<void> _loadMemories() async {
    setState(() {
      _isLoading = true;
    });

    final allEvents = await _supabaseService.getAllEvents();

    setState(() {
      if (_sessionService.isLoggedIn) {
        _myEvents = allEvents
            .where((event) => event.userId == _sessionService.currentUser?.id)
            .toList();
      } else {
        _myEvents = [];
      }
      _allMemories = List.from(_myEvents);
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    List<EventModel> filtered = List.from(_allMemories);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((event) =>
              event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              event.location.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered
          .where((event) => event.category == _selectedCategory)
          .toList();
    }

    if (_selectedType == 'created') {
      filtered = filtered.where((event) => _myEvents.contains(event)).toList();
    } else if (_selectedType == 'bookmarked') {
      filtered =
          filtered.where((event) => _bookmarkedEvents.contains(event)).toList();
    }

    setState(() {
      _filteredMemories = filtered;
    });
  }

  void _scrollToYear(String year) {
    final key = _sectionKeys[year];
    if (key != null) {
      _activeYear = year;
      _progressController.forward(from: 0.0);
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatYear(DateTime date) {
    return DateFormat('yyyy').format(date);
  }

  Color _getYearColor(String year) {
    return _yearColors[year] ?? AppTheme.surface.withOpacity(0.5);
  }

  @override
  Widget build(BuildContext context) {
    final eventsByYear = <String, List<EventModel>>{};
    for (var event in _filteredMemories) {
      final year = _formatYear(event.createdAt);
      if (!eventsByYear.containsKey(year)) {
        eventsByYear[year] = [];
      }
      eventsByYear[year]!.add(event);
    }

    final sortedYears = eventsByYear.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header - Full Width
            _buildHeader(),

            // Body with Timeline and Memory Cards
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline Rail - Fixed Width
                  if (_filteredMemories.isNotEmpty && !_isLoading)
                    SizedBox(
                      width: 65,
                      child: _buildTimelineRail(sortedYears, eventsByYear),
                    ),

                  // Memory Cards - Expanded
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredMemories.isEmpty
                            ? _buildEmptyState()
                            : _buildMemoryCardsList(eventsByYear, sortedYears),
                  ),
                ],
              ),
            ),

            // Floating Action Button
            _buildFloatingActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.timelineInactive.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Memories',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  _buildIconButton(
                    icon: Icons.search,
                    onPressed: () => _showSearchModal(),
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    icon: Icons.filter_list,
                    onPressed: () => _showFilterModal(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your journey through Vesak events',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 20),
          if (_filteredMemories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatChip(
                    icon: Icons.photo_library,
                    label: '${_filteredMemories.length} Memories',
                  ),
                  const SizedBox(width: 12),
                  _buildStatChip(
                    icon: Icons.event,
                    label:
                        '${_filteredMemories.map((e) => e.id).toSet().length} Events',
                  ),
                  const SizedBox(width: 12),
                  _buildStatChip(
                    icon: Icons.calendar_today,
                    label:
                        '${_filteredMemories.map((e) => _formatYear(e.createdAt)).toSet().length} Years',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: AppTheme.primary,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildStatChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.timelineInactive.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCardsList(
      Map<String, List<EventModel>> eventsByYear, List<String> sortedYears) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final year = sortedYears[index];
                final events = eventsByYear[year]!;

                if (!_sectionKeys.containsKey(year)) {
                  _sectionKeys[year] = GlobalKey();
                }

                return _buildYearSection(year, events);
              },
              childCount: sortedYears.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }

  Widget _buildYearSection(String year, List<EventModel> events) {
    final bgColor = _getYearColor(year);

    return Container(
      key: _sectionKeys[year],
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primary, AppTheme.accent],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      year.substring(2, 4),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  year,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Events in this year
          ..._groupEventsByEvent(events)
              .map((eventGroup) => _buildEventSection(eventGroup)),
        ],
      ),
    );
  }

  List<List<EventModel>> _groupEventsByEvent(List<EventModel> events) {
    final Map<String, List<EventModel>> grouped = {};
    for (var event in events) {
      if (!grouped.containsKey(event.id)) {
        grouped[event.id] = [];
      }
      grouped[event.id]!.add(event);
    }
    return grouped.values.toList();
  }

  Widget _buildEventSection(List<EventModel> memories) {
    final event = memories.first;
    final startDate = _formatDate(memories.first.createdAt);
    final endDate =
        memories.length > 1 ? _formatDate(memories.last.createdAt) : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.timelineInactive.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            endDate != null
                                ? '$startDate — $endDate'
                                : startDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${memories.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Memory Cards
          ...memories.map((memory) => _buildMemoryCard(memory)),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(EventModel memory) {
    final categoryColor = AppConstants.getCategoryColor(memory.category);
    final icon = memory.getMarkerIcon();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailsScreen(event: memory),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: categoryColor.withOpacity(0.1),
                    child: memory.hasImage
                        ? Image.network(
                            memory.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  icon,
                                  style: const TextStyle(fontSize: 48),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              icon,
                              style: const TextStyle(fontSize: 48),
                            ),
                          ),
                  ),
                  // Image Counter
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            '1/1',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Category Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            icon,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            memory.getCategoryDisplayName(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.description ?? 'No description added yet.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(memory.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time,
                            size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          memory.time,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineRail(
      List<String> years, Map<String, List<EventModel>> eventsByYear) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          const SizedBox(height: 20),
          ...years.asMap().entries.map((entry) {
            final index = entry.key;
            final year = entry.value;
            final isActive = year == _activeYear;
            final yearEvents = eventsByYear[year] ?? [];
            final locations = yearEvents
                .map((e) => e.location.split(',').first)
                .toSet()
                .toList();
            final isLast = index == years.length - 1;

            return Column(
              children: [
                // Timeline Dot
                GestureDetector(
                  onTap: () => _scrollToYear(year),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isActive ? 36 : 28,
                    height: isActive ? 36 : 28,
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isActive ? null : AppTheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Center(
                      child: Text(
                        year.substring(2, 4),
                        style: TextStyle(
                          fontSize: isActive ? 13 : 11,
                          fontWeight: FontWeight.w700,
                          color:
                              isActive ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),

                if (!isLast)
                  Container(
                    width: 2,
                    height: 50,
                    color: isActive
                        ? AppTheme.primary.withOpacity(0.5)
                        : AppTheme.timelineInactive.withOpacity(0.5),
                  ),

                if (isActive && locations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        locations.first.length > 6
                            ? '${locations.first.substring(0, 6)}...'
                            : locations.first,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
              ],
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showSearchModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.timelineInactive,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Search Memories',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                    setModalState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by title or location...',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                                _applyFilters();
                              });
                              setModalState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppTheme.background,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFilterModal() {
    String? tempCategory = _selectedCategory;
    String? tempType = _selectedType;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.timelineInactive,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Filter Memories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Divider(color: AppTheme.timelineInactive, height: 24),
                  const Text(
                    'CATEGORY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: tempCategory == null,
                        onSelected: (_) {
                          setModalState(() {
                            tempCategory = null;
                          });
                        },
                        backgroundColor: AppTheme.background,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: tempCategory == null
                              ? Colors.white
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      ...AppConstants.eventCategories.map((category) {
                        return FilterChip(
                          label: Text(category),
                          selected: tempCategory == category,
                          onSelected: (_) {
                            setModalState(() {
                              tempCategory = category;
                            });
                          },
                          backgroundColor: AppTheme.background,
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: tempCategory == category
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'TYPE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: tempType == null,
                        onSelected: (_) {
                          setModalState(() {
                            tempType = null;
                          });
                        },
                        backgroundColor: AppTheme.background,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: tempType == null
                              ? Colors.white
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Created by me'),
                        selected: tempType == 'created',
                        onSelected: (_) {
                          setModalState(() {
                            tempType = 'created';
                          });
                        },
                        backgroundColor: AppTheme.background,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: tempType == 'created'
                              ? Colors.white
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      FilterChip(
                        label: const Text('Bookmarked'),
                        selected: tempType == 'bookmarked',
                        onSelected: (_) {
                          setModalState(() {
                            tempType = 'bookmarked';
                          });
                        },
                        backgroundColor: AppTheme.background,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: tempType == 'bookmarked'
                              ? Colors.white
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              tempCategory = null;
                              tempType = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = tempCategory;
                              _selectedType = tempType;
                              _applyFilters();
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No memories yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create events or bookmark them to see here',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Explore Events'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, AppTheme.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {},
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 24),
        ),
      ),
    );
  }
}
