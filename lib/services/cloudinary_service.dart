import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

class CompressionConfig {
  final int maxWidth;
  final int maxHeight;
  final int quality;
  final String format;

  const CompressionConfig({
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
    this.format = 'jpeg',
  });

  // Event thumbnail (displayed in lists, cards)
  static const eventThumbnail = CompressionConfig(
    maxWidth: 400,
    maxHeight: 400,
    quality: 75,
  );

  // Memory images (full quality for details screen)
  static const memoryImage = CompressionConfig(
    maxWidth: 1200,
    maxHeight: 1200,
    quality: 85,
  );

  // Large images (>10MB) - aggressive compression
  static const largeImage = CompressionConfig(
    maxWidth: 1024,
    maxHeight: 1024,
    quality: 70,
  );

  // Video thumbnail
  static const videoThumbnail = CompressionConfig(
    maxWidth: 300,
    maxHeight: 300,
    quality: 70,
  );
}

class CloudinaryService {
  final String _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  final String _uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  final _uuid = const Uuid();

  // Progress callback
  Function(double progress, String status)? onProgress;

  // ============================================
  // PICK IMAGES/VIDEOS
  // ============================================

  Future<File?> pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  Future<File?> pickVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('Error picking video: $e');
      return null;
    }
  }

  // ============================================
  // SMART COMPRESSION
  // ============================================

  Future<File> compressWithStrategy(File file, String type) async {
    final sizeInMB = await file.length() / (1024 * 1024);

    CompressionConfig config;

    if (type == 'event_thumbnail') {
      config = CompressionConfig.eventThumbnail;
    } else if (type == 'memory_image') {
      if (sizeInMB >= 10) {
        config = CompressionConfig.largeImage;
      } else {
        config = CompressionConfig.memoryImage;
      }
    } else if (type == 'video_thumbnail') {
      config = CompressionConfig.videoThumbnail;
    } else {
      config = CompressionConfig.eventThumbnail;
    }

    return await compressImage(file, config);
  }

  Future<File> compressImage(File imageFile, CompressionConfig config) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${_uuid.v4()}.${config.format}';

      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: config.quality,
        minWidth: config.maxWidth,
        minHeight: config.maxHeight,
        format:
            config.format == 'jpeg' ? CompressFormat.jpeg : CompressFormat.png,
      );

      if (result != null) {
        final compressedFile = File(result.path);
        final originalSize = await imageFile.length();
        final compressedSize = await compressedFile.length();
        print(
            'Compression: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB → ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB');
        return compressedFile;
      }
      return imageFile;
    } catch (e) {
      print('Error compressing image: $e');
      return imageFile;
    }
  }

  // ============================================
  // UPLOAD IMAGES WITH PROGRESS
  // ============================================

  Future<String?> uploadImage(File imageFile, String folder,
      {String? type}) async {
    try {
      final compressType = type ?? 'memory_image';
      onProgress?.call(0.2, 'Compressing image...');

      final compressedFile =
          await compressWithStrategy(imageFile, compressType);

      onProgress?.call(0.4, 'Uploading to Cloudinary...');

      final url =
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/upload');
      final request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'vesakgo/$folder';
      request.files
          .add(await http.MultipartFile.fromPath('file', compressedFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        onProgress?.call(0.9, 'Finalizing...');
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        final secureUrl = jsonMap['secure_url'] as String;
        final publicId = jsonMap['public_id'] as String;

        onProgress?.call(1.0, 'Complete!');
        return '$secureUrl|$publicId';
      }
      onProgress?.call(0, 'Upload failed');
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      onProgress?.call(0, 'Error: $e');
      return null;
    }
  }

  Future<List<String>> uploadMultipleImages(
      List<File> images,
      String folder,
      Function(int current, int total, double progress)?
          onImageProgress) async {
    final List<String> results = [];
    int completed = 0;

    for (final image in images) {
      final result = await uploadImage(image, folder);
      if (result != null) {
        results.add(result);
      }
      completed++;
      if (onImageProgress != null) {
        onImageProgress(completed, images.length, completed / images.length);
      }
    }
    return results;
  }

  // ============================================
  // UPLOAD VIDEO WITH PROGRESS
  // ============================================

  Future<String?> uploadVideo(File videoFile, String folder,
      {Function(double)? onVideoProgress}) async {
    try {
      onVideoProgress?.call(0.1);

      final url =
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/video/upload');
      final request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'vesakgo/$folder';
      request.fields['resource_type'] = 'video';
      request.files
          .add(await http.MultipartFile.fromPath('file', videoFile.path));

      onVideoProgress?.call(0.3);

      final response = await request.send();

      if (response.statusCode == 200) {
        onVideoProgress?.call(0.8);
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        final secureUrl = jsonMap['secure_url'] as String;
        final publicId = jsonMap['public_id'] as String;

        onVideoProgress?.call(1.0);
        return '$secureUrl|$publicId';
      }
      onVideoProgress?.call(0);
      return null;
    } catch (e) {
      print('Error uploading video: $e');
      onVideoProgress?.call(0);
      return null;
    }
  }

  // ============================================
  // DELETE FILES
  // ============================================

  Future<bool> deleteFile(String publicId) async {
    try {
      print('Delete requested for: $publicId');
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  String extractUrl(String data) {
    final parts = data.split('|');
    return parts.isNotEmpty ? parts[0] : '';
  }

  String extractPublicId(String data) {
    final parts = data.split('|');
    return parts.length > 1 ? parts[1] : '';
  }
}
