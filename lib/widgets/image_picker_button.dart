import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

class ImagePickerButton extends StatelessWidget {
  final File? selectedImage;
  final ValueChanged<File?> onImagePicked;
  final VoidCallback onRemoveImage;
  final double size;

  const ImagePickerButton({
    super.key,
    this.selectedImage,
    required this.onImagePicked,
    required this.onRemoveImage,
    this.size = 100,
  });

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      onImagePicked(File(pickedFile.path));
    }
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Image',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
            ),
            const Divider(color: AppTheme.sand, height: 24),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.saffron),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.saffron),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showPickerOptions(context),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.sand,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.saffron, width: 2),
            ),
            child: selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      selectedImage!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 32,
                        color: AppTheme.saffron,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add Image',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.saffron,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (selectedImage != null)
          TextButton(
            onPressed: onRemoveImage,
            child: const Text(
              'Remove Image',
              style: TextStyle(color: AppTheme.maroon),
            ),
          ),
      ],
    );
  }
}
