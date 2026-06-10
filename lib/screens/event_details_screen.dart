import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/event_model.dart';
import '../models/memory_model.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/memory_service.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import 'create_memory_screen.dart';
import 'create_event_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen>
    with SingleTickerProviderStateMixin {
  final SessionService _sessionService = SessionService();
  final MemoryService _memoryService = MemoryService();

  bool _isBookmarked = false;
  bool _isLoading = false;
  bool _hasMemory = false;
  bool _hasVisited = false;
  bool _isMarkingVisited = false;
  int _totalVisits = 0;
  int _totalMemories = 0;
  int _totalBookmarks = 0;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _checkStatus();
    _checkMemory();
    _checkVisited();
    _loadStats();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    // Stats will be implemented when backend adds this endpoint
    setState(() {
      _totalVisits = 0;
      _totalMemories = 0;
      _totalBookmarks = 0;
    });
  }

  Future<void> _checkVisited() async {
    if (!_sessionService.isLoggedIn) return;
    // Will be implemented when backend adds visited check endpoint
    setState(() => _hasVisited = false);
  }

  Future<void> _checkStatus() async {
    if (!_sessionService.isLoggedIn) return;

    final bookmarked = await ApiService.isBookmarked(widget.event.id);

    setState(() => _isBookmarked = bookmarked);
    _fadeController.forward(from: 0.0);
  }

  Future<void> _checkMemory() async {
    if (!_sessionService.isLoggedIn) return;

    final hasMemory = await _memoryService.hasMemory(
      widget.event.id,
      _sessionService.currentUser!.id,
    );

    setState(() => _hasMemory = hasMemory);
  }

  Future<void> _toggleBookmark() async {
    if (!_sessionService.isLoggedIn) {
      _showLoginRequired();
      return;
    }

    setState(() => _isLoading = true);

    if (_isBookmarked) {
      final success = await ApiService.removeBookmark(widget.event.id);
      if (success) {
        setState(() {
          _isBookmarked = false;
          if (_totalBookmarks > 0) _totalBookmarks--;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            _buildSnackBar('Removed from bookmarks', Icons.bookmark_remove),
          );
        }
      }
    } else {
      final success = await ApiService.addBookmark(widget.event.id);
      if (success) {
        setState(() {
          _isBookmarked = true;
          _totalBookmarks++;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            _buildSnackBar('Added to bookmarks', Icons.bookmark_added),
          );
        }
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _markAsVisited() async {
    if (!_sessionService.isLoggedIn) {
      _showLoginRequired();
      return;
    }
    if (_hasVisited) return;

    setState(() => _isMarkingVisited = true);

    // Will be implemented when backend adds visited endpoint
    setState(() {
      _hasVisited = true;
      _totalVisits++;
      _isMarkingVisited = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marked as visited! ✓')),
    );
  }

  Future<void> _handleMemoryAction() async {
    if (!_sessionService.isLoggedIn) {
      _showLoginRequired();
      return;
    }

    if (_hasMemory) {
      final memory = await _memoryService.getMemoryByEvent(
        widget.event.id,
        _sessionService.currentUser!.id,
      );
      if (memory != null && mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateMemoryScreen(
              event: widget.event,
              isEditing: true,
              existingMemoryId: memory.id,
              existingNote: memory.experienceNote,
              existingImageUrls: memory.imageUrls,
              existingImagePublicIds: memory.imagePublicIds,
              existingVideoUrl: memory.videoUrl,
              existingVideoPublicId: memory.videoPublicId,
            ),
          ),
        );
        if (result == true) {
          await _checkMemory();
          await _checkVisited();
          await _loadStats();
        }
      }
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateMemoryScreen(event: widget.event),
        ),
      );
      if (result == true) {
        await _checkMemory();
        await _checkVisited();
        await _loadStats();
      }
    }
  }

  void _shareEvent() {
    Share.share(
      '🎉 ${widget.event.title}\n\n'
      '📅 Date: ${widget.event.date}\n'
      '⏰ Time: ${widget.event.time}\n'
      '📍 Location: ${widget.event.location}\n'
      '📂 Category: ${widget.event.category}\n\n'
      'Check out this event on VesakGO!',
      subject: 'VesakGO Event: ${widget.event.title}',
    );
  }

  void _openInMaps() async {
    final lat = widget.event.latitude;
    final lng = widget.event.longitude;
    final title = Uri.encodeComponent(widget.event.title);

    final googleMapsAppUrl =
        'comgooglemaps://?center=$lat,$lng&zoom=15&q=$lat,$lng($title)';
    final googleMapsWebUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$title';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsAppUrl))) {
        await launchUrl(Uri.parse(googleMapsAppUrl));
      } else {
        await launchUrl(Uri.parse(googleMapsWebUrl));
      }
    } catch (e) {
      await launchUrl(Uri.parse(googleMapsWebUrl));
    }
  }

  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar('Please login to use this feature', Icons.lock_outline),
    );
  }

  SnackBar _buildSnackBar(String message, IconData icon) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(message),
        ],
      ),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  bool _isEventActive() {
    try {
      final eventDate = DateTime.parse(widget.event.date);
      final now = DateTime.now();
      if (eventDate.year == now.year &&
          eventDate.month == now.month &&
          eventDate.day == now.day) {
        final timeStr = widget.event.time.toLowerCase();
        final isPM = timeStr.contains('pm');
        final parts =
            timeStr.replaceAll(RegExp(r'[apm]'), '').trim().split(':');
        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        final eventDateTime = DateTime(
            eventDate.year, eventDate.month, eventDate.day, hour, minute);
        return eventDateTime.isAfter(DateTime.now());
      }
    } catch (_) {}
    return false;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  bool get _isOwner =>
      _sessionService.isLoggedIn &&
      widget.event.userId == _sessionService.currentUser?.id;

  Future<void> _editEvent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateEventScreen(
          userId: _sessionService.currentUser!.id,
          userFirstName: _sessionService.currentUser!.firstName,
          editEvent: widget.event,
        ),
      ),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ApiService.deleteEvent(widget.event.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppConstants.getCategoryColor(widget.event.category);
    final icon = widget.event.getMarkerIcon();
    final isActive = _isEventActive();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _buildAmbientBlobs(categoryColor),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeroSection(categoryColor, icon, isActive),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleSection(categoryColor),
                        const SizedBox(height: 20),
                        _buildDateTimeCard(),
                        const SizedBox(height: 16),
                        _buildStatsCard(),
                        const SizedBox(height: 16),
                        _buildLocationCard(),
                        const SizedBox(height: 16),
                        if (widget.event.description != null &&
                            widget.event.description!.isNotEmpty)
                          _buildDescriptionCard(),
                        const SizedBox(height: 16),
                        _buildCreatorCard(),
                        const SizedBox(height: 24),
                        if (!_isOwner) _buildMarkAsVisitedButton(),
                        if (!_isOwner) const SizedBox(height: 8),
                        if (!_isOwner) _buildMemoryActionButton(),
                        if (_isOwner) const SizedBox(height: 8),
                        if (_isOwner) _buildOwnerActions(),
                        const SizedBox(height: 12),
                        _buildCloseButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SafeArea(child: _buildFloatingAppBar()),
        ],
      ),
    );
  }

  Widget _buildAmbientBlobs(Color categoryColor) {
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
              color: categoryColor.withOpacity(0.10),
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

  Widget _buildHeroSection(Color categoryColor, String icon, bool isActive) {
    return Stack(
      children: [
        SizedBox(
          height: 300,
          width: double.infinity,
          child: widget.event.hasImage
              ? CachedNetworkImage(
                  imageUrl: widget.event.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      _buildHeroGradient(categoryColor, icon),
                  errorWidget: (_, __, ___) =>
                      _buildHeroGradient(categoryColor, icon),
                )
              : _buildHeroGradient(categoryColor, icon),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                ],
                stops: const [0.5, 0.8, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  widget.event.getCategoryDisplayName(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.event.category == 'දන්සල' && widget.event.foodType != 'none')
          Positioned(
            bottom: 20,
            left: 160,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_rounded,
                      size: 12, color: AppTheme.accent),
                  const SizedBox(width: 4),
                  Text(
                    widget.event.foodType,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        if (isActive)
          Positioned(
            top: 20,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fiber_manual_record, size: 8, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Active Now',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroGradient(Color categoryColor, String icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withOpacity(0.85),
            categoryColor.withOpacity(0.60),
            AppTheme.primary.withOpacity(0.40),
          ],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.8, -0.6),
        child: Opacity(
          opacity: 0.15,
          child: Text(icon, style: const TextStyle(fontSize: 120)),
        ),
      ),
    );
  }

  Widget _buildTitleSection(Color categoryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.event.title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.6,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.event.getCategoryDisplayName(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: categoryColor,
                ),
              ),
            ),
            if (widget.event.category == 'දන්සල' &&
                widget.event.foodType != 'none')
              const SizedBox(width: 8),
            if (widget.event.category == 'දන්සල' &&
                widget.event.foodType != 'none')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_rounded,
                        size: 12, color: AppTheme.accent),
                    const SizedBox(width: 4),
                    Text(
                      widget.event.foodType,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateTimeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.60),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(widget.event.date),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.access_time_rounded,
                    size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Time',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      widget.event.time,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.60),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 24, color: AppTheme.success),
                const SizedBox(height: 4),
                Text(
                  _totalVisits.toString(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Text('Visited', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Icon(Icons.memory_rounded,
                    size: 24, color: AppTheme.memoryPrimary),
                const SizedBox(height: 4),
                Text(
                  _totalMemories.toString(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Text('Memories', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Icon(Icons.bookmark_outline_rounded,
                    size: 24, color: AppTheme.accent),
                const SizedBox(height: 4),
                Text(
                  _totalBookmarks.toString(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Text('Saved', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return GestureDetector(
      onTap: _openInMaps,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.60),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      size: 18, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Location',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        widget.event.location,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: AppTheme.textSecondary),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 100,
                width: double.infinity,
                color: Colors.grey[200],
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map, size: 32, color: Colors.grey[400]),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to open in maps',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
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
                            Icon(Icons.open_in_new,
                                size: 10, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Open Maps',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.60),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_rounded,
                    size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              const Text(
                'About this Event',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.event.description!,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.60),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded,
                size: 18, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Created by',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  widget.event.createdBy,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkAsVisitedButton() {
    if (!_sessionService.isLoggedIn) return const SizedBox.shrink();
    if (_hasVisited || _hasMemory) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isMarkingVisited ? null : _markAsVisited,
        icon: _isMarkingVisited
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('Mark as Visited'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.success,
          side: BorderSide(color: AppTheme.success.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildMemoryActionButton() {
    if (!_sessionService.isLoggedIn) return const SizedBox.shrink();
    if (_isOwner) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _handleMemoryAction,
        icon: Icon(_hasMemory ? Icons.edit_note_rounded : Icons.memory_rounded,
            size: 20),
        label: Text(_hasMemory ? 'Update Memory' : 'Add Memory'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.memoryPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildOwnerActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _editEvent,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit Event'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _deleteEvent,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCloseButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Close',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildFloatingAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withOpacity(0.35), width: 1),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: AppTheme.primary,
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            ),
          ),
          const Spacer(),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withOpacity(0.35), width: 1),
            ),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      _isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 20,
                    ),
                    color: _isBookmarked ? AppTheme.accent : AppTheme.primary,
                    onPressed: _toggleBookmark,
                    padding: EdgeInsets.zero,
                  ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withOpacity(0.35), width: 1),
            ),
            child: IconButton(
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              color: AppTheme.primary,
              onPressed: _shareEvent,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
