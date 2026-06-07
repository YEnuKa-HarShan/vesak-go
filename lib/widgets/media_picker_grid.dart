import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class MediaPickerGrid extends StatelessWidget {
  final List<File> selectedImages;
  final List<String> existingImageUrls;
  final Map<int, double> uploadProgress;
  final int maxImages;
  final VoidCallback onAddImage;
  final Function(int, bool, int) onRemoveImage;

  const MediaPickerGrid({
    super.key,
    required this.selectedImages,
    required this.existingImageUrls,
    required this.uploadProgress,
    this.maxImages = 3,
    required this.onAddImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    final totalImages = existingImageUrls.length + selectedImages.length;

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (totalImages < maxImages) _buildAddButton(),
          ...existingImageUrls
              .asMap()
              .entries
              .map((entry) => _buildExistingImageItem(entry.value, entry.key)),
          ...selectedImages.asMap().entries.map((entry) => _buildNewImageItem(
              selectedImages[entry.key],
              entry.key,
              uploadProgress[entry.key] ?? 0)),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: onAddImage,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppTheme.memoryPrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.memoryPrimary.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate,
                size: 28, color: AppTheme.memoryPrimary),
            const SizedBox(height: 4),
            Text('Add Photos',
                style: TextStyle(fontSize: 12, color: AppTheme.memoryPrimary)),
            Text('(Max $maxImages)',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingImageItem(String url, int index) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: 100,
              height: 100,
              errorWidget: (_, __, ___) =>
                  Icon(Icons.broken_image, size: 40, color: Colors.grey),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 8,
          child: GestureDetector(
            onTap: () => onRemoveImage(index, true, index),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewImageItem(File imageFile, int index, double progress) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(imageFile,
                fit: BoxFit.cover, width: 100, height: 100),
          ),
        ),
        if (progress < 1.0 && progress > 0)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (progress >= 1.0)
          Positioned(
            top: 4,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
          ),
        Positioned(
          top: 4,
          right: 8,
          child: GestureDetector(
            onTap: () => onRemoveImage(index, false, index),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
