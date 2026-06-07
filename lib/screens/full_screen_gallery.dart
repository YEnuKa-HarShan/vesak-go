import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

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
  bool _isLoading = false;

  static const int _visibleThumbnails = 5;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  int get _startIndex {
    final half = _visibleThumbnails ~/ 2;
    int start = _currentIndex - half;
    if (start < 0) start = 0;
    if (start > widget.images.length - _visibleThumbnails) {
      start = widget.images.length - _visibleThumbnails;
    }
    return start.clamp(0, widget.images.length - 1);
  }

  List<int> get _visibleIndices {
    final end = (_startIndex + _visibleThumbnails - 1)
        .clamp(0, widget.images.length - 1);
    return List.generate(end - _startIndex + 1, (i) => _startIndex + i);
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _jumpToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _shareImage() async {
    final imageUrl = widget.images[_currentIndex];
    setState(() => _isLoading = true);

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/vesakgo_share_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles(
          [XFile(tempFile.path)],
          text: 'Check out this beautiful memory from VesakGO! 🌼✨',
          sharePositionOrigin: Rect.zero,
        );

        await tempFile.delete();
      }
    } catch (e) {
      _showSnackBar('Failed to share image', Icons.error_outline);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadImage() async {
    final imageUrl = widget.images[_currentIndex];
    setState(() => _isLoading = true);

    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          _showSnackBar('Storage permission required', Icons.lock_outline);
          setState(() => _isLoading = false);
          return;
        }
      }

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final fileName = 'vesakgo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        _showSnackBar('Image saved to device', Icons.check_circle);
      }
    } catch (e) {
      _showSnackBar('Failed to save image', Icons.error_outline);
    } finally {
      setState(() => _isLoading = false);
    }
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
        backgroundColor: AppTheme.memoryPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getOriginalQualityUrl(String url) {
    if (url.contains('cloudinary.com')) {
      String cleanUrl = url.replaceAll(RegExp(r'/[qc]_\d+'), '');
      if (cleanUrl.contains('?')) {
        return '$cleanUrl&q=100';
      } else {
        return '$cleanUrl?q=100';
      }
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView for swiping
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: _toggleControls,
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    child: CachedNetworkImage(
                      imageUrl: _getOriginalQualityUrl(widget.images[index]),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Failed to load image',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Top Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: _showControls ? 0 : -80,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    // Close button
                    GestureDetector(
                      onTap: () {
                        widget.onClose();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 24),
                      ),
                    ),
                    const Spacer(),
                    // Share button
                    GestureDetector(
                      onTap: _shareImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Download button
                    GestureDetector(
                      onTap: _downloadImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.download,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Controls Pill
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: _showControls ? 100 : -80,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Previous button
                    GestureDetector(
                      onTap: _goToPrevious,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          color: _currentIndex > 0
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Dot indicators
                    ...List.generate(
                      widget.images.length > 5 ? 5 : widget.images.length,
                      (index) {
                        final isActive = index == _currentIndex;
                        final isNearActive = (_currentIndex - index).abs() <= 2;
                        if (!isNearActive && widget.images.length > 5)
                          return const SizedBox.shrink();
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isActive ? 10 : 6,
                          height: isActive ? 10 : 6,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.4),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    // Counter text
                    Text(
                      '${_currentIndex + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Next button
                    GestureDetector(
                      onTap: _goToNext,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: _currentIndex < widget.images.length - 1
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Centered Thumbnail Strip - Carousel Style
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: _showControls ? 20 : -100,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                child: Row(
                  key: ValueKey(_startIndex),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _visibleIndices.map((index) {
                    final isActive = index == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 66 : 60,
                      height: isActive ? 66 : 60,
                      child: GestureDetector(
                        onTap: () => _jumpToPage(index),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? AppTheme.memoryPrimary
                                  : Colors.white.withOpacity(0.3),
                              width: isActive ? 2 : 1,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: AppTheme.memoryPrimary
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl:
                                  _getOriginalQualityUrl(widget.images[index]),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey[800],
                                child: const Icon(Icons.broken_image,
                                    size: 24, color: Colors.white54),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Processing...',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
