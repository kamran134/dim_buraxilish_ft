import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/common/message_display.dart';
import 'admin_person_rows.dart';
import 'admin_person_tile.dart';
import 'admin_statistics_rows.dart';

/// The people of a building (split into İştirakçılar / Nəzarətçilər /
/// İmtahan rəhbərləri) or of a room (no segment switch: [onSegmentChanged] is
/// null). Pure view: the loader hands over the rows of the selected [segment]
/// only.
class AdminPeopleView extends StatefulWidget {
  final String title;
  final String? subtitle;
  final AdminStatsSegment segment;

  /// null hides the segment switch (a room has imtahan rəhbərləri only).
  final ValueChanged<AdminStatsSegment>? onSegmentChanged;

  /// Rows of the selected segment; null until the first load finished.
  final List<AdminPersonRow>? rows;
  final bool loading;
  final String? error;

  final Future<void> Function() onRefresh;
  final VoidCallback? onRetry;
  final ValueChanged<AdminPersonRow>? onOpenPerson;

  const AdminPeopleView({
    super.key,
    required this.title,
    required this.segment,
    this.onSegmentChanged,
    required this.onRefresh,
    this.subtitle,
    this.rows,
    this.loading = false,
    this.error,
    this.onRetry,
    this.onOpenPerson,
  });

  @override
  State<AdminPeopleView> createState() => _AdminPeopleViewState();
}

class _AdminPeopleViewState extends State<AdminPeopleView> {
  String _query = '';
  AdminRegFilter _filter = AdminRegFilter.all;

  @override
  void didUpdateWidget(AdminPeopleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segment != widget.segment) {
      _query = '';
      _filter = AdminRegFilter.all;
    }
  }

  bool get _participants => widget.segment == AdminStatsSegment.participants;

  String get _emptyTitle => switch (widget.segment) {
        AdminStatsSegment.participants => 'Bu binada iştirakçı tapılmadı',
        AdminStatsSegment.supervisors => 'Bu binada nəzarətçi tapılmadı',
        AdminStatsSegment.monitors => 'Bu binada imtahan rəhbəri tapılmadı',
      };

  @override
  Widget build(BuildContext context) {
    final header = widget.onSegmentChanged == null
        ? null
        : AdminSegmented<AdminStatsSegment>(
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
            onChanged: widget.onSegmentChanged!,
          );

    final all = widget.rows;
    if (all == null) {
      final Widget body = widget.error != null && !widget.loading
          ? AdminErrorState(message: widget.error!, onRetry: widget.onRetry)
          : const AdminLoading();
      return AdminPage(
        title: widget.title,
        subtitle: widget.subtitle,
        headerBottom: header,
        onRefresh: widget.onRefresh,
        body: body,
      );
    }

    final rows = AdminPersonRow.filter(all, filter: _filter, query: _query);

    return AdminPage.builder(
      title: widget.title,
      subtitle: widget.subtitle,
      headerBottom: header,
      onRefresh: widget.onRefresh,
      itemCount: 2 + (rows.isEmpty ? 1 : rows.length),
      itemBuilder: (context, index) {
        if (index == 0) return _buildSummary(all);
        if (index == 1) return _buildControls();
        if (rows.isEmpty) {
          return AdminEmptyState(
            icon: all.isEmpty ? Icons.inbox_outlined : Icons.search_off,
            title: all.isEmpty ? _emptyTitle : 'Heç nə tapılmadı',
          );
        }
        final row = rows[index - 2];
        return AdminPersonTile(
          row: row,
          onTap: widget.onOpenPerson == null
              ? null
              : () => widget.onOpenPerson!(row),
        );
      },
    );
  }

  Widget _buildSummary(List<AdminPersonRow> all) {
    final registered = all.where((row) => row.registered).length;
    final total = all.length;
    final rate = total == 0 ? 0.0 : registered / total * 100;
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
            AdminStatTile(
              value: '$total',
              label: 'Ümumi',
              icon: Icons.groups,
            ),
            AdminStatTile(
              value: '$registered',
              label: 'Qeydiyyatdan keçən',
              icon: Icons.check_circle,
              color: AppColors.success,
              percent: rate,
            ),
            AdminStatTile(
              value: '${total - registered}',
              label: 'Qeydiyyatdan keçməyən',
              icon: Icons.cancel,
              color: AppColors.error,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSegmented<AdminRegFilter>(
          segments: [
            const AdminSegment(value: AdminRegFilter.all, label: 'Hamısı'),
            const AdminSegment(
              value: AdminRegFilter.registered,
              label: 'Keçən',
            ),
            const AdminSegment(
              value: AdminRegFilter.notRegistered,
              label: 'Keçməyən',
            ),
            if (_participants)
              const AdminSegment(
                value: AdminRegFilter.violators,
                label: 'Pozuntu',
              ),
          ],
          selected: _filter,
          onChanged: (value) => setState(() => _filter = value),
        ),
        AppSpacing.verticalGapSM,
        AdminSearchField(
          key: ValueKey(widget.segment),
          hint: _participants ? 'Ad, iş nömrəsi, FİN' : 'Ad, nömrə, FİN',
          onChanged: (value) => setState(() => _query = value),
        ),
      ],
    );
  }
}
