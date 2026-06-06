import 'package:flutter/material.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final SessionService _sessionService = SessionService();

  bool _isLoading = true;
  int _eventsCount = 0;
  int _storiesCount = 0;
  List<EventModel> _upcomingEvents = [];

  final PageController _carouselController = PageController();
  int _currentCarouselPage = 0;

  @override
  void initState() {
    super.initState();
    _sessionService.addListener(_onSessionChanged);
    _loadData();
    _startCarouselTimer();
  }

  @override
  void dispose() {
    _sessionService.removeListener(_onSessionChanged);
    _carouselController.dispose();
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
    setState(() {
      _isLoading = true;
    });

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
      if (result == true) {
        _loadData();
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildQuickStats(),
                ),
                const SizedBox(height: 24),
                if (_sessionService.isLoggedIn) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildXpProgressCard(),
                  ),
                  const SizedBox(height: 24),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildQuickActionsGrid(),
                ),
                const SizedBox(height: 24),
                if (_upcomingEvents.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildFeaturedEventsHeader(),
                  ),
                  const SizedBox(height: 12),
                  _buildFeaturedEventsCarousel(),
                  const SizedBox(height: 24),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildQuoteCard(),
                ),
                const SizedBox(height: 24),
                if (_upcomingEvents.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildUpcomingEventsHeader(),
                  ),
                  const SizedBox(height: 12),
                  _buildUpcomingEventsList(),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.accent],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar with XP ring
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _sessionService.isLoggedIn
                        ? const LinearGradient(
                            colors: [AppTheme.accent, AppTheme.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _sessionService.isLoggedIn
                              ? '${_sessionService.currentUser!.firstName[0]}${_sessionService.currentUser!.lastName[0]}'
                              : 'G',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getGreeting()},',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sessionService.isLoggedIn
                            ? _sessionService.currentUser!.firstName
                            : 'Guest User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification Bell
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_sessionService.isLoggedIn)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
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
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Level ${_sessionService.currentUser!.currentLevel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EventsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _eventsCount.toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Events',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_stories,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _storiesCount.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Stories',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildXpProgressCard() {
    final user = _sessionService.currentUser!;
    final progress = _getXpProgress();
    final currentLevel = user.currentLevel;
    final nextLevelXp = AppConstants.getRequiredXpForLevel(currentLevel + 1);
    final currentXp = user.totalXp;
    final xpNeeded = nextLevelXp - currentXp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accent.withOpacity(0.15),
            AppTheme.primary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accent.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
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
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$currentXp / $nextLevelXp XP',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.timelineInactive,
              color: AppTheme.accent,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${(progress * 100).toInt()}% to Level ${currentLevel + 1}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${xpNeeded} XP needed',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppTheme.timelineInactive, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDailyTaskItem(
                  'Create Event', '+50 XP', Icons.add_circle_outline),
              const SizedBox(width: 16),
              _buildDailyTaskItem('Login Today', '+5 XP', Icons.login),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskItem(String title, String reward, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
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
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  reward,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Column(
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
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildActionGridItem(
              title: 'Create',
              icon: Icons.add_circle_outline,
              onTap: _handleCreateEvent,
              color: AppTheme.primary.withOpacity(0.1),
            ),
            _buildActionGridItem(
              title: 'Events',
              icon: Icons.event_note,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EventsScreen()),
                );
              },
              color: AppTheme.primary.withOpacity(0.1),
            ),
            _buildActionGridItem(
              title: 'Map',
              icon: Icons.map,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              },
              color: AppTheme.primary.withOpacity(0.1),
            ),
            _buildActionGridItem(
              title: 'Memories',
              icon: Icons.memory,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MemoriesScreen()),
                );
              },
              color: AppTheme.accent.withOpacity(0.1),
            ),
            _buildActionGridItem(
              title: 'Profile',
              icon: Icons.person_outline,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen()),
                );
              },
              color: AppTheme.primary.withOpacity(0.1),
            ),
            _buildActionGridItem(
              title: 'Bookmarks',
              icon: Icons.bookmark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EventsScreen(initialTab: 2)),
                );
              },
              color: AppTheme.accent.withOpacity(0.1),
            ),
            if (!_sessionService.isLoggedIn)
              _buildActionGridItem(
                title: 'Login',
                icon: Icons.login,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                },
                color: AppTheme.error.withOpacity(0.1),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionGridItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(icon, size: 24, color: AppTheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedEventsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Featured Events',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EventsScreen()),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primary,
          ),
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _buildFeaturedEventsCarousel() {
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _carouselController,
        onPageChanged: (index) {
          setState(() {
            _currentCarouselPage = index;
          });
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
    );
  }

  Widget _buildQuoteCard() {
    final quotes = [
      '“Happiness never decreases by being shared.” - Buddha',
      '“Peace comes from within. Do not seek it without.” - Buddha',
      '“The mind is everything. What you think you become.” - Buddha',
      '“Thousands of candles can be lit from a single candle.” - Buddha',
      '“Better than a thousand hollow words is one word that brings peace.” - Buddha',
    ];

    final randomIndex = DateTime.now().day % quotes.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.format_quote, size: 24, color: AppTheme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quotes[randomIndex],
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEventsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Upcoming Events',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EventsScreen()),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primary,
          ),
          child: const Text('View All'),
        ),
      ],
    );
  }

  Widget _buildUpcomingEventsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _upcomingEvents.length > 3 ? 3 : _upcomingEvents.length,
      itemBuilder: (context, index) {
        final event = _upcomingEvents[index];
        final categoryColor = AppConstants.getCategoryColor(event.category);
        final icon = event.getMarkerIcon();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 24),
                  ),
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
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.date} at ${event.time}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showEventDetails(event),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEventDetails(EventModel event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  style: const TextStyle(fontSize: 28),
                ),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.getCategoryColor(event.category)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                event.getCategoryDisplayName(),
                style: TextStyle(
                  fontSize: 12,
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
                    Text(
                      'Food: ${event.foodType}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
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
                child: _buildDetailRow(Icons.description, event.description!,
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
                ),
                child: const Text('Close'),
              ),
            ),
          ],
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
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            maxLines: isMultiline ? 3 : 1,
            overflow:
                isMultiline ? TextOverflow.ellipsis : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
