import '../constants.dart';

class EventModel {
  final String id;
  final String category;
  final String title;
  final String? description;
  final String date;
  final String time;
  final String location;
  final String userId;
  final String createdBy;
  final DateTime createdAt;
  final double latitude;
  final double longitude;
  final String foodType;
  final String imageUrl;
  final String imagePublicId;

  EventModel({
    required this.id,
    required this.category,
    required this.title,
    this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.userId,
    required this.createdBy,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.foodType,
    required this.imageUrl,
    required this.imagePublicId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'description': description,
      'date': date,
      'time': time,
      'location': location,
      'user_id': userId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'food_type': foodType,
      'image_url': imageUrl,
      'image_public_id': imagePublicId,
    };
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'],
      category: json['category'],
      title: json['title'],
      description: json['description'],
      date: json['date'],
      time: json['time'],
      location: json['location'],
      userId: json['user_id'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      foodType: json['food_type'] ?? 'none',
      imageUrl: json['image_url'] ?? '',
      imagePublicId: json['image_public_id'] ?? '',
    );
  }

  String getMarkerIcon() {
    if (category == 'දන්සල' && foodType != 'none') {
      for (var food in AppConstants.foodTypes) {
        if (food['sinhala'] == foodType) {
          return food['emoji']!;
        }
      }
    }
    return AppConstants.getCategoryIcon(category);
  }

  String getCategoryDisplayName() {
    if (category == 'දන්සල' && foodType != 'none') {
      return '$category - $foodType';
    }
    return category;
  }

  bool get hasImage => imageUrl.isNotEmpty;
}
