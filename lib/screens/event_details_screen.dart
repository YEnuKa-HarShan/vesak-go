import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/event_model.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';
import '../constants.dart';
import '../theme/app_theme.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final SessionService _sessionService = SessionService();

  bool _isBookmarked = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (!_sessionService.isLoggedIn) return;

    final bookmarked = await _supabaseService.isBookmarked(
      _sessionService.currentUser!.id,
      widget.event.id,
    );

    setState(() {
      _isBookmarked = bookmarked;
    });
  }

  Future<void> _toggleBookmark() async {
    if (!_sessionService.isLoggedIn) {
      _showLoginRequired();
      return;
    }

    setState(() => _isLoading = true);

    if (_isBookmarked) {
      await _supabaseService.removeBookmark(
        _sessionService.currentUser!.id,
        widget.event.id,
      );
      setState(() => _isBookmarked = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from bookmarks')),
      );
    } else {
      await _supabaseService.addBookmark(
        _sessionService.currentUser!.id,
        widget.event.id,
      );
      setState(() => _isBookmarked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to bookmarks')),
      );
    }

    setState(() => _isLoading = false);
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

  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please login to use this feature')),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppConstants.getCategoryColor(widget.event.category);
    final icon = widget.event.getMarkerIcon();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Hero Header Sliver
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                color: Colors.white,
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                  ),
                  color: _isBookmarked ? AppTheme.accent : Colors.white,
                  onPressed: _toggleBookmark,
                  padding: EdgeInsets.zero,
                ),
              ),
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, size: 20),
                  color: Colors.white,
                  onPressed: _shareEvent,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Image or Gradient
                  if (widget.event.hasImage)
                    CachedNetworkImage(
                      imageUrl: widget.event.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              categoryColor,
                              categoryColor.withOpacity(0.7)
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              categoryColor,
                              categoryColor.withOpacity(0.7)
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            categoryColor,
                            categoryColor.withOpacity(0.7)
                          ],
                        ),
                      ),
                    ),
                  // Dark Overlay for text visibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                  // Category Badge
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            icon,
                            style: const TextStyle(fontSize: 14),
                          ),
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
                ],
              ),
            ),
          ),

          // Content Sliver
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.event.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info Cards
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Date',
                          _formatDate(widget.event.date),
                          AppTheme.primary,
                        ),
                        const Divider(
                          color: AppTheme.timelineInactive,
                          height: 1,
                          thickness: 0.5,
                        ),
                        _buildInfoRow(
                          Icons.access_time,
                          'Time',
                          widget.event.time,
                          AppTheme.primary,
                        ),
                        const Divider(
                          color: AppTheme.timelineInactive,
                          height: 1,
                          thickness: 0.5,
                        ),
                        _buildInfoRow(
                          Icons.location_on,
                          'Location',
                          widget.event.location,
                          AppTheme.primary,
                          isMultiline: true,
                        ),
                        if (widget.event.category == 'දන්සල' &&
                            widget.event.foodType != 'none')
                          Column(
                            children: [
                              const Divider(
                                color: AppTheme.timelineInactive,
                                height: 1,
                                thickness: 0.5,
                              ),
                              _buildInfoRow(
                                Icons.restaurant,
                                'Food Type',
                                widget.event.foodType,
                                AppTheme.accent,
                              ),
                            ],
                          ),
                        if (widget.event.description != null &&
                            widget.event.description!.isNotEmpty)
                          Column(
                            children: [
                              const Divider(
                                color: AppTheme.timelineInactive,
                                height: 1,
                                thickness: 0.5,
                              ),
                              _buildInfoRow(
                                Icons.description,
                                'Description',
                                widget.event.description!,
                                AppTheme.textSecondary,
                                isMultiline: true,
                              ),
                            ],
                          ),
                        const Divider(
                          color: AppTheme.timelineInactive,
                          height: 1,
                          thickness: 0.5,
                        ),
                        _buildInfoRow(
                          Icons.person,
                          'Created by',
                          widget.event.createdBy,
                          AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (_sessionService.isLoggedIn &&
                      widget.event.userId == _sessionService.currentUser?.id)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit Event'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Event'),
                                  content: const Text(
                                      'Are you sure you want to delete this event?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.error,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _supabaseService
                                    .deleteEvent(widget.event.id);
                                if (mounted) {
                                  Navigator.pop(context, true);
                                }
                              }
                            },
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: const BorderSide(color: AppTheme.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, Color iconColor,
      {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              maxLines: isMultiline ? 5 : 1,
              overflow:
                  isMultiline ? TextOverflow.ellipsis : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
