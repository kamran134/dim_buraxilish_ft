import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../widgets/admin/admin_widgets.dart';
import 'admin_person_rows.dart';

/// Row of a person list: registration icon, name, identifier / details and
/// the registration (and violation) badges.
class AdminPersonTile extends StatelessWidget {
  final AdminPersonRow row;
  final VoidCallback? onTap;

  const AdminPersonTile({super.key, required this.row, this.onTap});

  @override
  Widget build(BuildContext context) {
    final detail = row.detail;
    final subtitle = [
      row.identifier,
      if (detail != null && detail.isNotEmpty) detail,
    ].join('\n');

    return AdminListTile(
      title: row.name,
      subtitle: subtitle,
      onTap: onTap,
      leading: Icon(
        row.registered ? Icons.check_circle : Icons.cancel,
        color: row.registered ? AppColors.success : AppColors.error,
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (row.violator) ...[
            const AdminStatusBadge(
              status: AdminStatus.warning,
              label: 'Pozuntu',
            ),
            AppSpacing.verticalGapXS,
          ],
          AdminStatusBadge(
            status: row.registered
                ? AdminStatus.registered
                : AdminStatus.notRegistered,
            label: row.registered ? 'Keçib' : 'Keçməyib',
          ),
        ],
      ),
    );
  }
}
