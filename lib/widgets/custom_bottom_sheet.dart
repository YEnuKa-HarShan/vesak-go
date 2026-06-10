import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/event_model.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';
import '../services/memory_service.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import '../screens/event_details_screen.dart';
import '../screens/create_memory_screen.dart';

enum EventStatus { active, upcoming, expired }

class EventBottomSheet extends StatefulWidget {
  final EventModel event;
  final double? distance;
  final VoidCallback? onBookmarkChanged;
  final VoidCallback? onMemoryChanged;

  const EventBottomSheet({
    super.key,
    required this.event,
    this.distance,
    this.onBookmarkChanged,
    this.onMemoryChanged,
  });

  @override
  State<EventBottomSheet> createState() => _EventBottomSheetState();
}

class _EventBottomSheetState extends State<EventBottomSheet> {
  final SessionService _sessionService = SessionService();
  final MemoryService _memoryService = MemoryService();

  bool _isBookmarked = false;
  bool _hasMemory = false;
  bool _hasVisited = false;
  bool _isBookmarkLoading = false;
  bool _isMarkingVisited = false;
  int _totalVisits = 0;
  int _totalMemories = 0;
  int _totalBookmarks = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _checkMemory();
    _checkVisited();
    _loadStats();
  }

  Future<void> _loadStats() async {
    // Stats will be implemented when backend adds this endpoint
    setState(() {
      _totalVisits = 0;
      _totalMemories = 0;
      _totalBookmarks = 0;
    });
  }

  Future<void> _checkStatus() async {
    if (!_sessionService.isLoggedIn) return;

    final bookmarked = await ApiService.isBookmarked(widget.event.id);
    setState(() => _isBookmarked = bookmarked);
  }

  Future<void> _checkMemory() async {
    if (!_sessionService.isLoggedIn) return;
    final hasMemory = await _memoryService.hasMemory(
      widget.event.id,
      _sessionService.currentUser!.id,
    );
    setState(() => _hasMemory = hasMemory);
  }

  Future<void> _checkVisited() async {
    if (!_sessionService.isLoggedIn) return;
    // Will be implemented when backend adds visited check endpoint
    setState(() => _hasVisited = false);
  }

  Future<void> _toggleBookmark() async {
    if (!_sessionService.isLoggedIn) {
      _showLoginRequired();
      return;
    }

    setState(() => _isBookmarkLoading = true);

    if (_isBookmarked) {
      final success = await ApiService.removeBookmark(widget.event.id);
      if (success) {
        setState(() {
          _isBookmarked = false;
          if (_totalBookmarks > 0) _totalBookmarks--;
        });
      }
    } else {
      final success = await ApiService.addBookmark(widget.event.id);
      if (success) {
        setState(() {
          _isBookmarked = true;
          _totalBookmarks++;
        });
      }
    }

    setState(() => _isBookmarkLoading = false);
    widget.onBookmarkChanged?.call();
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
    _showSnackBar('Marked as visited! ✓', Icons.check_circle);
  }

  Future<void> _handleMemoryAction() async {
    if (!_sessionService.isLoggedIn) {
      _showLoginRequired();
      return;
    }
    Navigator.pop(context);
    if (_hasMemory) {
      final memory = await _memoryService.getMemoryByEvent(
        widget.event.id,
        _sessionService.currentUser!.id,
      );
      if (memory != null && context.mounted) {
        await Navigator.push(
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
        await _loadStats();
        await _checkMemory();
        await _checkVisited();
      }
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateMemoryScreen(event: widget.event),
        ),
      );
      await _loadStats();
      await _checkMemory();
      await _checkVisited();
    }
    widget.onMemoryChanged?.call();
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
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openFullDetails() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailsScreen(event: widget.event),
      ),
    );
  }

  void _shareEvent() {
    Navigator.pop(context);
  }

  void _openInMaps() async {
    final lat = widget.event.latitude;
    final lng = widget.event.longitude;
    final title = Uri.encodeComponent(widget.event.title);

    final googleMapsAppUrl =
        'comgooglemaps://?center=$lat,$lng&zoom=15&q=$lat,$lng($title)';
    final googleMapsWebUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$title';
    final geoUrl = 'geo:$lat,$lng?q=$lat,$lng($title)';
    final wazeUrl = 'waze://?ll=$lat,$lng&navigate=yes';

    try {
      if (await canLaunchUrl(Uri.parse(googleMapsAppUrl))) {
        await launchUrl(Uri.parse(googleMapsAppUrl));
      } else if (await canLaunchUrl(Uri.parse(wazeUrl))) {
        await launchUrl(Uri.parse(wazeUrl));
      } else if (await canLaunchUrl(Uri.parse(geoUrl))) {
        await launchUrl(Uri.parse(geoUrl));
      } else {
        await launchUrl(Uri.parse(googleMapsWebUrl));
      }
    } catch (e) {
      await launchUrl(Uri.parse(googleMapsWebUrl));
    }
  }

  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please login to use this feature')),
    );
  }

  EventStatus _getEventStatus() {
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
        if (eventDateTime.isAfter(now)) return EventStatus.active;
      }

      if (eventDate.isAfter(now)) return EventStatus.upcoming;

      return EventStatus.expired;
    } catch (_) {
      return EventStatus.expired;
    }
  }

  Map<String, dynamic> _getStatusConfig() {
    switch (_getEventStatus()) {
      case EventStatus.active:
        return {
          'label': 'Active Now',
          'color': AppTheme.success,
          'icon': Icons.fiber_manual_record,
        };
      case EventStatus.upcoming:
        return {
          'label': 'Upcoming',
          'color': AppTheme.primary,
          'icon': Icons.schedule,
        };
      case EventStatus.expired:
        return {
          'label': 'Expired',
          'color': AppTheme.textSecondary,
          'icon': Icons.check_circle,
        };
      default:
        return {
          'label': 'Expired',
          'color': AppTheme.textSecondary,
          'icon': Icons.check_circle,
        };
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${_getMonthAbbr(date.month)} ${date.day}, ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _getCategoryEnglish() {
    return AppConstants.getCategoryName(widget.event.category);
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppConstants.getCategoryColor(widget.event.category);
    final categoryIcon = widget.event.getMarkerIcon();
    final categoryEnglish = _getCategoryEnglish();
    final statusConfig = _getStatusConfig();
    final hasImage = widget.event.hasImage;
    final canMarkVisited =
        _sessionService.isLoggedIn && !_hasVisited && !_hasMemory;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderImage(
                          hasImage, categoryColor, categoryIcon, statusConfig),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatsSection(),
                            const SizedBox(height: 20),
                            _buildEventDetailsSection(categoryEnglish),
                            const SizedBox(height: 16),
                            if (widget.event.description != null &&
                                widget.event.description!.isNotEmpty)
                              _buildDescriptionSection(),
                            const SizedBox(height: 16),
                            _buildActionButtons(canMarkVisited),
                            const SizedBox(height: 16),
                            _buildAddMemoryButton(),
                            const SizedBox(height: 16),
                            _buildCloseButtons(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderImage(bool hasImage, Color categoryColor,
      String categoryIcon, Map<String, dynamic> statusConfig) {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            image: hasImage
                ? DecorationImage(
                    image: NetworkImage(widget.event.imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: !hasImage
              ? Container(
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
                  child: Center(
                    child: Text(categoryIcon,
                        style: const TextStyle(fontSize: 64)),
                  ),
                )
              : null,
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.5, 0.8, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(categoryIcon,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          widget.event.getCategoryDisplayName(),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusConfig['color'].withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusConfig['icon'],
                            size: 10, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          statusConfig['label'],
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.event.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(_formatDate(widget.event.date),
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white70)),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(widget.event.time,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.event.location,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            children: [
              GestureDetector(
                onTap: _toggleBookmark,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isBookmarkLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(
                          _isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 18,
                          color: _isBookmarked ? AppTheme.accent : Colors.white,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openFullDetails,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.open_in_new_rounded,
                      size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: _totalVisits,
            label: 'Visited',
            icon: Icons.check_circle_outline,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: _totalMemories,
            label: 'Memories',
            icon: Icons.memory_rounded,
            color: AppTheme.memoryPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: _totalBookmarks,
            label: 'Saved',
            icon: Icons.bookmark_outline_rounded,
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildEventDetailsSection(String categoryEnglish) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_rounded,
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Event Details',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(
              label: 'Category',
              value: '${widget.event.category} ($categoryEnglish)'),
          const SizedBox(height: 8),
          _DetailRow(label: 'Organized by', value: widget.event.createdBy),
          if (widget.event.district != null &&
              widget.event.district!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DetailRow(
              label: 'District',
              value: widget.event.province != null &&
                      widget.event.province!.isNotEmpty
                  ? '${widget.event.district}, ${widget.event.province}'
                  : widget.event.district!,
            ),
          ],
          if (widget.distance != null) ...[
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Distance',
              value: '${widget.distance!.toStringAsFixed(1)} km from you',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final description = widget.event.description!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_quote_rounded,
                  size: 16, color: AppTheme.memoryPrimary),
              const SizedBox(width: 8),
              const Text(
                'Description',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool canMarkVisited) {
    if (!_sessionService.isLoggedIn) return const SizedBox.shrink();

    return Column(
      children: [
        if (canMarkVisited)
          SizedBox(
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (_hasVisited && !_hasMemory)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                  SizedBox(width: 8),
                  Text('You visited this event',
                      style: TextStyle(fontSize: 13, color: AppTheme.success)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddMemoryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _handleMemoryAction,
        icon: Icon(_hasMemory ? Icons.edit_note_rounded : Icons.memory_rounded,
            size: 18),
        label: Text(_hasMemory
            ? 'Update Memory to My Journey'
            : 'Add Memory to My Journey'),
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

  Widget _buildCloseButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openInMaps,
            icon: const Icon(Icons.map_rounded, size: 18),
            label: const Text('Map'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _shareEvent,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              side: BorderSide(color: AppTheme.accent.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Close'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: BorderSide(color: AppTheme.error.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
