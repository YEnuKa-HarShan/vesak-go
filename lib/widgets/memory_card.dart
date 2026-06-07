import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/memory_model.dart';
import '../models/event_model.dart';
import '../constants.dart';
import '../theme/app_theme.dart';

class MemoryCard extends StatelessWidget {
  final MemoryModel memory;
  final EventModel event;
  final VoidCallback onTap;

  const MemoryCard({
    super.key,
    required this.memory,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final catColor = AppConstants.getCategoryColor(event.category);
    final hasCoverImage = memory.hasImages;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.62),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withOpacity(0.70), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Image
                if (hasCoverImage)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        child: CachedNetworkImage(
                          imageUrl: memory.coverImage,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 160,
                            color: catColor.withOpacity(0.2),
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 160,
                            color: catColor.withOpacity(0.2),
                            child: Center(
                                child: Text(event.getMarkerIcon(),
                                    style: const TextStyle(fontSize: 48))),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.4)
                              ],
                            ),
                          ),
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
                          child: Row(
                            children: [
                              if (memory.hasImages) ...[
                                Icon(Icons.photo_library_rounded,
                                    size: 12, color: Colors.white),
                                Text(' ${memory.imageUrls.length}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.white)),
                              ],
                              if (memory.hasVideo) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.videocam_rounded,
                                    size: 12, color: Colors.white),
                                const Text(' 1',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.2),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Center(
                        child: Text(event.getMarkerIcon(),
                            style: const TextStyle(fontSize: 48))),
                  ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 12,
                              color: AppTheme.textSecondary.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            '${dateFormat.format(memory.visitedAt)} · ${event.time}',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary.withOpacity(0.7)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        memory.experienceNote.length > 100
                            ? '${memory.experienceNote.substring(0, 100)}...'
                            : memory.experienceNote,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
}
