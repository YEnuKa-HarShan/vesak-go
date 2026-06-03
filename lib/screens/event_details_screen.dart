import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppConstants.getCategoryColor(widget.event.category);
    final icon = widget.event.getMarkerIcon();

    return Scaffold(
      backgroundColor: AppTheme.sand,
      appBar: AppBar(
        title: Text(
          widget.event.title,
          style: const TextStyle(color: AppTheme.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppTheme.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? AppTheme.gold : AppTheme.white,
            ),
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.white),
            onPressed: _shareEvent,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [categoryColor, categoryColor.withOpacity(0.7)],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    icon,
                    style: const TextStyle(fontSize: 80),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.event.category,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: categoryColor, width: 1),
                    ),
                    child: Text(
                      widget.event.getCategoryDisplayName(),
                      style: TextStyle(
                        fontSize: 12,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.charcoal.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Date',
                          widget.event.date,
                          AppTheme.saffron,
                        ),
                        const Divider(color: AppTheme.sand),
                        _buildInfoRow(
                          Icons.access_time,
                          'Time',
                          widget.event.time,
                          AppTheme.saffron,
                        ),
                        const Divider(color: AppTheme.sand),
                        _buildInfoRow(
                          Icons.location_on,
                          'Location',
                          widget.event.location,
                          AppTheme.saffron,
                        ),
                        if (widget.event.category == 'දන්සල' &&
                            widget.event.foodType != 'none')
                          Column(
                            children: [
                              const Divider(color: AppTheme.sand),
                              _buildInfoRow(
                                Icons.restaurant,
                                'Food Type',
                                widget.event.foodType,
                                AppTheme.saffron,
                              ),
                            ],
                          ),
                        if (widget.event.description != null &&
                            widget.event.description!.isNotEmpty)
                          Column(
                            children: [
                              const Divider(color: AppTheme.sand),
                              _buildInfoRow(
                                Icons.description,
                                'Description',
                                widget.event.description!,
                                AppTheme.saffron,
                                isMultiline: true,
                              ),
                            ],
                          ),
                        const Divider(color: AppTheme.sand),
                        _buildInfoRow(
                          Icons.person,
                          'Created by',
                          widget.event.createdBy,
                          AppTheme.saffron,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
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

  Widget _buildInfoRow(
      IconData icon, String label, String value, Color iconColor,
      {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.charcoal.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.charcoal,
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
