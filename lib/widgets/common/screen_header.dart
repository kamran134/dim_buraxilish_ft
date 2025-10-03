import 'package:flutter/material.dart';
import '../../design/app_text_styles.dart';

/// Переиспользуемый заголовок для экранов с кнопкой назад
class ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;
  final bool showBackButton;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const ScreenHeader({
    super.key,
    required this.title,
    this.onBackPressed,
    this.backgroundColor,
    this.textColor = Colors.white,
    this.iconColor = Colors.white,
    this.showBackButton = true,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              if (showBackButton)
                IconButton(
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.arrow_back,
                    color: iconColor,
                    size: 28,
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Балансируем кнопку назад
              SizedBox(width: showBackButton ? 48 : 0),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}
