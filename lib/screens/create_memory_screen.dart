import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vesak_go/constants.dart';
import '../models/event_model.dart';
import '../services/memory_service.dart';
import '../services/cloudinary_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

class CreateMemoryScreen extends StatefulWidget {
  final EventModel event;
  final bool isEditing;
  final String? existingMemoryId;
  final String? existingNote;
  final List<String>? existingImageUrls;
  final List<String>? existingImagePublicIds;
  final String? existingVideoUrl;
  final String? existingVideoPublicId;

  const CreateMemoryScreen({
    super.key,
    required this.event,
    this.isEditing = false,
    this.existingMemoryId,
    this.existingNote,
    this.existingImageUrls,
    this.existingImagePublicIds,
    this.existingVideoUrl,
    this.existingVideoPublicId,
  });

  @override
  State<CreateMemoryScreen> createState() => _CreateMemoryScreenState();
}

class _CreateMemoryScreenState extends State<CreateMemoryScreen> {
  final MemoryService _memoryService = MemoryService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final SessionService _sessionService = SessionService();

  final TextEditingController _noteController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<String> _existingImageUrls = [];
  final List<String> _existingImagePublicIds = [];
  File? _selectedVideo;
  String? _existingVideoUrl;
  String? _existingVideoPublicId;

  bool _isLoading = false;
  bool _isSaving = false;

  static const int _maxImages = 3;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    if (widget.isEditing) {
      _noteController.text = widget.existingNote ?? '';
      _existingImageUrls.addAll(widget.existingImageUrls ?? []);
      _existingImagePublicIds.addAll(widget.existingImagePublicIds ?? []);
      _existingVideoUrl = widget.existingVideoUrl;
      _existingVideoPublicId = widget.existingVideoPublicId;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= _maxImages) {
      _showSnack('Maximum $_maxImages images allowed', Icons.warning_rounded);
      return;
    }

