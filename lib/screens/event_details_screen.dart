import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/event_model.dart';
import '../models/memory_model.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';
import '../services/memory_service.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import 'create_memory_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Glass helper
// ─────────────────────────────────────────────────────────────

class _Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final double blur;
  final double opacity;
  final Border? border;

  const _Glass({
    required this.child,
    this.borderRadius,
    this.padding,
    this.tint = Colors.white,
    this.blur = 18,
    this.opacity = 0.10,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withOpacity(opacity),
            borderRadius: br,
            border: border ??
                Border.all(color: Colors.white.withOpacity(0.18), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final SessionService _sessionService = SessionService();
  final MemoryService _memoryService = MemoryService();

  bool _isBookmarked = false;
  bool _isLoading = false;
  bool _hasMemory = false;

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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (!_sessionService.isLoggedIn) return;

    final bookmarked = await _supabaseService.isBookmarked(
      _sessionService.currentUser!.id,
      widget.event.id,
    );

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
      await _supabaseService.removeBookmark(
        _sessionService.currentUser!.id,
        widget.event.id,
      );
      setState(() => _isBookmarked = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Removed from bookmarks', Icons.bookmark_remove),
        );
      }
    } else {
      await _supabaseService.addBookmark(
        _sessionService.currentUser!.id,
        widget.event.id,
      );
      setState(() => _isBookmarked = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Added to bookmarks', Icons.bookmark_added),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handleMemoryAction() async {
    if (!_sessionService.isLoggedIn) {
      _showLoginRequired();
      return;
    }

    if (_hasMemory) {
      // Edit existing memory
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
        }
      }
    } else {
      // Create new memory
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateMemoryScreen(event: widget.event),
        ),
      );
      if (result == true) {
        await _checkMemory();
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD ROOT
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppConstants.getCategoryColor(widget.event.category);
    final icon = widget.event.getMarkerIcon();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Ambient blobs ──
          _buildAmbientBlobs(categoryColor),

          // ── Main scroll content ──
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero sliver ──
              SliverToBoxAdapter(
                child: _buildHeroSection(categoryColor, icon),
              ),

              // ── Content ──
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildTitleSection(categoryColor, icon),
                        const SizedBox(height: 20),
                        _buildInfoCard(),
                        if (widget.event.description != null &&
                            widget.event.description!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildDescriptionCard(),
                        ],
                        const SizedBox(height: 16),
                        _buildMemoryAction(),
                        const SizedBox(height: 8),
                        _buildMetaCard(),
                        const SizedBox(height: 24),
                        if (_sessionService.isLoggedIn &&
                            widget.event.userId ==
                                _sessionService.currentUser?.id) ...[
                          _buildOwnerActions(),
                          const SizedBox(height: 12),
                        ],
                        _buildCloseButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Floating back + actions bar ──
          SafeArea(child: _buildFloatingAppBar()),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  AMBIENT BLOBS
  // ─────────────────────────────────────────────

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

  // ─────────────────────────────────────────────
  //  FLOATING APP BAR
  // ─────────────────────────────────────────────

  Widget _buildFloatingAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Back button
          _Glass(
            borderRadius: BorderRadius.circular(14),
            blur: 16,
            opacity: 0.55,
            tint: Colors.white,
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: AppTheme.primary,
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
          ),

          const Spacer(),

          // Bookmark button
          _Glass(
            borderRadius: BorderRadius.circular(14),
            blur: 16,
            opacity: 0.55,
            tint: Colors.white,
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
            child: SizedBox(
              width: 44,
              height: 44,
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
          ),

          const SizedBox(width: 8),

          // Share button
          _Glass(
            borderRadius: BorderRadius.circular(14),
            blur: 16,
            opacity: 0.55,
            tint: Colors.white,
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                color: AppTheme.primary,
                onPressed: _shareEvent,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  HERO SECTION
  // ─────────────────────────────────────────────

  Widget _buildHeroSection(Color categoryColor, String icon) {
    return Stack(
      children: [
        // ── Image / gradient background ──
        SizedBox(
          height: 300,
          width: double.infinity,
          child: widget.event.hasImage
              ? CachedNetworkImage(
                  imageUrl: widget.event.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildHeroGradient(categoryColor),
                  errorWidget: (_, __, ___) =>
                      _buildHeroGradient(categoryColor),
                )
              : _buildHeroGradient(categoryColor),
        ),

        // ── Scrim ──
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.45),
                ],
              ),
            ),
          ),
        ),

        // ── Bottom-left category badge ──
        Positioned(
          bottom: 20,
          left: 16,
          child: _Glass(
            borderRadius: BorderRadius.circular(20),
            blur: 16,
            opacity: 0.75,
            tint: Colors.white,
            border: Border.all(color: Colors.white.withOpacity(0.45), width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

        // ── Bottom-right date chip ──
        Positioned(
          bottom: 20,
          right: 16,
          child: _Glass(
            borderRadius: BorderRadius.circular(20),
            blur: 16,
            opacity: 0.75,
            tint: Colors.white,
            border: Border.all(color: Colors.white.withOpacity(0.45), width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 11, color: AppTheme.textSecondary.withOpacity(0.8)),
                const SizedBox(width: 5),
                Text(
                  widget.event.date,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroGradient(Color categoryColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withOpacity(0.85),
            categoryColor.withOpacity(0.50),
            AppTheme.primary.withOpacity(0.30),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  TITLE SECTION
  // ─────────────────────────────────────────────

  Widget _buildTitleSection(Color categoryColor, String icon) {
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
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Category pill
            _Glass(
              borderRadius: BorderRadius.circular(20),
              blur: 8,
              opacity: 0.55,
              tint: categoryColor,
              border:
                  Border.all(color: categoryColor.withOpacity(0.25), width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                widget.event.foodType != 'none') ...[
              const SizedBox(width: 8),
              _Glass(
                borderRadius: BorderRadius.circular(20),
                blur: 8,
                opacity: 0.55,
                tint: Colors.white,
                border:
                    Border.all(color: Colors.white.withOpacity(0.35), width: 1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_rounded,
                        size: 12, color: AppTheme.accent),
                    const SizedBox(width: 5),
                    Text(
                      widget.event.foodType,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  INFO CARD  (date · time · location)
  // ─────────────────────────────────────────────

  Widget _buildInfoCard() {
    return _buildGlassCard(
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: _formatDate(widget.event.date),
            iconColor: AppTheme.primary,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: widget.event.time,
            iconColor: AppTheme.primary,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.location_on_rounded,
            label: 'Location',
            value: widget.event.location,
            iconColor: AppTheme.primary,
            isMultiline: true,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  DESCRIPTION CARD
  // ─────────────────────────────────────────────

  Widget _buildDescriptionCard() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded,
                      size: 16, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                const Text(
                  'About this Event',
                  style: TextStyle(
                    fontSize: 14,
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
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  MEMORY ACTION BUTTON
  // ─────────────────────────────────────────────

  Widget _buildMemoryAction() {
    return _Glass(
      borderRadius: BorderRadius.circular(16),
      blur: 12,
      opacity: 0.90,
      tint: _hasMemory ? AppTheme.memoryPrimary : AppTheme.memoryPrimary,
      border: Border.all(
        color: AppTheme.memoryPrimary.withOpacity(0.30),
        width: 1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _handleMemoryAction,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _hasMemory ? Icons.edit_note_rounded : Icons.memory_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _hasMemory ? 'Update Memory' : 'Add Memory',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  META CARD  (created by)
  // ─────────────────────────────────────────────

  Widget _buildMetaCard() {
    return _buildGlassCard(
      child: _buildInfoRow(
        icon: Icons.person_rounded,
        label: 'Created by',
        value: widget.event.createdBy,
        iconColor: AppTheme.textSecondary,
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  OWNER ACTIONS  (edit / delete)
  // ─────────────────────────────────────────────

  Widget _buildOwnerActions() {
    return Row(
      children: [
        Expanded(
          child: _Glass(
            borderRadius: BorderRadius.circular(16),
            blur: 12,
            opacity: 0.55,
            tint: Colors.white,
            border:
                Border.all(color: AppTheme.primary.withOpacity(0.30), width: 1),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.edit_rounded,
                          size: 16, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text(
                        'Edit Event',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Glass(
            borderRadius: BorderRadius.circular(16),
            blur: 12,
            opacity: 0.55,
            tint: Colors.white,
            border:
                Border.all(color: AppTheme.error.withOpacity(0.40), width: 1),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _confirmDelete,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppTheme.error),
                      SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
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
      await _supabaseService.deleteEvent(widget.event.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  // ─────────────────────────────────────────────
  //  CLOSE BUTTON
  // ─────────────────────────────────────────────

  Widget _buildCloseButton() {
    return _Glass(
      borderRadius: BorderRadius.circular(16),
      blur: 12,
      opacity: 0.90,
      tint: AppTheme.primary,
      border: Border.all(color: AppTheme.primary.withOpacity(0.30), width: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context),
          child: const SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Center(
                child: Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  SHARED WIDGETS
  // ─────────────────────────────────────────────

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.60),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: AppTheme.timelineInactive.withOpacity(0.50),
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          // Icon bubble
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),

          // Label
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Value
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
              maxLines: isMultiline ? 5 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
