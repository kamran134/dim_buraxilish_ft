import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../widgets/admin/admin_layout.dart';
import '../../widgets/admin_drawer.dart';
import '../monitor_screen.dart';
import 'admin_home_screen.dart';
import 'admin_sections.dart';
import 'protocols/admin_protocol_reports_screen.dart';
import 'statistics/admin_statistics_rows.dart';
import 'statistics/admin_statistics_screen.dart';

/// Root of the admin area: four tabs (Əsas, Statistika, Skan, Protokollar)
/// behind a bottom bar — or a NavigationRail from `medium` width up — plus
/// the admin drawer. Tabs are built on first visit and then kept alive, so
/// their state survives switching.
class AdminShell extends StatefulWidget {
  final AdminTab initialTab;

  const AdminShell({super.key, this.initialTab = AdminTab.home});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const _destinations = <AdminTab, ({String label, IconData icon})>{
    AdminTab.home: (label: 'Əsas', icon: Icons.home),
    AdminTab.statistics: (label: 'Statistika', icon: Icons.analytics),
    AdminTab.scan: (label: 'Skan', icon: Icons.qr_code_scanner),
    AdminTab.protocols: (label: 'Protokollar', icon: Icons.assessment),
  };

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AdminTab _tab;
  AdminStatsSegment _statsSegment = AdminStatsSegment.participants;
  final Set<AdminTab> _visited = {};

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _visited.add(_tab);
  }

  void _select(AdminTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  void _openSection(AdminSection section) {
    final tab = section.tab;
    if (tab != null) {
      final segment = section.statsSegment;
      if (segment != null) setState(() => _statsSegment = segment);
      _select(tab);
    } else {
      pushAdminSection(Navigator.of(context), section);
    }
  }

  Widget _buildTab(AdminTab tab) {
    switch (tab) {
      case AdminTab.home:
        return AdminHomeScreen(
          active: _tab == AdminTab.home,
          onMenu: _openMenu,
          onOpenSection: _openSection,
        );
      case AdminTab.statistics:
        return AdminStatisticsScreen(
          segment: _statsSegment,
          onSegmentChanged: (segment) =>
              setState(() => _statsSegment = segment),
          active: _tab == AdminTab.statistics,
          onMenu: _openMenu,
        );
      case AdminTab.scan:
        return MonitorScreen(
          inShell: true,
          onMenu: _openMenu,
          active: _tab == AdminTab.scan,
        );
      case AdminTab.protocols:
        return AdminProtocolReportsScreen(inShell: true, onMenu: _openMenu);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = AdminLayout.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? AppColors.darkGradient2 : AppColors.primaryDark;

    final stack = IndexedStack(
      index: AdminTab.values.indexOf(_tab),
      children: [
        for (final tab in AdminTab.values)
          _visited.contains(tab)
              ? KeyedSubtree(key: ValueKey(tab), child: _buildTab(tab))
              : const SizedBox.shrink(),
      ],
    );

    return PopScope(
      canPop: _tab == AdminTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(AdminTab.home);
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: AdminDrawer(
          selectedTab: _tab,
          selectedSegment: _statsSegment,
          onSelectSection: _openSection,
        ),
        body: layout.useRail
            ? Row(
                children: [
                  _buildRail(barColor),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeLeft: true,
                      child: stack,
                    ),
                  ),
                ],
              )
            : stack,
        bottomNavigationBar: layout.useRail ? null : _buildBottomBar(barColor),
      ),
    );
  }

  Widget _buildBottomBar(Color barColor) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: barColor,
        indicatorColor: Colors.white.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white70,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white70,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: AdminTab.values.indexOf(_tab),
        onDestinationSelected: (index) => _select(AdminTab.values[index]),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final tab in AdminTab.values)
            NavigationDestination(
              icon: Icon(_destinations[tab]!.icon),
              label: _destinations[tab]!.label,
            ),
        ],
      ),
    );
  }

  Widget _buildRail(Color barColor) {
    return Material(
      color: barColor,
      child: SafeArea(
        right: false,
        child: LayoutBuilder(
          // Scrolls instead of overflowing on short (landscape) screens.
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: NavigationRail(
                  backgroundColor: barColor,
                  selectedIndex: AdminTab.values.indexOf(_tab),
                  onDestinationSelected: (index) =>
                      _select(AdminTab.values[index]),
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: Colors.white.withValues(alpha: 0.2),
                  selectedIconTheme: const IconThemeData(color: Colors.white),
                  unselectedIconTheme:
                      const IconThemeData(color: Colors.white70),
                  selectedLabelTextStyle: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelTextStyle: AppTextStyles.caption.copyWith(
                    color: Colors.white70,
                  ),
                  destinations: [
                    for (final tab in AdminTab.values)
                      NavigationRailDestination(
                        icon: Icon(_destinations[tab]!.icon),
                        label: Text(_destinations[tab]!.label),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
