import 'package:flutter/material.dart';

import '../screens/admin/admin_sections.dart';
import 'common/base_drawer.dart';

/// Drawer of the admin area, built on [BaseDrawer] from [adminSections].
///
/// Inside `AdminShell` pass [selectedTab] / [onSelectTab]: items that match a
/// bottom-bar tab switch the tab, the rest are pushed. Without [onSelectTab]
/// (a screen pushed on top of the shell) every item is pushed, and "Əsas"
/// returns to the shell.
class AdminDrawer extends StatelessWidget {
  final AdminTab? selectedTab;
  final ValueChanged<AdminTab>? onSelectTab;

  const AdminDrawer({super.key, this.selectedTab, this.onSelectTab});

  void _open(BuildContext context, AdminSection section) {
    final navigator = Navigator.of(context);
    navigator.pop(); // close the drawer

    final tab = section.tab;
    if (tab != null && onSelectTab != null) {
      onSelectTab!(tab);
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
          isSelected: section.tab != null && section.tab == selectedTab,
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
