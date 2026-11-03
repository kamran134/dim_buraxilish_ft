import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'admin_card.dart';
import 'admin_style.dart';

/// Summary tile: a big number with a caption, an icon and an optional
/// percentage chip. [color] is the accent (icon + chip); defaults to the
/// brand blue. Used in the summary grids ([AdminGrid]).
class AdminStatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  /// Percentage 0–100, shown as a chip next to the icon when not null.
  final double? percent;
  final VoidCallback? onTap;

  const AdminStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color,
    this.percent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AdminStyle.accent(context);
    return AdminCard(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSpacing.avatarSM + AppSpacing.xs,
                height: AppSpacing.avatarSM + AppSpacing.xs,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
                ),
                child: Icon(icon, color: accent, size: AppSpacing.iconSM),
              ),
              const Spacer(),
              if (percent != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.borderRadiusLG),
                    ),
                    child: Text(
                      '${percent!.toStringAsFixed(1)}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.verticalGapSM,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.h3.copyWith(
                color: AdminStyle.textPrimary(context),
              ),
            ),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AdminStyle.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
