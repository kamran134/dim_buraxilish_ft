import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import '../services/http_service.dart';

class AuthProvider extends ChangeNotifier {
  final HttpService _httpService = HttpService();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  AccessTokenModel? _accessToken;
  List<String> _examDates = [];
  Auth? _authData;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AccessTokenModel? get accessToken => _accessToken;
  List<String> get examDates => _examDates;
  Auth? get authData => _authData;

  // Check authentication status on app start
  Future<void> checkAuthStatus() async {
    _setLoading(true);
    try {
      final token = await _httpService.getToken();
      if (token != null) {
        _isAuthenticated = true;
        _clearError();
      } else {
        final auth = await _httpService.getAuth();
        _isAuthenticated = auth;
      }
    } catch (e) {
      _setError('Avtorizasiya yoxlanılarkən xəta baş verdi');
      _isAuthenticated = false;
    } finally {
      _setLoading(false);
    }
  }

  // Load exam dates
  Future<void> loadExamDates() async {
    _setLoading(true);
    try {
      final result = await _httpService.getExamDates();
      if (result.success) {
        _examDates = result.data;
        _clearError();
      } else {
        _setError(result.message);
      }
    } catch (e) {
      _setError('İmtahan tarixləri yüklənmədi');
    } finally {
      _setLoading(false);
    }
  }

  // Login with JWT
  Future<bool> signInWithJWT(
      String userName, String password, String examDate) async {
    _setLoading(true);
    _clearError();

    try {
      // First sign out to clear any existing auth
      await signOut(clearData: false);

      final response = await _httpService.login(userName, password, examDate);

      if (response.success && response.data.token.isNotEmpty) {
        // Store token
        await _httpService.storeToken(response.data);
        await _httpService.storeAuth(true);

        // Extract bina from userName (following the original logic)
        final bina = int.tryParse(userName.substring(4)) ?? 0;

        // Update state
        _accessToken = response.data;
        _authData = Auth(bina: bina, examDate: examDate);
        _isAuthenticated = true;

        _clearError();
        notifyListeners();
        return true;
      } else {
        _setError(response.message);
        return false;
      }
    } catch (e) {
      _setError('Giriş zamanı xəta baş verdi');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Change password
  Future<bool> changePassword(
      String userName, String currentPassword, String newPassword) async {
    _setLoading(true);
    _clearError();

    try {
      final changePasswordModel = ChangePasswordModel(
        userName: userName,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      final response = await _httpService.changePassword(changePasswordModel);

      if (response.success) {
        _clearError();
        return true;
      } else {
        _setError(response.message);
        return false;
      }
    } catch (e) {
      _setError('Parol dəyişdirilərkən xəta baş verdi');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> signOut({bool clearData = true}) async {
    _setLoading(true);
    try {
      if (clearData) {
        await _httpService.clearAllData();
      } else {
        await _httpService.removeToken();
      }

      _isAuthenticated = false;
      _accessToken = null;
      _authData = null;
      _examDates.clear();
      _clearError();

      notifyListeners();
    } catch (e) {
      _setError('Çıxış zamanı xəta baş verdi');
    } finally {
      _setLoading(false);
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Public method to clear error
  void clearError() {
    _clearError();
  }
}
