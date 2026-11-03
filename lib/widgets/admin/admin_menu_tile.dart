import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'admin_card.dart';
import 'admin_style.dart';

/// Menu tile in the style of `MenuCard` on the building home screen: a
/// round gradient icon, a caption and an optional badge. Unlike `MenuCard`
/// it has no fixed aspect ratio, so large text scales never overflow it.
class AdminMenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final int badgeCount;
  final VoidCallback? onTap;

  const AdminMenuTile({
    super.key,
    required this.title,
    required this.icon,
    required this.gradient,
    this.badgeCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: AppSpacing.xxl + AppSpacing.sm,
                height: AppSpacing.xxl + AppSpacing.sm,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: AppSpacing.iconMD + 4, color: Colors.white),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    constraints:
                        const BoxConstraints(minWidth: 20, minHeight: 20),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.overline.copyWith(
                        color: Colors.white,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.verticalGapSM,
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AdminStyle.textPrimary(context),
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
