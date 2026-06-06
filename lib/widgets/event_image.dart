import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../constants.dart';

class EventImage extends StatelessWidget {
  final String? imageUrl;
  final String category;
  final double width;
  final double height;
  final BoxFit fit;
  final bool isFullScreen;
  final VoidCallback? onTap;

  const EventImage({
    super.key,
    this.imageUrl,
    required this.category,
    this.width = double.infinity,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.isFullScreen = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppConstants.getCategoryColor(category);
    final icon = AppConstants.getCategoryIcon(category);

    final br = BorderRadius.circular(isFullScreen ? 0 : 20);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: br,
          boxShadow: isFullScreen
              ? null
              : [
                  BoxShadow(
                    color: categoryColor.withOpacity(0.20),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: br,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Main Image / Fallback ──
              _buildImageLayer(categoryColor, icon),

              // ── Gradient scrim ──
              _buildScrim(),

              // ── Glass corner shimmer (non-fullscreen only) ──
              if (!isFullScreen) _buildCornerShimmer(categoryColor),

              // ── Full-screen overlays ──
              if (isFullScreen) ...[
                _buildFullScreenBadges(icon),
              ],

              // ── Loading / tap ripple border ──
              if (!isFullScreen)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: br,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1,
                      ),
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
  // IMAGE LAYER
  // ─────────────────────────────────────────────

  Widget _buildImageLayer(Color categoryColor, String icon) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) =>
            _buildPlaceholder(categoryColor, icon, loading: true),
        errorWidget: (_, __, ___) => _buildPlaceholder(categoryColor, icon,
            errorText: 'Image not available'),
      );
    }
    return _buildPlaceholder(categoryColor, icon);
  }

  Widget _buildPlaceholder(
    Color color,
    String icon, {
    bool loading = false,
    String? errorText,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.75),
            color.withOpacity(0.50),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Watermark emoji
          Align(
            alignment: const Alignment(0.80, -0.55),
            child: Opacity(
              opacity: 0.15,
              child: Text(icon, style: const TextStyle(fontSize: 90)),
            ),
          ),
          // Centre content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white70,
                    ),
                  )
                else ...[
                  Text(icon, style: const TextStyle(fontSize: 48)),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                                width: 1),
                          ),
                          child: Text(
                            errorText,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.80),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // GRADIENT SCRIM
  // ─────────────────────────────────────────────

  Widget _buildScrim() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isFullScreen
              ? [
                  Colors.black.withOpacity(0.10),
                  Colors.transparent,
                  Colors.black.withOpacity(0.45),
                  Colors.black.withOpacity(0.65),
                ]
              : [
                  Colors.black.withOpacity(0.05),
                  Colors.transparent,
                  Colors.black.withOpacity(0.25),
                ],
          stops: isFullScreen
              ? const [0.0, 0.30, 0.70, 1.0]
              : const [0.0, 0.40, 1.0],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // CORNER SHIMMER  (non-fullscreen only)
  // ─────────────────────────────────────────────

  Widget _buildCornerShimmer(Color color) {
    return Positioned(
      top: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(50),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 60,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              border: Border(
                left:
                    BorderSide(color: Colors.white.withOpacity(0.14), width: 1),
                bottom:
                    BorderSide(color: Colors.white.withOpacity(0.14), width: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FULL-SCREEN BADGES
  // ─────────────────────────────────────────────

  Widget _buildFullScreenBadges(String icon) {
    return Stack(
      children: [
        // Category badge — bottom-left (glass style)
        Positioned(
          bottom: 16,
          left: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.20), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Photo count badge — bottom-right (glass style)
        Positioned(
          bottom: 16,
          right: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.20), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_rounded,
                        size: 12, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      '1 / 1',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