    final file = await _cloudinaryService.pickImage();
    if (file != null) {
      setState(() {
        _selectedImages.add(file);
      });
    }
  }

  void _removeImage(int index,
      {bool isExisting = false, int existingIndex = 0}) {
    setState(() {
      if (isExisting) {
        _existingImageUrls.removeAt(existingIndex);
        _existingImagePublicIds.removeAt(existingIndex);
      } else {
        _selectedImages.removeAt(index);
      }
    });
  }

  Future<void> _pickVideo() async {
    if (_selectedVideo != null || _existingVideoUrl != null) {
      _showSnack('Only one video allowed', Icons.warning_rounded);
      return;
    }

    final file = await _cloudinaryService.pickVideo();
    if (file != null) {
      setState(() {
        _selectedVideo = file;
      });
    }
  }

  void _removeVideo() {
    setState(() {
      _selectedVideo = null;
      _existingVideoUrl = null;
      _existingVideoPublicId = null;
    });
  }

  Future<void> _saveMemory() async {
    if (_noteController.text.trim().isEmpty) {
      _showSnack('Please write your experience', Icons.edit_note_rounded);
      return;
    }

    setState(() => _isSaving = true);

    // Upload new images
    List<String> finalImageUrls = List.from(_existingImageUrls);
    List<String> finalImagePublicIds = List.from(_existingImagePublicIds);

    if (_selectedImages.isNotEmpty) {
      final results = await _cloudinaryService.uploadMultipleImages(
          _selectedImages, 'memories/${widget.event.id}');
      for (final result in results) {
        if (result != null) {
          finalImageUrls.add(_cloudinaryService.extractUrl(result));
          finalImagePublicIds.add(_cloudinaryService.extractPublicId(result));
        }
      }
    }

    // Upload new video
    String finalVideoUrl = _existingVideoUrl ?? '';
    String finalVideoPublicId = _existingVideoPublicId ?? '';

    if (_selectedVideo != null) {
      final result = await _cloudinaryService.uploadVideo(
          _selectedVideo!, 'memories/${widget.event.id}');
      if (result != null) {
        finalVideoUrl = _cloudinaryService.extractUrl(result);
        finalVideoPublicId = _cloudinaryService.extractPublicId(result);
      }
    }

    bool success;
    final userId = _sessionService.currentUser!.id;

    if (widget.isEditing && widget.existingMemoryId != null) {
      success = await _memoryService.updateMemory(
        memoryId: widget.existingMemoryId!,
        experienceNote: _noteController.text.trim(),
        imageUrls: finalImageUrls,
        imagePublicIds: finalImagePublicIds,
        videoUrl: finalVideoUrl,
        videoPublicId: finalVideoPublicId,
      );
    } else {
      success = await _memoryService.createMemory(
        eventId: widget.event.id,
        userId: userId,
        experienceNote: _noteController.text.trim(),
        imageUrls: finalImageUrls,
        imagePublicIds: finalImagePublicIds,
        videoUrl: finalVideoUrl,
        videoPublicId: finalVideoPublicId,
      );
    }

    setState(() => _isSaving = false);

    if (success) {
      _showSnack(widget.isEditing ? 'Memory updated! ✨' : 'Memory saved! ✨',
          Icons.check_circle_rounded,
          isSuccess: true);
      Navigator.pop(context, true);
    } else {
      _showSnack('Failed to save memory', Icons.error_outline_rounded,
          isError: true);
    }
  }

  void _showSnack(String message, IconData icon,
      {bool isSuccess = false, bool isError = false}) {
    final color = isError
        ? AppTheme.error
        : isSuccess
            ? AppTheme.success
            : AppTheme.primary;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message))
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM d, yyyy · h:mm a');
    final eventDate = DateTime.tryParse(widget.event.date) ?? DateTime.now();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _buildAmbientBlobs(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildEventInfoCard(eventDate, dateFormat),
                        const SizedBox(height: 16),
                        _buildExperienceCard(),
                        const SizedBox(height: 16),
                        _buildMediaCard(),
                        const SizedBox(height: 24),
                        _buildSaveButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBlobs() {
    return Stack(
      children: [
        Positioned(
            top: -60,
            left: -60,
            child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withOpacity(0.12)))),
        Positioned(
            top: 100,
            right: -80,
            child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withOpacity(0.10)))),
        Positioned(
            bottom: -80,
            left: 60,
            child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.blobEmerald.withOpacity(0.08)))),
      ],
    );
  }

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withOpacity(0.35), width: 1))),
          child: Row(
            children: [
              _Glass(
                child: IconButton(
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: AppTheme.primary,
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(widget.isEditing ? 'Edit Memory' : 'Add Memory',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventInfoCard(DateTime eventDate, DateFormat dateFormat) {
    final catColor = AppConstants.getCategoryColor(widget.event.category);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.60),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withOpacity(0.55), width: 1)),
          child: Row(
            children: [
              Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                      color: catColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(
                      child: Text(widget.event.getMarkerIcon(),
                          style: const TextStyle(fontSize: 24)))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.event.title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('${dateFormat.format(eventDate)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary.withOpacity(0.8))),
                      Text(widget.event.location,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary.withOpacity(0.8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExperienceCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.60),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withOpacity(0.55), width: 1)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.edit_note_rounded,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('Your Experience',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary))
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Write about your experience...',
                  hintStyle:
                      TextStyle(color: AppTheme.textSecondary.withOpacity(0.6)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.5))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.5))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppTheme.primary, width: 1.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.70),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.bottomRight,
                  child: Text('${_noteController.text.length}/500',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary.withOpacity(0.6)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCard() {
    final totalImages = _existingImageUrls.length + _selectedImages.length;
    final hasVideo = _selectedVideo != null ||
        (_existingVideoUrl != null && _existingVideoUrl!.isNotEmpty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.60),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withOpacity(0.55), width: 1)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.photo_library_rounded,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('Photos (Max $_maxImages)',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary))
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (totalImages < _maxImages) _buildAddImageButton(),
                    ..._existingImageUrls.asMap().entries.map((entry) =>
                        _buildImageItem(entry.value,
                            isExisting: true, index: entry.key)),
                    ..._selectedImages.asMap().entries.map((entry) =>
                        _buildImageItem(entry.value.path,
                            imageFile: _selectedImages[entry.key],
                            index: entry.key)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.grey.withOpacity(0.2)),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.videocam_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('Video (Optional)',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary))
              ]),
              const SizedBox(height: 12),
              if (!hasVideo) _buildAddVideoButton() else _buildVideoPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.primary.withOpacity(0.3),
                width: 1.5,
                style: BorderStyle.solid)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_a_photo, size: 28, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text('Add', style: TextStyle(fontSize: 12, color: AppTheme.primary))
        ]),
      ),
    );
  }

  Widget _buildImageItem(String url,
      {bool isExisting = false, File? imageFile, required int index}) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12), color: Colors.grey[200]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isExisting
                ? Image.network(url,
                    fit: BoxFit.cover,
                    width: 100,
                    height: 100,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.broken_image, size: 40, color: Colors.grey))
                : Image.file(imageFile!,
                    fit: BoxFit.cover, width: 100, height: 100),
          ),
        ),
        Positioned(
          top: 4,
          right: 8,
          child: GestureDetector(
            onTap: () => _removeImage(index,
                isExisting: isExisting, existingIndex: index),
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddVideoButton() {
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.primary.withOpacity(0.3), width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.play_circle_outline, size: 28, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text('Add Video (Max 30 sec)',
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w500))
        ]),
      ),
    );
  }

  Widget _buildVideoPreview() {
    String? previewUrl;
    if (_selectedVideo != null) {
      previewUrl = _selectedVideo!.path;
    } else if (_existingVideoUrl != null && _existingVideoUrl!.isNotEmpty) {
      previewUrl = _existingVideoUrl;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1)),
      child: Row(
        children: [
          Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.play_circle_filled,
                  size: 40, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
              child: Text('Video attached',
                  style: TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
          GestureDetector(
              onTap: _removeVideo,
              child: const Icon(Icons.close, size: 20, color: AppTheme.error)),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveMemory,
        style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(widget.isEditing ? 'Update Memory' : 'Save Memory',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  const _Glass({required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withOpacity(0.35), width: 1)),
            child: child),
      ),
    );
  }
}
