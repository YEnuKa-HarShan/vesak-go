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
  final String? district;
  final String? province;

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
    this.district,
    this.province,
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
      'district': district,
      'province': province,
    };
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Handle both camelCase (backend) and snake_case (legacy)
    String createdByName = '';
    if (json['createdBy'] != null) {
      createdByName = json['createdBy'].toString();
    } else if (json['created_by'] != null) {
      createdByName = json['created_by'].toString();
    } else {
      createdByName = 'Unknown Organizer';
    }

    return EventModel(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      createdBy: createdByName,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'].toString())
              : DateTime.now()),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      foodType: json['foodType']?.toString() ??
          json['food_type']?.toString() ??
          'none',
      imageUrl:
          json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '',
      imagePublicId: json['imagePublicId']?.toString() ??
          json['image_public_id']?.toString() ??
          '',
      district: json['district']?.toString(),
      province: json['province']?.toString(),
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

  String get locationDisplay {
    if (district != null && district!.isNotEmpty) {
      return '$location ($district${province != null ? ', $province' : ''})';
    }
    return location;
  }
}
