import 'package:flutter/material.dart';

import '../../design/app_colors.dart';
import '../monitor_screen.dart';
import '../protocol_reports_screen.dart';
import '../settings_screen.dart';
import 'statistics/admin_statistics_rows.dart';
import 'statistics/admin_statistics_screen.dart';

/// Tabs of the bottom bar / rail, in display order.
enum AdminTab { home, statistics, scan, protocols }

/// One destination of the admin area. The drawer, the quick-link grid on
/// Əsas and the shell all read this single list, so adding a screen means
/// adding one entry here.
///
/// A section with a [tab] lives in a shell tab; without one it is pushed as
/// a normal route. Several sections may share a tab: the three Statistika
/// entries differ in [statsSegment]. [pageBuilder] is the screen to push; for tab sections it
/// is used only when the drawer is shown outside the shell.
class AdminSection {
  final String id;
  final String drawerTitle;
  final String tileTitle;
  final IconData icon;
  final List<Color> gradient;
  final AdminTab? tab;
  final AdminStatsSegment? statsSegment;
  final WidgetBuilder? pageBuilder;

  const AdminSection({
    required this.id,
    required this.drawerTitle,
    String? tileTitle,
    required this.icon,
    required this.gradient,
    this.tab,
    this.statsSegment,
    this.pageBuilder,
  }) : tileTitle = tileTitle ?? drawerTitle;

  bool get isHome => tab == AdminTab.home;
}

/// Sections in drawer order. Later stages append their screens here
/// (Bütün iştirakçılar, Cihazların statusu, Təcili elan, Profil, Şifrəni
/// dəyiş) — they are hidden until a screen exists.
final List<AdminSection> adminSections = [
  const AdminSection(
    id: 'home',
    drawerTitle: 'Əsas',
    icon: Icons.home,
    gradient: AppColors.blueGradient,
    tab: AdminTab.home,
  ),
  AdminSection(
    id: 'scan',
    drawerTitle: 'İmtahan rəhbəri skanı',
    icon: Icons.qr_code_scanner,
    gradient: AppColors.greenGradient,
    tab: AdminTab.scan,
    pageBuilder: (_) => const MonitorScreen(),
  ),
  AdminSection(
    id: 'statistics_participants',
    drawerTitle: 'Statistika: İştirakçılar',
    icon: Icons.analytics,
    gradient: AppColors.participantGradient,
    tab: AdminTab.statistics,
    statsSegment: AdminStatsSegment.participants,
    pageBuilder: (_) => const AdminStatisticsPage(
      segment: AdminStatsSegment.participants,
    ),
  ),
  AdminSection(
    id: 'statistics_supervisors',
    drawerTitle: 'Statistika: Nəzarətçilər',
    icon: Icons.supervisor_account,
    gradient: AppColors.participantGradient,
    tab: AdminTab.statistics,
    statsSegment: AdminStatsSegment.supervisors,
    pageBuilder: (_) => const AdminStatisticsPage(
      segment: AdminStatsSegment.supervisors,
    ),
  ),
  AdminSection(
    id: 'statistics_monitors',
    drawerTitle: 'Statistika: İmtahan rəhbərləri',
    icon: Icons.badge,
    gradient: AppColors.participantGradient,
    tab: AdminTab.statistics,
    statsSegment: AdminStatsSegment.monitors,
    pageBuilder: (_) => const AdminStatisticsPage(
      segment: AdminStatsSegment.monitors,
    ),
  ),
  AdminSection(
    id: 'protocols',
    drawerTitle: 'Protokol hesabatları',
    icon: Icons.assessment,
    gradient: AppColors.orangeGradient,
    tab: AdminTab.protocols,
    pageBuilder: (_) => const ProtocolReportsScreen(),
  ),
  AdminSection(
    id: 'settings',
    drawerTitle: 'Ayarlar',
    icon: Icons.settings,
    gradient: AppColors.purpleGradient,
    pageBuilder: (_) => const SettingsScreen(),
  ),
];

/// Opens [section] with plain navigation (used when there is no shell to
/// switch tabs in).
void pushAdminSection(NavigatorState navigator, AdminSection section) {
  final builder = section.pageBuilder;
  if (builder == null) return;
  navigator.push(MaterialPageRoute(builder: builder));
}
