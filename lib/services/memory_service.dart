import '../models/memory_model.dart';
import '../models/event_model.dart';
import 'api_service.dart';
import 'session_service.dart';

class MemoryService {
  final SessionService _sessionService = SessionService();

  Future<bool> hasMemory(String eventId, String userId) async {
    try {
      // Use userId from session if not provided
      final effectiveUserId =
          userId.isNotEmpty ? userId : _sessionService.currentUser?.id ?? '';
      if (effectiveUserId.isEmpty) return false;

      return await ApiService.hasMemory(eventId);
    } catch (e) {
      print('Has memory error: $e');
      return false;
    }
  }

  Future<MemoryModel?> getMemoryByEvent(String eventId, String userId) async {
    try {
      final memoryData = await ApiService.getMemoryByEvent(eventId);

      if (memoryData == null) return null;

      return MemoryModel(
        id: memoryData['id'],
        eventId: memoryData['eventId'],
        userId: memoryData['userId'],
        experienceNote: memoryData['experienceNote'],
        visitedAt: DateTime.parse(memoryData['visitedAt']),
        createdAt: DateTime.parse(memoryData['createdAt']),
        updatedAt: DateTime.parse(memoryData['updatedAt']),
        imageUrls: List<String>.from(memoryData['imageUrls']),
        imagePublicIds: List<String>.from(memoryData['imagePublicIds']),
        videoUrl: memoryData['videoUrl'] ?? '',
        videoPublicId: memoryData['videoPublicId'] ?? '',
      );
    } catch (e) {
      print('Get memory by event error: $e');
      return null;
    }
  }

  Future<bool> createMemory({
    required String eventId,
    required String userId,
    required String experienceNote,
    required List<String> imageUrls,
    required List<String> imagePublicIds,
    required String videoUrl,
    required String videoPublicId,
  }) async {
    try {
      final result = await ApiService.createMemory(
        eventId: eventId,
        experienceNote: experienceNote,
        imageUrls: imageUrls,
        imagePublicIds: imagePublicIds,
        videoUrl: videoUrl,
        videoPublicId: videoPublicId,
      );

      return result != null;
    } catch (e) {
      print('Create memory error: $e');
      return false;
    }
  }

  Future<bool> updateMemory({
    required String memoryId,
    required String experienceNote,
    required List<String> imageUrls,
    required List<String> imagePublicIds,
    required String videoUrl,
    required String videoPublicId,
  }) async {
    try {
      return await ApiService.updateMemory(
        memoryId: memoryId,
        experienceNote: experienceNote,
        imageUrls: imageUrls,
        imagePublicIds: imagePublicIds,
        videoUrl: videoUrl,
        videoPublicId: videoPublicId,
      );
    } catch (e) {
      print('Update memory error: $e');
      return false;
    }
  }

  Future<bool> deleteMemory(String memoryId) async {
    try {
      return await ApiService.deleteMemory(memoryId);
    } catch (e) {
      print('Delete memory error: $e');
      return false;
    }
  }

  Future<Map<String, List<MemoryWithEvent>>> getUserMemories(
      String userId) async {
    try {
      final memoriesData = await ApiService.getUserMemories();

      final Map<String, List<MemoryWithEvent>> grouped = {};

      for (var item in memoriesData) {
        final memoryData = item['memory'];
        final eventData = item['event'];

        final memory = MemoryModel(
          id: memoryData['id'],
          eventId: memoryData['eventId'],
          userId: memoryData['userId'],
          experienceNote: memoryData['experienceNote'],
          visitedAt: DateTime.parse(memoryData['visitedAt']),
          createdAt: DateTime.parse(memoryData['createdAt']),
          updatedAt: DateTime.parse(memoryData['updatedAt']),
          imageUrls: List<String>.from(memoryData['imageUrls']),
          imagePublicIds: List<String>.from(memoryData['imagePublicIds']),
          videoUrl: memoryData['videoUrl'] ?? '',
          videoPublicId: memoryData['videoPublicId'] ?? '',
        );

        final event = EventModel(
          id: eventData['id'],
          category: eventData['category'],
          title: eventData['title'],
          description: eventData['description'],
          date: eventData['date'],
          time: eventData['time'],
          location: eventData['location'],
          userId: eventData['userId'],
          createdBy: eventData['createdBy'],
          createdAt: DateTime.parse(eventData['createdAt']),
          latitude: eventData['latitude'],
          longitude: eventData['longitude'],
          foodType: eventData['foodType'],
          imageUrl: eventData['imageUrl'] ?? '',
          imagePublicId: eventData['imagePublicId'] ?? '',
          district: eventData['district'],
          province: eventData['province'],
        );

        final year = memory.createdAt.year.toString();

        grouped.putIfAbsent(year, () => []);
        grouped[year]!.add(MemoryWithEvent(memory: memory, event: event));
      }

      // Sort years in descending order
      final sortedGrouped = Map.fromEntries(
          grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));

      return sortedGrouped;
    } catch (e) {
      print('Get user memories error: $e');
      return {};
    }
  }
}

class MemoryWithEvent {
  final MemoryModel memory;
  final EventModel event;

  MemoryWithEvent({required this.memory, required this.event});
}
