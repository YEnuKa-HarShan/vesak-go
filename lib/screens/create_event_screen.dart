import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../services/cloudinary_service.dart';
import '../models/event_model.dart';
import '../constants.dart';
import '../theme/app_theme.dart';

class _Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final double blur;
  final double opacity;
  final Border? border;

  const _Glass({
    required this.child,
    this.borderRadius,
    this.padding,
    this.tint = Colors.white,
    this.blur = 18,
    this.opacity = 0.10,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withOpacity(opacity),
            borderRadius: br,
            border: border ??
                Border.all(color: Colors.white.withOpacity(0.18), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class CreateEventScreen extends StatefulWidget {
  final String userId;
  final String userFirstName;
  final EventModel? editEvent;

  const CreateEventScreen({
    super.key,
    required this.userId,
    required this.userFirstName,
    this.editEvent,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final LocationService _locationService = LocationService();
  final SessionService _sessionService = SessionService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  String? _selectedCategory;
  String? _selectedFoodType;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _locationController = TextEditingController();
  File? _selectedImage;
  String? _existingImageUrl;
  String? _existingImagePublicId;

  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _isEditMode = false;
  int _currentStep = 0;

  late AnimationController _fadeController;
  static const int _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _isEditMode = widget.editEvent != null;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();

    if (_isEditMode) {
      _loadEventData();
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _loadEventData() {
    final event = widget.editEvent!;
    _selectedCategory = event.category;
    _selectedFoodType = event.foodType != 'none' ? event.foodType : null;
    _titleController.text = event.title;
    _descriptionController.text = event.description ?? '';
    _locationController.text = event.location;
    _existingImageUrl = event.imageUrl;
    _existingImagePublicId = event.imagePublicId;

    try {
      _selectedDate = DateTime.parse(event.date);
    } catch (_) {}

    try {
      final timeStr = event.time.toLowerCase();
      final isPM = timeStr.contains('pm');
      final parts = timeStr.replaceAll(RegExp(r'[apm]'), '').trim().split(':');
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    } catch (_) {}
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    final location = await _locationService.getCurrentLocation();
    setState(() {
      _locationController.text = location;
      _isGettingLocation = false;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          buttonTheme:
              const ButtonThemeData(textTheme: ButtonTextTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedCategory == null) {
        _showSnack('Please select a category', Icons.category_rounded);
        return;
      }
      if (_selectedCategory == 'දන්සල' &&
          (_selectedFoodType == null || _selectedFoodType == 'none')) {
        _showSnack(
            'Please select food type for Dansala', Icons.restaurant_rounded);
        return;
      }
      if (_titleController.text.isEmpty) {
        _showSnack('Please enter event title', Icons.title_rounded);
        return;
      }
    }

    if (_currentStep == 1) {
      if (_selectedDate == null) {
        _showSnack('Please select event date', Icons.calendar_today_rounded);
        return;
      }
      if (_selectedTime == null) {
        _showSnack('Please select event time', Icons.access_time_rounded);
        return;
      }
      if (_locationController.text.isEmpty) {
        _showSnack('Please enter event location', Icons.location_on_rounded);
        return;
      }
    }

    _fadeController.forward(from: 0.0);
    setState(() => _currentStep++);
  }

  void _previousStep() {
    _fadeController.forward(from: 0.0);
    setState(() => _currentStep--);
  }

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);

    double latitude = 7.8731;
    double longitude = 80.7718;
    String? district;
    String? province;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        latitude = position.latitude;
        longitude = position.longitude;

        final locationInfo =
            await _locationService.getDistrictAndProvince(latitude, longitude);
        district = locationInfo['district'];
        province = locationInfo['province'];
      }
    } catch (e) {
      debugPrint('Could not get coordinates: $e');
    }

    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final timeString = _selectedTime!.format(context);

    String imageUrl = _existingImageUrl ?? '';
    String imagePublicId = _existingImagePublicId ?? '';

    if (_selectedImage != null) {
      final eventIdForUpload = _isEditMode
          ? widget.editEvent!.id
          : DateTime.now().millisecondsSinceEpoch.toString();
      final uploadResult = await _cloudinaryService.uploadImage(
          _selectedImage!, 'events/$eventIdForUpload');
      if (uploadResult != null) {
        imageUrl = _cloudinaryService.extractUrl(uploadResult);
        imagePublicId = _cloudinaryService.extractPublicId(uploadResult);
      }
    }

    bool success;

    if (_isEditMode) {
      success = await _supabaseService.updateEvent(
        eventId: widget.editEvent!.id,
        category: _selectedCategory!,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? ''
            : _descriptionController.text,
        date: dateString,
        time: timeString,
        location: _locationController.text,
        latitude: latitude,
        longitude: longitude,
        foodType: _selectedCategory == 'දන්සල' ? _selectedFoodType! : 'none',
        imageUrl: imageUrl,
        imagePublicId: imagePublicId,
        district: district,
        province: province,
      );
    } else {
      success = await _supabaseService.createEvent(
        category: _selectedCategory!,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        date: dateString,
        time: timeString,
        location: _locationController.text,
        userId: widget.userId,
        createdBy: widget.userFirstName,
        latitude: latitude,
        longitude: longitude,
        foodType: _selectedCategory == 'දන්සල' ? _selectedFoodType! : 'none',
        imageUrl: imageUrl,
        imagePublicId: imagePublicId,
        district: district,
        province: province,
      );
    }

    setState(() => _isLoading = false);

    if (success) {
      if (!_isEditMode) {
        final updatedUser = await _supabaseService.getUserById(widget.userId);
        if (updatedUser != null) {
          await _sessionService.login(updatedUser);
        }
      }

      if (mounted) {
        _showSnack(
          _isEditMode
              ? 'Event updated successfully!'
              : 'Event created! +50 XP 🎉',
          Icons.check_circle_rounded,
          isSuccess: true,
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        _showSnack('Failed to save event. Please try again.',
            Icons.error_outline_rounded,
            isError: true);
      }
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
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _buildAmbientBlobs(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildStepIndicator(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      child: _buildCurrentStep(),
                    ),
                  ),
                ),
                _buildBottomActions(),
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
              color: AppTheme.primary.withOpacity(0.12),
            ),
          ),
        ),
        Positioned(
          top: 100,
          right: -80,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withOpacity(0.10),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: 60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.blobEmerald.withOpacity(0.08),
            ),
          ),
        ),
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
                color: Colors.white.withOpacity(0.35),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              _Glass(
                borderRadius: BorderRadius.circular(14),
                blur: 12,
                opacity: 0.55,
                tint: Colors.white,
                border:
                    Border.all(color: Colors.white.withOpacity(0.35), width: 1),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: AppTheme.primary,
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditMode ? 'Edit Event' : 'Create Event',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      _isEditMode
                          ? 'Update the event details below'
                          : 'Share something with your community',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              _Glass(
                borderRadius: BorderRadius.circular(20),
                blur: 8,
                opacity: 0.55,
                tint: Colors.white,
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.20), width: 1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  'Step ${_currentStep + 1}/$_totalSteps',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final stepLabels = ['Basic Info', 'Date & Location', 'Photo & Review'];
    final stepIcons = [
      Icons.info_outline_rounded,
      Icons.calendar_month_rounded,
      Icons.photo_camera_rounded,
    ];

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: AppTheme.timelineInactive.withOpacity(0.40),
              color: AppTheme.primary,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_totalSteps, (i) {
              final isActive = i == _currentStep;
              final isDone = i < _currentStep;
              final color = isDone || isActive
                  ? AppTheme.primary
                  : AppTheme.textSecondary;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppTheme.primary
                            : isActive
                                ? AppTheme.primary.withOpacity(0.12)
                                : AppTheme.timelineInactive.withOpacity(0.30),
                        shape: BoxShape.circle,
                        border: isActive
                            ? Border.all(color: AppTheme.primary, width: 1.5)
                            : null,
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : Icon(stepIcons[i],
                              size: 15,
                              color: isActive
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary.withOpacity(0.50)),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stepLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color: color.withOpacity(isActive ? 1.0 : 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStepBasicInfo();
      case 1:
        return _buildStepDateLocation();
      case 2:
        return _buildStepPhotoReview();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Category', Icons.category_rounded),
        const SizedBox(height: 10),
        _buildGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.eventCategories.map((category) {
                final isSelected = _selectedCategory == category;
                final catColor = AppConstants.getCategoryColor(category);
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = category;
                    if (category != 'දන්සල') _selectedFoodType = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? catColor.withOpacity(0.15)
                          : Colors.white.withOpacity(0.50),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? catColor.withOpacity(0.60)
                            : Colors.white.withOpacity(0.60),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppConstants.getCategoryIcon(category),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color:
                                isSelected ? catColor : AppTheme.textSecondary,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.check_circle_rounded,
                              size: 14, color: catColor),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (_selectedCategory == 'දන්සල') ...[
          const SizedBox(height: 20),
          _buildSectionLabel('Food Type', Icons.restaurant_rounded),
          const SizedBox(height: 10),
          _buildGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DropdownButtonFormField<String>(
                value: _selectedFoodType,
                decoration: _inputDecoration(
                  label: 'Food Type *',
                  hint: 'Select food type for Dansala',
                  icon: Icons.restaurant_rounded,
                ),
                items: AppConstants.foodTypes.map((food) {
                  return DropdownMenuItem(
                    value: food['sinhala'],
                    child: Row(
                      children: [
                        Text(food['emoji']!,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(food['sinhala']!,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            Text(food['english']!,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
                selectedItemBuilder: (context) =>
                    AppConstants.foodTypes.map((food) {
                  return Row(
                    children: [
                      Text(food['emoji']!,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Text(food['sinhala']!),
                    ],
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedFoodType = v),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _buildSectionLabel('Event Details', Icons.edit_rounded),
        const SizedBox(height: 10),
        _buildGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: _inputDecoration(
                    label: 'Event Title *',
                    hint: 'e.g., Vesak Lantern Festival',
                    icon: Icons.title_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    label: 'Description (Optional)',
                    hint: 'Tell people about your event...',
                    icon: Icons.description_rounded,
                    alignHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepDateLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('When', Icons.calendar_month_rounded),
        const SizedBox(height: 10),
        _buildGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: TextField(
                      controller: TextEditingController(
                        text: _selectedDate != null
                            ? DateFormat('EEEE, MMM d, yyyy')
                                .format(_selectedDate!)
                            : '',
                      ),
                      decoration: _inputDecoration(
                        label: 'Date *',
                        hint: 'Select date',
                        icon: Icons.calendar_today_rounded,
                        suffixIcon: Icons.arrow_drop_down_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _selectTime,
                  child: AbsorbPointer(
                    child: TextField(
                      controller: TextEditingController(
                        text: _selectedTime != null
                            ? _selectedTime!.format(context)
                            : '',
                      ),
                      decoration: _inputDecoration(
                        label: 'Time *',
                        hint: 'Select time',
                        icon: Icons.access_time_rounded,
                        suffixIcon: Icons.arrow_drop_down_rounded,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionLabel('Where', Icons.location_on_rounded),
        const SizedBox(height: 10),
        _buildGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                TextField(
                  controller: _locationController,
                  decoration: _inputDecoration(
                    label: 'Location *',
                    hint: 'Event address or venue',
                    icon: Icons.location_on_rounded,
                    suffixWidget: _isGettingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.primary),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location_rounded,
                                color: AppTheme.primary),
                            onPressed: _getCurrentLocation,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Glass(
          borderRadius: BorderRadius.circular(14),
          blur: 8,
          opacity: 0.45,
          tint: AppTheme.primary,
          border:
              Border.all(color: AppTheme.primary.withOpacity(0.15), width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 15, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap 📍 to auto-fill your current location.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.primary.withOpacity(0.85)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepPhotoReview() {
    final canPreview = _selectedCategory != null &&
        _titleController.text.isNotEmpty &&
        _selectedDate != null &&
        _selectedTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Event Photo', Icons.photo_camera_rounded),
        const SizedBox(height: 10),
        _buildGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final file = await _cloudinaryService.pickImage();
                      if (file != null) {
                        setState(() => _selectedImage = file);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedImage != null ||
                                  (_existingImageUrl != null &&
                                      _existingImageUrl!.isNotEmpty)
                              ? AppTheme.accent
                              : AppTheme.primary,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_selectedImage != null)
                              Image.file(_selectedImage!, fit: BoxFit.cover)
                            else if (_existingImageUrl != null &&
                                _existingImageUrl!.isNotEmpty)
                              Image.network(_existingImageUrl!,
                                  fit: BoxFit.cover)
                            else
                              Container(
                                color: AppTheme.background,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate,
                                      size: 32,
                                      color: AppTheme.primary.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add Image',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            AppTheme.primary.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _selectedImage != null ||
                                            (_existingImageUrl != null &&
                                                _existingImageUrl!.isNotEmpty)
                                        ? Icons.edit
                                        : Icons.add_a_photo,
                                    size: 20,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_selectedImage != null ||
                      (_existingImageUrl != null &&
                          _existingImageUrl!.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: () => setState(() {
                          _selectedImage = null;
                          _existingImageUrl = null;
                          _existingImagePublicId = null;
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                        ),
                        child: const Text('Remove Image'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Optional — add a photo to make your event stand out',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withOpacity(0.75),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (canPreview) ...[
          const SizedBox(height: 24),
          _buildSectionLabel('Preview', Icons.visibility_rounded),
          const SizedBox(height: 10),
          _buildPreviewCard(),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final catColor = AppConstants.getCategoryColor(_selectedCategory!);
    final catIcon = AppConstants.getCategoryIcon(_selectedCategory!);

    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(catIcon, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleController.text,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _Glass(
                        borderRadius: BorderRadius.circular(20),
                        blur: 4,
                        opacity: 0.45,
                        tint: catColor,
                        border: Border.all(
                            color: catColor.withOpacity(0.20), width: 1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        child: Text(
                          _selectedCategory!,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: catColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _previewInfoRow(
              Icons.calendar_today_rounded,
              DateFormat('MMM d, yyyy').format(_selectedDate!),
            ),
            const SizedBox(height: 6),
            _previewInfoRow(
              Icons.access_time_rounded,
              _selectedTime!.format(context),
            ),
            if (_locationController.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              _previewInfoRow(
                Icons.location_on_rounded,
                _locationController.text,
                multiline: true,
              ),
            ],
            if (_selectedCategory == 'දන්සල' && _selectedFoodType != null) ...[
              const SizedBox(height: 6),
              _previewInfoRow(
                Icons.restaurant_rounded,
                '${AppConstants.getFoodTypeEmoji(_selectedFoodType!)} $_selectedFoodType',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _previewInfoRow(IconData icon, String text, {bool multiline = false}) {
    return Row(
      crossAxisAlignment:
          multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary.withOpacity(0.7)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withOpacity(0.85),
            ),
            maxLines: multiline ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.60),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.35),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              if (_currentStep > 0) ...[
                _Glass(
                  borderRadius: BorderRadius.circular(16),
                  blur: 12,
                  opacity: 0.55,
                  tint: Colors.white,
                  border: Border.all(
                      color: AppTheme.timelineInactive.withOpacity(0.60),
                      width: 1),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _previousStep,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios_new_rounded,
                                size: 14, color: AppTheme.textSecondary),
                            SizedBox(width: 6),
                            Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _Glass(
                  borderRadius: BorderRadius.circular(16),
                  blur: 12,
                  opacity: 0.90,
                  tint: AppTheme.primary,
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.30), width: 1),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isLoading
                          ? null
                          : (_currentStep == _totalSteps - 1
                              ? _handleSubmit
                              : _nextStep),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _currentStep == _totalSteps - 1
                                          ? (_isEditMode
                                              ? 'Update Event'
                                              : 'Create Event')
                                          : 'Continue',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (_currentStep < _totalSteps - 1) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: Colors.white),
                                    ] else ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.check_rounded,
                                          size: 16, color: Colors.white),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppTheme.primary),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.60),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    IconData? suffixIcon,
    Widget? suffixWidget,
    bool alignHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignHint,
      prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
      suffixIcon: suffixWidget ??
          (suffixIcon != null
              ? Icon(suffixIcon, color: AppTheme.primary)
              : null),
      filled: true,
      fillColor: Colors.white.withOpacity(0.70),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6)),
    );
  }
}
