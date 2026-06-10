import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/user_model.dart';
import '../models/event_model.dart';
import '../models/memory_model.dart';
import '../services/session_service.dart';

class ApiService {
  // ============================================
  // HELPER METHODS
  // ============================================

  // Get headers with user ID for authentication
  static Map<String, String> _getHeaders() {
    final sessionService = SessionService();
    return {
      'Content-Type': 'application/json',
      'X-User-Id': sessionService.currentUser?.id ?? '',
    };
  }

  // ============================================
  // AUTH ENDPOINTS
  // ============================================

  // Register new user
  static Future<Map<String, dynamic>?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrlAuth}/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return data['data'];
      } else {
        print('Register error: ${data['error']}');
        return null;
      }
    } catch (e) {
      print('Register exception: $e');
      return null;
    }
  }

  // Login user
  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrlAuth}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      } else {
        print('Login error: ${data['error']}');
        return null;
      }
    } catch (e) {
      print('Login exception: $e');
      return null;
    }
  }

  // Get user by ID
  static Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlAuth}/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final userData = data['data'];
        return UserModel(
          id: userData['id'],
          firstName: userData['firstName'],
          lastName: userData['lastName'],
          email: userData['email'],
          passwordHash: '',
          role: userData['role'],
          createdAt: DateTime.parse(userData['createdAt']),
          totalXp: userData['totalXp'],
          currentLevel: userData['currentLevel'],
        );
      }
      return null;
    } catch (e) {
      print('Get user error: $e');
      return null;
    }
  }

  // ============================================
  // EVENT ENDPOINTS
  // ============================================

  // Create event
  static Future<Map<String, dynamic>?> createEvent({
    required String category,
    required String title,
    String? description,
    required String date,
    required String time,
    required String location,
    required String userId,
    required String createdBy,
    required double latitude,
    required double longitude,
    required String foodType,
    String? imageUrl,
    String? imagePublicId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrlEvents}/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'category': category,
          'title': title,
          'description': description,
          'date': date,
          'time': time,
          'location': location,
          'userId': userId,
          'createdBy': createdBy,
          'latitude': latitude,
          'longitude': longitude,
          'foodType': foodType,
          'imageUrl': imageUrl ?? '',
          'imagePublicId': imagePublicId ?? '',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return data['data'];
      } else {
        print('Create event error: ${data['error']}');
        return null;
      }
    } catch (e) {
      print('Create event exception: $e');
      return null;
    }
  }

  // Update event
  static Future<Map<String, dynamic>?> updateEvent({
    required String eventId,
    String? category,
    String? title,
    String? description,
    String? date,
    String? time,
    String? location,
    double? latitude,
    double? longitude,
    String? foodType,
    String? imageUrl,
    String? imagePublicId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.apiBaseUrlEvents}/$eventId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'category': category,
          'title': title,
          'description': description,
          'date': date,
          'time': time,
          'location': location,
          'latitude': latitude,
          'longitude': longitude,
          'foodType': foodType,
          'imageUrl': imageUrl,
          'imagePublicId': imagePublicId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      } else {
        print('Update event error: ${data['error']}');
        return null;
      }
    } catch (e) {
      print('Update event exception: $e');
      return null;
    }
  }

  // Delete event
  static Future<bool> deleteEvent(String eventId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.apiBaseUrlEvents}/$eventId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      } else {
        print('Delete event error: ${data['error']}');
        return false;
      }
    } catch (e) {
      print('Delete event exception: $e');
      return false;
    }
  }

  // Get all events
  static Future<List<EventModel>> getAllEvents() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlEvents}/'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final List eventsData = data['data'];
        return eventsData.map((json) => EventModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get all events exception: $e');
      return [];
    }
  }

  // Get event by ID
  static Future<EventModel?> getEventById(String eventId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlEvents}/$eventId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return EventModel.fromJson(data['data']);
      }
      return null;
    } catch (e) {
      print('Get event by ID exception: $e');
      return null;
    }
  }

  // Get my events
  static Future<List<EventModel>> getMyEvents(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlEvents}/my/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final List eventsData = data['data'];
        return eventsData.map((json) => EventModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get my events exception: $e');
      return [];
    }
  }

  // Get events count
  static Future<int> getEventsCount() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlEvents}/count'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data']['count'];
      }
      return 0;
    } catch (e) {
      print('Get events count exception: $e');
      return 0;
    }
  }

  // Get events for map
  static Future<List<Map<String, dynamic>>> getEventsForMap() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlEvents}/map'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('Get events for map exception: $e');
      return [];
    }
  }

  // Get event stats (visits, memories, bookmarks)
  static Future<Map<String, int>> getEventStats(String eventId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlEvents}/stats/$eventId'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'totalVisits': data['data']['totalVisits'] ?? 0,
          'totalMemories': data['data']['totalMemories'] ?? 0,
          'totalBookmarks': data['data']['totalBookmarks'] ?? 0,
        };
      }
      return {'totalVisits': 0, 'totalMemories': 0, 'totalBookmarks': 0};
    } catch (e) {
      print('Get event stats exception: $e');
      return {'totalVisits': 0, 'totalMemories': 0, 'totalBookmarks': 0};
    }
  }

  // ============================================
  // BOOKMARK ENDPOINTS
  // ============================================

  // Add bookmark
  static Future<bool> addBookmark(String eventId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrlBookmarks}/'),
        headers: _getHeaders(),
        body: jsonEncode({'eventId': eventId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return true;
      } else {
        print('Add bookmark error: ${data['error']}');
        return false;
      }
    } catch (e) {
      print('Add bookmark exception: $e');
      return false;
    }
  }

  // Remove bookmark
  static Future<bool> removeBookmark(String eventId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.apiBaseUrlBookmarks}/$eventId'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      } else {
        print('Remove bookmark error: ${data['error']}');
        return false;
      }
    } catch (e) {
      print('Remove bookmark exception: $e');
      return false;
    }
  }

  // Check if bookmarked
  static Future<bool> isBookmarked(String eventId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlBookmarks}/check/$eventId'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data']['isBookmarked'] == true;
      }
      return false;
    } catch (e) {
      print('Check bookmark exception: $e');
      return false;
    }
  }

  // Get bookmarked events
  static Future<List<EventModel>> getBookmarkedEvents() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlBookmarks}/'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final List eventsData = data['data'];
        return eventsData.map((json) => EventModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Get bookmarked events exception: $e');
      return [];
    }
  }

  // ============================================
  // MEMORY ENDPOINTS
  // ============================================

  // Create memory
  static Future<Map<String, dynamic>?> createMemory({
    required String eventId,
    required String experienceNote,
    required List<String> imageUrls,
    required List<String> imagePublicIds,
    required String videoUrl,
    required String videoPublicId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrlMemories}/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'eventId': eventId,
          'experienceNote': experienceNote,
          'imageUrls': imageUrls,
          'imagePublicIds': imagePublicIds,
          'videoUrl': videoUrl,
          'videoPublicId': videoPublicId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return data['data'];
      } else {
        print('Create memory error: ${data['error']}');
        return null;
      }
    } catch (e) {
      print('Create memory exception: $e');
      return null;
    }
  }

  // Update memory
  static Future<bool> updateMemory({
    required String memoryId,
    required String experienceNote,
    required List<String> imageUrls,
    required List<String> imagePublicIds,
    required String videoUrl,
    required String videoPublicId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.apiBaseUrlMemories}/$memoryId'),
        headers: _getHeaders(),
        body: jsonEncode({
          'experienceNote': experienceNote,
          'imageUrls': imageUrls,
          'imagePublicIds': imagePublicIds,
          'videoUrl': videoUrl,
          'videoPublicId': videoPublicId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      } else {
        print('Update memory error: ${data['error']}');
        return false;
      }
    } catch (e) {
      print('Update memory exception: $e');
      return false;
    }
  }

  // Delete memory
  static Future<bool> deleteMemory(String memoryId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.apiBaseUrlMemories}/$memoryId'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      } else {
        print('Delete memory error: ${data['error']}');
        return false;
      }
    } catch (e) {
      print('Delete memory exception: $e');
      return false;
    }
  }

  // Check if user has memory for event
  static Future<bool> hasMemory(String eventId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlMemories}/check/$eventId'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data']['hasMemory'] == true;
      }
      return false;
    } catch (e) {
      print('Check memory exception: $e');
      return false;
    }
  }

  // Get memory by event ID
  static Future<Map<String, dynamic>?> getMemoryByEvent(String eventId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlMemories}/event/$eventId'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      }
      return null;
    } catch (e) {
      print('Get memory by event exception: $e');
      return null;
    }
  }

  // Get all user memories
  static Future<List<Map<String, dynamic>>> getUserMemories() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlMemories}/user'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('Get user memories exception: $e');
      return [];
    }
  }

  // ============================================
  // EVENT VISIT ENDPOINTS
  // ============================================

  // Mark event as visited
  static Future<bool> markEventAsVisited(String eventId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrlVisits}/'),
        headers: _getHeaders(),
        body: jsonEncode({'eventId': eventId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return true;
      } else {
        print('Mark as visited error: ${data['error']}');
        return false;
      }
    } catch (e) {
      print('Mark as visited exception: $e');
      return false;
    }
  }

  // Check if user has visited event
  static Future<Map<String, dynamic>> hasUserVisitedEvent(
      String eventId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlVisits}/check/$eventId'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'hasVisited': data['data']['hasVisited'] == true,
          'visitedAt': data['data']['visitedAt'],
          'hasMemory': data['data']['hasMemory'] == true,
        };
      }
      return {'hasVisited': false, 'visitedAt': null, 'hasMemory': false};
    } catch (e) {
      print('Check visited exception: $e');
      return {'hasVisited': false, 'visitedAt': null, 'hasMemory': false};
    }
  }

  // Get all visited events for user
  static Future<List<Map<String, dynamic>>> getUserVisits() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrlVisits}/user'),
        headers: _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('Get user visits exception: $e');
      return [];
    }
  }
}
