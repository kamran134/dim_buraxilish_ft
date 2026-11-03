import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

enum AdminStatus { registered, notRegistered, online, offline, warning }

/// Status pill (registered / not registered / online / offline / warning).
/// The default caption follows the status; pass [label] to override it.
class AdminStatusBadge extends StatelessWidget {
  final AdminStatus status;
  final String? label;

  const AdminStatusBadge({super.key, required this.status, this.label});

  Color get _color => switch (status) {
        AdminStatus.registered => AppColors.success,
        AdminStatus.online => AppColors.success,
        AdminStatus.notRegistered => AppColors.error,
        AdminStatus.offline => AppColors.error,
        AdminStatus.warning => AppColors.warning,
      };

  String get _defaultLabel => switch (status) {
        AdminStatus.registered => 'Qeydiyyatdan keçib',
        AdminStatus.notRegistered => 'Qeydiyyatdan keçməyib',
        AdminStatus.online => 'Onlayn',
        AdminStatus.offline => 'Oflayn',
        AdminStatus.warning => 'Diqqət',
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXL),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          AppSpacing.horizontalGapXS,
          Flexible(
            child: Text(
              label ?? _defaultLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
