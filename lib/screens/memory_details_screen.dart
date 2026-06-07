import 'dart:ui';
import 'dart:async';
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

class MemoryDetailsScreen extends StatefulWidget {
  final MemoryModel memory;
  final EventModel event;
  const MemoryDetailsScreen(
      {super.key, required this.memory, required this.event});

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
  bool _isAutoPlaying = true;
  bool _isInitialDelay = true;
  Timer? _autoPlayTimer;
  Timer? _initialDelayTimer;
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderSticky = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _scrollController.addListener(_onScroll);
    _startAutoPlayWithDelay();
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _initialDelayTimer?.cancel();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldBeSticky = _scrollController.offset > 200;
    if (shouldBeSticky != _isHeaderSticky) {
      setState(() => _isHeaderSticky = shouldBeSticky);
    }
  }

  void _startAutoPlayWithDelay() {
    if (widget.memory.imageUrls.length <= 1) return;
    _initialDelayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isInitialDelay = false);
        _startAutoPlay();
      }
    });
  }

  void _startAutoPlay() {
    if (widget.memory.imageUrls.length <= 1) return;
    _stopAutoPlay();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isAutoPlaying && mounted) {
        setState(() {
          _currentImageIndex =
              (_currentImageIndex + 1) % widget.memory.imageUrls.length;
        });
      }
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  void _pauseAutoPlay() {
    setState(() => _isAutoPlaying = false);
    _stopAutoPlay();
  }

  void _resumeAutoPlay() {
    if (!_isAutoPlaying) {
      setState(() => _isAutoPlaying = true);
      _startAutoPlay();
    }
  }

  void _toggleAutoPlay() {
    if (_isAutoPlaying) {
      _pauseAutoPlay();
    } else {
      _resumeAutoPlay();
    }
    setState(() {});
  }

  void _openFullScreenGallery() {
    _pauseAutoPlay();
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenGallery(
          images: widget.memory.imageUrls,
          initialIndex: _currentImageIndex,
          onClose: () {
            _resumeAutoPlay();
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
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
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
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
              const SnackBar(content: Text('Memory deleted successfully')));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete memory')));
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
    if (result == true && mounted) Navigator.pop(context, true);
  }

  void _shareMemory() {
    final dateFormat = DateFormat('MMMM d, yyyy');
    Share.share(
      '📝 My memory at ${widget.event.title}\n\n📅 Date visited: ${dateFormat.format(widget.memory.visitedAt)}\n📍 Location: ${widget.event.location}\n\n✨ Experience:\n${widget.memory.experienceNote}\n\nShared from VesakGO 🌼',
      subject: 'My Vesak Memory - ${widget.event.title}',
    );
  }

  void _showVideo() {
    if (widget.memory.videoUrl.isEmpty) return;
    _pauseAutoPlay();
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
                        borderRadius: BorderRadius.circular(12)),
                    child: CachedNetworkImage(
                      imageUrl: widget.memory.videoUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)),
                      errorWidget: (_, __, ___) => const Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Icon(Icons.play_circle_filled,
                                size: 50, color: Colors.white),
                            SizedBox(height: 8),
                            Text('Tap to play video',
                                style: TextStyle(color: Colors.white))
                          ])),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                      'Video from ${DateFormat('MMM d, yyyy').format(widget.memory.visitedAt)}',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  _resumeAutoPlay();
                  Navigator.pop(context);
                },
                child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 24)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _resumeAutoPlay());
  }

  String _formatDate(DateTime date) =>
      DateFormat('EEEE, MMMM d, yyyy').format(date);
  String _formatTime(DateTime date) => DateFormat('h:mm a').format(date);
  bool get _canEdit =>
      _sessionService.isLoggedIn &&
      widget.memory.userId == _sessionService.currentUser?.id;

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppConstants.getCategoryColor(widget.event.category);
    final hasMultipleImages = widget.memory.imageUrls.length > 1;
    final hasVideo = widget.memory.hasVideo;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _buildAmbientBlobs(categoryColor),
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  isVisible: _isHeaderSticky,
                  title: widget.event.title,
                  location: widget.event.location,
                  onEdit: _canEdit ? _editMemory : null,
                  onShare: _shareMemory,
                  onDelete: _canEdit ? _deleteMemory : null,
                ),
              ),
              if (widget.memory.hasImages)
                SliverToBoxAdapter(
                    child: _buildMediaGallery(hasMultipleImages, hasVideo)),
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
          SafeArea(child: _buildFloatingAppBar()),
        ],
      ),
    );
  }

  Widget _buildMediaGallery(bool hasMultipleImages, bool hasVideo) {
    return SizedBox(
      height: 400,
      child: Stack(
        children: [
          // Main Image (tap to open full-screen)
          GestureDetector(
            onTap: _openFullScreenGallery,
            child: CachedNetworkImage(
              imageUrl: widget.memory.imageUrls[_currentImageIndex],
              width: double.infinity,
              height: 400,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                  height: 400,
                  color: Colors.grey[200],
                  child: const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.memoryPrimary))),
              errorWidget: (_, __, ___) => Container(
                  height: 400,
                  color: Colors.grey[200],
                  child: const Center(
                      child: Icon(Icons.broken_image,
                          size: 50, color: Colors.grey))),
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
                    Colors.black.withOpacity(0.6)
                  ],
                  stops: const [0.6, 0.8, 1.0],
                ),
              ),
            ),
          ),
          // Auto-play button (Top Right)
          if (hasMultipleImages)
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: _toggleAutoPlay,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isAutoPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          // Auto-play starting soon indicator
          if (_isInitialDelay && hasMultipleImages)
            Positioned(
              top: 20,
              right: 80,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 8),
                    Text('Auto-play starting...',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
          // Image counter (Bottom Left)
          Positioned(
            bottom: 20,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_library_rounded,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentImageIndex + 1} / ${widget.memory.imageUrls.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          // Video FAB button (Bottom Right)
          if (hasVideo)
            Positioned(
              bottom: 20,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: _showVideo,
                backgroundColor: AppTheme.accent,
                elevation: 0,
                child:
                    const Icon(Icons.play_arrow, color: Colors.white, size: 24),
              ),
            ),
          // Progress bar (Bottom edge)
          if (hasMultipleImages && _isAutoPlaying && !_isInitialDelay)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _AutoPlayProgressBar(
                duration: const Duration(seconds: 5),
                onComplete: () {
                  if (_isAutoPlaying && mounted) {
                    setState(() {
                      _currentImageIndex = (_currentImageIndex + 1) %
                          widget.memory.imageUrls.length;
                    });
                  }
                },
                key: ValueKey(_currentImageIndex),
              ),
            ),
          // Thumbnail strip (Bottom Center)
          if (hasMultipleImages)
            Positioned(
              bottom: 20,
              left: 100,
              right: 100,
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.memory.imageUrls.length,
                  itemBuilder: (context, index) {
                    final isActive = index == _currentImageIndex;
                    return GestureDetector(
                      onTap: () {
                        _pauseAutoPlay();
                        setState(() => _currentImageIndex = index);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  isActive ? Colors.white : Colors.transparent,
                              width: 2),
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
                    color: AppTheme.memoryPrimary.withOpacity(0.12)))),
        Positioned(
            top: 100,
            right: -80,
            child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: categoryColor.withOpacity(0.10)))),
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

  Widget _buildFloatingAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
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
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: AppTheme.primary,
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero)),
          ),
          const Spacer(),
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
                    padding: EdgeInsets.zero)),
          ),
          if (_canEdit) const SizedBox(width: 8),
          if (_canEdit)
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
                      padding: EdgeInsets.zero)),
            ),
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
                    const BorderRadius.vertical(top: Radius.circular(28))),
            child: SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 12),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                ListTile(
                    leading:
                        const Icon(Icons.edit_rounded, color: AppTheme.primary),
                    title: const Text('Edit Memory'),
                    onTap: () {
                      Navigator.pop(context);
                      _editMemory();
                    }),
                ListTile(
                    leading: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.error),
                    title: const Text('Delete Memory',
                        style: TextStyle(color: AppTheme.error)),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMemory();
                    }),
                const SizedBox(height: 8),
              ]),
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
        Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppTheme.memoryPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.memory_rounded,
                  size: 18, color: AppTheme.memoryPrimary)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(widget.event.title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.calendar_today_rounded,
              size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text('Visited on ${_formatDate(widget.memory.visitedAt)}',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(width: 12),
          Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.5),
                  shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Icon(Icons.access_time_rounded,
              size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(_formatTime(widget.memory.visitedAt),
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
      ],
    );
  }

  Widget _buildEventInfoCard() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.event_rounded,
                    size: 14, color: AppTheme.primary)),
            const SizedBox(width: 8),
            const Text('Event Details',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
          ]),
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
        ]),
      ),
    );
  }

  Widget _buildExperienceCard() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: AppTheme.memoryPrimary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit_note_rounded,
                    size: 14, color: AppTheme.memoryPrimary)),
            const SizedBox(width: 8),
            const Text('My Experience',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
          ]),
          const SizedBox(height: 12),
          Text(widget.memory.experienceNote,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textSecondary, height: 1.6)),
        ]),
      ),
    );
  }

  Widget _buildMetaCard() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
              child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.photo_library_rounded,
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 4),
              Text('${widget.memory.imageUrls.length}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))
            ]),
            const SizedBox(height: 4),
            Text('Photos',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))
          ])),
          Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.2)),
          Expanded(
              child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.videocam_rounded,
                  size: 16,
                  color: widget.memory.hasVideo
                      ? AppTheme.accent
                      : AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(widget.memory.hasVideo ? '1' : '0',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.memory.hasVideo
                          ? AppTheme.accent
                          : AppTheme.textSecondary))
            ]),
            const SizedBox(height: 4),
            Text('Video',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))
          ])),
          Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.2)),
          Expanded(
              child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(DateFormat('yyyy').format(widget.memory.visitedAt),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))
            ]),
            const SizedBox(height: 4),
            Text('Year',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))
          ])),
        ]),
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                      child: Text('Close',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white))))),
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
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary.withOpacity(0.85)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _AutoPlayProgressBar extends StatefulWidget {
  final Duration duration;
  final VoidCallback onComplete;
  const _AutoPlayProgressBar(
      {required this.duration, required this.onComplete, super.key});

  @override
  State<_AutoPlayProgressBar> createState() => _AutoPlayProgressBarState();
}

