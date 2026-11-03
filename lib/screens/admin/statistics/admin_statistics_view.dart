import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../models/exam_statistics_dto.dart';
import '../../../models/monitor_room_statistics.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/common/message_display.dart';
import 'admin_statistics_rows.dart';

/// Statistika tab: segments (İştirakçılar / Nəzarətçilər / İmtahan
/// rəhbərləri), a summary, search + sort and the building (or room) list.
/// Pure view: data and callbacks come from `AdminStatisticsScreen`.
class AdminStatisticsView extends StatefulWidget {
  final AdminStatsSegment segment;
  final ValueChanged<AdminStatsSegment> onSegmentChanged;

  final List<ExamStatisticsDto> buildings;
  final List<MonitorRoomStatistics> rooms;
  final bool loading;
  final String? error;
  final bool noActiveSlot;
  final bool inShell;
  final VoidCallback? onMenu;

  final Future<void> Function() onRefresh;
  final VoidCallback? onRetry;
  final void Function(ExamStatisticsDto building, AdminStatsSegment segment)?
      onOpenBuilding;
  final ValueChanged<MonitorRoomStatistics>? onOpenRoom;

  const AdminStatisticsView({
    super.key,
    required this.segment,
    required this.onSegmentChanged,
    required this.onRefresh,
    this.buildings = const [],
    this.rooms = const [],
    this.loading = false,
    this.error,
    this.noActiveSlot = false,
    this.inShell = true,
    this.onMenu,
    this.onRetry,
    this.onOpenBuilding,
    this.onOpenRoom,
  });

  @override
  State<AdminStatisticsView> createState() => _AdminStatisticsViewState();
}

class _AdminStatisticsViewState extends State<AdminStatisticsView> {
  String _query = '';
  late AdminStatsSort _sort;
  late bool _ascending;

  @override
  void initState() {
    super.initState();
    _resetSort();
  }

