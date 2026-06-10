import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import 'session_service.dart';

class UploadService {
  final _uuid = const Uuid();
  final SessionService _sessionService = SessionService();

  // Progress callback
  Function(double progress, String status)? onProgress;

  // ============================================
  // MAIN UPLOAD METHOD (Server-side)
  // ============================================

  Future<Map<String, String>?> uploadImage({
    required File imageFile,
    required String userId,
    String? type, // 'event' or 'memory'
    String? eventId, // Required for memory uploads
  }) async {
    try {
      // Step 1: Compress image
      onProgress?.call(0.1, 'Compressing image...');
      final compressedFile = await compressImage(imageFile);

      // Get file size for logging
      final originalSize = await imageFile.length();
      final compressedSize = await compressedFile.length();
      print(
          'Compression: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB → ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB');

      // Step 2: Prepare multipart request
      onProgress?.call(0.3, 'Preparing upload...');

      final uri = Uri.parse('${AppConstants.apiBaseUrl}/upload/image');
      final request = http.MultipartRequest('POST', uri);

      // Add headers with authentication
      request.headers['Content-Type'] = 'multipart/form-data';
      request.headers['X-User-Id'] = userId;

      // Add form fields
      request.fields['userId'] = userId;
      request.fields['type'] = type ?? 'event';
      if (eventId != null && eventId.isNotEmpty) {
        request.fields['eventId'] = eventId;
      }

      // Add image file
      onProgress?.call(0.5, 'Uploading to server...');
      final multipartFile = await http.MultipartFile.fromPath(
        'image',
        compressedFile.path,
      );
      request.files.add(multipartFile);

      // Step 3: Send request
      final streamedResponse = await request.send();

      // Step 4: Read response
      final responseBody = await streamedResponse.stream.bytesToString();
      final response = jsonDecode(responseBody);

      // Step 5: Handle response
      if (streamedResponse.statusCode == 200 && response['success'] == true) {
        onProgress?.call(1.0, 'Complete!');
        return {
          'url': response['data']['url'],
          'publicId': response['data']['publicId'],
        };
      } else {
        final errorMsg = response['error'] ?? 'Unknown error';
        print('Upload failed: $errorMsg');
        onProgress?.call(0, 'Failed: $errorMsg');
        return null;
      }
    } catch (e) {
      print('Upload error: $e');
      onProgress?.call(0, 'Error: $e');
      return null;
    }
  }

  // ============================================
  // COMPRESSION
  // ============================================

  Future<File> compressImage(File imageFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${_uuid.v4()}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: 80,
        minWidth: 1200,
        minHeight: 1200,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final compressedFile = File(result.path);
        if (await compressedFile.exists()) {
          return compressedFile;
        }
      }
      return imageFile;
    } catch (e) {
      print('Compression error: $e');
      return imageFile;
    }
  }

  // ============================================
  // IMAGE PICKER
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

  Future<List<File>> pickMultipleImages({int maxCount = 3}) async {
    try {
      final picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final files = pickedFiles
            .take(maxCount)
            .map((xfile) => File(xfile.path))
            .toList();
        if (pickedFiles.length > maxCount) {
          print('Only first $maxCount images will be used');
        }
        return files;
      }
      return [];
    } catch (e) {
      print('Error picking multiple images: $e');
      return [];
    }
  }

  // ============================================
  // DELETE FILE (via backend)
  // ============================================

  Future<bool> deleteFile(String publicId, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.apiBaseUrl}/upload/image/$publicId'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': userId,
        },
      );

      final data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Delete error: $e');
      return false;
    }
  }
}
