import 'package:flutter/material.dart';

/// Цветовая палитра приложения
class AppColors {
  AppColors._();

  // ========== ОСНОВНЫЕ ЦВЕТА ==========

  /// Главные цвета бренда
  static const Color primary = Color(0xFF0046a3);
  static const Color primaryLight = Color(0xFF0c7bc5);
  static const Color primaryDark = Color(0xFF003176);

  /// Вторичные цвета
  static const Color secondary = Color(0xFF667eea);
  static const Color secondaryLight = Color(0xFF8e96f0);
  static const Color secondaryDark = Color(0xFF4c63d2);

  // ========== СЕМАНТИЧЕСКИЕ ЦВЕТА ==========

  /// Статусные цвета
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  /// Фоновые цвета
  static const Color background = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF1E293B);
  static const Color surface = Colors.white;
  static const Color surfaceDark = Color(0xFF334155);

  // ========== ТЕКСТОВЫЕ ЦВЕТА ==========

  /// Цвета текста
  static const Color textPrimary = Color(0xDE000000); // 87% black
  static const Color textSecondary = Color(0x99000000); // 60% black
  static const Color textHint = Color(0x61000000); // 38% black
  static const Color textOnPrimary = Colors.white;
  static const Color textOnDark = Colors.white;

  // ========== СОВМЕСТИМОСТЬ (LEGACY) ==========

  /// Старые названия для обратной совместимости
  static const Color primaryBlue = primary;
  static const Color newBlueLight = primaryLight;
  static const Color newBlueDark = primaryDark;
  static const Color lightBlue = primaryLight;
  static const Color white = Colors.white;
  static final Color whiteTransparent15 = Colors.white.withOpacity(0.15);
  static final Color whiteTransparent95 = Colors.white.withOpacity(0.95);
  static const Color white30 = Colors.white30;
  static const Color darkBlue = primaryDark;

  // ========== ГРАДИЕНТЫ ==========

  /// Градиенты для экранов
  static const List<Color> participantGradient = [
    Color(0xFF667eea),
    Color(0xFF764ba2)
  ];

  static const List<Color> supervisorGradient = [
    Color(0xFFf093fb),
    Color(0xFFf5576c)
  ];

  static const List<Color> orangeGradient = [
    Color(0xFFe67e22),
    Color(0xFFd35400)
  ];

  static const List<Color> greenGradient = [
    Color(0xFF16a085),
    Color(0xFF27ae60)
  ];

  static const List<Color> blueGradient = [
    Color(0xFF3498db),
    Color(0xFF2980b9)
  ];

  // ========== СОВМЕСТИМОСТЬ - СТАРЫЕ НАЗВАНИЯ ==========

  /// Цвета статистики (legacy)
  static const Color statisticsBlue = Color(0xFF677EEA);
  static const Color successGreen = success;
  static const Color errorRed = error;

  /// Кнопки (legacy)
  static const Color buttonBlue = Color(0xFF3498db);
  static const Color buttonRed = Color(0xFFe74c3c);
  static const Color redButton = buttonRed;
  static const Color blueButton = buttonBlue;

  /// UI элементы (legacy)
  static const Color borderGrey = Color(0xFFE5E5E5);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color cardBackground = surface;

  // ========== ДОПОЛНИТЕЛЬНЫЕ ГРАДИЕНТЫ ==========

  static const List<Color> purpleGradient = [
    Color(0xFF8e44ad),
    Color(0xFF9b59b6)
  ];

  // ========== ДОПОЛНИТЕЛЬНЫЕ ЦВЕТА ==========

  /// Вспомогательные цвета
  static const Color lightBackground = background;
  static const Color lightGrey = Color(0xFFe2e8f0);
  static const Color lightGrey200 = Color(0xFFeeeeee);
  static const Color darkGrey = Color(0xFF757575);

  /// Специальные цвета
  static const Color deepBlue = Color(0xFF1E3A8A);
  static const Color splashBlue = Color(0xFF3B82F6);
  static const Color splashLightBlue = Color(0xFF60A5FA);
  static const Color splashLightGrey = Color(0xFFF3F4F6);

  /// Статусные цвета (дополнительные)
  static const Color registeredGreen = success;
  static const Color notRegisteredRed = error;
  static const Color materialBlue = info;
  static const Color materialGreen = success;

  /// Темные градиентные цвета
  static const Color darkGradient1 = backgroundDark;
  static const Color darkGradient2 = surfaceDark;
  static const Color darkGradient3 = Color(0xFF475569);

  /// Дополнительные оттенки
  static const Color blackText = textPrimary;
  static const Color darkRed = Color(0xFFd32f2f);
  static const Color orangeButton = warning;
}
