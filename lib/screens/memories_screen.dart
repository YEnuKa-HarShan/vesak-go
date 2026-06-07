import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vesak_go/constants.dart';
import '../services/memory_service.dart';
import '../services/session_service.dart';
import '../models/memory_model.dart';
import '../models/event_model.dart';
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

  Map<String, List<MemoryWithEvent>> _memories = {};
  bool _isLoading = true;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _loadMemories();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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
        body: Center(
            child: _GlassCard(
                child: const CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2.5))),
      );
    }

    if (_memories.isEmpty) {
      return _buildEmptyState();
    }

    final sortedYears = _memories.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _buildAmbientBlobs(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadMemories,
                    color: AppTheme.accent,
                    child: FadeTransition(
                      opacity: _fadeController,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: sortedYears.length,
                        itemBuilder: (context, index) {
                          final year = sortedYears[index];
                          final memories = _memories[year]!;
                          return _buildYearSection(year, memories);
                        },
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
                    color: AppTheme.primary.withOpacity(0.12)))),
        Positioned(
            top: 100,
            right: -80,
            child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withOpacity(0.10)))),
        Positioned(
            bottom: -80,
            left: 60,
            child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.blobEmerald.withOpacity(0.08)))),
      ],
    );
  }

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
                      color: Colors.white.withOpacity(0.35), width: 1))),
          child: Row(
            children: [
              _GlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('My Memories',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.6)),
                    Text('${_memories.values.expand((i) => i).length} memories',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary.withOpacity(0.8)))
                  ])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYearSection(String year, List<MemoryWithEvent> memories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: AppTheme.primary, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(year,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5)),
              const SizedBox(width: 8),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('${memories.length}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary))),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: memories.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildMemoryCard(memories[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildMemoryCard(MemoryWithEvent data) {
    final memory = data.memory;
    final event = data.event;
    final dateFormat = DateFormat('MMM d, yyyy');
    final catColor = AppConstants.getCategoryColor(event.category);

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  MemoryDetailsScreen(memory: memory, event: event))),
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
                    color: Colors.white.withOpacity(0.70), width: 1.2)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: memory.hasImages
                      ? Image.network(memory.imageUrls.first,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(
                              event.getMarkerIcon(), catColor))
                      : _buildPlaceholder(event.getMarkerIcon(), catColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                          '${dateFormat.format(memory.visitedAt)} · ${event.time}',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary.withOpacity(0.7))),
                      const SizedBox(height: 6),
                      Text(
                          memory.experienceNote.length > 80
                              ? '${memory.experienceNote.substring(0, 80)}...'
                              : memory.experienceNote,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(children: [
                        if (memory.hasImages)
                          Row(children: [
                            Icon(Icons.photo_library_rounded,
                                size: 14, color: AppTheme.primary),
                            Text(' ${memory.imageUrls.length}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary))
                          ]),
                        const SizedBox(width: 8),
                        if (memory.hasVideo)
                          Row(children: [
                            Icon(Icons.videocam_rounded,
                                size: 14, color: AppTheme.accent),
                            Text(' 1',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary))
                          ])
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String icon, Color color) {
    return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14)),
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 28))));
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _GlassCard(
              child: Icon(Icons.memory_rounded,
                  size: 48, color: AppTheme.primary.withOpacity(0.5))),
          const SizedBox(height: 20),
          const Text('No Memories Yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Add memories to events you\'ve visited',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Explore Events')),
        ]),
      ),
    );
  }

  Widget _buildAuthPrompt() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _GlassCard(
              child: Icon(Icons.lock_outline_rounded,
                  size: 48, color: AppTheme.primary.withOpacity(0.5))),
          const SizedBox(height: 20),
          const Text('Login to View Memories',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Sign in to see your event memories',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/login');
                _loadMemories();
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Login Now')),
        ]),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.62),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.70), width: 1.2)),
              child: child)),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _GlassIconButton({required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.35), width: 1)),
              child: IconButton(
                  icon: Icon(icon, size: 20),
                  color: AppTheme.primary,
                  onPressed: onPressed,
                  padding: EdgeInsets.zero))),
    );
  }
}
