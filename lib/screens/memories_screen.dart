import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/memory_service.dart';
import '../services/session_service.dart';
import '../models/memory_model.dart';
import '../models/event_model.dart';
import '../widgets/memory_card.dart';
import '../widgets/glass_app_bar.dart';
import '../theme/app_theme.dart';
import 'memory_details_screen.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen>
    with SingleTickerProviderStateMixin {
  final MemoryService _memoryService = MemoryService();
  final SessionService _sessionService = SessionService();
  final ScrollController _scrollController = ScrollController();

  Map<String, List<MemoryWithEvent>> _memories = {};
  bool _isLoading = true;
  String _activeYear = '';
  final Map<String, GlobalKey> _sectionKeys = {};

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scrollController.addListener(_onScroll);
    _loadMemories();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onScroll() {
    for (final entry in _sectionKeys.entries) {
      final key = entry.value;
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero).dy;
        if (position < 200 && position > -100) {
          if (_activeYear != entry.key) {
            setState(() => _activeYear = entry.key);
          }
          break;
        }
      }
    }
  }

  void _scrollToYear(String year) {
    final key = _sectionKeys[year];
    if (key?.currentContext != null) {
      setState(() => _activeYear = year);
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);

    if (!_sessionService.isLoggedIn) {
      setState(() => _isLoading = false);
      _fadeController.forward();
      return;
    }

    final memories =
        await _memoryService.getUserMemories(_sessionService.currentUser!.id);

    setState(() {
      _memories = memories;
      _isLoading = false;
      if (memories.isNotEmpty) {
        _activeYear = memories.keys.toList().first;
      }
    });
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionService.isLoggedIn) {
      return _buildAuthPrompt();
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const Center(
            child: CircularProgressIndicator(color: AppTheme.memoryPrimary)),
      );
    }

    if (_memories.isEmpty) {
      return _buildEmptyState();
    }

    final sortedYears = _memories.keys.toList()..sort((a, b) => b.compareTo(a));
    final totalMemories = _memories.values.expand((i) => i).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          GlassAppBar(
            title: 'My Memories',
            subtitle:
                '$totalMemories ${totalMemories == 1 ? 'memory' : 'memories'}',
          ),
          Expanded(
            child: Row(
              children: [
                // Timeline Rail
                SizedBox(
                  width: 80,
                  child: _buildTimelineRail(sortedYears),
                ),
                // Memories List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadMemories,
                    color: AppTheme.memoryPrimary,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 8, bottom: 32),
                      itemCount: sortedYears.length,
                      itemBuilder: (context, index) {
                        final year = sortedYears[index];
                        final memories = _memories[year]!;
                        return _buildYearSection(year, memories);
                      },
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

  Widget _buildTimelineRail(List<String> years) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),
          ...years.asMap().entries.map((entry) {
            final idx = entry.key;
            final year = entry.value;
            final isActive = year == _activeYear;
            final isLast = idx == years.length - 1;
            final memoryCount = _memories[year]?.length ?? 0;

            return Column(
              children: [
                GestureDetector(
                  onTap: () => _scrollToYear(year),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Container(
                          width: isActive ? 40 : 32,
                          height: isActive ? 40 : 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive
                                  ? AppTheme.memoryPrimary
                                  : Colors.grey.withOpacity(0.4),
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: isActive ? 12 : 8,
                              height: isActive ? 12 : 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? AppTheme.memoryPrimary
                                    : Colors.grey.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          year,
                          style: TextStyle(
                            fontSize: isActive ? 13 : 11,
                            fontWeight:
                                isActive ? FontWeight.w800 : FontWeight.w500,
                            color: isActive
                                ? AppTheme.memoryPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        if (memoryCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '$memoryCount',
                              style: TextStyle(
                                fontSize: 9,
                                color: isActive
                                    ? AppTheme.memoryPrimary
                                    : AppTheme.textSecondary.withOpacity(0.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isActive
                        ? AppTheme.memoryPrimary.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.2),
                  ),
              ],
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildYearSection(String year, List<MemoryWithEvent> memories) {
    return Container(
      key: _sectionKeys.putIfAbsent(year, () => GlobalKey()),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.memoryPrimary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      year.substring(2),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.memoryPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      year,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${memories.length} ${memories.length == 1 ? 'memory' : 'memories'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...memories.map((data) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: MemoryCard(
                  memory: data.memory,
                  event: data.event,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MemoryDetailsScreen(
                            memory: data.memory, event: data.event)),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          GlassAppBar(title: 'My Memories'),
          Expanded(
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.62),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.memory_rounded,
                          size: 48,
                          color: AppTheme.memoryPrimary.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 20),
                    const Text('No Memories Yet',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Add memories to events you\'ve visited',
                        style: TextStyle(
                            fontSize: 14, color: AppTheme.textSecondary)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.memoryPrimary),
                      child: const Text('Explore Events'),
                    ),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPrompt() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          GlassAppBar(title: 'My Memories'),
          Expanded(
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.62),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_outline_rounded,
                          size: 48,
                          color: AppTheme.memoryPrimary.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 20),
                    const Text('Login to View Memories',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Sign in to see your event memories',
                        style: TextStyle(
                            fontSize: 14, color: AppTheme.textSecondary)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        await Navigator.pushNamed(context, '/login');
                        _loadMemories();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.memoryPrimary),
                      child: const Text('Login Now'),
                    ),
                  ]),
            ),
          ),
        ],
      ),
    );
  }
}
