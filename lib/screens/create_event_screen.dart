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
            primaryColor: AppTheme.saffron,
            colorScheme: const ColorScheme.light(primary: AppTheme.saffron),
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
            primaryColor: AppTheme.saffron,
            colorScheme: const ColorScheme.light(primary: AppTheme.saffron),
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

  Future<void> _handleSubmit() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    if (_selectedCategory == 'දන්සල' &&
        (_selectedFoodType == null || _selectedFoodType == 'none')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select food type for Dansala')),
      );
      return;
    }

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter event title')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event date')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event time')),
      );
      return;
    }

    if (_locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter event location')),
      );
      return;
    }

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

    // Upload new image if selected
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
      final tempEventId = DateTime.now().millisecondsSinceEpoch.toString();
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
      backgroundColor: AppTheme.sand,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Event' : 'Create Event',
          style: const TextStyle(color: AppTheme.white),
        ),
        backgroundColor: AppTheme.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: ImagePickerButton(
                selectedImage: _selectedImage,
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
                size: 120,
              ),
            ),
            if (_existingImageUrl != null &&
                _existingImageUrl!.isNotEmpty &&
                _selectedImage == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    'Current image will be kept',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.forestGreen,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category *',
                labelStyle: const TextStyle(color: AppTheme.charcoal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.saffron, width: 2),
                ),
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
              style: const TextStyle(color: AppTheme.charcoal),
              dropdownColor: AppTheme.white,
              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 20),
            if (_selectedCategory == 'දන්සල')
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedFoodType,
                    decoration: InputDecoration(
                      labelText: 'Food Type *',
                      labelStyle: const TextStyle(color: AppTheme.charcoal),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.saffron, width: 2),
                      ),
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
                            Text(food['sinhala']!),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFoodType = value;
                      });
                    },
                    style: const TextStyle(color: AppTheme.charcoal),
                    dropdownColor: AppTheme.white,
                    icon: const Icon(Icons.arrow_drop_down,
                        color: AppTheme.charcoal),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Event Title *',
                labelStyle: const TextStyle(color: AppTheme.charcoal),
                hintText: 'e.g., Vesak Lantern Festival',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.saffron, width: 2),
                ),
              ),
              style: const TextStyle(color: AppTheme.charcoal),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: const TextStyle(color: AppTheme.charcoal),
                hintText: 'Tell people about your event...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.saffron, width: 2),
                ),
              ),
              style: const TextStyle(color: AppTheme.charcoal),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _selectDate,
              child: AbsorbPointer(
                child: TextField(
                  controller: TextEditingController(
                    text: _selectedDate != null
                        ? DateFormat('EEEE, MMM d, yyyy').format(_selectedDate!)
                        : '',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Date *',
                    labelStyle: const TextStyle(color: AppTheme.charcoal),
                    hintText: 'Select date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.saffron, width: 2),
                    ),
                    suffixIcon:
                        Icon(Icons.calendar_today, color: AppTheme.saffron),
                  ),
                  style: const TextStyle(color: AppTheme.charcoal),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
                    labelStyle: const TextStyle(color: AppTheme.charcoal),
                    hintText: 'Select time',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.saffron, width: 2),
                    ),
                    suffixIcon:
                        Icon(Icons.access_time, color: AppTheme.saffron),
                  ),
                  style: const TextStyle(color: AppTheme.charcoal),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location *',
                labelStyle: const TextStyle(color: AppTheme.charcoal),
                hintText: 'Event address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.saffron, width: 2),
                ),
                suffixIcon: _isGettingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: Icon(Icons.my_location, color: AppTheme.saffron),
                        onPressed: _getCurrentLocation,
                      ),
              ),
              style: const TextStyle(color: AppTheme.charcoal),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: 'Contact Info (Optional)',
                labelStyle: const TextStyle(color: AppTheme.charcoal),
                hintText: 'Phone number or email for inquiries',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.saffron, width: 2),
                ),
                prefixIcon: Icon(Icons.contact_phone, color: AppTheme.saffron),
              ),
              style: const TextStyle(color: AppTheme.charcoal),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 30),
            if (_selectedCategory != null &&
                _titleController.text.isNotEmpty &&
                _selectedDate != null &&
                _selectedTime != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.sand, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppConstants.getCategoryColor(
                                _selectedCategory!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              AppConstants.getCategoryIcon(_selectedCategory!),
                              style: const TextStyle(fontSize: 20),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${DateFormat('MMM d, yyyy').format(_selectedDate!)} at ${_selectedTime!.format(context)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.charcoal.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppTheme.white)
                    : Text(_isEditMode ? 'Update Event' : 'Create Event',
                        style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
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
