/// Центральный файл для импорта всех элементов дизайн-системы
/// Использование: import '../design/app_theme.dart';
library app_theme;

// Экспорт всех компонентов дизайн-системы
export 'app_colors.dart';
export 'app_text_styles.dart';
export 'app_spacing.dart';

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_spacing.dart';

/// Главный класс темы приложения
class AppTheme {
  AppTheme._();

  /// Светлая тема приложения
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Цветовая схема
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryLight,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryLight,
        surface: AppColors.surface,
        background: AppColors.background,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSecondary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
        onError: AppColors.textOnPrimary,
      ),

      // Типографика
      textTheme: const TextTheme(
        headlineLarge: AppTextStyles.h1,
        headlineMedium: AppTextStyles.h2,
        headlineSmall: AppTextStyles.h3,
        titleLarge: AppTextStyles.h4,
        titleMedium: AppTextStyles.h5,
        titleSmall: AppTextStyles.cardTitle,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.buttonText,
        labelMedium: AppTextStyles.caption,
        labelSmall: AppTextStyles.overline,
      ),

      // AppBar тема
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: AppSpacing.appBarElevation,
        centerTitle: true,
        titleTextStyle: AppTextStyles.appBarTitle,
        iconTheme: IconThemeData(
          color: AppColors.textOnPrimary,
          size: AppSpacing.iconMD,
        ),
      ),

      // Тема кнопок
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          textStyle: AppTextStyles.buttonText,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
          ),
          padding: AppSpacing.paddingMD,
          elevation: AppSpacing.cardElevation,
        ),
      ),

      // Тема карточек
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: AppSpacing.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
        ),
        margin: AppSpacing.paddingSM,
      ),

      // Тема полей ввода
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSM),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSM),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSM),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSM),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: AppSpacing.paddingMD,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textHint,
        ),
      ),

      // Тема иконок
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: AppSpacing.iconMD,
      ),

      // Общие отступы
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.borderGrey,
    );
  }

  /// Темная тема приложения (для будущего использования)
  static ThemeData get darkTheme {
    return lightTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        primaryContainer: AppColors.primary,
        secondary: AppColors.secondaryLight,
        secondaryContainer: AppColors.secondary,
        surface: AppColors.surfaceDark,
        background: AppColors.backgroundDark,
        error: AppColors.error,
        onPrimary: AppColors.textOnDark,
        onSecondary: AppColors.textOnDark,
        onSurface: AppColors.textOnDark,
        onBackground: AppColors.textOnDark,
        onError: AppColors.textOnDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
    );
  }

  /// Получить подходящий цвет текста для заданного фона
  static Color getTextColorForBackground(Color backgroundColor) {
    return ThemeData.estimateBrightnessForColor(backgroundColor) ==
            Brightness.light
        ? AppColors.textPrimary
        : AppColors.textOnDark;
  }

  /// Получить подходящий стиль текста с цветом для заданного фона
  static TextStyle getTextStyleForBackground(
      TextStyle baseStyle, Color backgroundColor) {
    return baseStyle.copyWith(
      color: getTextColorForBackground(backgroundColor),
    );
  }
}

/// Дополнительные утилиты для работы с темой
class AppThemeUtils {
  AppThemeUtils._();

  /// Создать Box Shadow для карточек
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: AppColors.textPrimary.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Создать Box Shadow для модальных окон
  static List<BoxShadow> get modalShadow => [
        BoxShadow(
          color: AppColors.textPrimary.withOpacity(0.2),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  /// Создать Border для элементов
  static Border get defaultBorder => Border.all(
        color: AppColors.borderGrey,
        width: 1,
      );

  /// Создать Border Radius
  static BorderRadius borderRadius(double radius) =>
      BorderRadius.circular(radius);

  /// Стандартные Border Radius'ы
  static BorderRadius get smallRadius =>
      borderRadius(AppSpacing.borderRadiusSM);
  static BorderRadius get mediumRadius =>
      borderRadius(AppSpacing.borderRadiusMD);
  static BorderRadius get largeRadius =>
      borderRadius(AppSpacing.borderRadiusLG);
}
