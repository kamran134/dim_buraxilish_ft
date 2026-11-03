import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'admin_style.dart';

class AdminKeyValue {
  final String label;
  final String value;

  const AdminKeyValue(this.label, this.value);
}

/// "Label — value" rows for details screens, separated by hairlines. Empty
/// values render as an em dash. Long values wrap (up to 4 lines).
class AdminKeyValueList extends StatelessWidget {
  final List<AdminKeyValue> items;

  const AdminKeyValueList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(height: 1, thickness: 1, color: AdminStyle.divider(context)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    items[i].label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AdminStyle.textSecondary(context),
                    ),
                  ),
                ),
                AppSpacing.horizontalGapSM,
                Expanded(
                  flex: 3,
                  child: Text(
                    items[i].value.isEmpty ? '—' : items[i].value,
                    textAlign: TextAlign.end,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AdminStyle.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
