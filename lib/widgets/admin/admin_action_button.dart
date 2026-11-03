import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'admin_style.dart';

/// Look of an [AdminActionButton].
///  * [primary] — white on the gradient (the main action of a screen);
///  * [glass] — translucent white with white text, for a secondary action on
///    the gradient;
///  * [outlined] — bordered, for use on a white card;
///  * [filled] — accent colour on a white card;
///  * [danger] — red, for destructive actions.
enum AdminActionStyle { primary, glass, outlined, filled, danger }

/// Full-width, 48 dp+ tall button of the admin kit.
class AdminActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AdminActionStyle style;
  final bool loading;

  const AdminActionButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.style = AdminActionStyle.primary,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AdminStyle.accent(context);
    final (Color bg, Color fg) = switch (style) {
      AdminActionStyle.primary => (Colors.white, AppColors.primary),
      AdminActionStyle.glass => (
          Colors.white.withValues(alpha: 0.15),
          Colors.white,
        ),
      AdminActionStyle.outlined => (Colors.transparent, accent),
      AdminActionStyle.filled => (AppColors.primary, Colors.white),
      AdminActionStyle.danger => (AppColors.error, Colors.white),
    };

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
      side: style == AdminActionStyle.outlined
          ? BorderSide(color: accent)
          : BorderSide.none,
    );
    final text = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppTextStyles.bodyMedium.copyWith(
        color: fg,
        fontWeight: FontWeight.w700,
      ),
    );
    final leading = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : (icon == null ? null : Icon(icon, color: fg));

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          minimumSize: const Size(0, AppSpacing.buttonHeight + 4),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: shape,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, AppSpacing.horizontalGapSM],
            Flexible(child: text),
          ],
        ),
      ),
    );
  }
}
