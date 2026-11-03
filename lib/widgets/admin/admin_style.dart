import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

/// Shared colours and decorations of the admin kit, resolved against the
/// current theme brightness. Keeps every kit widget on the same palette.
class AdminStyle {
  AdminStyle._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(AppSpacing.borderRadiusXL));

  /// White card at 95 % (dark theme: [AppColors.surfaceDark]).
  static Color cardColor(BuildContext context) => isDark(context)
      ? AppColors.surfaceDark
      : Colors.white.withValues(alpha: 0.95);

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? AppColors.textOnDark : AppColors.textPrimary;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? Colors.white70 : AppColors.textSecondary;

  /// Accent used for icons / links on top of a card.
  static Color accent(BuildContext context) =>
      isDark(context) ? AppColors.splashLightBlue : AppColors.primary;

  static Color divider(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ];

  /// Same shadow idea for the glass blocks, a bit stronger on the gradient.
  static List<BoxShadow> get glassShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ];
}
