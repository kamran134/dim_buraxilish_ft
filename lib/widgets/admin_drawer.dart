import 'package:flutter/material.dart';

import '../screens/admin/admin_sections.dart';
import '../screens/admin/statistics/admin_statistics_rows.dart';
import 'common/base_drawer.dart';

/// Drawer of the admin area, built on [BaseDrawer] from [adminSections].
///
/// Inside `AdminShell` pass [selectedTab] / [selectedSegment] /
/// [onSelectSection]: items that live in a bottom-bar tab switch the tab (the
/// shell also applies the Statistika segment), the rest are pushed. Without
/// [onSelectSection] (a screen pushed on top of the shell) every item is
/// pushed, and "Əsas" returns to the shell.
class AdminDrawer extends StatelessWidget {
  final AdminTab? selectedTab;
  final AdminStatsSegment? selectedSegment;
  final ValueChanged<AdminSection>? onSelectSection;

  const AdminDrawer({
    super.key,
    this.selectedTab,
    this.selectedSegment,
    this.onSelectSection,
  });

  void _open(BuildContext context, AdminSection section) {
    final navigator = Navigator.of(context);
    navigator.pop(); // close the drawer

    if (section.tab != null && onSelectSection != null) {
      onSelectSection!(section);
    } else if (section.isHome) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      pushAdminSection(navigator, section);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final section in adminSections)
        DrawerMenuItem(
          icon: section.icon,
          title: section.drawerTitle,
          isSelected: section.tab != null &&
              section.tab == selectedTab &&
              (section.statsSegment == null ||
                  section.statsSegment == selectedSegment),
          onTap: () => _open(context, section),
        ),
    ];

    return BaseDrawer(
      menuItems: items,
      title: 'Dövlət İmtahan Mərkəzi',
      subtitle: 'Admin Panel',
    );
  }
}