  @override
  void didUpdateWidget(AdminStatisticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segment != widget.segment) {
      _query = '';
      _resetSort();
    }
  }

  // Rooms start with the least registered ones, buildings in code order.
  void _resetSort() {
    final rooms = widget.segment == AdminStatsSegment.monitors;
    _sort = rooms ? AdminStatsSort.rate : AdminStatsSort.code;
    _ascending = true;
  }

  List<AdminStatsRow> _allRows() {
    switch (widget.segment) {
      case AdminStatsSegment.participants:
        return AdminStatsRow.participants(widget.buildings);
      case AdminStatsSegment.supervisors:
        return AdminStatsRow.supervisors(widget.buildings);
      case AdminStatsSegment.monitors:
        return AdminStatsRow.rooms(widget.rooms);
    }
  }

  bool get _hasData => widget.segment == AdminStatsSegment.monitors
      ? widget.rooms.isNotEmpty
      : widget.buildings.isNotEmpty;

  void _open(AdminStatsRow row) {
    final source = row.source;
    if (source is ExamStatisticsDto) {
      widget.onOpenBuilding?.call(source, widget.segment);
    } else if (source is MonitorRoomStatistics) {
      widget.onOpenRoom?.call(source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = AdminSegmented<AdminStatsSegment>(
      segments: const [
        AdminSegment(
          value: AdminStatsSegment.participants,
          label: 'İştirakçılar',
        ),
        AdminSegment(
          value: AdminStatsSegment.supervisors,
          label: 'Nəzarətçilər',
        ),
        AdminSegment(
          value: AdminStatsSegment.monitors,
          label: 'İmtahan rəhbərləri',
        ),
      ],
      selected: widget.segment,
      onChanged: widget.onSegmentChanged,
    );

    Widget statePage(Widget body) => AdminPage(
          title: 'Statistika',
          subtitle: _subtitle,
          inShell: widget.inShell,
          onMenu: widget.onMenu,
          headerBottom: header,
          onRefresh: widget.onRefresh,
          body: body,
        );

    if (widget.noActiveSlot) {
      return statePage(
        const AdminEmptyState(
          icon: Icons.event_busy,
          title: 'İmtahan seçilməyib',
          message: 'Statistikanı görmək üçün imtahan seansını seçin',
        ),
      );
    }
    if (!_hasData) {
      if (widget.error != null && !widget.loading) {
        return statePage(
          AdminErrorState(message: widget.error!, onRetry: widget.onRetry),
        );
      }
      if (widget.loading) return statePage(const AdminLoading());
      return statePage(
        AdminEmptyState(
          icon: widget.segment == AdminStatsSegment.monitors
              ? Icons.meeting_room_outlined
              : Icons.business_outlined,
          title: widget.segment == AdminStatsSegment.monitors
              ? 'Otaq statistikası yoxdur'
              : 'Bina statistikası yoxdur',
          message: 'Bu seans üçün məlumat tapılmadı',
        ),
      );
    }

    final rows = AdminStatsRow.filterAndSort(
      _allRows(),
      query: _query,
      sort: _sort,
      ascending: _ascending,
    );

    return AdminPage.builder(
      title: 'Statistika',
      subtitle: _subtitle,
      inShell: widget.inShell,
      onMenu: widget.onMenu,
      headerBottom: header,
      onRefresh: widget.onRefresh,
      itemCount: 2 + (rows.isEmpty ? 1 : rows.length),
      itemBuilder: (context, index) {
        if (index == 0) return _buildSummary(context);
        if (index == 1) return _buildSearchRow();
        if (rows.isEmpty) {
          return const AdminEmptyState(
            icon: Icons.search_off,
            title: 'Heç nə tapılmadı',
          );
        }
        final row = rows[index - 2];
        return _StatsRowCard(
          row: row,
          showShortage: widget.segment == AdminStatsSegment.supervisors,
          onTap: () => _open(row),
        );
      },
    );
  }

  String get _subtitle => switch (widget.segment) {
        AdminStatsSegment.participants => 'Binalar üzrə iştirakçılar',
        AdminStatsSegment.supervisors => 'Binalar üzrə nəzarətçilər',
        AdminStatsSegment.monitors => 'Otaqlar üzrə imtahan rəhbərləri',
      };

  Widget _buildSearchRow() {
    final rooms = widget.segment == AdminStatsSegment.monitors;
    return Row(
      children: [
        Expanded(
          child: AdminSearchField(
            key: ValueKey(widget.segment),
            hint: rooms ? 'Otaq adı' : 'Bina kodu və ya adı',
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        AdminSortMenu<AdminStatsSort>(
          options: [
            AdminSortOption(
              value: AdminStatsSort.code,
              label: rooms ? 'Otaq nömrəsinə görə' : 'Bina koduna görə',
            ),
            const AdminSortOption(
              value: AdminStatsSort.name,
              label: 'Ada görə',
            ),
            const AdminSortOption(
              value: AdminStatsSort.rate,
              label: 'Qeydiyyat faizinə görə',
            ),
          ],
          selected: _sort,
          ascending: _ascending,
          onChanged: (value, ascending) => setState(() {
            _sort = value;
            _ascending = ascending;
          }),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final rows = _allRows();
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);
    final done = rows.fold<int>(0, (sum, row) => sum + row.done);
    final rate = total <= 0 ? 0.0 : done / total * 100;

    final String totalLabel;
    final IconData totalIcon;
    final String countLabel;
    final IconData countIcon;
    final String countValue;
    switch (widget.segment) {
      case AdminStatsSegment.participants:
        totalLabel = 'Ümumi iştirakçı';
        totalIcon = Icons.school;
        countLabel = 'Bina sayı';
        countIcon = Icons.business;
        countValue = '${rows.length}';
      case AdminStatsSegment.supervisors:
        totalLabel = 'Ümumi nəzarətçi';
        totalIcon = Icons.supervisor_account;
        countLabel = 'Zal sayı';
        countIcon = Icons.meeting_room;
        countValue =
            '${widget.buildings.fold<int>(0, (s, b) => s + (b.hallCount ?? 0))}';
      case AdminStatsSegment.monitors:
        totalLabel = 'Ümumi imtahan rəhbəri';
        totalIcon = Icons.badge;
        countLabel = 'Otaq sayı';
        countIcon = Icons.meeting_room;
        countValue = '${rows.length}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.error != null) ...[
          MessageDisplay(
            message: widget.error!,
            type: MessageType.error,
            margin: EdgeInsets.zero,
          ),
          AppSpacing.verticalGapMD,
        ],
        AdminGrid.tiles(
          children: [
            AdminStatTile(value: '$total', label: totalLabel, icon: totalIcon),
            AdminStatTile(
              value: '$done',
              label: 'Qeydiyyatdan keçən',
              icon: Icons.check_circle,
              color: AppColors.success,
              percent: rate,
            ),
            AdminStatTile(
              value: '${total - done}',
              label: 'Qeydiyyatdan keçməyən',
              icon: Icons.cancel,
              color: AppColors.error,
            ),
            AdminStatTile(
              value: countValue,
              label: countLabel,
              icon: countIcon,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsRowCard extends StatelessWidget {
  final AdminStatsRow row;
  final bool showShortage;
  final VoidCallback onTap;

  const _StatsRowCard({
    required this.row,
    required this.showShortage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminListTile.codeLeading(context, row.code),
              AppSpacing.horizontalGapMD,
              Expanded(
                child: AdminProgressRow(
                  label: row.title,
                  done: row.done,
                  total: row.total,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AdminStyle.textSecondary(context),
              ),
            ],
          ),
          if (row.note != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    row.note!,
                    style: AppTextStyles.caption.copyWith(
                      color: AdminStyle.textSecondary(context),
                    ),
                  ),
                  if (showShortage)
                    AdminStatusBadge(
                      status: row.shortage
                          ? AdminStatus.warning
                          : AdminStatus.registered,
                      label: row.shortage ? 'Yetərsay yoxdur' : 'Yetərsay var',
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
