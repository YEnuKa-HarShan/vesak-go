class MemoryModel {
  final String id;
  final String eventId;
  final String userId;
  final String experienceNote;
  final DateTime visitedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> imageUrls;
  final List<String> imagePublicIds;
  final String videoUrl;
  final String videoPublicId;

  MemoryModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.experienceNote,
    required this.visitedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.imageUrls,
    required this.imagePublicIds,
    required this.videoUrl,
    required this.videoPublicId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'experience_note': experienceNote,
      'visited_at': visitedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'image_urls': imageUrls,
      'image_public_ids': imagePublicIds,
      'video_url': videoUrl,
      'video_public_id': videoPublicId,
    };
  }

  factory MemoryModel.fromJson(Map<String, dynamic> json) {
    return MemoryModel(
      id: json['id'] ?? '',
      eventId: json['event_id'] ?? '',
      userId: json['user_id'] ?? '',
      experienceNote: json['experience_note'] ?? '',
      visitedAt: json['visited_at'] != null
          ? DateTime.parse(json['visited_at'])
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      imageUrls: json['image_urls'] is List
          ? List<String>.from(json['image_urls'])
          : [],
      imagePublicIds: json['image_public_ids'] is List
          ? List<String>.from(json['image_public_ids'])
          : [],
      videoUrl: json['video_url'] ?? '',
      videoPublicId: json['video_public_id'] ?? '',
    );
  }

  bool get hasImages => imageUrls.isNotEmpty;
  bool get hasVideo => videoUrl.isNotEmpty;
  int get mediaCount => (hasImages ? imageUrls.length : 0) + (hasVideo ? 1 : 0);
  String get coverImage => hasImages ? imageUrls.first : '';
}
