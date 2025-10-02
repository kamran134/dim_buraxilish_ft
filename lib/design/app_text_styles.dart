import 'package:flutter/material.dart';

/// Типографическая система приложения
class AppTextStyles {
  AppTextStyles._();

  /// Заголовки
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle h5 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  /// Основной текст
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// Специальные стили
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle appBarTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  // Aliases for backward compatibility
  static const TextStyle heading1 = h1;
  static const TextStyle heading2 = h2;
  static const TextStyle heading3 = h3;
  static const TextStyle heading4 = h4;
  static const TextStyle heading5 = h5;

  static const TextStyle body1 = bodyLarge;
  static const TextStyle body2 = bodyMedium;
  static const TextStyle body3 = bodySmall;
}
