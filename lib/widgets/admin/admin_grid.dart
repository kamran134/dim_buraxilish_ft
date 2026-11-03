import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'admin_layout.dart';

/// Non-scrolling grid for use inside a `ListView` / `Column`: lays children
/// out in rows of [columns] equal cells, every row as tall as its tallest
/// cell. Unlike a fixed-aspect-ratio `GridView` it cannot overflow when the
/// text scale grows — cells simply get taller.
///
/// Use [AdminGrid.tiles] / [AdminGrid.cards] to pick the column count from
/// [AdminLayout] (clamped so cells never get narrower than
/// [AdminLayout.minCellWidth]).
class AdminGrid extends StatelessWidget {
  final int columns;
  final double spacing;
  final List<Widget> children;

  const AdminGrid({
    super.key,
    required this.columns,
    this.spacing = AppSpacing.md,
    required this.children,
  });

  /// 2 / 3 / 4 columns by breakpoint (stat tiles, menu tiles).
  static Widget tiles({
    Key? key,
    double spacing = AppSpacing.md,
    required List<Widget> children,
  }) =>
      _AdaptiveGrid(
        key: key,
        spacing: spacing,
        columnsFor: (layout) => layout.tileColumns,
        children: children,
      );

  /// 1 / 2 / 3 columns by breakpoint (wide cards).
  static Widget cards({
    Key? key,
    double spacing = AppSpacing.md,
    required List<Widget> children,
  }) =>
      _AdaptiveGrid(
        key: key,
        spacing: spacing,
        columnsFor: (layout) => layout.cardColumns,
        children: children,
      );

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final cols = columns < 1 ? 1 : columns;
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += cols) {
      final cells = <Widget>[];
      for (var i = 0; i < cols; i++) {
        if (i > 0) cells.add(SizedBox(width: spacing));
        final index = start + i;
        cells.add(
          Expanded(
            child: index < children.length
                ? children[index]
                : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _AdaptiveGrid extends StatelessWidget {
  final double spacing;
  final int Function(AdminLayout layout) columnsFor;
  final List<Widget> children;

  const _AdaptiveGrid({
    super.key,
    required this.spacing,
    required this.columnsFor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final layout = AdminLayout.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AdminLayout.fitColumns(
          columnsFor(layout),
          constraints.maxWidth,
          spacing,
        );
        return AdminGrid(
          columns: columns,
          spacing: spacing,
          children: children,
        );
      },
    );
  }
}
