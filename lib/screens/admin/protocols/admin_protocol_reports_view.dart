import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../models/protocol_models.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/admin/admin_widgets.dart';

/// Filters of the protocol report (web `protocol-reports`): the exam date
/// plus a creation-date interval. At least one date is required to search.
class AdminProtocolFilters {
  final DateTime? examDate;
  final DateTime? startDate;
  final DateTime? endDate;

  const AdminProtocolFilters({this.examDate, this.startDate, this.endDate});

  static const AdminProtocolFilters empty = AdminProtocolFilters();

  bool get isEmpty => examDate == null && startDate == null && endDate == null;

  /// `yyyy-MM-dd` as the protocol API expects it.
  static String? apiDate(DateTime? date) => date == null
      ? null
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

  AdminProtocolFilters copyWith({
    DateTime? Function()? examDate,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
  }) =>
      AdminProtocolFilters(
        examDate: examDate != null ? examDate() : this.examDate,
        startDate: startDate != null ? startDate() : this.startDate,
        endDate: endDate != null ? endDate() : this.endDate,
      );

  @override
  bool operator ==(Object other) =>
      other is AdminProtocolFilters &&
      other.examDate == examDate &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(examDate, startDate, endDate);
}

/// How the result list is grouped.
enum AdminProtocolGrouping { none, building, type }

/// One line of the (possibly grouped) result list.
class AdminProtocolEntry {
  final String? groupLabel;
  final int? groupCount;
  final ProtocolNote? note;

  const AdminProtocolEntry.group(String label, int count)
      : groupLabel = label,
        groupCount = count,
        note = null;

  const AdminProtocolEntry.note(ProtocolNote this.note)
      : groupLabel = null,
        groupCount = null;

  bool get isGroup => note == null;

  /// Applies the free-text search (building, type, note — as the web does)
  /// and the grouping.
  static List<AdminProtocolEntry> build(
    List<ProtocolNote> notes, {
    String query = '',
    AdminProtocolGrouping grouping = AdminProtocolGrouping.none,
  }) {
    final needle = query.trim().toLowerCase();
    final filtered = needle.isEmpty
        ? notes
        : notes
            .where((n) => [n.buildingCode, n.noteTypeName, n.note]
                .any((v) => '$v'.toLowerCase().contains(needle)))
            .toList();

    if (grouping == AdminProtocolGrouping.none) {
      return [for (final n in filtered) AdminProtocolEntry.note(n)];
    }

    final groups = <Object, List<ProtocolNote>>{};
    for (final n in filtered) {
      final key = grouping == AdminProtocolGrouping.building
          ? n.buildingCode
          : n.noteTypeName;
      groups.putIfAbsent(key, () => []).add(n);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) => a is int && b is int
          ? a.compareTo(b)
          : '$a'.toLowerCase().compareTo('$b'.toLowerCase()));

    return [
      for (final key in keys) ...[
        AdminProtocolEntry.group(
          grouping == AdminProtocolGrouping.building ? 'Bina $key' : '$key',
          groups[key]!.length,
        ),
        for (final n in groups[key]!) AdminProtocolEntry.note(n),
      ],
    ];
  }
}

/// Protocol hesabatları: filters, search, grouping and a viewer for a single
/// record. Pure view — the loader owns the data and runs the request when
/// [onApply] fires.
class AdminProtocolReportsView extends StatefulWidget {
  /// Filters of the loaded data (the form starts from them).
  final AdminProtocolFilters filters;

  /// Null before the first search; empty after a search without results.
  final List<ProtocolNote>? protocols;
  final bool loading;
  final String? error;

  final ValueChanged<AdminProtocolFilters> onApply;
  final Future<void> Function() onRefresh;
  final VoidCallback? onRetry;

  final bool inShell;
  final VoidCallback? onMenu;

  const AdminProtocolReportsView({
    super.key,
    required this.filters,
    required this.onApply,
    required this.onRefresh,
    this.protocols,
    this.loading = false,
    this.error,
    this.onRetry,
    this.inShell = false,
    this.onMenu,
  });

  @override
  State<AdminProtocolReportsView> createState() =>
      _AdminProtocolReportsViewState();
}

class _AdminProtocolReportsViewState extends State<AdminProtocolReportsView> {
  late AdminProtocolFilters _draft = widget.filters;
  bool _filtersOpen = false;
  bool _missingDate = false;
  String _query = '';
  AdminProtocolGrouping _grouping = AdminProtocolGrouping.none;

