import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'admin_style.dart';

/// White content card (SPEC §2): 95 % white / `surfaceDark`, radius 20,
/// soft shadow, 16 px padding. Optional [title] row with [trailing]; the
/// whole card is tappable when [onTap] is set (tap target ≥ 48 px high).
class AdminCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const AdminCard({
    super.key,
    this.title,
    this.trailing,
    this.onTap,
    this.padding = AppSpacing.paddingMD,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: AdminStyle.textPrimary(context),
                    ),
                  ),
                ),
                if (trailing != null) ...[AppSpacing.horizontalGapSM, trailing!],
              ],
            ),
            AppSpacing.verticalGapMD,
          ],
          child,
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AdminStyle.cardColor(context),
        borderRadius: AdminStyle.cardRadius,
        boxShadow: AdminStyle.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: AdminStyle.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: content,
                ),
              ),
      ),
    );
  }
}

/// "Glass" hero block: white 15 %, radius 20, soft shadow. For accent blocks
/// that sit directly on the gradient (white text inside).
class AdminGlassCard extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Widget child;

  const AdminGlassCard({
    super.key,
    this.padding = AppSpacing.paddingMD,
    this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AdminStyle.cardRadius,
        boxShadow: AdminStyle.glassShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: AdminStyle.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
