import 'dart:ui';
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

  String _formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  bool _computeIsActive(DateTime eventDate) {
    try {
      final today = DateTime.now();
      if (eventDate.year == today.year &&
          eventDate.month == today.month &&
          eventDate.day == today.day) {
        final ts = event.time.toLowerCase();
        final isPM = ts.contains('pm');
        final parts = ts.replaceAll(RegExp(r'[apm]'), '').trim().split(':');
        int h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        if (isPM && h != 12) h += 12;
        if (!isPM && h == 12) h = 0;
        return DateTime(eventDate.year, eventDate.month, eventDate.day, h, m)
            .isAfter(today);
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppConstants.getCategoryColor(event.category);
    final icon = event.getMarkerIcon();

    DateTime eventDate;
    try {
      eventDate = DateTime.parse(event.date);
    } catch (_) {
      eventDate = DateTime.now();
    }

    final isActive = _computeIsActive(eventDate);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: categoryColor.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // ── Background: image or category gradient ──
              _buildBackground(categoryColor, icon),

              // ── Rich scrim: subtle top vignette + strong bottom fade ──
              _buildScrim(),

              // ── Glass shimmer strip (top-left corner accent) ──
              if (!isCompact) _buildCornerAccent(categoryColor),

              // ── Content ──
              SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: category pill + active badge (spacer pushes to top)
                      Row(
                        children: [
                          _buildCategoryPill(icon),
                          if (isActive && !isCompact) ...[
                            const SizedBox(width: 8),
                            _buildActiveBadge(),
                          ],
                          const Spacer(),
                          // Tap-target hint icon
                          if (!isCompact)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.20),
                                    width: 1),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),

                      const Spacer(),

                      // Title
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

                      // ── Glass info strip ──
                      _buildGlassInfoStrip(eventDate),

                      // ── Action buttons ──
                      if (showActions) ...[
                        const SizedBox(height: 12),
                        _buildActionRow(),
                      ],
                    ],
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
  // BACKGROUND
  // ─────────────────────────────────────────────

  Widget _buildBackground(Color categoryColor, String icon) {
    if (event.hasImage && !isCompact) {
      return CachedNetworkImage(
        imageUrl: event.imageUrl,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => _gradientFallback(categoryColor, icon),
        errorWidget: (_, __, ___) => _gradientFallback(categoryColor, icon),
      );
    }
    return _gradientFallback(categoryColor, icon);
  }

  Widget _gradientFallback(Color color, String icon) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.75),
            color.withOpacity(0.55),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: isCompact
          ? null
          : Align(
              alignment: const Alignment(0.85, -0.6),
              child: Opacity(
                opacity: 0.18,
                child: Text(icon, style: const TextStyle(fontSize: 80)),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────
  // SCRIM
  // ─────────────────────────────────────────────

  Widget _buildScrim() {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.08),
            Colors.transparent,
            Colors.black.withOpacity(0.55),
            Colors.black.withOpacity(0.80),
          ],
          stops: const [0.0, 0.25, 0.65, 1.0],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CORNER ACCENT  (glass shimmer strip)
  // ─────────────────────────────────────────────

  Widget _buildCornerAccent(Color color) {
    return Positioned(
      top: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(60),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 70,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              border: Border(
                left:
                    BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
                bottom:
                    BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CATEGORY PILL
  // ─────────────────────────────────────────────

  Widget _buildCategoryPill(String icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(
                event.getCategoryDisplayName(),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ACTIVE BADGE
  // ─────────────────────────────────────────────

  Widget _buildActiveBadge() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.88),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppTheme.accent.withOpacity(0.40), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.30),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Active',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // GLASS INFO STRIP  (date · time · location)
  // ─────────────────────────────────────────────

  Widget _buildGlassInfoStrip(DateTime eventDate) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.14), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date & time row
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 12, color: Colors.white70),
                  const SizedBox(width: 5),
                  Text(
                    _formatDate(eventDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.access_time_rounded,
                      size: 12, color: Colors.white70),
                  const SizedBox(width: 5),
                  Text(
                    event.time,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Location row
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 12, color: Colors.white70),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      event.location,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ACTION BUTTONS ROW
  // ─────────────────────────────────────────────

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: _buildGlassActionButton(
            label: 'Edit',
            icon: Icons.edit_rounded,
            color: AppTheme.primary,
            onPressed: onEdit,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildGlassActionButton(
            label: 'Share',
            icon: Icons.share_rounded,
            color: AppTheme.accent,
            onPressed: onShare,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildGlassActionButton(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            color: AppTheme.error,
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withOpacity(0.70), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
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
