import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/memory_model.dart';
import '../models/event_model.dart';
import '../services/memory_service.dart';
import '../services/session_service.dart';
import '../services/cloudinary_service.dart';
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

class MemoryDetailsScreen extends StatefulWidget {
  final MemoryModel memory;
  final EventModel event;

  const MemoryDetailsScreen({
    super.key,
    required this.memory,
    required this.event,
  });

  @override
  State<MemoryDetailsScreen> createState() => _MemoryDetailsScreenState();
}

class _MemoryDetailsScreenState extends State<MemoryDetailsScreen>
    with SingleTickerProviderStateMixin {
  final MemoryService _memoryService = MemoryService();
  final SessionService _sessionService = SessionService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  late AnimationController _fadeController;
  bool _isLoading = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _deleteMemory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Memory',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Are you sure you want to delete this memory? This action cannot be undone.'),
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
      setState(() => _isLoading = true);

      // Delete images from Cloudinary
      for (final publicId in widget.memory.imagePublicIds) {
        await _cloudinaryService.deleteFile(publicId);
      }
      if (widget.memory.videoPublicId.isNotEmpty) {
        await _cloudinaryService.deleteFile(widget.memory.videoPublicId);
      }

      final success = await _memoryService.deleteMemory(widget.memory.id);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Memory deleted successfully')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete memory')),
          );
        }
      }
    }
  }

  void _editMemory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMemoryScreen(
          event: widget.event,
          isEditing: true,
          existingMemoryId: widget.memory.id,
          existingNote: widget.memory.experienceNote,
          existingImageUrls: widget.memory.imageUrls,
          existingImagePublicIds: widget.memory.imagePublicIds,
          existingVideoUrl: widget.memory.videoUrl,
          existingVideoPublicId: widget.memory.videoPublicId,
        ),
      ),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _shareMemory() {
    final dateFormat = DateFormat('MMMM d, yyyy');
    Share.share(
      '📝 My memory at ${widget.event.title}\n\n'
      '📅 Date visited: ${dateFormat.format(widget.memory.visitedAt)}\n'
      '📍 Location: ${widget.event.location}\n\n'
      '✨ Experience:\n${widget.memory.experienceNote}\n\n'
      'Shared from VesakGO 🌼',
      subject: 'My Vesak Memory - ${widget.event.title}',
    );
  }

  void _showFullScreenImage(int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: widget.memory.imageUrls[index],
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child:
                      Icon(Icons.broken_image, size: 50, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
            if (widget.memory.imageUrls.length > 1)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${index + 1} / ${widget.memory.imageUrls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showVideo() {
    if (widget.memory.videoUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.5,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: widget.memory.videoUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_filled,
                                size: 50, color: Colors.white),
                            SizedBox(height: 8),
                            Text('Tap to play video',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Video from ${DateFormat('MMM d, yyyy').format(widget.memory.visitedAt)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMMM d, yyyy').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  bool get _canEdit =>
      _sessionService.isLoggedIn &&
      widget.memory.userId == _sessionService.currentUser?.id;

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppConstants.getCategoryColor(widget.event.category);
    final icon = widget.event.getMarkerIcon();
    final dateFormat = DateFormat('MMMM d, yyyy');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Ambient blobs ──
          _buildAmbientBlobs(categoryColor),

          // ── Main content ──
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Media Gallery Sliver ──
              if (widget.memory.hasImages)
                SliverToBoxAdapter(
                  child: _buildMediaGallery(),
                )
              else
                SliverToBoxAdapter(
                  child: _buildHeroSection(categoryColor, icon),
                ),

              // ── Content Sliver ──
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleSection(),
                        const SizedBox(height: 16),
                        _buildEventInfoCard(),
                        const SizedBox(height: 16),
                        _buildExperienceCard(),
                        const SizedBox(height: 16),
                        _buildMetaCard(),
                        const SizedBox(height: 24),
                        if (_canEdit) _buildActionButtons(),
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

          // ── Floating app bar ──
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
              color: AppTheme.memoryPrimary.withOpacity(0.12),
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

  Widget _buildMediaGallery() {
    return SizedBox(
      height: 350,
      child: Stack(
        children: [
          // Main image
          if (widget.memory.imageUrls.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullScreenImage(_currentImageIndex),
              child: CachedNetworkImage(
                imageUrl: widget.memory.imageUrls[_currentImageIndex],
                width: double.infinity,
                height: 350,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 350,
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 350,
                  color: Colors.grey[200],
                  child: const Center(
                    child:
                        Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  ),
                ),
              ),
            ),

          // Gradient overlay
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
                  stops: const [0.6, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // Image counter and video badge
          Positioned(
            bottom: 20,
            left: 16,
            child: Row(
              children: [
                if (widget.memory.imageUrls.length > 1)
                  _Glass(
                    borderRadius: BorderRadius.circular(20),
                    blur: 16,
                    opacity: 0.75,
                    tint: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${_currentImageIndex + 1} / ${widget.memory.imageUrls.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (widget.memory.hasVideo) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showVideo,
                    child: _Glass(
                      borderRadius: BorderRadius.circular(20),
                      blur: 16,
                      opacity: 0.75,
                      tint: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: const [
                          Icon(Icons.play_circle_filled,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Play Video',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Thumbnail strip
          if (widget.memory.imageUrls.length > 1)
            Positioned(
              bottom: 20,
              right: 16,
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: widget.memory.imageUrls.length,
                  itemBuilder: (context, index) {
                    final isActive = index == _currentImageIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _currentImageIndex = index),
                      child: Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: widget.memory.imageUrls[index],
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Container(color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(Color categoryColor, String icon) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.memoryPrimary.withOpacity(0.85),
            AppTheme.memoryPrimary.withOpacity(0.50),
            categoryColor.withOpacity(0.30),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              widget.event.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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
                onPressed: _shareMemory,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_canEdit) ...[
            const SizedBox(width: 8),
            _Glass(
              borderRadius: BorderRadius.circular(14),
              blur: 16,
              opacity: 0.55,
              tint: Colors.white,
              border:
                  Border.all(color: Colors.white.withOpacity(0.35), width: 1),
              child: SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                  color: AppTheme.primary,
                  onPressed: () => _showOptionsMenu(),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading:
                        const Icon(Icons.edit_rounded, color: AppTheme.primary),
                    title: const Text('Edit Memory'),
                    onTap: () {
                      Navigator.pop(context);
                      _editMemory();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.error),
                    title: const Text('Delete Memory',
                        style: TextStyle(color: AppTheme.error)),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMemory();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.memoryPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.memory_rounded,
                  size: 18, color: AppTheme.memoryPrimary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.event.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 12, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Visited on ${_formatDate(widget.memory.visitedAt)}',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 12),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.5),
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Icon(Icons.access_time_rounded,
                size: 12, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              _formatTime(widget.memory.visitedAt),
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEventInfoCard() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event_rounded,
                      size: 14, color: AppTheme.primary),
                ),
                const SizedBox(width: 8),
                const Text('Event Details',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.location_on_rounded, widget.event.location),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.category_rounded, widget.event.category),
            if (widget.event.foodType != 'none') ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                  Icons.restaurant_rounded, 'Food: ${widget.event.foodType}'),
            ],
            const SizedBox(height: 8),
            _buildDetailRow(
                Icons.person_rounded, 'Created by: ${widget.event.createdBy}'),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceCard() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.memoryPrimary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      size: 14, color: AppTheme.memoryPrimary),
                ),
                const SizedBox(width: 8),
                const Text('My Experience',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.memory.experienceNote,
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

  Widget _buildMetaCard() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_rounded,
                          size: 16, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.memory.imageUrls.length}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Photos',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Container(
                width: 1, height: 30, color: Colors.grey.withOpacity(0.2)),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_rounded,
                          size: 16,
                          color: widget.memory.hasVideo
                              ? AppTheme.accent
                              : AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        widget.memory.hasVideo ? '1' : '0',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.memory.hasVideo
                                ? AppTheme.accent
                                : AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Video',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Container(
                width: 1, height: 30, color: Colors.grey.withOpacity(0.2)),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('yyyy').format(widget.memory.visitedAt),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Year',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
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
                onTap: _editMemory,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.edit_rounded,
                          size: 16, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('Edit',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
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
                onTap: _deleteMemory,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppTheme.error),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error)),
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

  Widget _buildCloseButton() {
    return _Glass(
      borderRadius: BorderRadius.circular(16),
      blur: 12,
      opacity: 0.90,
      tint: AppTheme.memoryPrimary,
      border:
          Border.all(color: AppTheme.memoryPrimary.withOpacity(0.30), width: 1),
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
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary.withOpacity(0.85)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
