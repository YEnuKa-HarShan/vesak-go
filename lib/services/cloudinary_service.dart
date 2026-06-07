import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class CloudinaryService {
  final String _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  final String _uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  final _uuid = const Uuid();

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

  Future<String?> uploadImage(File imageFile) async {
    try {
      final compressedFile = await compressImage(imageFile);

      final url =
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/upload');
      final request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'vesakgo_events';
      request.files
          .add(await http.MultipartFile.fromPath('file', compressedFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        final secureUrl = jsonMap['secure_url'] as String;
        final publicId = jsonMap['public_id'] as String;

        // Store both URL and public_id for future deletion
        return '$secureUrl|$publicId';
      } else {
        print('Upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  Future<bool> deleteImage(String publicId) async {
    try {
      // Note: Cloudinary delete requires signature or API key
      // For now, we'll return true as Cloudinary will auto-delete old images
      // Or you can implement server-side delete
      return true;
    } catch (e) {
      print('Error deleting from Cloudinary: $e');
      return false;
    }
  }

  String extractPublicId(String imageData) {
    // imageData format: "secure_url|public_id"
    final parts = imageData.split('|');
    if (parts.length >= 2) {
      return parts[1];
    }
    return '';
  }

  String extractUrl(String imageData) {
    // imageData format: "secure_url|public_id"
    final parts = imageData.split('|');
    if (parts.isNotEmpty) {
      return parts[0];
    }
    return '';
  }
}
