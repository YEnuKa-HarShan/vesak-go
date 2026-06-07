import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/memory_model.dart';
import '../models/event_model.dart';

class MemoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Check if memory exists for an event
  Future<bool> hasMemory(String eventId, String userId) async {
    try {
      final response = await _supabase
          .from('event_memories')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('Check memory error: $e');
      return false;
    }
  }

  // Get memory by event
  Future<MemoryModel?> getMemoryByEvent(String eventId, String userId) async {
    try {
      final response = await _supabase
          .from('event_memories')
          .select('*')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return MemoryModel.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Get memory by event error: $e');
      return null;
    }
  }

  // Create memory
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
      final newMemory = {
        'event_id': eventId,
        'user_id': userId,
        'experience_note': experienceNote,
        'visited_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'image_urls': imageUrls,
        'image_public_ids': imagePublicIds,
        'video_url': videoUrl,
        'video_public_id': videoPublicId,
      };

      await _supabase.from('event_memories').insert(newMemory);
      return true;
    } catch (e) {
      print('Create memory error: $e');
      return false;
    }
  }

  // Update memory
  Future<bool> updateMemory({
    required String memoryId,
    required String experienceNote,
    required List<String> imageUrls,
    required List<String> imagePublicIds,
    required String videoUrl,
    required String videoPublicId,
  }) async {
    try {
      final updatedMemory = {
        'experience_note': experienceNote,
        'updated_at': DateTime.now().toIso8601String(),
        'image_urls': imageUrls,
        'image_public_ids': imagePublicIds,
        'video_url': videoUrl,
        'video_public_id': videoPublicId,
      };

      await _supabase
          .from('event_memories')
          .update(updatedMemory)
          .eq('id', memoryId);
      return true;
    } catch (e) {
      print('Update memory error: $e');
      return false;
    }
  }

  // Delete memory
  Future<bool> deleteMemory(String memoryId) async {
    try {
      await _supabase.from('event_memories').delete().eq('id', memoryId);
      return true;
    } catch (e) {
      print('Delete memory error: $e');
      return false;
    }
  }

  // Get all user memories (grouped by year)
  Future<Map<String, List<MemoryWithEvent>>> getUserMemories(
      String userId) async {
    try {
      final response = await _supabase
          .from('event_memories')
          .select('*, events(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final Map<String, List<MemoryWithEvent>> grouped = {};

      for (var json in response) {
        final memory = MemoryModel.fromJson(json);
        final event = EventModel.fromJson(json['events']);
        final year = memory.createdAt.year.toString();

        grouped.putIfAbsent(year, () => []);
        grouped[year]!.add(MemoryWithEvent(memory: memory, event: event));
      }

      return grouped;
    } catch (e) {
      print('Get user memories error: $e');
      return {};
    }
  }
}

// Helper class for memory with event data
class MemoryWithEvent {
  final MemoryModel memory;
  final EventModel event;

  MemoryWithEvent({required this.memory, required this.event});
}
