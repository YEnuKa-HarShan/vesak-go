import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../constants.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

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

  Future<bool> createEvent({
    required String category,
    required String title,
    required String date,
    required String time,
    required String location,
    required String userId,
    required String createdBy,
    String? description,
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
      };

      await _supabase.from('events').insert(newEvent);

      // Add XP and get updated user
      final updatedUser =
          await _addXpAndReturnUser(userId, 50, 'event_created');

      return true;
    } catch (e) {
      print('Create event error: $e');
      return false;
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

        // Return updated user
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

  Future<UserModel?> addXpAndUpdateUser(String userId, int xpAmount) async {
    return await _addXpAndReturnUser(userId, xpAmount, 'manual');
  }

  Future<bool> updateEvent({
    required String eventId,
    required String category,
    required String title,
    required String description,
    required String date,
    required String time,
    required String location,
  }) async {
    try {
      final updatedEvent = {
        'category': category,
        'title': title,
        'description': description,
        'date': date,
        'time': time,
        'location': location,
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

  Future<List<Map<String, dynamic>>> getAllEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      print('Get all events error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyEvents(String userId) async {
    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response;
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
}
