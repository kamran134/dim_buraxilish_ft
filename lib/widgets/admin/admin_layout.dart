import 'package:flutter/material.dart';

/// Width classes used by every admin screen.
enum AdminBreakpoint { compact, medium, expanded }

/// Responsive layout rules for the admin UI kit (SPEC §2.2).
///
/// compact < 600, medium 600–1024, expanded ≥ 1024. Create one from the
/// current screen width with [AdminLayout.of] or from any width with
/// [AdminLayout.fromWidth] (handy in tests and inside `LayoutBuilder`).
class AdminLayout {
  static const double mediumFrom = 600;
  static const double expandedFrom = 1024;

  /// Smallest width a grid cell may shrink to before a column is dropped.
  static const double minCellWidth = 140;

  final double width;
  final AdminBreakpoint breakpoint;

  const AdminLayout._(this.width, this.breakpoint);

  factory AdminLayout.fromWidth(double width) {
    final AdminBreakpoint breakpoint;
    if (width >= expandedFrom) {
      breakpoint = AdminBreakpoint.expanded;
    } else if (width >= mediumFrom) {
      breakpoint = AdminBreakpoint.medium;
    } else {
      breakpoint = AdminBreakpoint.compact;
    }
    return AdminLayout._(width, breakpoint);
  }

  factory AdminLayout.of(BuildContext context) =>
      AdminLayout.fromWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => breakpoint == AdminBreakpoint.compact;
  bool get isExpanded => breakpoint == AdminBreakpoint.expanded;

  /// medium+ swaps the bottom bar for a NavigationRail (SPEC §2.2).
  bool get useRail => !isCompact;

  /// Columns for grids of small tiles (stat tiles, menu tiles): 2 / 3 / 4.
  int get tileColumns => switch (breakpoint) {
        AdminBreakpoint.compact => 2,
        AdminBreakpoint.medium => 3,
        AdminBreakpoint.expanded => 4,
      };

  /// Columns for grids of wide cards: 1 / 2 / 3.
  int get cardColumns => switch (breakpoint) {
        AdminBreakpoint.compact => 1,
        AdminBreakpoint.medium => 2,
        AdminBreakpoint.expanded => 3,
      };

  /// Widest the page content may grow; compact uses the whole width.
  double get maxContentWidth => switch (breakpoint) {
        AdminBreakpoint.compact => double.infinity,
        AdminBreakpoint.medium => 840,
        AdminBreakpoint.expanded => 1200,
      };

  /// Horizontal gutter: 16 / 24 / 32.
  double get horizontalPadding => switch (breakpoint) {
        AdminBreakpoint.compact => 16,
        AdminBreakpoint.medium => 24,
        AdminBreakpoint.expanded => 32,
      };

  /// [columns] reduced so cells of an [available]-wide area never get
  /// narrower than [minCellWidth] (landscape phones, rail layouts).
  static int fitColumns(int columns, double available, double spacing) {
    var result = columns;
    while (result > 1 &&
        (available - spacing * (result - 1)) / result < minCellWidth) {
      result--;
    }
    return result;
  }
}