class _AutoPlayProgressBarState extends State<_AutoPlayProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
    _controller.addListener(() {
      if (_controller.isCompleted) {
        widget.onComplete();
        _controller.reset();
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: _controller.value,
      backgroundColor: Colors.white.withOpacity(0.3),
      color: Colors.white,
      minHeight: 3,
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isVisible;
  final String title;
  final String location;
  final VoidCallback? onEdit;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  _StickyHeaderDelegate({
    required this.isVisible,
    required this.title,
    required this.location,
    this.onEdit,
    this.onShare,
    this.onDelete,
  });

  @override
  double get minExtent => isVisible ? 70 : 0;
  @override
  double get maxExtent => isVisible ? 70 : 0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    if (!isVisible) return const SizedBox.shrink();
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            border: Border(
                bottom:
                    BorderSide(color: Colors.grey.withOpacity(0.2), width: 1)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(location,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary.withOpacity(0.7)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (onShare != null)
                  IconButton(
                      icon: const Icon(Icons.share_rounded, size: 20),
                      color: AppTheme.primary,
                      onPressed: onShare),
                if (onEdit != null)
                  IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      color: AppTheme.primary,
                      onPressed: onEdit),
                if (onDelete != null)
                  IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: AppTheme.error,
                      onPressed: onDelete),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

// ============================================
// FULL SCREEN GALLERY WIDGET
// ============================================

class FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final VoidCallback onClose;

  const FullScreenGallery({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.onClose,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: _toggleControls,
                child: Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: widget.images[index],
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)),
                      errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image,
                              size: 50, color: Colors.white)),
                    ),
                  ),
                ),
              );
            },
          ),
          // Close button
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  widget.onClose();
                  Navigator.pop(context);
                },
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
          ),
          // Index indicator
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
