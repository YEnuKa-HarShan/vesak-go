import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../models/event_model.dart';
import '../models/memory_model.dart';
import '../constants.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ============================================
  // AUTH / USER MANAGEMENT
  // ============================================

  Future<bool> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final existingUser = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (existingUser != null) {
        return false;
      }

      final passwordHash = _hashPassword(password);

      final newUser = {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password_hash': passwordHash,
        'role': 'logged',
        'created_at': DateTime.now().toIso8601String(),
        'total_xp': 50,
        'current_level': AppConstants.calculateLevelFromXp(50),
        'last_login_date': DateTime.now().toIso8601String().split('T')[0],
      };

      await _supabase.from('users').insert(newUser);
      return true;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  Future<UserModel?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final passwordHash = _hashPassword(password);

      final response = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .eq('password_hash', passwordHash)
          .maybeSingle();

      if (response != null) {
        final lastLogin = response['last_login_date'];
        final today = DateTime.now().toIso8601String().split('T')[0];

        if (lastLogin != today) {
          final currentXp = response['total_xp'] as int;
          final newXp = currentXp + 5;
          final newLevel = AppConstants.calculateLevelFromXp(newXp);

          await _supabase.from('users').update({
            'total_xp': newXp,
            'current_level': newLevel,
            'last_login_date': today,
          }).eq('id', response['id']);

          response['total_xp'] = newXp;
          response['current_level'] = newLevel;
        }

        return UserModel.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final response =
          await _supabase.from('users').select().eq('id', userId).maybeSingle();

      if (response != null) {
        return UserModel.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Get user error: $e');
      return null;
    }
  }

  Future<bool> updateUserProfile({
    required String userId,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    try {
      final existingUser = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .neq('id', userId)
          .maybeSingle();

      if (existingUser != null) {
        return false;
      }

      final updatedUser = {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
      };

      await _supabase.from('users').update(updatedUser).eq('id', userId);
      return true;
    } catch (e) {
      print('Update profile error: $e');
      return false;
    }
  }

  Future<bool> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final currentHash = _hashPassword(currentPassword);

      final user = await _supabase
          .from('users')
          .select('password_hash')
          .eq('id', userId)
          .maybeSingle();

      if (user == null || user['password_hash'] != currentHash) {
        return false;
      }

      final newHash = _hashPassword(newPassword);
      await _supabase
          .from('users')
          .update({'password_hash': newHash}).eq('id', userId);
      return true;
    } catch (e) {
      print('Change password error: $e');
      return false;
    }
  }

  // ============================================
  // EVENTS CRUD
  // ============================================

  Future<bool> createEvent({
    required String category,
    required String title,
    required String date,
    required String time,
    required String location,
    required String userId,
    required String createdBy,
    required double latitude,
    required double longitude,
    required String foodType,
    required String imageUrl,
    required String imagePublicId,
    String? description,
    String? district,
    String? province,
  }) async {
    try {
      final newEvent = {
        'category': category,
        'title': title,
        'description': description,
        'date': date,
        'time': time,
        'location': location,
        'user_id': userId,
        'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'food_type': foodType,
        'image_url': imageUrl,
        'image_public_id': imagePublicId,
        'district': district,
        'province': province,
      };

      await _supabase.from('events').insert(newEvent);
      await _addXpAndReturnUser(userId, 50, 'event_created');
      return true;
    } catch (e) {
      print('Create event error: $e');
      return false;
    }
  }

  Future<bool> updateEvent({
    required String eventId,
    required String category,
    required String title,
    required String description,
    required String date,
    required String time,
    required String location,
    required double latitude,
    required double longitude,
    required String foodType,
    required String imageUrl,
    required String imagePublicId,
    String? district,
    String? province,
  }) async {
    try {
      final updatedEvent = {
        'category': category,
        'title': title,
        'description': description,
        'date': date,
        'time': time,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'food_type': foodType,
        'image_url': imageUrl,
        'image_public_id': imagePublicId,
        'district': district,
        'province': province,
      };

      await _supabase.from('events').update(updatedEvent).eq('id', eventId);
      return true;
    } catch (e) {
      print('Update event error: $e');
      return false;
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    try {
      await _supabase.from('events').delete().eq('id', eventId);
      return true;
    } catch (e) {
      print('Delete event error: $e');
      return false;
    }
  }

  // ============================================
  // GET EVENTS
  // ============================================

  Future<List<EventModel>> getAllEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .order('created_at', ascending: false);

      List<EventModel> events = [];
      for (var json in response) {
        try {
          events.add(EventModel.fromJson(json));
        } catch (e) {
          print('Error parsing event: $e');
        }
      }
      return events;
    } catch (e) {
      print('Get all events error: $e');
      return [];
    }
  }

  Future<List<EventModel>> getEventsForMap() async {
    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .order('created_at', ascending: false);

      List<EventModel> events = [];
      for (var json in response) {
        try {
          final latitude = (json['latitude'] as num?)?.toDouble();
          final longitude = (json['longitude'] as num?)?.toDouble();

          if (latitude == null || longitude == null) {
            continue;
          }

          events.add(EventModel(
            id: json['id'] ?? '',
            category: json['category'] ?? 'තොරණ',
            title: json['title'] ?? 'Untitled',
            description: json['description'] ?? '',
            date: json['date'] ?? '',
            time: json['time'] ?? '',
            location: json['location'] ?? '',
            userId: json['user_id'] ?? '',
            createdBy: json['created_by'] ?? 'Unknown',
            createdAt: json['created_at'] != null
                ? DateTime.parse(json['created_at'])
                : DateTime.now(),
            latitude: latitude,
            longitude: longitude,
            foodType: json['food_type'] ?? 'none',
            imageUrl: json['image_url'] ?? '',
            imagePublicId: json['image_public_id'] ?? '',
            district: json['district'],
            province: json['province'],
          ));
        } catch (e) {
          print('Error parsing map event: $e');
        }
      }
      return events;
    } catch (e) {
      print('Get events for map error: $e');
      return [];
    }
  }

  Future<List<EventModel>> getMyEvents(String userId) async {
    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      List<EventModel> events = [];
      for (var json in response) {
        try {
          events.add(EventModel.fromJson(json));
        } catch (e) {
          print('Error parsing my event: $e');
        }
      }
      return events;
    } catch (e) {
      print('Get my events error: $e');
      return [];
    }
  }

  Future<int> getEventsCount() async {
    try {
      final List<dynamic> response = await _supabase.from('events').select();
      return response.length;
    } catch (e) {
      print('Get events count error: $e');
      return 0;
    }
  }

  Future<int> getStoriesCount() async {
    try {
      final List<dynamic> response = await _supabase.from('stories').select();
      return response.length;
    } catch (e) {
      print('Get stories count error: $e');
      return 0;
    }
  }

  // ============================================
  // EVENT STATS METHODS
  // ============================================

  Future<Map<String, int>> getEventStats(String eventId) async {
    try {
      final response = await _supabase
          .from('events')
          .select('total_visits, total_memories, total_bookmarks')
          .eq('id', eventId)
          .maybeSingle();

      if (response != null) {
        return {
          'total_visits': response['total_visits'] ?? 0,
          'total_memories': response['total_memories'] ?? 0,
          'total_bookmarks': response['total_bookmarks'] ?? 0,
        };
      }
      return {'total_visits': 0, 'total_memories': 0, 'total_bookmarks': 0};
    } catch (e) {
      print('Get event stats error: $e');
      return {'total_visits': 0, 'total_memories': 0, 'total_bookmarks': 0};
    }
  }

  Future<bool> hasUserVisitedEvent(String eventId, String userId) async {
    try {
      final result = await _supabase
          .from('event_visits')
          .select()
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();
      return result != null;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markEventAsVisited(String eventId, String userId) async {
    try {
      final existing = await _supabase
          .from('event_visits')
          .select()
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existing != null) return true;

      await _supabase.from('event_visits').insert({
        'user_id': userId,
        'event_id': eventId,
        'visited_at': DateTime.now().toIso8601String(),
        'has_memory': false,
      });

      return true;
    } catch (e) {
      print('Mark as visited error: $e');
      return false;
    }
  }

  Future<int> getUserMemoryCount(String eventId, String userId) async {
    try {
      final response = await _supabase
          .from('event_memories')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', userId);
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  // ============================================
  // BOOKMARKS
  // ============================================

  Future<bool> addBookmark(String userId, String eventId) async {
    try {
      final existing = await _supabase
          .from('bookmarks')
          .select()
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existing != null) return true;

      await _supabase.from('bookmarks').insert({
        'user_id': userId,
        'event_id': eventId,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Add bookmark error: $e');
      return false;
    }
  }

  Future<bool> removeBookmark(String userId, String eventId) async {
    try {
      await _supabase
          .from('bookmarks')
          .delete()
          .eq('user_id', userId)
          .eq('event_id', eventId);
      return true;
    } catch (e) {
      print('Remove bookmark error: $e');
      return false;
    }
  }

  Future<bool> isBookmarked(String userId, String eventId) async {
    try {
      final result = await _supabase
          .from('bookmarks')
          .select()
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();
      return result != null;
    } catch (e) {
      print('Check bookmark error: $e');
      return false;
    }
  }

  Future<List<EventModel>> getBookmarkedEvents(String userId) async {
    try {
      final bookmarks = await _supabase
          .from('bookmarks')
          .select('event_id')
          .eq('user_id', userId);

      if (bookmarks.isEmpty) return [];

      final eventIds = bookmarks.map((b) => b['event_id']).toList();
      final events = await _supabase
          .from('events')
          .select('*')
          .inFilter('id', eventIds)
          .order('created_at', ascending: false);

      return events.map((json) => EventModel.fromJson(json)).toList();
    } catch (e) {
      print('Get bookmarked events error: $e');
      return [];
    }
  }

  // ============================================
  // LEADERBOARD & XP
  // ============================================

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      final response = await _supabase
          .from('users')
          .select('first_name, last_name, total_xp, current_level')
          .order('total_xp', ascending: false)
          .limit(10);

      return response;
    } catch (e) {
      print('Get leaderboard error: $e');
      return [];
    }
  }

  Future<UserModel?> _addXpAndReturnUser(
      String userId, int xpAmount, String reason) async {
    try {
      final user =
          await _supabase.from('users').select().eq('id', userId).maybeSingle();

      if (user != null) {
        final currentXp = user['total_xp'] as int;
        final newXp = currentXp + xpAmount;
        final newLevel = AppConstants.calculateLevelFromXp(newXp);

        await _supabase.from('users').update({
          'total_xp': newXp,
          'current_level': newLevel,
        }).eq('id', userId);

        final updatedUser = await _supabase
            .from('users')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (updatedUser != null) {
          return UserModel.fromJson(updatedUser);
        }
      }
      return null;
    } catch (e) {
      print('Add XP error: $e');
      return null;
    }
  }
}
