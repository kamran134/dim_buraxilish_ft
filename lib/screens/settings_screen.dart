import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/font_provider.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<FontProvider>(
          builder: (context, fontProvider, child) {
            return Text(
              'Ayarlar',
              style: fontProvider.titleLarge.copyWith(color: Colors.white),
            );
          },
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Settings Section
            _buildSectionCard(
              context: context,
              title: 'Görünüş',
              icon: Icons.palette_outlined,
              children: [
                _buildThemeSelector(context),
              ],
            ),

            const SizedBox(height: 16),

            // Font Settings Section
            _buildSectionCard(
              context: context,
              title: 'Şrift ölçüsü',
              icon: Icons.text_fields_outlined,
              children: [
                _buildFontSizeSelector(context),
              ],
            ),

            const SizedBox(height: 24),

            // Logout Section
            _buildSectionCard(
              context: context,
              title: 'Hesab',
              icon: Icons.account_circle_outlined,
              children: [
                _buildLogoutTile(context),
              ],
            ),

            const SizedBox(height: 32),

            // About Section
            _buildAboutSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Consumer<FontProvider>(
      builder: (context, fontProvider, child) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: fontProvider.getTextSize(20),
                      color: const Color(0xFF1976D2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: fontProvider.titleMedium.copyWith(
                        color: const Color(0xFF1976D2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return Consumer2<ThemeProvider, FontProvider>(
      builder: (context, themeProvider, fontProvider, child) {
        return Column(
          children: AppThemeMode.values.map((themeMode) {
            final isSelected = themeProvider.themeMode == themeMode;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => themeProvider.setThemeMode(themeMode),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? const Color(0xFF1976D2).withOpacity(0.1)
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1976D2)
                          : Colors.grey.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        themeProvider.getThemeIcon(themeMode),
                        size: fontProvider.getTextSize(20),
                        color: isSelected
                            ? const Color(0xFF1976D2)
                            : Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          themeProvider.getThemeDisplayName(themeMode),
                          style: fontProvider.bodyLarge.copyWith(
                            color: isSelected ? const Color(0xFF1976D2) : null,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: const Color(0xFF1976D2),
                          size: fontProvider.getTextSize(20),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFontSizeSelector(BuildContext context) {
    return Consumer<FontProvider>(
      builder: (context, fontProvider, child) {
        return Column(
          children: AppFontSize.values.map((fontSize) {
            final isSelected = fontProvider.fontSize == fontSize;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => fontProvider.setFontSize(fontSize),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? const Color(0xFF1976D2).withOpacity(0.1)
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1976D2)
                          : Colors.grey.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.text_format,
                        size: fontProvider.getFontSizeMultiplier(fontSize) * 20,
                        color: isSelected
                            ? const Color(0xFF1976D2)
                            : Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          fontProvider.getFontSizeDisplayName(fontSize),
                          style: TextStyle(
                            fontSize:
                                fontProvider.getFontSizeMultiplier(fontSize) *
                                    16,
                            color: isSelected ? const Color(0xFF1976D2) : null,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: const Color(0xFF1976D2),
                          size: fontProvider.getTextSize(20),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return Consumer<FontProvider>(
      builder: (context, fontProvider, child) {
        return InkWell(
          onTap: () => _showLogoutDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.logout_outlined,
                  size: fontProvider.getTextSize(20),
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Çıxış et',
                    style: fontProvider.bodyLarge.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: fontProvider.getTextSize(16),
                  color: Colors.red,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Consumer<FontProvider>(
      builder: (context, fontProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                size: fontProvider.getTextSize(32),
                color: const Color(0xFF1976D2),
              ),
              const SizedBox(height: 12),
              Text(
                'Haqqında',
                style: fontProvider.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Buraxılış Skan Sistemi',
                style: fontProvider.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Versiya 1.0.0',
                style: fontProvider.labelSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Dövlət İmtahan Mərkəzi © 2025',
                style: fontProvider.labelSmall.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Consumer<FontProvider>(
          builder: (context, fontProvider, child) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.logout_outlined,
                    color: Colors.red,
                    size: fontProvider.getTextSize(24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Çıxış et',
                    style: fontProvider.titleMedium,
                  ),
                ],
              ),
              content: Text(
                'Həqiqətən çıxış etmək istəyirsiniz?',
                style: fontProvider.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    'Ləğv et',
                    style: fontProvider.labelLarge.copyWith(
                      color: Colors.grey[600],
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
                  ),
                  child: Text(
                    'Çıxış et',
                    style:
                        fontProvider.labelLarge.copyWith(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _performLogout(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.signOut().then((_) {
      // Navigate to login screen
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    });
  }
}
