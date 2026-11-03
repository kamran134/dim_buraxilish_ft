import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../common/photo_widget.dart';
import 'admin_style.dart';

/// Header of a person card (participant / supervisor / imtahan rəhbəri):
/// photo, full name, the key identifier (block / card number / code) and a
/// status widget (usually an [AdminStatusBadge]). Put it at the top of an
/// [AdminCard] on a details screen.
class AdminPersonHeader extends StatelessWidget {
  /// Base64 / data-URL photo, see [PhotoWidget].
  final String? photoData;
  final IconData placeholderIcon;
  final String name;
  final String? identifier;
  final Widget? status;
  final double photoSize;

  const AdminPersonHeader({
    super.key,
    this.photoData,
    this.placeholderIcon = Icons.person,
    required this.name,
    this.identifier,
    this.status,
    this.photoSize = AppSpacing.avatarXL,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
          child: SizedBox(
            width: photoSize,
            height: photoSize,
            child: ColoredBox(
              color: AdminStyle.divider(context),
              child: PhotoWidget(
                photoData: photoData,
                placeholderIcon: placeholderIcon,
                placeholderSize: photoSize / 2,
                width: photoSize,
                height: photoSize,
              ),
            ),
          ),
        ),
        AppSpacing.horizontalGapMD,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h5.copyWith(
                  color: AdminStyle.textPrimary(context),
                ),
              ),
              if (identifier != null && identifier!.isNotEmpty)
                Text(
                  identifier!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AdminStyle.textSecondary(context),
                  ),
                ),
              if (status != null) ...[AppSpacing.verticalGapSM, status!],
            ],
          ),
        ),
      ],
    );
  }
}
