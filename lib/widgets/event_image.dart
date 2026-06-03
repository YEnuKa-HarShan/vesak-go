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

  const EventImage({
    super.key,
    this.imageUrl,
    required this.category,
    this.width = double.infinity,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: AppTheme.sand,
          child: Center(
            child: CircularProgressIndicator(
              color: AppTheme.gold,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallbackImage(),
      );
    } else {
      return _buildFallbackImage();
    }
  }

  Widget _buildFallbackImage() {
    final color = AppConstants.getCategoryColor(category);
    final icon = AppConstants.getCategoryIcon(category);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.7)],
        ),
      ),
      child: Center(
        child: Text(
          icon,
          style: const TextStyle(fontSize: 64),
        ),
      ),
    );
  }
}
