import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class SessionService extends ChangeNotifier {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  UserModel? _currentUser;
  bool _isLoading = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String get role => _currentUser?.role ?? 'guest';

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');

    if (userData != null) {
      try {
        final Map<String, dynamic> userMap = {
          'id': prefs.getString('user_id') ?? '',
          'first_name': prefs.getString('user_first_name') ?? '',
          'last_name': prefs.getString('user_last_name') ?? '',
          'email': prefs.getString('user_email') ?? '',
          'password_hash': '',
          'role': prefs.getString('user_role') ?? 'logged',
          'created_at': DateTime.now().toIso8601String(),
          'total_xp': prefs.getInt('user_total_xp') ?? 0,
          'current_level': prefs.getInt('user_current_level') ?? 0,
        };
        _currentUser = UserModel.fromJson(userMap);
      } catch (e) {
        print('Error restoring session: $e');
        _currentUser = null;
      }
    }

    _isLoading = false;
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
    await prefs.setInt('user_total_xp', user.totalXp);
    await prefs.setInt('user_current_level', user.currentLevel);
    await prefs.setString('user_data', user.toJson().toString());

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
    await prefs.remove('user_total_xp');
    await prefs.remove('user_current_level');
    await prefs.remove('user_data');

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
}
