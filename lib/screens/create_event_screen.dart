import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../services/image_service.dart';
import '../models/event_model.dart';
import '../constants.dart';
import '../theme/app_theme.dart';
import '../widgets/image_picker_button.dart';

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

class _CreateEventScreenState extends State<CreateEventScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final LocationService _locationService = LocationService();
  final SessionService _sessionService = SessionService();
  final ImageService _imageService = ImageService();

  String? _selectedCategory;
  String? _selectedFoodType;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  File? _selectedImage;
  String? _existingImageUrl;
  String? _existingImagePublicId;

  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _isEditMode = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.editEvent != null;

    if (_isEditMode) {
      _loadEventData();
    } else {
      _getCurrentLocation();
    }
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
    } catch (e) {
      _selectedDate = null;
    }

    try {
      final timeStr = event.time.toLowerCase();
      bool isPM = timeStr.contains('pm');
      final timeParts =
          timeStr.replaceAll(RegExp(r'[apm]'), '').trim().split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      _selectedTime = null;
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    final location = await _locationService.getCurrentLocation();

    setState(() {
      _locationController.text = location;
      _isGettingLocation = false;
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppTheme.primary,
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
            buttonTheme:
                const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppTheme.primary,
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _nextStep() {
    if (_currentStep == 0) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return Future.value();
      }
      if (_selectedCategory == 'දන්සල' &&
          (_selectedFoodType == null || _selectedFoodType == 'none')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select food type for Dansala')),
        );
        return Future.value();
      }
      if (_titleController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter event title')),
        );
        return Future.value();
      }
    }

    if (_currentStep == 1) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select event date')),
        );
        return Future.value();
      }
      if (_selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select event time')),
        );
        return Future.value();
      }
      if (_locationController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter event location')),
        );
        return Future.value();
      }
    }

    setState(() {
      _currentStep++;
    });
    return Future.value();
  }

  Future<void> _previousStep() {
    setState(() {
      _currentStep--;
    });
    return Future.value();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
    });

    double latitude = 7.8731;
    double longitude = 80.7718;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }
    } catch (e) {
      print('Could not get coordinates: $e');
    }

    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final timeString = _selectedTime!.format(context);

    String imageUrl = _existingImageUrl ?? '';
    String imagePublicId = _existingImagePublicId ?? '';

    if (_selectedImage != null) {
      final eventId = _isEditMode
          ? widget.editEvent!.id
          : DateTime.now().millisecondsSinceEpoch.toString();
      final uploadedUrl = await _imageService.updateImage(
          _selectedImage!, eventId, imagePublicId);
      if (uploadedUrl != null) {
        imageUrl = uploadedUrl;
        imagePublicId = uploadedUrl.split('/event-images/').last;
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
      );
    }

    if (success) {
      if (!_isEditMode) {
        final updatedUser = await _supabaseService.getUserById(widget.userId);
        if (updatedUser != null) {
          await _sessionService.login(updatedUser);
        }
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isEditMode
                ? 'Event updated successfully!'
                : 'Event created successfully! +50 XP')),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save event')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Event' : 'Create Event',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentStep > 0 && !_isLoading)
            TextButton(
              onPressed: _previousStep,
              style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
              child: const Text('Back'),
            ),
        ],
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _currentStep == 2 ? _handleSubmit : _nextStep,
        onStepCancel: _currentStep > 0 ? _previousStep : null,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _currentStep == 2
                          ? (_isEditMode ? 'Update Event' : 'Create Event')
                          : 'Next',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (details.onStepCancel != null) const SizedBox(width: 12),
                if (details.onStepCancel != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side:
                            const BorderSide(color: AppTheme.timelineInactive),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
              ],
            ),
          );
        },
        steps: [
          // Step 1: Basic Info
          Step(
            title: const Text('Basic Info'),
            subtitle: const Text('Category & Title'),
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            isActive: _currentStep >= 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    hintText: 'Select event category',
                    prefixIcon: Icon(Icons.category, color: AppTheme.primary),
                  ),
                  items: AppConstants.eventCategories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Text(
                            AppConstants.getCategoryIcon(category),
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(category),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                      if (value != 'දන්සල') {
                        _selectedFoodType = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Food Type (Visible only when Category is දන්සල)
                if (_selectedCategory == 'දන්සල')
                  Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedFoodType,
                        decoration: InputDecoration(
                          labelText: 'Food Type *',
                          hintText: 'Select food type for Dansala',
                          prefixIcon:
                              Icon(Icons.restaurant, color: AppTheme.primary),
                        ),
                        items: AppConstants.foodTypes.map((food) {
                          return DropdownMenuItem(
                            value: food['sinhala'],
                            child: Row(
                              children: [
                                Text(
                                  food['emoji']!,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        food['sinhala']!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        food['english']!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFoodType = value;
                          });
                        },
                        // This ensures only Sinhala name is shown in the selected box
                        selectedItemBuilder: (context) {
                          return AppConstants.foodTypes.map((food) {
                            return Row(
                              children: [
                                Text(
                                  food['emoji']!,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 12),
                                Text(food['sinhala']!),
                              ],
                            );
                          }).toList();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Title
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Event Title *',
                    hintText: 'e.g., Vesak Lantern Festival',
                    prefixIcon: Icon(Icons.title, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Tell people about your event...',
                    prefixIcon:
                        Icon(Icons.description, color: AppTheme.primary),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),

          // Step 2: Date, Time & Location
          Step(
            title: const Text('Date & Location'),
            subtitle: const Text('When and where'),
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            isActive: _currentStep >= 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Picker
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
                      decoration: InputDecoration(
                        labelText: 'Date *',
                        hintText: 'Select date',
                        prefixIcon:
                            Icon(Icons.calendar_today, color: AppTheme.primary),
                        suffixIcon: Icon(Icons.arrow_drop_down,
                            color: AppTheme.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Time Picker
                GestureDetector(
                  onTap: _selectTime,
                  child: AbsorbPointer(
                    child: TextField(
                      controller: TextEditingController(
                        text: _selectedTime != null
                            ? _selectedTime!.format(context)
                            : '',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Time *',
                        hintText: 'Select time',
                        prefixIcon:
                            Icon(Icons.access_time, color: AppTheme.primary),
                        suffixIcon: Icon(Icons.arrow_drop_down,
                            color: AppTheme.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Location
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location *',
                    hintText: 'Event address',
                    prefixIcon:
                        Icon(Icons.location_on, color: AppTheme.primary),
                    suffixIcon: _isGettingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: Icon(Icons.my_location,
                                color: AppTheme.primary),
                            onPressed: _getCurrentLocation,
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Contact Info
                TextField(
                  controller: _contactController,
                  decoration: InputDecoration(
                    labelText: 'Contact Info (Optional)',
                    hintText: 'Phone number or email for inquiries',
                    prefixIcon:
                        Icon(Icons.contact_phone, color: AppTheme.primary),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),

          // Step 3: Images & Review
          Step(
            title: const Text('Images & Review'),
            subtitle: const Text('Add photos'),
            state: _currentStep == 2 ? StepState.editing : StepState.indexed,
            isActive: _currentStep >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Picker
                Center(
                  child: ImagePickerButton(
                    selectedImage: _selectedImage,
                    existingImageUrl: _existingImageUrl,
                    onImagePicked: (file) {
                      setState(() {
                        _selectedImage = file;
                      });
                    },
                    onRemoveImage: () {
                      setState(() {
                        _selectedImage = null;
                        _existingImageUrl = null;
                        _existingImagePublicId = null;
                      });
                    },
                    size: 140,
                  ),
                ),
                if (_existingImageUrl != null &&
                    _existingImageUrl!.isNotEmpty &&
                    _selectedImage == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Current image will be kept',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Preview Card
                if (_selectedCategory != null &&
                    _titleController.text.isNotEmpty &&
                    _selectedDate != null &&
                    _selectedTime != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.timelineInactive),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preview',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppConstants.getCategoryColor(
                                    _selectedCategory!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  AppConstants.getCategoryIcon(
                                      _selectedCategory!),
                                  style: const TextStyle(fontSize: 28),
                                ),
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
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_selectedCategory == 'දන්සල' &&
                                      _selectedFoodType != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Text(
                                            AppConstants.getFoodTypeEmoji(
                                                _selectedFoodType!),
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _selectedFoodType!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Text(
                                    '${DateFormat('MMM d, yyyy').format(_selectedDate!)} at ${_selectedTime!.format(context)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    _locationController.text.isNotEmpty
                                        ? _locationController.text
                                        : 'Location not set',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    super.dispose();
  }
}
