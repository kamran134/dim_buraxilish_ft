import 'package:flutter/material.dart';
import '../../design/app_theme.dart';
import '../../constants/app_version.dart';
import 'logout_button.dart';

/// Модель элемента меню drawer
class DrawerMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isEnabled;

  const DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isEnabled = true,
  });
}

/// Базовый переиспользуемый компонент drawer
class BaseDrawer extends StatelessWidget {
  final List<DrawerMenuItem> menuItems;
  final String title;
  final String subtitle;

  const BaseDrawer({
    super.key,
    required this.menuItems,
    this.title = 'Dövlət İmtahan Mərkəzi',
    this.subtitle = 'Buraxılış Sistemi',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Container(
        color: isDark ? AppColors.backgroundDark : Colors.white,
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark.withOpacity(0.8)
                    : AppColors.surface.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Logo with enhanced styling
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color:
                                Colors.white.withOpacity(isDark ? 0.05 : 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                            spreadRadius: 0,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(isDark ? 0.1 : 0.2),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/logos/DIMLogo.png',
                          fit: BoxFit.cover,
                          width: 70,
                          height: 70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: isDark
                            ? AppColors.textOnDark
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: (isDark
                                ? AppColors.textOnDark
                                : AppColors.textPrimary)
                            .withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Menu Items Section
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: SingleChildScrollView(
                  child: Column(
                    children: menuItems
                        .map((item) => _buildDrawerItem(
                              context: context,
                              icon: item.icon,
                              title: item.title,
                              onTap: item.onTap,
                              isEnabled: item.isEnabled,
                              isDark: isDark,
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),

            // Footer Section
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Logout Button
                  LogoutButton.drawer(
                    onLogoutSuccess: () {
                      // Close drawer before navigation
                      Navigator.of(context).pop();
                    },
                  ),

                  // Footer Info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: (isDark
                                  ? AppColors.textOnDark
                                  : AppColors.textPrimary)
                              .withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Versiya: ${AppVersion.version}',
                          style: AppTextStyles.caption.copyWith(
                            color: (isDark
                                    ? AppColors.textOnDark
                                    : AppColors.textPrimary)
                                .withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Dövlət İmtahan Mərkəzi Ⓒ 2025',
                          style: AppTextStyles.caption.copyWith(
                            color: (isDark
                                    ? AppColors.textOnDark
                                    : AppColors.textPrimary)
                                .withOpacity(0.7),
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isEnabled,
    required bool isDark,
  }) {
    final Color textColor = isEnabled
        ? (isDark ? AppColors.textOnDark : AppColors.textPrimary)
        : (isDark ? AppColors.textOnDark : AppColors.textPrimary)
            .withOpacity(0.4);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        enabled: isEnabled,
        leading: Icon(
          icon,
          color: textColor,
          size: 20,
        ),
        title: Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        onTap: isEnabled ? onTap : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        hoverColor: (isDark ? AppColors.textOnDark : AppColors.textPrimary)
            .withOpacity(0.05),
        splashColor: (isDark ? AppColors.textOnDark : AppColors.textPrimary)
            .withOpacity(0.1),
      ),
    );
  }
}
