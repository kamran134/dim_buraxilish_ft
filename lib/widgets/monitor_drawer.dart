import 'package:flutter/material.dart';
import '../screens/supervisor_screen.dart';
import '../screens/participant_screen.dart';
import '../screens/unsent_data_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/offline_database_screen.dart';
import 'common/base_drawer.dart';

/// Drawer для мониторов
/// Содержит полный набор функций для мониторинга экзамена
class MonitorDrawer extends StatelessWidget {
  const MonitorDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DrawerMenuItem> monitorMenuItems = [
      DrawerMenuItem(
        icon: Icons.home,
        title: 'Əsas',
        onTap: () {
          Navigator.pop(context);
        },
      ),
      DrawerMenuItem(
        icon: Icons.school,
        title: 'İmtahan iştirakçıları',
        onTap: () {
          Navigator.pop(context);
          _navigateToParticipantScreen(context);
        },
      ),
      DrawerMenuItem(
        icon: Icons.supervisor_account,
        title: 'Nəzarətçilər',
        onTap: () {
          Navigator.pop(context);
          _navigateToSupervisorScreen(context);
        },
      ),
      DrawerMenuItem(
        icon: Icons.signal_cellular_off,
        title: 'Göndərilməmiş məlumatlar',
        onTap: () {
          Navigator.pop(context);
          _navigateToUnsentDataScreen(context);
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
        icon: Icons.storage,
        title: 'Oflayn baza',
        onTap: () {
          Navigator.pop(context);
          _navigateToOfflineDatabaseScreen(context);
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
      menuItems: monitorMenuItems,
      title: 'Dövlət İmtahan Mərkəzi',
      subtitle: 'Buraxılış Sistemi',
    );
  }

  void _navigateToParticipantScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ParticipantScreen(),
      ),
    );
  }

  void _navigateToSupervisorScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SupervisorScreen(),
      ),
    );
  }

  void _navigateToUnsentDataScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const UnsentDataScreen(),
      ),
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

  void _navigateToOfflineDatabaseScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const OfflineDatabaseScreen(),
      ),
    );
  }
}
