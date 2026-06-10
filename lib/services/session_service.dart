import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class SessionService extends ChangeNotifier {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isInitialized = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String get role => _currentUser?.role ?? 'guest';

  Future<void> init() async {
    _isLoading = true;
    _isInitialized = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId != null && userId.isNotEmpty) {
        final firstName = prefs.getString('user_first_name') ?? '';
        final lastName = prefs.getString('user_last_name') ?? '';
        final email = prefs.getString('user_email') ?? '';
        final role = prefs.getString('user_role') ?? 'user';
        final createdAtStr = prefs.getString('user_created_at');
        final totalXp = prefs.getInt('user_total_xp') ?? 0;
        final currentLevel = prefs.getInt('user_current_level') ?? 0;

        final userData = {
          'id': userId,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password_hash': '',
          'role': role,
          'created_at': createdAtStr ?? DateTime.now().toIso8601String(),
          'total_xp': totalXp,
          'current_level': currentLevel,
        };
        _currentUser = UserModel.fromJson(userData);
      } else {
        _currentUser = null;
      }
    } catch (e) {
      print('SessionService init error: $e');
      _currentUser = null;
    }

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> login(UserModel user) async {
    _currentUser = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_first_name', user.firstName);
    await prefs.setString('user_last_name', user.lastName);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_role', user.role);
    await prefs.setString('user_created_at', user.createdAt.toIso8601String());
    await prefs.setInt('user_total_xp', user.totalXp);
    await prefs.setInt('user_current_level', user.currentLevel);

    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_first_name');
    await prefs.remove('user_last_name');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('user_created_at');
    await prefs.remove('user_total_xp');
    await prefs.remove('user_current_level');

    notifyListeners();
  }

  bool canCreateEvent() {
    return isLoggedIn;
  }

  bool canEditEvent(String eventUserId) {
    return isLoggedIn && _currentUser?.id == eventUserId;
  }

  bool canDeleteEvent(String eventUserId) {
    return isLoggedIn && _currentUser?.id == eventUserId;
  }

  // Update user data in session (call after XP changes)
  Future<void> updateUser(UserModel updatedUser) async {
    _currentUser = updatedUser;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_total_xp', updatedUser.totalXp);
    await prefs.setInt('user_current_level', updatedUser.currentLevel);

    notifyListeners();
  }
}
