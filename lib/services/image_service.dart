import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  Future<File?> pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
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

  Future<String?> uploadImage(File imageFile, String eventId) async {
    try {
      final compressedFile = await compressImage(imageFile);
      final fileExtension = compressedFile.path.split('.').last;
      final fileName = 'events/$eventId/${_uuid.v4()}.$fileExtension';

      await _supabase.storage.from('event-images').upload(
            fileName,
            compressedFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final publicUrl =
          _supabase.storage.from('event-images').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<bool> deleteImage(String publicUrl) async {
    try {
      final path = publicUrl.split('/event-images/').last;
      await _supabase.storage.from('event-images').remove([path]);
      return true;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  Future<String?> updateImage(
      File imageFile, String eventId, String? oldPublicId) async {
    try {
      if (oldPublicId != null && oldPublicId.isNotEmpty) {
        await deleteImage(oldPublicId);
      }
      return await uploadImage(imageFile, eventId);
    } catch (e) {
      print('Error updating image: $e');
      return null;
    }
  }
}
