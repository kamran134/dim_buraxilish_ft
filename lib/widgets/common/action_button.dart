import 'package:flutter/material.dart';
import '../../design/app_theme.dart';

/// Переиспользуемая кнопка действия с иконкой
class ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String title;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;
  final double? width;
  final double? height;
  final double? fontSize;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final bool isLoading;
  final bool isEnabled;

  const ActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.title,
    this.backgroundColor,
    this.textColor = Colors.white,
    this.iconColor,
    this.width,
    this.height,
    this.fontSize = 18,
    this.iconSize = 24,
    this.padding,
    this.borderRadius = 12,
    this.isLoading = false,
    this.isEnabled = true,
  });

  /// Фабричный метод для кнопки сканирования
  factory ActionButton.scan({
    required VoidCallback onPressed,
    String? title,
    Color? backgroundColor,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return ActionButton(
      onPressed: onPressed,
      icon: Icons.qr_code_scanner,
      title: title ?? 'Skan et',
      backgroundColor: backgroundColor ?? AppColors.redButton,
      isLoading: isLoading,
      isEnabled: isEnabled,
    );
  }

  /// Фабричный метод для кнопки ручного ввода
  factory ActionButton.manualInput({
    required VoidCallback onPressed,
    String? title,
    Color? backgroundColor,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return ActionButton(
      onPressed: onPressed,
      icon: Icons.keyboard,
      title: title ?? 'Əllə daxil et',
      backgroundColor: backgroundColor ?? AppColors.blueButton,
      isLoading: isLoading,
      isEnabled: isEnabled,
    );
  }

  /// Фабричный метод для кнопки "Следующий"
  factory ActionButton.next({
    required VoidCallback onPressed,
    String? title,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return ActionButton(
      onPressed: onPressed,
      icon: Icons.qr_code_scanner,
      title: title ?? 'Növbəti',
      backgroundColor: Colors.green,
      fontSize: 14,
      iconSize: 18,
      isLoading: isLoading,
      isEnabled: isEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton.icon(
        onPressed: (isEnabled && !isLoading) ? onPressed : null,
        icon: isLoading
            ? SizedBox(
                width: iconSize ?? 24,
                height: iconSize ?? 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    iconColor ?? textColor ?? Colors.white,
                  ),
                ),
              )
            : Icon(
                icon,
                size: iconSize,
                color: iconColor ?? textColor,
              ),
        label: Text(
          title,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isEnabled ? (backgroundColor ?? AppColors.primary) : Colors.grey,
          foregroundColor: textColor ?? AppColors.textOnPrimary,
          padding: padding ?? AppSpacing.paddingMD,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                borderRadius ?? AppSpacing.borderRadiusMD),
          ),
          elevation: AppSpacing.cardElevation,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[600],
        ),
      ),
    );
  }
}
