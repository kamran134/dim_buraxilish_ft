import 'dart:convert';
import '../models/auth_models.dart';
import '../models/participant_models.dart';
import '../services/http_service.dart';
import '../services/storage_service.dart';

/// Repository pattern for authentication-related operations
/// Separates business logic from data sources
abstract class AuthRepository {
  Future<LoginResponse> login(
      String username, String password, String examDate);
  Future<bool> isAuthenticated();
  Future<void> logout();
  Future<UserProfile?> getCurrentUser();
  Future<ExamDetails?> getExamDetails();
}

class AuthRepositoryImpl implements AuthRepository {
  final HttpService _httpService;
  final StorageService _storageService;

  AuthRepositoryImpl({
    HttpService? httpService,
    StorageService? storageService,
  })  : _httpService = httpService ?? HttpService(),
        _storageService = storageService ?? StorageService();

  @override
  Future<LoginResponse> login(
      String username, String password, String examDate) async {
    try {
      final loginResponse =
          await _httpService.login(username, password, examDate);

      // Store authentication data if successful
      if (loginResponse.success) {
        await _storageService.storeToken(loginResponse.data.token);

        // Create and store user profile from login response
        final userProfile = UserProfile(
          userName: username,
          role: loginResponse.data.role,
        );
        await _storageService.storeUserProfile(userProfile);

        // Store auth state
        await _storageService.storeAuthState(true);
      }

      return loginResponse;
    } catch (e) {
      throw AuthException('Login failed: $e');
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await _storageService.getToken();
    return token != null && !_isTokenExpired(token);
  }

  @override
  Future<void> logout() async {
    await Future.wait([
      _storageService.removeToken(),
      _storageService.removeUserProfile(),
      _storageService.removeExamDetails(),
    ]);
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    return await _storageService.getUserProfile();
  }

  @override
  Future<ExamDetails?> getExamDetails() async {
    return await _storageService.getExamDetails();
  }

  bool _isTokenExpired(String token) {
    try {
      // Simple JWT expiration check - you might want to use a proper JWT library
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = parts[1];
      // Add padding if necessary
      var normalized = payload;
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }

      final decoded = base64.decode(normalized);
      final payloadString = utf8.decode(decoded);
      final payloadMap = jsonDecode(payloadString) as Map<String, dynamic>;

      if (payloadMap['exp'] != null) {
        final exp = DateTime.fromMillisecondsSinceEpoch(
            (payloadMap['exp'] as int) * 1000);
        return DateTime.now().isAfter(exp);
      }
      return false;
    } catch (e) {
      return true; // If we can't parse, consider it expired
    }
  }
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
