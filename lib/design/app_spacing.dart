import 'package:flutter/material.dart';

/// Система отступов и размеров приложения
class AppSpacing {
  AppSpacing._();

  /// Базовые отступы
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  /// Отступы для компонентов
  static const double cardPadding = 16.0;
  static const double screenPadding = 24.0;
  static const double buttonPadding = 16.0;
  static const double iconPadding = 12.0;

  /// Размеры элементов
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 60.0;

  /// Радиусы скругления
  static const double borderRadiusXS = 4.0;
  static const double borderRadiusSM = 8.0;
  static const double borderRadiusMD = 12.0;
  static const double borderRadiusLG = 16.0;
  static const double borderRadiusXL = 20.0;

  /// Размеры иконок
  static const double iconXS = 16.0;
  static const double iconSM = 20.0;
  static const double iconMD = 24.0;
  static const double iconLG = 32.0;
  static const double iconXL = 48.0;
  static const double iconXXL = 60.0;

  /// Отступы для EdgeInsets
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);

  /// Горизонтальные отступы
  static const EdgeInsets paddingHorizontalXS =
      EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets paddingHorizontalSM =
      EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMD =
      EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalLG =
      EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHorizontalXL =
      EdgeInsets.symmetric(horizontal: xl);

  /// Вертикальные отступы
  static const EdgeInsets paddingVerticalXS =
      EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets paddingVerticalSM =
      EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMD =
      EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalLG =
      EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets paddingVerticalXL =
      EdgeInsets.symmetric(vertical: xl);

  /// Отступы для экранов
  static const EdgeInsets screenPaddingAll = EdgeInsets.all(screenPadding);
  static const EdgeInsets screenPaddingHorizontal =
      EdgeInsets.symmetric(horizontal: screenPadding);

  /// SizedBox'ы для удобства
  static const Widget gapXS = SizedBox(height: xs, width: xs);
  static const Widget gapSM = SizedBox(height: sm, width: sm);
  static const Widget gapMD = SizedBox(height: md, width: md);
  static const Widget gapLG = SizedBox(height: lg, width: lg);
  static const Widget gapXL = SizedBox(height: xl, width: xl);

  /// Вертикальные разрывы
  static const Widget verticalGapXS = SizedBox(height: xs);
  static const Widget verticalGapSM = SizedBox(height: sm);
  static const Widget verticalGapMD = SizedBox(height: md);
  static const Widget verticalGapLG = SizedBox(height: lg);
  static const Widget verticalGapXL = SizedBox(height: xl);

  /// Горизонтальные разрывы
  static const Widget horizontalGapXS = SizedBox(width: xs);
  static const Widget horizontalGapSM = SizedBox(width: sm);
  static const Widget horizontalGapMD = SizedBox(width: md);
  static const Widget horizontalGapLG = SizedBox(width: lg);
  static const Widget horizontalGapXL = SizedBox(width: xl);

  /// Размеры для карточек и контейнеров
  static const double cardElevation = 2.0;
  static const double modalElevation = 8.0;
  static const double appBarElevation = 4.0;

  /// Размеры фотографий
  static const double avatarSM = 32.0;
  static const double avatarMD = 48.0;
  static const double avatarLG = 64.0;
  static const double avatarXL = 80.0;
  static const double avatarXXL = 120.0;
}