  @override
  void didUpdateWidget(AdminProtocolReportsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filters != widget.filters) _draft = widget.filters;
  }

  Future<void> _pick(
    DateTime? current,
    AdminProtocolFilters Function(DateTime? picked) apply,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() {
        _draft = apply(picked);
        _missingDate = false;
      });
    }
  }

  void _search() {
    if (_draft.isEmpty) {
      setState(() => _missingDate = true);
      return;
    }
    setState(() {
      _missingDate = false;
      _query = '';
    });
    widget.onApply(_draft);
  }

  void _clear() {
    setState(() {
      _draft = AdminProtocolFilters.empty;
      _missingDate = false;
      _query = '';
    });
    widget.onApply(AdminProtocolFilters.empty);
  }

  String get _filterSummary {
    final f = widget.filters;
    final parts = [
      if (f.examDate != null)
        'İmtahan: ${DateFormatter.formatDateToAz(f.examDate!)}',
      if (f.startDate != null)
        'Başlanğıc: ${DateFormatter.formatDateToAz(f.startDate!)}',
      if (f.endDate != null)
        'Son: ${DateFormatter.formatDateToAz(f.endDate!)}',
    ];
    return parts.isEmpty ? 'Tarix seçilməyib' : parts.join(' · ');
  }

  void _openNote(ProtocolNote note) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AdminStyle.isDark(context)
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusXL),
        ),
      ),
      builder: (context) => _ProtocolNoteSheet(note: note),
    );
  }

  @override
  Widget build(BuildContext context) {
    final protocols = widget.protocols;
    final entries = protocols == null
        ? const <AdminProtocolEntry>[]
        : AdminProtocolEntry.build(
            protocols,
            query: _query,
            grouping: _grouping,
          );
    final noteCount = entries.where((e) => !e.isGroup).length;
    final hasData = protocols != null && protocols.isNotEmpty;

    // 0 filters, 1 controls (when there is data), 2 state / entries.
    final controlCount = hasData ? 1 : 0;
    final Widget? stateItem;
    if (widget.loading) {
      stateItem = const AdminLoading(message: 'Protokollar yüklənir...');
    } else if (widget.error != null) {
      stateItem =
          AdminErrorState(message: widget.error!, onRetry: widget.onRetry);
    } else if (protocols == null) {
      stateItem = const AdminEmptyState(
        icon: Icons.event_note,
        title: 'Tarix seçib axtarın',
        message: 'İmtahan və ya yaradılma tarixini seçin',
      );
    } else if (protocols.isEmpty) {
      stateItem = const AdminEmptyState(
        icon: Icons.search_off,
        title: 'Protokol tapılmadı',
        message: 'Seçilmiş filtrlər üçün heç bir protokol tapılmadı',
      );
    } else if (entries.isEmpty) {
      stateItem = const AdminEmptyState(
        icon: Icons.search_off,
        title: 'Heç nə tapılmadı',
      );
    } else {
      stateItem = null;
    }
    final listCount = stateItem != null ? 1 : entries.length;
    final showList = !widget.loading && widget.error == null;

    return AdminPage.builder(
      title: 'Protokol hesabatları',
      inShell: widget.inShell,
      onMenu: widget.onMenu,
      onRefresh: widget.onRefresh,
      itemCount: 1 + (showList ? controlCount : 0) + listCount,
      itemBuilder: (context, index) {
        if (index == 0) return _buildFilters();
        var i = index - 1;
        if (showList && controlCount > 0) {
          if (i == 0) return _buildControls(noteCount);
          i -= 1;
        }
        if (stateItem != null) return stateItem;
        final entry = entries[i];
        if (entry.isGroup) {
          return _GroupHeader(
            label: entry.groupLabel!,
            count: entry.groupCount!,
          );
        }
        return _ProtocolCard(
          note: entry.note!,
          onTap: () => _openNote(entry.note!),
        );
      },
    );
  }

  Widget _buildFilters() {
    return AdminCard(
      title: 'Filtrlər',
      trailing: IconButton(
        tooltip: _filtersOpen ? 'Filtrləri gizlə' : 'Filtrləri göstər',
        onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
        icon: Icon(
          _filtersOpen ? Icons.expand_less : Icons.expand_more,
          color: AdminStyle.textSecondary(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_filtersOpen)
            Text(
              _filterSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AdminStyle.textSecondary(context),
              ),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  _DateField(
                    label: 'İmtahan tarixi',
                    value: _draft.examDate,
                    onTap: () => _pick(
                      _draft.examDate,
                      (d) => _draft.copyWith(examDate: () => d),
                    ),
                    onClear: () => setState(
                      () => _draft = _draft.copyWith(examDate: () => null),
                    ),
                  ),
                  _DateField(
                    label: 'Başlanğıc tarix (yaradılma)',
                    value: _draft.startDate,
                    onTap: () => _pick(
                      _draft.startDate,
                      (d) => _draft.copyWith(startDate: () => d),
                    ),
                    onClear: () => setState(
                      () => _draft = _draft.copyWith(startDate: () => null),
                    ),
                  ),
                  _DateField(
                    label: 'Son tarix (yaradılma)',
                    value: _draft.endDate,
                    onTap: () => _pick(
                      _draft.endDate,
                      (d) => _draft.copyWith(endDate: () => d),
                    ),
                    onClear: () => setState(
                      () => _draft = _draft.copyWith(endDate: () => null),
                    ),
                  ),
                ];
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final field in fields) ...[
                        field,
                        AppSpacing.verticalGapSM,
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0) AppSpacing.horizontalGapSM,
                      Expanded(child: fields[i]),
                    ],
                  ],
                );
              },
            ),
            if (_missingDate)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Zəhmət olmasa axtarış üçün tarix seçin',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            AppSpacing.verticalGapSM,
            Row(
              children: [
                Expanded(
                  child: AdminActionButton(
                    label: 'Axtar',
                    icon: Icons.search,
                    style: AdminActionStyle.filled,
                    loading: widget.loading,
                    onPressed: _search,
                  ),
                ),
                AppSpacing.horizontalGapSM,
                Expanded(
                  child: AdminActionButton(
                    label: 'Təmizlə',
                    icon: Icons.close,
                    style: AdminActionStyle.outlined,
                    onPressed: _clear,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControls(int noteCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            '$noteCount protokol',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        AdminSegmented<AdminProtocolGrouping>(
          segments: const [
            AdminSegment(value: AdminProtocolGrouping.none, label: 'Hamısı'),
            AdminSegment(
              value: AdminProtocolGrouping.building,
              label: 'Bina üzrə',
            ),
            AdminSegment(
              value: AdminProtocolGrouping.type,
              label: 'Növ üzrə',
            ),
          ],
          selected: _grouping,
          onChanged: (value) => setState(() => _grouping = value),
        ),
        AppSpacing.verticalGapSM,
        AdminSearchField(
          hint: 'Bina, qeyd növü, qeyd',
          onChanged: (value) => setState(() => _query = value),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = AdminStyle.textSecondary(context);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.only(left: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AdminStyle.divider(context)),
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
          ),
          child: Row(
            children: [
              Icon(Icons.event, color: secondary),
              AppSpacing.horizontalGapSM,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: secondary),
                    ),
                    Text(
                      value == null
                          ? 'GG.AA.İİİİ'
                          : DateFormatter.formatDateToAz(value!),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: value == null
                            ? AppColors.textHint
                            : AdminStyle.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (value != null)
                IconButton(
                  tooltip: 'Təmizlə',
                  onPressed: onClear,
                  icon: Icon(Icons.close, color: secondary),
                )
              else
                const SizedBox(width: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final int count;

  const _GroupHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h5.copyWith(color: Colors.white),
            ),
          ),
          AppSpacing.horizontalGapSM,
          Text(
            '$count',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color color;

  const _Pill({this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXL),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            AppSpacing.horizontalGapXS,
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  final ProtocolNote note;
  final VoidCallback onTap;

  const _ProtocolCard({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final secondary = AdminStyle.textSecondary(context);
    return AdminCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _Pill(
                icon: Icons.business,
                text: 'Bina ${note.buildingCode}',
                color: AdminStyle.accent(context),
              ),
              _Pill(text: note.noteTypeName, color: AppColors.info),
            ],
          ),
          AppSpacing.verticalGapSM,
          Text(
            note.note,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AdminStyle.textPrimary(context),
            ),
          ),
          AppSpacing.verticalGapSM,
          Text(
            'İmtahan: ${DateFormatter.formatISOToAz(note.examDate)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: secondary),
          ),
          Text(
            'Əlavə edilib: ${DateFormatter.formatISOToAz(note.createdAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

/// Full record of one protocol note.
class _ProtocolNoteSheet extends StatelessWidget {
  final ProtocolNote note;

  const _ProtocolNoteSheet({required this.note});

  @override
  Widget build(BuildContext context) {
    final edited = note.updatedAt != note.createdAt;
    return SingleChildScrollView(
      padding: AppSpacing.paddingLG,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            note.noteTypeName,
            style: AppTextStyles.h4.copyWith(
              color: AdminStyle.textPrimary(context),
            ),
          ),
          AppSpacing.verticalGapMD,
          SelectableText(
            note.note,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AdminStyle.textPrimary(context),
            ),
          ),
          AppSpacing.verticalGapMD,
          AdminKeyValueList(
            items: [
              AdminKeyValue('Bina', '${note.buildingCode}'),
              AdminKeyValue(
                'İmtahan tarixi',
                DateFormatter.formatISOToAz(note.examDate),
              ),
              AdminKeyValue(
                'Yaradılma tarixi',
                DateFormatter.formatISOToAz(note.createdAt),
              ),
              if (edited)
                AdminKeyValue(
                  'Son redaktə',
                  DateFormatter.formatISOToAz(note.updatedAt),
                ),
            ],
          ),
          AppSpacing.verticalGapMD,
          AdminActionButton(
            label: 'Bağla',
            style: AdminActionStyle.outlined,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
