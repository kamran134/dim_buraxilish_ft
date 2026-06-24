import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/font_provider.dart';
import '../constants/app_version.dart';
import '../widgets/common/logout_button.dart';
import '../design/app_colors.dart';
import 'offline_database_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.lightBackground,
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
            _buildSectionCard(
              context: context,
              isDark: isDark,
              title: 'Görünüş',
              icon: Icons.palette_outlined,
              children: [
                _buildThemeSelector(context, isDark),
              ],
            ),

            const SizedBox(height: 16),

            _buildSectionCard(
              context: context,
              isDark: isDark,
              title: 'Şrift ölçüsü',
              icon: Icons.text_fields_outlined,
              children: [
                _buildFontSizeSelector(context, isDark),
              ],
            ),

            const SizedBox(height: 16),

            _buildSectionCard(
              context: context,
              isDark: isDark,
              title: 'Oflayn baza',
              icon: Icons.storage_outlined,
              children: [
                _buildNavigationTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.storage_outlined,
                  label: 'Oflayn bazanı idarə et',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OfflineDatabaseScreen(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildSectionCard(
              context: context,
              isDark: isDark,
              title: 'Hesab',
              icon: Icons.account_circle_outlined,
              children: [
                LogoutButton.settings(),
              ],
            ),

            const SizedBox(height: 32),

            _buildAboutSection(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Consumer<FontProvider>(
      builder: (context, fontProvider, child) {
        return Card(
          elevation: 2,
          color: isDark ? AppColors.surfaceDark : Colors.white,
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

  Widget _buildNavigationTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Consumer<FontProvider>(
      builder: (context, fontProvider, _) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                Icon(icon,
                    size: fontProvider.getTextSize(20),
                    color: const Color(0xFF1976D2)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: fontProvider.bodyLarge.copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: isDark ? Colors.white38 : Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeSelector(BuildContext context, bool isDark) {
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
                        ? const Color(0xFF1976D2).withValues(alpha: 0.15)
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1976D2)
                          : isDark
                              ? Colors.white24
                              : Colors.grey.withValues(alpha: 0.3),
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
                            : isDark
                                ? Colors.white70
                                : Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          themeProvider.getThemeDisplayName(themeMode),
                          style: fontProvider.bodyLarge.copyWith(
                            color: isSelected
                                ? const Color(0xFF1976D2)
                                : isDark
                                    ? Colors.white
                                    : Colors.black87,
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

  Widget _buildFontSizeSelector(BuildContext context, bool isDark) {
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
                        ? const Color(0xFF1976D2).withValues(alpha: 0.15)
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1976D2)
                          : isDark
                              ? Colors.white24
                              : Colors.grey.withValues(alpha: 0.3),
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
                            : isDark
                                ? Colors.white70
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
                            color: isSelected
                                ? const Color(0xFF1976D2)
                                : isDark
                                    ? Colors.white
                                    : Colors.black87,
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

  Widget _buildAboutSection(BuildContext context, bool isDark) {
    return Consumer<FontProvider>(
      builder: (context, fontProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white12
                  : Colors.grey.withValues(alpha: 0.2),
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
                style: fontProvider.titleMedium.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Buraxılış Skan Sistemi',
                style: fontProvider.bodyMedium.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Versiya ${AppVersion.version}',
                style: fontProvider.labelSmall.copyWith(
                  color: isDark ? Colors.white38 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Dövlət İmtahan Mərkəzi © 2025',
                style: fontProvider.labelSmall.copyWith(
                  color: isDark ? Colors.white54 : Colors.grey[600],
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
}
