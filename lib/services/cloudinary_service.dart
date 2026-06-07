import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  final String _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  final String _uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  final _uuid = const Uuid();

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
  // IMAGE COMPRESSION
  // ============================================

  Future<File> compressImage(File imageFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${_uuid.v4()}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: 85,
        minWidth: 800,
        minHeight: 800,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        return File(result.path);
      }
      return imageFile;
    } catch (e) {
      print('Error compressing image: $e');
      return imageFile;
    }
  }

  // ============================================
  // UPLOAD IMAGES
  // ============================================

  Future<String?> uploadImage(File imageFile, String folder) async {
    try {
      final compressedFile = await compressImage(imageFile);

      final url =
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/upload');
      final request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'vesakgo/$folder';
      request.files
          .add(await http.MultipartFile.fromPath('file', compressedFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        final secureUrl = jsonMap['secure_url'] as String;
        final publicId = jsonMap['public_id'] as String;

        return '$secureUrl|$publicId';
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<List<String>> uploadMultipleImages(
      List<File> images, String folder) async {
    final List<String> results = [];
    for (final image in images) {
      final result = await uploadImage(image, folder);
      if (result != null) {
        results.add(result);
      }
    }
    return results;
  }

  // ============================================
  // UPLOAD VIDEO
  // ============================================

  Future<String?> uploadVideo(File videoFile, String folder) async {
    try {
      final url =
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/video/upload');
      final request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'vesakgo/$folder';
      request.fields['resource_type'] = 'video';
      request.files
          .add(await http.MultipartFile.fromPath('file', videoFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        final secureUrl = jsonMap['secure_url'] as String;
        final publicId = jsonMap['public_id'] as String;

        return '$secureUrl|$publicId';
      }
      return null;
    } catch (e) {
      print('Error uploading video: $e');
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
