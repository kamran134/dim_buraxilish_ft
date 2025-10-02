import 'dart:convert';
import '../models/role_models.dart';

/// Helper класс для работы с ролями пользователей
class RoleHelper {
  /// Проверяет, является ли роль административной (SuperAdmin или Admin)
  static bool isAdministrativeRole(String? role) {
    if (role == null) return false;
    final userRole = UserRole.fromString(role);
    return userRole.isAdmin;
  }

  /// Проверяет, является ли роль монитором
  static bool isMonitorRole(String? role) {
    if (role == null) return false;
    final userRole = UserRole.fromString(role);
    return userRole.isMonitor;
  }

  /// Проверяет, является ли роль супер-администратором
  static bool isSuperAdminRole(String? role) {
    if (role == null) return false;
    final userRole = UserRole.fromString(role);
    return userRole.isSuperAdmin;
  }

  /// Получает роль из JWT токена
  static String? getRoleFromToken(String? token) {
    if (token == null || token.isEmpty) return null;

    try {
      // Декодируем JWT токен
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Декодируем payload
      final payload = parts[1];
      final normalizedPayload = base64Url.normalize(payload);
      final decodedPayload = utf8.decode(base64Url.decode(normalizedPayload));
      final Map<String, dynamic> claims = json.decode(decodedPayload);

      // Извлекаем роль из claims (сначала проверяем .NET Core claim, потом простой)
      String? role =
          claims['http://schemas.microsoft.com/ws/2008/06/identity/claims/role']
                  as String? ??
              claims['role'] as String?;

      // Убираем лишние пробелы из роли
      return role?.trim();
    } catch (e) {
      return null;
    }
  }

  /// Получает описание роли на азербайджанском языке
  static String getRoleDescription(String? role) {
    if (role == null) return 'Monitor';

    final userRole = UserRole.fromString(role);
    switch (userRole) {
      case UserRole.superadmin:
        return 'Super Administrator';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.monitor:
        return 'Monitor';
    }
  }

  /// Определяет, какой экран показать пользователю после логина
  static String getHomeRoute(String? role) {
    if (isAdministrativeRole(role)) {
      return '/dashboard';
    } else {
      return '/home';
    }
  }

  /// Проверяет, может ли пользователь получить доступ к административным функциям
  static bool canAccessAdmin(String? role) {
    return isAdministrativeRole(role);
  }

  /// Проверяет, может ли пользователь получить доступ к сканеру
  static bool canAccessScanner(String? role) {
    return isMonitorRole(role) || isAdministrativeRole(role);
  }

  /// Проверяет, может ли пользователь управлять всеми данными
  static bool canManageAllData(String? role) {
    return isSuperAdminRole(role);
  }

  /// Проверяет, может ли пользователь просматривать статистику
  static bool canViewStatistics(String? role) {
    return isAdministrativeRole(role);
  }

  /// Получает список доступных функций для роли
  static List<String> getAvailableFunctions(String? role) {
    final userRole = UserRole.fromString(role);

    switch (userRole) {
      case UserRole.superadmin:
        return [
          'dashboard',
          'statistics',
          'participants',
          'supervisors',
          'settings',
          'user_management',
          'system_management',
        ];
      case UserRole.admin:
        return [
          'dashboard',
          'statistics',
          'participants',
          'supervisors',
          'settings',
        ];
      case UserRole.monitor:
        return [
          'scanner',
          'participants',
          'supervisors',
          'offline_data',
        ];
    }
  }

  /// Получает цвет темы для роли
  static int getRoleColor(String? role) {
    final userRole = UserRole.fromString(role);

    switch (userRole) {
      case UserRole.superadmin:
        return 0xFF6A11CB; // Фиолетовый
      case UserRole.admin:
        return 0xFF2575FC; // Синий
      case UserRole.monitor:
        return 0xFF00C851; // Зеленый
    }
  }

  /// Получает иконку для роли
  static int getRoleIconCode(String? role) {
    final userRole = UserRole.fromString(role);

    switch (userRole) {
      case UserRole.superadmin:
        return 0xe57c; // Icons.security
      case UserRole.admin:
        return 0xe8e6; // Icons.admin_panel_settings
      case UserRole.monitor:
        return 0xe8f4; // Icons.visibility
    }
  }
}
