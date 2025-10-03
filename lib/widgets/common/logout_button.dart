import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/login_screen.dart';

/// Типы отображения кнопки выхода
enum LogoutButtonType {
  drawer, // В боковом меню
  settings, // В настройках
  appBar, // В app bar
  floating, // Плавающая кнопка
}

/// Переиспользуемая кнопка выхода из системы
class LogoutButton extends StatelessWidget {
  final LogoutButtonType type;
  final String? title;
  final String? confirmTitle;
  final String? confirmMessage;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final VoidCallback? onLogoutSuccess;

  const LogoutButton({
    super.key,
    this.type = LogoutButtonType.settings,
    this.title,
    this.confirmTitle,
    this.confirmMessage,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onLogoutSuccess,
  });

  /// Фабричный метод для кнопки в drawer
  factory LogoutButton.drawer({
    VoidCallback? onLogoutSuccess,
  }) {
    return LogoutButton(
      type: LogoutButtonType.drawer,
      title: 'Sistemdən çıxış',
      confirmTitle: 'Sistemdən çıxış',
      confirmMessage: 'Sistemdən çıxmaq istədiyinizə əminsiniz?',
      onLogoutSuccess: onLogoutSuccess,
    );
  }

  /// Фабричный метод для кнопки в настройках
  factory LogoutButton.settings({
    VoidCallback? onLogoutSuccess,
  }) {
    return LogoutButton(
      type: LogoutButtonType.settings,
      title: 'Çıxış et',
      confirmTitle: 'Çıxış et',
      confirmMessage: 'Həqiqətən çıxış etmək istəyirsiniz?',
      onLogoutSuccess: onLogoutSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LogoutButtonType.drawer:
        return _buildDrawerButton(context);
      case LogoutButtonType.settings:
        return _buildSettingsButton(context);
      case LogoutButtonType.appBar:
        return _buildAppBarButton(context);
      case LogoutButtonType.floating:
        return _buildFloatingButton(context);
    }
  }

  Widget _buildDrawerButton(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showLogoutDialog(context),
        borderRadius: BorderRadius.circular(borderRadius ?? 8),
        child: Container(
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius ?? 8),
            border: Border.all(
              color: Colors.red.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.logout_outlined,
                size: 20,
                color: iconColor ?? Colors.red,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title ?? 'Sistemdən çıxış',
                  style: TextStyle(
                    color: textColor ?? Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: iconColor ?? Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context) {
    return InkWell(
      onTap: () => _showLogoutDialog(context),
      borderRadius: BorderRadius.circular(borderRadius ?? 8),
      child: Container(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius ?? 8),
          border: Border.all(
            color: backgroundColor ?? Colors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.logout_outlined,
              size: 20,
              color: iconColor ?? Colors.red,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title ?? 'Çıxış et',
                style: TextStyle(
                  color: textColor ?? Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: iconColor ?? Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarButton(BuildContext context) {
    return IconButton(
      onPressed: () => _showLogoutDialog(context),
      icon: Icon(
        Icons.logout_outlined,
        color: iconColor ?? Colors.white,
      ),
      tooltip: title ?? 'Çıxış',
    );
  }

  Widget _buildFloatingButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showLogoutDialog(context),
      backgroundColor: backgroundColor ?? Colors.red,
      child: Icon(
        Icons.logout_outlined,
        color: iconColor ?? Colors.white,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout_outlined,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                confirmTitle ?? 'Çıxış et',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            confirmMessage ?? 'Həqiqətən çıxış etmək istəyirsiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size(60, 36),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                'Ləğv et',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performLogout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 36),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Çıxış',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }

  void _performLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Perform logout
    await authProvider.signOut();

    // Call success callback if provided
    if (onLogoutSuccess != null) {
      onLogoutSuccess!();
    }

    // Navigate to login screen
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }
}
