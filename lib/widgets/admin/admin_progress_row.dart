import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'admin_style.dart';

/// "Label — X / Y — %" row with a linear progress bar (registration of a
/// building or a hall). Wrap it in an [AdminCard] or put it in a list.
class AdminProgressRow extends StatelessWidget {
  final String label;
  final int done;
  final int total;

  /// Overrides the bar / percent colour; defaults to [colorForRate].
  final Color? color;
  final VoidCallback? onTap;

  const AdminProgressRow({
    super.key,
    required this.label,
    required this.done,
    required this.total,
    this.color,
    this.onTap,
  });

  double get rate => total <= 0 ? 0 : done / total * 100;

  /// ≥ 95 % success, ≥ 85 % brand blue, below that error.
  static Color colorForRate(double rate) {
    if (rate >= 95) return AppColors.success;
    if (rate >= 85) return AppColors.primary;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? colorForRate(rate);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AdminStyle.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppSpacing.horizontalGapSM,
              Text(
                '${rate.toStringAsFixed(1)}%',
                maxLines: 1,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AdminStyle.isDark(context)
                      ? AppColors.textOnDark
                      : barColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapXS,
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSM),
            child: LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              minHeight: 8,
              color: barColor,
              backgroundColor: AdminStyle.divider(context),
            ),
          ),
          AppSpacing.verticalGapXS,
          Text(
            '$done / $total',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AdminStyle.textSecondary(context),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: row,
      ),
    );
  }
}
