import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/event_model.dart';
import '../constants.dart';
import '../theme/app_theme.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final bool showActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onTap;
  final double height;
  final bool isCompact;

  const EventCard({
    super.key,
    required this.event,
    this.showActions = false,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.onTap,
    this.height = 200,
    this.isCompact = false,
  });

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppConstants.getCategoryColor(event.category);
    final icon = event.getMarkerIcon();
    DateTime eventDate;
    try {
      eventDate = DateTime.parse(event.date);
    } catch (e) {
      eventDate = DateTime.now();
    }

    bool isActive = false;
    try {
      final today = DateTime.now();
      if (eventDate.year == today.year &&
          eventDate.month == today.month &&
          eventDate.day == today.day) {
        final timeStr = event.time.toLowerCase();
        bool isPM = timeStr.contains('pm');
        final timeParts =
            timeStr.replaceAll(RegExp(r'[apm]'), '').trim().split(':');
        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        final eventDateTime = DateTime(
            eventDate.year, eventDate.month, eventDate.day, hour, minute);
        isActive = eventDateTime.isAfter(DateTime.now());
      }
    } catch (e) {
      isActive = false;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background Image or Gradient
              if (event.hasImage && !isCompact)
                CachedNetworkImage(
                  imageUrl: event.imageUrl,
                  width: double.infinity,
                  height: height,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [categoryColor, categoryColor.withOpacity(0.7)],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [categoryColor, categoryColor.withOpacity(0.7)],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [categoryColor, categoryColor.withOpacity(0.7)],
                    ),
                  ),
                ),

              // Dark Overlay for text visibility
              Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Category Chip
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                icon,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                event.getCategoryDisplayName(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive && !isCompact) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Date and Time
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(eventDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          event.time,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.location,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // Action Buttons (for Events Screen)
                    if (showActions) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onEdit,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.9),
                                foregroundColor: AppTheme.primary,
                                side: BorderSide.none,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit, size: 14),
                                  SizedBox(width: 4),
                                  Text('Edit', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onShare,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.9),
                                foregroundColor: AppTheme.accent,
                                side: BorderSide.none,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.share, size: 14),
                                  SizedBox(width: 4),
                                  Text('Share', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onDelete,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.9),
                                foregroundColor: AppTheme.error,
                                side: BorderSide.none,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete, size: 14),
                                  SizedBox(width: 4),
                                  Text('Delete',
                                      style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
