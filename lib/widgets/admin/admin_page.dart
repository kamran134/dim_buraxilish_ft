import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../common/gradient_background.dart';
import 'admin_layout.dart';

/// Frame of every admin screen: [GradientBackground] + white header (title,
/// subtitle, back OR menu button, [actions]) + body centred to
/// [AdminLayout.maxContentWidth].
///
/// Three ways to supply the body:
///  * `AdminPage(body: …)` — any widget; gets the page gutter as padding.
///  * `AdminPage.list(children: …)` — a scrolling list with gutters and
///    [spacing] between children.
///  * `AdminPage.builder(itemCount, itemBuilder)` — a lazy list for long data.
///
/// [headerBottom] (search field, segment switch, exam bar) is pinned under
/// the header. Set [onRefresh] for pull-to-refresh on the list variants.
///
/// With [inShell] the page lives in a bottom-bar tab of `AdminShell`: it
/// shows a "menu" button (opens the shell drawer) instead of "back" and does
/// not create its own `Scaffold`.
class AdminPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool inShell;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final List<Widget> actions;
  final Widget? headerBottom;
  final Future<void> Function()? onRefresh;

  final Widget? _body;
  final List<Widget>? _children;
  final int? _itemCount;
  final IndexedWidgetBuilder? _itemBuilder;
  final double _spacing;

  const AdminPage({
    super.key,
    required this.title,
    this.subtitle,
    this.inShell = false,
    this.onBack,
    this.onMenu,
    this.actions = const [],
    this.headerBottom,
    this.onRefresh,
    required Widget body,
  })  : _body = body,
        _children = null,
        _itemCount = null,
        _itemBuilder = null,
        _spacing = 0;

  const AdminPage.list({
    super.key,
    required this.title,
    this.subtitle,
    this.inShell = false,
    this.onBack,
    this.onMenu,
    this.actions = const [],
    this.headerBottom,
    this.onRefresh,
    double spacing = AppSpacing.md,
    required List<Widget> children,
  })  : _body = null,
        _children = children,
        _itemCount = null,
        _itemBuilder = null,
        _spacing = spacing;

  const AdminPage.builder({
    super.key,
    required this.title,
    this.subtitle,
    this.inShell = false,
    this.onBack,
    this.onMenu,
    this.actions = const [],
    this.headerBottom,
    this.onRefresh,
    double spacing = AppSpacing.sm + AppSpacing.xs,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  })  : _body = null,
        _children = null,
        _itemCount = itemCount,
        _itemBuilder = itemBuilder,
        _spacing = spacing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = AdminLayout.of(context);

    final content = GradientBackground(
      isDarkMode: isDark,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            _buildHeader(context, layout),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    _buildBody(context, layout, constraints),
              ),
            ),
          ],
        ),
      ),
    );

    if (inShell) return content;
    return Scaffold(backgroundColor: Colors.transparent, body: content);
  }

  Widget _buildHeader(BuildContext context, AdminLayout layout) {
    final canPop = onBack != null || Navigator.canPop(context);
    final Widget? leading;
    if (inShell) {
      leading = IconButton(
        tooltip: 'Menyu',
        onPressed: onMenu ?? () => _openDrawer(context),
        icon: const Icon(Icons.menu, color: Colors.white, size: 28),
      );
    } else if (canPop) {
      leading = IconButton(
        tooltip: 'Geri',
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
      );
    } else {
      leading = null;
    }

    // Keep the title centred: the leading slot and the actions slot get the
    // same width.
    const slot = 48.0;
    final sideWidth = math.max(slot, actions.length * slot);

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              layout.horizontalPadding - AppSpacing.sm,
              AppSpacing.sm,
              layout.horizontalPadding - AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: sideWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: leading,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.h4.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: sideWidth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions,
                      ),
                    ),
                  ],
                ),
                if (headerBottom != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      0,
                    ),
                    child: headerBottom,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDrawer(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.hasDrawer) scaffold.openDrawer();
  }

  Widget _buildBody(
    BuildContext context,
    AdminLayout layout,
    BoxConstraints constraints,
  ) {
    final gutter = layout.horizontalPadding;
    final contentWidth = math.min(constraints.maxWidth, layout.maxContentWidth);
    // Lists span the whole width (scrollbar and overscroll at the screen
    // edge); the inset keeps their content in the centred column.
    final sideInset = (constraints.maxWidth - contentWidth) / 2 + gutter;
    final bottomInset = AppSpacing.lg +
        (inShell ? 0 : MediaQuery.paddingOf(context).bottom);
    final listPadding = EdgeInsets.fromLTRB(
      sideInset,
      AppSpacing.md,
      sideInset,
      bottomInset,
    );

    final children = _children;
    final itemBuilder = _itemBuilder;
    Widget body;
    if (children != null) {
      body = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: listPadding,
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
        separatorBuilder: (context, index) => SizedBox(height: _spacing),
      );
    } else if (itemBuilder != null) {
      body = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: listPadding,
        itemCount: _itemCount!,
        itemBuilder: itemBuilder,
        separatorBuilder: (context, index) => SizedBox(height: _spacing),
      );
    } else {
      body = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: _body,
          ),
        ),
      );
    }

    if (onRefresh != null) {
      body = RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppColors.primary,
        child: body,
      );
    }
    return body;
  }
}
