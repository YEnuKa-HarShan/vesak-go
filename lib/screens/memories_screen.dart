import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vesak_go/constants.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';
import 'event_details_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Glass helpers
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

  late AnimationController _progressController;
  final TextEditingController _searchController = TextEditingController();

  // Premium year accent palette — no gradients, pure glass colours
  static const _yearAccent = {
    '2026': Color(0xFF6366F1), // indigo
    '2025': Color(0xFFF59E0B), // amber
    '2024': Color(0xFF10B981), // emerald
    '2023': Color(0xFFEC4899), // pink
    '2022': Color(0xFF8B5CF6), // violet
  };

  Color _accentFor(String year) => _yearAccent[year] ?? AppTheme.primary;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
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
    if (mounted) setState(() {});
  }

  void _updateActiveYear() {
    for (final entry in _sectionKeys.entries) {
      final rb = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (rb != null) {
        final dy = rb.localToGlobal(Offset.zero).dy;
        if (dy < 260 && dy > -120) {
          if (_activeYear != entry.key) {
            _activeYear = entry.key;
            _progressController.forward(from: 0.0);
          }
          break;
        }
      }
    }
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);
    final allEvents = await _supabaseService.getAllEvents();
    setState(() {
      if (_sessionService.isLoggedIn) {
        _myEvents = allEvents
            .where((e) => e.userId == _sessionService.currentUser?.id)
            .toList();
      } else {
        _myEvents = [];
      }
      _allMemories = List.from(_myEvents);
      _applyFilters();
      if (_filteredMemories.isNotEmpty) {
        _activeYear = _fmt4(
          _filteredMemories
              .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b)
              .createdAt,
        );
      }
      _isLoading = false;
    });
  }

  void _applyFilters() {
    List<EventModel> f = List.from(_allMemories);
    if (_searchQuery.isNotEmpty) {
      f = f
          .where((e) =>
              e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              e.location.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_selectedCategory != null) {
      f = f.where((e) => e.category == _selectedCategory).toList();
    }
    if (_selectedType == 'created') {
      f = f.where((e) => _myEvents.contains(e)).toList();
    } else if (_selectedType == 'bookmarked') {
      f = f.where((e) => _bookmarkedEvents.contains(e)).toList();
    }
    setState(() => _filteredMemories = f);
  }

  void _scrollToYear(String year) {
    final key = _sectionKeys[year];
    if (key?.currentContext != null) {
      setState(() => _activeYear = year);
      _progressController.forward(from: 0.0);
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  String _fmt4(DateTime d) => DateFormat('yyyy').format(d);
  String _fmtDate(DateTime d) => DateFormat('MMM dd, yyyy').format(d);
  String _fmtDateLong(DateTime d) => DateFormat('MMMM d, yyyy').format(d);

  // ─────────────────────────────────────────────
  // BUILD ROOT
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final eventsByYear = <String, List<EventModel>>{};
    for (final e in _filteredMemories) {
      eventsByYear.putIfAbsent(_fmt4(e.createdAt), () => []).add(e);
    }
    final sortedYears = eventsByYear.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: Stack(
        children: [
          // ── Ambient blobs ──
          _buildAmbientBlobs(),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_filteredMemories.isNotEmpty && !_isLoading)
                        SizedBox(
                          width: 76,
                          child: _buildTimelineRail(sortedYears, eventsByYear),
                        ),
                      Expanded(
                        child: _isLoading
                            ? _buildLoader()
                            : _filteredMemories.isEmpty
                                ? _buildEmptyState()
                                : _buildCardsList(eventsByYear, sortedYears),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── FAB ──
          Positioned(
            bottom: 28,
            right: 20,
            child: _buildFAB(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // AMBIENT BACKGROUND
  // ─────────────────────────────────────────────

  Widget _buildAmbientBlobs() {
    return Stack(
      children: [
        // Top-left blob
        Positioned(
          top: -60,
          left: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withOpacity(0.12),
            ),
          ),
        ),
        // Top-right blob
        Positioned(
          top: 80,
          right: -80,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withOpacity(0.10),
            ),
          ),
        ),
        // Bottom blob
        Positioned(
          bottom: -80,
          left: 60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withOpacity(0.08),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'All Memories',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(children: const [
                          Text(
                            'Your journey through Vesak events ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text('🌼', style: TextStyle(fontSize: 13)),
                        ]),
                      ],
                    ),
                  ),
                  _buildGlassIconButton(
                    icon: Icons.search_rounded,
                    onPressed: _showSearchModal,
                  ),
                  const SizedBox(width: 10),
                  _buildGlassIconButton(
                    icon: Icons.tune_rounded,
                    onPressed: _showFilterModal,
                  ),
                ],
              ),
              if (_filteredMemories.isNotEmpty) ...[
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatPill(
                        Icons.photo_library_outlined,
                        '${_filteredMemories.length} Memories',
                      ),
                      const SizedBox(width: 8),
                      _buildStatPill(
                        Icons.event_outlined,
                        '${_filteredMemories.map((e) => e.id).toSet().length} Events',
                      ),
                      const SizedBox(width: 8),
                      _buildStatPill(
                        Icons.calendar_today_outlined,
                        '${_filteredMemories.map((e) => _fmt4(e.createdAt)).toSet().length} Years',
                      ),
                    ],
                  ),
                ),
              ],
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

  Widget _buildStatPill(IconData icon, String label) {
    return _Glass(
      borderRadius: BorderRadius.circular(20),
      opacity: 0.55,
      tint: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TIMELINE RAIL
  // ─────────────────────────────────────────────

  Widget _buildTimelineRail(
      List<String> years, Map<String, List<EventModel>> eventsByYear) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),
          ...years.asMap().entries.map((entry) {
            final idx = entry.key;
            final year = entry.value;
            final isActive = year == _activeYear;
            final isLast = idx == years.length - 1;
            final accent = _accentFor(year);
            final events = eventsByYear[year] ?? [];
            final firstName = events.isNotEmpty
                ? events.first.title.split(' ').take(2).join('\n')
                : '';
            final firstDate = events.isNotEmpty
                ? DateFormat('MMM dd').format(events.first.createdAt)
                : '';

            return Column(
              children: [
                GestureDetector(
                  onTap: () => _scrollToYear(year),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        // Dot
                        _Glass(
                          borderRadius: BorderRadius.circular(50),
                          blur: 12,
                          opacity: isActive ? 0.25 : 0.10,
                          tint: isActive ? accent : Colors.white,
                          border: Border.all(
                            color: isActive
                                ? accent.withOpacity(0.8)
                                : Colors.white.withOpacity(0.4),
                            width: isActive ? 2 : 1,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            width: isActive ? 34 : 24,
                            height: isActive ? 34 : 24,
                            child: Center(
                              child: isActive
                                  ? Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Year text
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 280),
                          style: TextStyle(
                            fontSize: isActive ? 13 : 11,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w500,
                            color: isActive
                                ? accent
                                : AppTheme.textSecondary.withOpacity(0.6),
                          ),
                          child: Text(year),
                        ),

                        if (firstName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            firstName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppTheme.textPrimary.withOpacity(0.75)
                                  : AppTheme.textSecondary.withOpacity(0.4),
                              height: 1.3,
                            ),
                          ),
                        ],

                        if (firstDate.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            firstDate,
                            style: TextStyle(
                              fontSize: 8,
                              color: AppTheme.textSecondary
                                  .withOpacity(isActive ? 0.55 : 0.30),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Connector line
                if (!isLast)
                  Container(
                    width: 1.5,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isActive
                          ? accent.withOpacity(0.4)
                          : Colors.white.withOpacity(0.3),
                    ),
                  ),

                const SizedBox(height: 10),
              ],
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CARDS LIST
  // ─────────────────────────────────────────────

  Widget _buildCardsList(
      Map<String, List<EventModel>> eventsByYear, List<String> sortedYears) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 12, right: 14, bottom: 12),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final year = sortedYears[i];
                _sectionKeys.putIfAbsent(year, () => GlobalKey());
                return _buildYearSection(year, eventsByYear[year]!);
              },
              childCount: sortedYears.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // YEAR SECTION
  // ─────────────────────────────────────────────

  Widget _buildYearSection(String year, List<EventModel> events) {
    return Container(
      key: _sectionKeys[year],
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _groupEvents(events)
            .map((g) => _buildEventSection(g, year))
            .toList(),
      ),
    );
  }

  List<List<EventModel>> _groupEvents(List<EventModel> events) {
    final m = <String, List<EventModel>>{};
    for (final e in events) {
      m.putIfAbsent(e.id, () => []).add(e);
    }
    return m.values.toList();
  }

  // ─────────────────────────────────────────────
  // EVENT SECTION
  // ─────────────────────────────────────────────

  Widget _buildEventSection(List<EventModel> memories, String year) {
    final event = memories.first;
    final accent = _accentFor(year);
    final dateStr = _fmtDateLong(event.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.62),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.7),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Event Header ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(21)),
                    border: Border(
                      bottom: BorderSide(
                        color: accent.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Accent dot
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 10, top: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.location_on_outlined,
                                  size: 12,
                                  color:
                                      AppTheme.textSecondary.withOpacity(0.7)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  event.location,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppTheme.textSecondary.withOpacity(0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Date pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: accent.withOpacity(0.25), width: 1),
                        ),
                        child: Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Memory cards ──
                ...memories.map((m) => _buildMemoryCard(m, accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MEMORY CARD
  // ─────────────────────────────────────────────

  Widget _buildMemoryCard(EventModel memory, Color accent) {
    final icon = memory.getMarkerIcon();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailsScreen(event: memory)),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.70),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.80), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: memory.hasImage
                  ? _buildNetworkImage(memory.imageUrl, icon)
                  : _buildPlaceholderImage(icon, accent),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.description ?? 'No description added yet.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 12,
                          color: AppTheme.textSecondary.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        _fmtDate(memory.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(Icons.access_time_outlined,
                          size: 12,
                          color: AppTheme.textSecondary.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        memory.time,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary.withOpacity(0.7),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showMemoryOptions(memory),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          size: 20,
                          color: AppTheme.textSecondary.withOpacity(0.5),
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
    );
  }

  Widget _buildNetworkImage(String url, String icon) {
    return Stack(
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _buildPlaceholderImage(icon, AppTheme.primary),
          ),
        ),
        // Counter badge
        Positioned(
          bottom: 10,
          right: 10,
          child: _Glass(
            borderRadius: BorderRadius.circular(12),
            blur: 8,
            opacity: 0.6,
            tint: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: const Text(
              '1/1',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage(String icon, Color accent) {
    return Container(
      height: 140,
      width: double.infinity,
      color: accent.withOpacity(0.06),
      child: Center(
        child: Text(icon, style: const TextStyle(fontSize: 54)),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // LOADER
  // ─────────────────────────────────────────────

  Widget _buildLoader() {
    return Center(
      child: _Glass(
        borderRadius: BorderRadius.circular(20),
        opacity: 0.55,
        tint: Colors.white,
        padding: const EdgeInsets.all(28),
        child: CircularProgressIndicator(
          color: AppTheme.primary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Glass(
              borderRadius: BorderRadius.circular(60),
              opacity: 0.55,
              tint: Colors.white,
              padding: const EdgeInsets.all(30),
              child: Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: AppTheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'No memories yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create events or bookmark them to see here',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _Glass(
              borderRadius: BorderRadius.circular(30),
              opacity: 0.90,
              tint: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3), width: 1),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Explore Events',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FAB
  // ─────────────────────────────────────────────

  Widget _buildFAB() {
    return _Glass(
      borderRadius: BorderRadius.circular(50),
      blur: 20,
      opacity: 0.85,
      tint: AppTheme.primary,
      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      child: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          onPressed: () {},
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MEMORY OPTIONS SHEET
  // ─────────────────────────────────────────────

  void _showMemoryOptions(EventModel memory) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSheetHandle(),
                const SizedBox(height: 20),
                _buildOptionTile(
                  icon: Icons.edit_outlined,
                  label: 'Edit Memory',
                  onTap: () => Navigator.pop(context),
                ),
                _buildOptionTile(
                  icon: Icons.share_outlined,
                  label: 'Share Memory',
                  onTap: () => Navigator.pop(context),
                ),
                _buildOptionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete Memory',
                  color: AppTheme.error,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppTheme.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 21),
      title: Text(
        label,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // ─────────────────────────────────────────────
  // SEARCH MODAL
  // ─────────────────────────────────────────────

  void _showSearchModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.78),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSheetHandle(),
                  const SizedBox(height: 20),
                  const Text(
                    'Search Memories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (v) {
                      setState(() {
                        _searchQuery = v;
                        _applyFilters();
                      });
                      setM(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by title or location...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppTheme.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                  _applyFilters();
                                });
                                setM(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppTheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                        child: _glassOutlineButton(
                            'Cancel', () => Navigator.pop(ctx))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _glassPrimaryButton(
                            'Done', () => Navigator.pop(ctx))),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FILTER MODAL
  // ─────────────────────────────────────────────

  void _showFilterModal() {
    String? tempCategory = _selectedCategory;
    String? tempType = _selectedType;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.78),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSheetHandle(),
                    const SizedBox(height: 20),
                    const Text(
                      'Filter Memories',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Divider(height: 28, color: Colors.grey.withOpacity(0.2)),
                    _sectionLabel('CATEGORY'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _glassChip(
                          'All',
                          tempCategory == null,
                          () => setM(() => tempCategory = null),
                        ),
                        ...AppConstants.eventCategories.map((cat) => _glassChip(
                              cat,
                              tempCategory == cat,
                              () => setM(() => tempCategory = cat),
                            )),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('TYPE'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _glassChip('All', tempType == null,
                            () => setM(() => tempType = null)),
                        _glassChip('Created by me', tempType == 'created',
                            () => setM(() => tempType = 'created')),
                        _glassChip('Bookmarked', tempType == 'bookmarked',
                            () => setM(() => tempType = 'bookmarked')),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(children: [
                      Expanded(
                          child: _glassOutlineButton('Reset', () {
                        setM(() {
                          tempCategory = null;
                          tempType = null;
                        });
                      })),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _glassPrimaryButton('Apply', () {
                        setState(() {
                          _selectedCategory = tempCategory;
                          _selectedType = tempType;
                          _applyFilters();
                        });
                        Navigator.pop(ctx);
                      })),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SHARED UI HELPERS
  // ─────────────────────────────────────────────

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: AppTheme.textSecondary.withOpacity(0.6),
      ),
    );
  }

  Widget _glassChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withOpacity(0.12)
              : Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withOpacity(0.5)
                : Colors.grey.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.primary : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _glassOutlineButton(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassPrimaryButton(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
