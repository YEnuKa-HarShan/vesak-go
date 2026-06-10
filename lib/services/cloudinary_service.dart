import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';

class CloudinaryService {
  final _uuid = const Uuid();

  // Progress callback
  Function(double progress, String status)? onProgress;

  // ============================================
  // GET SIGNED UPLOAD PARAMS FROM BACKEND
  // ============================================

  Future<Map<String, dynamic>?> getSignedUploadParams({
    required String userId,
    String? folder,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/upload/signature'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'folder': folder,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      } else {
        print('Get signed params error: ${data['error']}');
        return null;
      }
    } catch (e) {
      print('Get signed params exception: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMemorySignedUploadParams({
    required String userId,
    required String eventId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/upload/memory-signature'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'eventId': eventId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      } else {
        print('Get memory signed params error: ${data['error']}');
        return null;
      }
    } catch (e) {
      print('Get memory signed params exception: $e');
      return null;
    }
  }

  // ============================================
  // UPLOAD IMAGE WITH SIGNED PARAMS
  // ============================================

  Future<String?> uploadImageWithSignature({
    required File imageFile,
    required String userId,
    String? customFolder,
    String? type, // 'event' or 'memory'
    required String eventId, // for memory uploads
  }) async {
    try {
      onProgress?.call(0.1, 'Getting upload authorization...');

      // Get signed params from backend
      Map<String, dynamic>? signedParams;

      if (type == 'memory' && eventId.isNotEmpty) {
        signedParams = await getMemorySignedUploadParams(
          userId: userId,
          eventId: eventId,
        );
      } else {
        signedParams = await getSignedUploadParams(
          userId: userId,
          folder: customFolder,
        );
      }

      if (signedParams == null) {
        onProgress?.call(0, 'Failed to get upload authorization');
        return null;
      }

      onProgress?.call(0.2, 'Compressing image...');

      // Compress image
      final compressedFile = await compressImage(imageFile);

      onProgress?.call(0.4, 'Uploading to Cloudinary...');

      // Upload to Cloudinary with signature
      final cloudName = signedParams['cloudName'];
      final uploadUrl =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/upload');

      final request = http.MultipartRequest('POST', uploadUrl);

      // Add signed parameters
      request.fields['api_key'] = signedParams['apiKey'];
      request.fields['timestamp'] = signedParams['timestamp'].toString();
      request.fields['signature'] = signedParams['signature'];
      request.fields['folder'] = signedParams['folder'];
      request.fields['allowed_formats'] =
          signedParams['allowedFormats'].join(',');
      request.fields['max_bytes'] = signedParams['maxBytes'].toString();

      // Add file
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
      } else {
        onProgress?.call(0, 'Upload failed');
        return null;
      }
    } catch (e) {
      print('Error uploading image with signature: $e');
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
  // PICK IMAGE
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

  // ============================================
  // LEGACY METHODS (for backward compatibility)
  // ============================================

  // This method is kept for compatibility but uses new signature method internally
  Future<String?> uploadImage(File imageFile, String folder,
      {String? type}) async {
    // Extract userId from folder or use default
    final userId = folder.split('/').first;
    return await uploadImageWithSignature(
      imageFile: imageFile,
      userId: userId,
      customFolder: folder,
      type: type,
      eventId: '',
    );
  }

  String extractUrl(String data) {
    final parts = data.split('|');
    return parts.isNotEmpty ? parts[0] : '';
  }

  String extractPublicId(String data) {
    final parts = data.split('|');
    return parts.length > 1 ? parts[1] : '';
  }

  Future<bool> deleteFile(String publicId) async {
    try {
      print('Delete requested for: $publicId');
      // Delete will be handled by backend in future
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }
}
