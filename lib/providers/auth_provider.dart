import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../models/participant_models.dart';
import '../utils/role_helper.dart';
import '../services/http_service.dart';
import '../services/database_service.dart';

class AuthProvider extends ChangeNotifier {
  final HttpService _httpService = HttpService();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  AccessTokenModel? _accessToken;
  List<String> _examDates = [];
  Auth? _authData;
  String? _currentUserRole;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AccessTokenModel? get accessToken => _accessToken;
  List<String> get examDates => _examDates;
  Auth? get authData => _authData;
  String? get currentUserRole => _currentUserRole;

  // Role-based getters
  bool get isAdmin => RoleHelper.isAdministrativeRole(_currentUserRole);
  bool get isMonitor => RoleHelper.isMonitorRole(_currentUserRole);
  bool get isSuperAdmin => RoleHelper.isSuperAdminRole(_currentUserRole);

  /// Проверяет, может ли текущий пользователь получить доступ к админ панели
  bool get canAccessDashboard => RoleHelper.canAccessAdmin(_currentUserRole);

  /// Проверяет, может ли текущий пользователь использовать сканер
  bool get canAccessScanner => RoleHelper.canAccessScanner(_currentUserRole);

  /// Проверяет, может ли текущий пользователь просматривать статистику
  bool get canViewStatistics => RoleHelper.canViewStatistics(_currentUserRole);

  /// Получает домашний маршрут на основе роли пользователя
  String get homeRoute => RoleHelper.getHomeRoute(_currentUserRole);

  // Check authentication status on app start
  Future<void> checkAuthStatus() async {
    _setLoading(true);
    try {
      final token = await _httpService.getToken();
      if (token != null && token.isNotEmpty) {
        // Восстанавливаем роль пользователя из токена
        _currentUserRole = RoleHelper.getRoleFromToken(token) ?? 'monitor';
        _isAuthenticated = true;

        // Пытаемся восстановить полный AccessToken из хранилища
        try {
          final prefs = await SharedPreferences.getInstance();
          final tokenData = prefs.getString('jwt_token');
          if (tokenData != null) {
            final tokenJson = jsonDecode(tokenData) as Map<String, dynamic>;
            _accessToken = AccessTokenModel.fromJson(tokenJson);
          }
        } catch (e) {
          print('Error restoring access token: $e');
        }

        // Также восстанавливаем данные экзамена если они есть
        final examDetails = await _httpService.getExamDetailsFromStorage();
        if (examDetails != null) {
          final bina = int.tryParse(examDetails.kodBina ?? '0') ?? 0;
          _authData = Auth(bina: bina, examDate: examDetails.imtTarix ?? '');
        }

        _clearError();
      } else {
        final auth = await _httpService.getAuth();
        _isAuthenticated = auth;
        if (!auth) {
          // Очищаем все данные если пользователь не авторизован
          _currentUserRole = null;
          _accessToken = null;
          _authData = null;
        }
      }
    } catch (e) {
      _setError('Avtorizasiya yoxlanılarkən xəta baş verdi');
      _isAuthenticated = false;
      _currentUserRole = null;
      _accessToken = null;
      _authData = null;
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

      // Clear all SQLite database on login
      await DatabaseService.clearAllDatabase();

      final response = await _httpService.login(userName, password, examDate);

      if (response.success && response.data.token.isNotEmpty) {
        // Store token
        await _httpService.storeToken(response.data);
        await _httpService.storeAuth(true);

        // Extract role from JWT token
        _currentUserRole =
            RoleHelper.getRoleFromToken(response.data.token) ?? 'monitor';

        // Extract bina from userName (following the original logic)
        final bina = int.tryParse(userName.substring(4)) ?? 0;

        // Store exam details for participant scanning
        final examDetails = ExamDetails(
          kodBina: bina.toString(),
          imtTarix: examDate,
          adBina: 'Bina $bina', // This could be fetched from server
        );
        await _httpService.storeExamDetails(examDetails);

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
      _currentUserRole = null;
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
