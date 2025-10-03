import 'package:flutter/material.dart';
import '../../design/app_theme.dart';

enum GradientType {
  participant,
  supervisor,
  default_,
}

/// Переиспользуемый виджет для создания градиентного фона
class GradientBackground extends StatelessWidget {
  final Widget child;
  final GradientType gradientType;
  final bool isDarkMode;
  final List<Color>? customColors;

  const GradientBackground({
    super.key,
    required this.child,
    this.gradientType = GradientType.default_,
    this.isDarkMode = false,
    this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getGradientColors(),
        ),
      ),
      child: child,
    );
  }

  List<Color> _getGradientColors() {
    if (customColors != null) {
      return customColors!;
    }

    if (isDarkMode) {
      return [
        AppColors.darkGradient1,
        AppColors.darkGradient2,
        AppColors.darkGradient3,
      ];
    }

    switch (gradientType) {
      case GradientType.participant:
        return [
          AppColors.lightBlue,
          AppColors.darkBlue,
          AppColors.primaryBlue,
        ];
      case GradientType.supervisor:
        return [
          AppColors.primaryBlue,
          const Color(0xFFf5576c),
          const Color(0xFF764ba2),
        ];
      case GradientType.default_:
      default:
        return [
          AppColors.lightBlue,
          AppColors.darkBlue,
          AppColors.primaryBlue,
        ];
    }
  }
}
