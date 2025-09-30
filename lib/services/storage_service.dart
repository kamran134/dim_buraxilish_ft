import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../models/participant_models.dart';

/// Service for handling local storage operations
/// Implements Storage pattern for persistent data
class StorageService {
  static const String _jwtTokenKey = 'jwt_token';
  static const String _userProfileKey = 'user_profile';
  static const String _examDetailsKey = 'exam_details';
  static const String _authKey = 'auth';

  // Token operations
  Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenData = {
      'token': token,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString(_jwtTokenKey, jsonEncode(tokenData));
  }

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenData = prefs.getString(_jwtTokenKey);

      if (tokenData != null) {
        final tokenJson = jsonDecode(tokenData) as Map<String, dynamic>;
        return tokenJson['token'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtTokenKey);
  }

  // User profile operations
  Future<void> storeUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userProfileKey, jsonEncode(profile.toJson()));
  }

  Future<UserProfile?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileData = prefs.getString(_userProfileKey);

      if (profileData != null) {
        final profileJson = jsonDecode(profileData) as Map<String, dynamic>;
        return UserProfile.fromJson(profileJson);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> removeUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userProfileKey);
  }

  // Exam details operations
  Future<void> storeExamDetails(ExamDetails details) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_examDetailsKey, jsonEncode(details.toJson()));
  }

  Future<ExamDetails?> getExamDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final detailsData = prefs.getString(_examDetailsKey);

      if (detailsData != null) {
        final detailsJson = jsonDecode(detailsData) as Map<String, dynamic>;
        return ExamDetails.fromJson(detailsJson);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> removeExamDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_examDetailsKey);
  }

  // Auth state operations
  Future<void> storeAuthState(bool isAuth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, isAuth);
  }

  Future<bool> getAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authKey) ?? false;
  }

  Future<void> removeAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
  }

  // Clear all stored data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_jwtTokenKey),
      prefs.remove(_userProfileKey),
      prefs.remove(_examDetailsKey),
      prefs.remove(_authKey),
    ]);
  }
}
