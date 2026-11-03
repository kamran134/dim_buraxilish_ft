import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'admin_card.dart';
import 'admin_style.dart';

/// List row: [leading] (photo / icon / building code), [title], [subtitle],
/// [trailing] (badge / chevron). Rendered as a white card by default so it
/// can be dropped straight into a `ListView.builder`; pass `asCard: false`
/// to use it inside another [AdminCard].
class AdminListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool asCard;

  const AdminListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.asCard = true,
  });

  /// Rounded square carrying a short code (building number) as leading.
  static Widget codeLeading(BuildContext context, String code) {
    final accent = AdminStyle.accent(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
      ),
      child: Text(
        code,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyMedium.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _row(BuildContext context, double maxWidth) {
    return Row(
      children: [
        if (leading != null) ...[leading!, AppSpacing.horizontalGapMD],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AdminStyle.textPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AdminStyle.textSecondary(context),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[
          AppSpacing.horizontalGapSM,
          // Cap the trailing widget so a long badge cannot squeeze the title
          // out (or overflow the row).
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth * 0.4),
            child: trailing,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (asCard) {
      return AdminCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        child: LayoutBuilder(builder: (context, c) => _row(context, c.maxWidth)),
      );
    }
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: LayoutBuilder(builder: (context, c) => _row(context, c.maxWidth)),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
