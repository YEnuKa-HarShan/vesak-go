import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';
import '../constants.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import 'login_screen.dart';
import 'create_event_screen.dart';
import 'events_screen.dart';
import 'profile_screen.dart';
import 'map_screen.dart';
import 'memories_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Glass helper (same as MemoriesScreen)
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final SessionService _sessionService = SessionService();

  bool _isLoading = true;
  int _eventsCount = 0;
  int _storiesCount = 0;
  List<EventModel> _upcomingEvents = [];

  final PageController _carouselController =
      PageController(viewportFraction: 0.92);
  int _currentCarouselPage = 0;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _sessionService.addListener(_onSessionChanged);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadData();
    _startCarouselTimer();
  }

  @override
  void dispose() {
    _sessionService.removeListener(_onSessionChanged);
    _carouselController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    setState(() {});
    _loadData();
  }

  void _startCarouselTimer() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _upcomingEvents.length > 1) {
        if (_currentCarouselPage < _upcomingEvents.length - 1) {
          _carouselController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          _carouselController.animateToPage(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
        _startCarouselTimer();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final eventsCount = await _supabaseService.getEventsCount();
    final storiesCount = await _supabaseService.getStoriesCount();
    final allEvents = await _supabaseService.getAllEvents();

    final now = DateTime.now();
    final upcoming = allEvents
        .where((event) {
          try {
            final eventDate = DateTime.parse(event.date);
            return eventDate.isAfter(now.subtract(const Duration(days: 1)));
          } catch (e) {
            return false;
          }
        })
        .take(5)
        .toList();

    setState(() {
      _eventsCount = eventsCount;
      _storiesCount = storiesCount;
      _upcomingEvents = upcoming;
      _isLoading = false;
    });

    _fadeController.forward(from: 0.0);
  }

  Future<void> _handleCreateEvent() async {
    if (_sessionService.canCreateEvent()) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateEventScreen(
            userId: _sessionService.currentUser!.id,
            userFirstName: _sessionService.currentUser!.firstName,
          ),
        ),
      );
      if (result == true) _loadData();
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  double _getXpProgress() {
    if (!_sessionService.isLoggedIn) return 0;
    final user = _sessionService.currentUser!;
    final currentXp = user.totalXp;
    final currentLevel = user.currentLevel;
    final nextLevelXp = AppConstants.getRequiredXpForLevel(currentLevel + 1);
    final currentLevelXp = AppConstants.getRequiredXpForLevel(currentLevel);
    final xpForNextLevel = nextLevelXp - currentLevelXp;
    final xpInCurrentLevel = currentXp - currentLevelXp;
    if (xpForNextLevel <= 0) return 0;
    return xpInCurrentLevel / xpForNextLevel;
  }

  // ─────────────────────────────────────────────
  // BUILD ROOT
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Ambient blobs ──
          _buildAmbientBlobs(),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppTheme.accent,
                    child: FadeTransition(
                      opacity: _fadeController,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildQuickStatsSection(),
                            const SizedBox(height: 20),
                            if (_sessionService.isLoggedIn) ...[
                              _buildXpProgressCard(),
                              const SizedBox(height: 20),
                            ],
                            _buildQuickActionsSection(),
                            const SizedBox(height: 20),
                            if (_upcomingEvents.isNotEmpty) ...[
                              _buildSectionHeader(
                                'Featured Events',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const EventsScreen()),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildFeaturedEventsCarousel(),
                              const SizedBox(height: 20),
                            ],
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: _buildQuoteCard(),
                            ),
                            if (_upcomingEvents.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _buildSectionHeader(
                                'Upcoming Events',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const EventsScreen()),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildUpcomingEventsList(),
                            ],
                          ],
                        ),
                      ),
                    ),
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
              color: const Color(0xFF10B981).withOpacity(0.08),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // HEADER  (glass — replaces gradient banner)
  // ─────────────────────────────────────────────

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
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
                  // ── Avatar ──
                  _Glass(
                    borderRadius: BorderRadius.circular(50),
                    blur: 12,
                    opacity: 0.55,
                    tint: Colors.white,
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.25), width: 1.5),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Text(
                          _sessionService.isLoggedIn
                              ? '${_sessionService.currentUser!.firstName[0]}${_sessionService.currentUser!.lastName[0]}'
                              : 'G',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // ── Greeting ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()},',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _sessionService.isLoggedIn
                              ? _sessionService.currentUser!.firstName
                              : 'Guest User',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Notification icon ──
                  _buildGlassIconButton(
                    icon: Icons.notifications_none_rounded,
                    onPressed: () {},
                  ),
                ],
              ),

              // ── League pill (logged in only) ──
              if (_sessionService.isLoggedIn) ...[
                const SizedBox(height: 14),
                _Glass(
                  borderRadius: BorderRadius.circular(20),
                  opacity: 0.55,
                  tint: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppConstants.getLeagueIcon(
                            _sessionService.currentUser!.currentLevel),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppConstants.getLeagueByLevel(
                            _sessionService.currentUser!.currentLevel),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Level ${_sessionService.currentUser!.currentLevel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary.withOpacity(0.8),
                        ),
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

  // ─────────────────────────────────────────────
  // QUICK STATS
  // ─────────────────────────────────────────────

  Widget _buildQuickStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _isLoading
          ? Center(
              child: _Glass(
                borderRadius: BorderRadius.circular(20),
                opacity: 0.55,
                tint: Colors.white,
                padding: const EdgeInsets.all(20),
                child: const CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2.5,
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EventsScreen()),
                    ),
                    child: _buildStatCard(
                      icon: Icons.event_rounded,
                      iconColor: AppTheme.primary,
                      count: _eventsCount.toString(),
                      label: 'Events',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.auto_stories_rounded,
                    iconColor: AppTheme.accent,
                    count: _storiesCount.toString(),
                    label: 'Stories',
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String count,
    required String label,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.white.withOpacity(0.70), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withOpacity(0.8),
                      ),
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

  // ─────────────────────────────────────────────
  // XP PROGRESS CARD
  // ─────────────────────────────────────────────

  Widget _buildXpProgressCard() {
    final user = _sessionService.currentUser!;
    final progress = _getXpProgress();
    final currentLevel = user.currentLevel;
    final nextLevelXp = AppConstants.getRequiredXpForLevel(currentLevel + 1);
    final currentXp = user.totalXp;
    final xpNeeded = nextLevelXp - currentXp;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.62),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: AppTheme.accent.withOpacity(0.30), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: AppTheme.accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Your Progress',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _Glass(
                      borderRadius: BorderRadius.circular(20),
                      opacity: 0.55,
                      tint: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Text(
                        '$currentXp / $nextLevelXp XP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.timelineInactive,
                    color: AppTheme.accent,
                    minHeight: 7,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${(progress * 100).toInt()}% to Level ${currentLevel + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary.withOpacity(0.7),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$xpNeeded XP needed',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.grey.withOpacity(0.18), height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildDailyTaskItem(
                        'Create Event', '+50 XP', Icons.add_circle_outline),
                    const SizedBox(width: 16),
                    _buildDailyTaskItem(
                        'Login Today', '+5 XP', Icons.login_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTaskItem(String title, String reward, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          _Glass(
            borderRadius: BorderRadius.circular(10),
            opacity: 0.55,
            tint: Colors.white,
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 14, color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  reward,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary.withOpacity(0.7),
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
  // QUICK ACTIONS GRID
  // ─────────────────────────────────────────────

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              _buildActionGridItem(
                title: 'Create',
                icon: Icons.add_circle_outline_rounded,
                onTap: _handleCreateEvent,
                accent: AppTheme.primary,
              ),
              _buildActionGridItem(
                title: 'Events',
                icon: Icons.event_note_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventsScreen()),
                ),
                accent: AppTheme.primary,
              ),
              _buildActionGridItem(
                title: 'Map',
                icon: Icons.map_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapScreen()),
                ),
                accent: AppTheme.primary,
              ),
              _buildActionGridItem(
                title: 'Memories',
                icon: Icons.photo_library_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MemoriesScreen()),
                ),
                accent: AppTheme.accent,
              ),
              _buildActionGridItem(
                title: 'Profile',
                icon: Icons.person_outline_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                accent: AppTheme.primary,
              ),
              _buildActionGridItem(
                title: 'Bookmarks',
                icon: Icons.bookmark_outline_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EventsScreen(initialTab: 2)),
                ),
                accent: AppTheme.accent,
              ),
              if (!_sessionService.isLoggedIn)
                _buildActionGridItem(
                  title: 'Login',
                  icon: Icons.login_rounded,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  accent: AppTheme.error,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionGridItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Color accent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.60),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withOpacity(0.70), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: accent),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SECTION HEADER
  // ─────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: _Glass(
              borderRadius: BorderRadius.circular(20),
              opacity: 0.55,
              tint: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FEATURED EVENTS CAROUSEL
  // ─────────────────────────────────────────────

  Widget _buildFeaturedEventsCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _carouselController,
            onPageChanged: (index) {
              setState(() => _currentCarouselPage = index);
            },
            itemCount: _upcomingEvents.length,
            itemBuilder: (context, index) {
              final event = _upcomingEvents[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: EventCard(
                  event: event,
                  height: 220,
                  onTap: () => _showEventDetails(event),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dot indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_upcomingEvents.length, (i) {
            final active = i == _currentCarouselPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primary
                    : AppTheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // QUOTE CARD
  // ─────────────────────────────────────────────

  Widget _buildQuoteCard() {
    final quotes = [
      '"Happiness never decreases by being shared." — Buddha',
      '"Peace comes from within. Do not seek it without." — Buddha',
      '"The mind is everything. What you think you become." — Buddha',
      '"Thousands of candles can be lit from a single candle." — Buddha',
      '"Better than a thousand hollow words is one word that brings peace." — Buddha',
    ];
    final quote = quotes[DateTime.now().day % quotes.length];

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: AppTheme.accent.withOpacity(0.25), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.format_quote_rounded,
                    size: 18, color: AppTheme.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  quote,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontStyle: FontStyle.italic,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UPCOMING EVENTS LIST
  // ─────────────────────────────────────────────

  Widget _buildUpcomingEventsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _upcomingEvents.length > 3 ? 3 : _upcomingEvents.length,
        itemBuilder: (context, index) {
          final event = _upcomingEvents[index];
          final categoryColor = AppConstants.getCategoryColor(event.category);
          final icon = event.getMarkerIcon();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.62),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.70), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: categoryColor.withOpacity(0.07),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child:
                              Text(icon, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 11,
                                    color: AppTheme.textSecondary
                                        .withOpacity(0.7)),
                                const SizedBox(width: 3),
                                Text(
                                  '${event.date} · ${event.time}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        AppTheme.textSecondary.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showEventDetails(event),
                        child: _Glass(
                          borderRadius: BorderRadius.circular(20),
                          opacity: 0.90,
                          tint: AppTheme.primary,
                          border: Border.all(
                              color: AppTheme.primary.withOpacity(0.3),
                              width: 1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: const Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // EVENT DETAILS BOTTOM SHEET
  // ─────────────────────────────────────────────

  void _showEventDetails(EventModel event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ClipRRect(
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
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(event.getMarkerIcon(),
                        style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppConstants.getCategoryColor(event.category)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    event.getCategoryDisplayName(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.getCategoryColor(event.category),
                    ),
                  ),
                ),
                if (event.category == 'දන්සල' && event.foodType != 'none')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Text('Food: ${event.foodType}',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
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
                    child: _buildDetailRow(
                        Icons.description, event.description!,
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
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
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
        Icon(icon, size: 16, color: AppTheme.textSecondary.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary.withOpacity(0.85),
            ),
            maxLines: isMultiline ? 3 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
