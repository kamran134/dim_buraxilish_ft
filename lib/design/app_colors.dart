import 'package:flutter/material.dart';

/// Цветовая палитра приложения
class AppColors {
  AppColors._();

  /// Основной синий цвет
  static const Color primaryBlue = Color(0xFF0046a3);

  /// Новые синие цвета для градиентов
  static const Color newBlueLight = Color(0xFF0c7bc5);
  static const Color newBlueDark = Color(0xFF0046a3);

  /// Дополнительные цвета
  static const Color lightBlue = Color(0xFF0c7bc5);
  static const Color white = Colors.white;
  static final Color whiteTransparent15 = Colors.white.withOpacity(0.15);
  static final Color whiteTransparent95 = Colors.white.withOpacity(0.95);
  static const Color white30 = Colors.white30;
  static const Color darkBlue = Color(0xFF0046a3);

  /// Цвета градиентов
  static const List<Color> participantGradient = [
    Color(0xFF667eea),
    Color(0xFF764ba2)
  ];

  static const List<Color> supervisorGradient = [
    Color(0xFFf093fb),
    Color(0xFFf5576c)
  ];

  /// Цвета статистики
  static const Color statisticsBlue = Color(0xFF677EEA);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFF44336);

  /// Фоновые цвета
  static const Color backgroundDark = Color(0xFF1e293b);
  static const Color backgroundMedium = Color(0xFF334155);
  static const Color backgroundLight = Color(0xFF475569);

  /// Цвета кнопок
  static const Color buttonBlue = Color(0xFF3498db);
  static const Color buttonRed = Color(0xFFe74c3c);

  /// Дополнительные цвета для UI
  static const Color borderGrey = Color(0xFFE5E5E5);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color cardBackground = Colors.white;

  /// Дополнительные градиенты
  static const List<Color> orangeGradient = [
    Color(0xFFe67e22),
    Color(0xFFd35400)
  ];

  static const List<Color> greenGradient = [
    Color(0xFF16a085),
    Color(0xFF27ae60)
  ];

  static const List<Color> purpleGradient = [
    Color(0xFF8e44ad),
    Color(0xFF9b59b6)
  ];

  static const List<Color> blueGradient = [
    Color(0xFF3498db),
    Color(0xFF2980b9)
  ];

  /// Светлые цвета
  static const Color lightBackground = Color(0xFFf8fafc);
  static const Color lightGrey = Color(0xFFe2e8f0);

  /// Глубокий синий
  static const Color deepBlue = Color(0xFF1E3A8A);

  /// Дополнительные цвета для splash screen
  static const Color splashBlue = Color(0xFF3B82F6);
  static const Color splashLightBlue = Color(0xFF60A5FA);
  static const Color splashLightGrey = Color(0xFFF3F4F6);

  /// Цвета для статусов
  static const Color registeredGreen = Color(0xFF4CAF50);
  static const Color notRegisteredRed = Color(0xFFf44336);

  /// Material Design цвета
  static const Color materialBlue = Color(0xFF2196F3);
  static const Color materialGreen = Color(0xFF4CAF50);

  /// Цвета кнопок (дополнительные)
  static const Color redButton = Color(0xFFe74c3c);
  static const Color blueButton = Color(0xFF3498db);

  /// Темные фоновые оттенки
  static const Color darkGradient1 = Color(0xFF1e293b);
  static const Color darkGradient2 = Color(0xFF334155);
  static const Color darkGradient3 = Color(0xFF475569);

  /// Оттенки серого
  static const Color lightGrey200 = Color(0xFFeeeeee);
  static const Color darkGrey = Color(0xFF757575);
  static const Color blackText = Color(0xDE000000); // Colors.black87

  /// Оттенки красного
  static const Color darkRed = Color(0xFFd32f2f); // Colors.red[700]

  /// Оттенки оранжевого
  static const Color orangeButton = Color(0xFFff9800); // Colors.orange.shade600
}
