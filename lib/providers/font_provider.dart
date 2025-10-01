import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Размеры шрифтов в приложении
enum AppFontSize { small, medium, large, extraLarge }

/// Провайдер для управления шрифтами приложения
class FontProvider extends ChangeNotifier {
  static const String _fontSizeKey = 'app_font_size';

  AppFontSize _fontSize = AppFontSize.medium;

  AppFontSize get fontSize => _fontSize;

  /// Инициализация провайдера - загрузка сохраненного размера шрифта
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFontSize = prefs.getString(_fontSizeKey);

      if (savedFontSize != null) {
        _fontSize = AppFontSize.values.firstWhere(
          (size) => size.name == savedFontSize,
          orElse: () => AppFontSize.medium,
        );
      }
    } catch (e) {
      print('Error loading font size: $e');
      _fontSize = AppFontSize.medium;
    }

    notifyListeners();
  }

  /// Изменить размер шрифта
  Future<void> setFontSize(AppFontSize size) async {
    if (_fontSize == size) return;

    _fontSize = size;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fontSizeKey, size.name);
    } catch (e) {
      print('Error saving font size: $e');
    }
  }

  /// Получить название размера шрифта на азербайджанском языке
  String getFontSizeDisplayName(AppFontSize size) {
    switch (size) {
      case AppFontSize.small:
        return 'Kiçik';
      case AppFontSize.medium:
        return 'Orta';
      case AppFontSize.large:
        return 'Böyük';
      case AppFontSize.extraLarge:
        return 'Çox böyük';
    }
  }

  /// Получить множитель размера шрифта
  double getFontSizeMultiplier(AppFontSize size) {
    switch (size) {
      case AppFontSize.small:
        return 0.85;
      case AppFontSize.medium:
        return 1.0;
      case AppFontSize.large:
        return 1.15;
      case AppFontSize.extraLarge:
        return 1.3;
    }
  }

  /// Получить размер для конкретного стиля текста
  double getTextSize(double baseSize) {
    return baseSize * getFontSizeMultiplier(_fontSize);
  }

  /// Создать TextStyle с учетом текущего размера шрифта
  TextStyle createTextStyle({
    required double baseSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontSize: getTextSize(baseSize),
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
    );
  }

  /// Готовые стили текста с учетом размера шрифта

  /// Заголовок страницы (AppBar title)
  TextStyle get titleLarge => createTextStyle(
        baseSize: 20,
        fontWeight: FontWeight.w600,
      );

  /// Заголовок секции
  TextStyle get titleMedium => createTextStyle(
        baseSize: 16,
        fontWeight: FontWeight.w600,
      );

  /// Обычный текст
  TextStyle get bodyLarge => createTextStyle(
        baseSize: 16,
      );

  /// Средний текст
  TextStyle get bodyMedium => createTextStyle(
        baseSize: 14,
      );

  /// Маленький текст
  TextStyle get bodySmall => createTextStyle(
        baseSize: 12,
      );

  /// Текст кнопки
  TextStyle get labelLarge => createTextStyle(
        baseSize: 16,
        fontWeight: FontWeight.w500,
      );

  /// Подпись/caption
  TextStyle get labelSmall => createTextStyle(
        baseSize: 12,
        color: Colors.grey[600],
      );
}
