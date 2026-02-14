import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/protocol_reports_screen.dart';
import '../screens/monitor_screen.dart';
import 'common/base_drawer.dart';

/// Drawer для администраторов
/// Содержит только основные разделы: Əsas, Statistika, Ayarlar, Sistemdən çıxış
class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DrawerMenuItem> adminMenuItems = [
      DrawerMenuItem(
        icon: Icons.home,
        title: 'Əsas',
        onTap: () {
          Navigator.pop(context);
        },
      ),
      DrawerMenuItem(
        icon: Icons.assessment,
        title: 'Protokol hesabatları',
        onTap: () {
          Navigator.pop(context);
          _navigateToProtocolReportsScreen(context);
        },
      ),
      DrawerMenuItem(
        icon: Icons.people_alt,
        title: 'İmtahan rəhbərləri',
        onTap: () {
          Navigator.pop(context);
          _navigateToMonitorScreen(context);
        },
      ),
      DrawerMenuItem(
        icon: Icons.analytics,
        title: 'Statistika',
        onTap: () {
          Navigator.pop(context);
          _navigateToStatisticsScreen(context);
        },
      ),
      DrawerMenuItem(
        icon: Icons.settings,
        title: 'Ayarlar',
        onTap: () {
          Navigator.pop(context);
          _navigateToSettingsScreen(context);
        },
      ),
    ];

    return BaseDrawer(
      menuItems: adminMenuItems,
      title: 'Dövlət İmtahan Mərkəzi',
      subtitle: 'Admin Panel',
    );
  }

  void _navigateToSettingsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _navigateToStatisticsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StatisticsScreen(),
      ),
    );
  }

  void _navigateToProtocolReportsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProtocolReportsScreen(),
      ),
    );
  }

  void _navigateToMonitorScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MonitorScreen(),
      ),
    );
  }
}
