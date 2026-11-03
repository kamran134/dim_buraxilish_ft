import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../models/admin_models.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/admin/admin_widgets.dart';
import 'emergency_draft.dart';

enum EmergencyTab { send, history }

Color emergencyColor(EmergencyImportance importance) => switch (importance) {
      EmergencyImportance.info => AppColors.info,
      EmergencyImportance.warning => AppColors.warning,
      EmergencyImportance.urgent => AppColors.error,
    };

IconData emergencyIcon(EmergencyImportance importance) => switch (importance) {
      EmergencyImportance.info => Icons.info_outline,
      EmergencyImportance.warning => Icons.warning_amber_rounded,
      EmergencyImportance.urgent => Icons.error_outline,
    };

/// Buildings whose code or name contains [query].
List<EmergencyBuilding> filterEmergencyBuildings(
  List<EmergencyBuilding> buildings,
  String query,
) {
  final term = query.trim().toLowerCase();
  if (term.isEmpty) return buildings;
  return [
    for (final b in buildings)
      if (b.code.toLowerCase().contains(term) ||
          b.name.toLowerCase().contains(term))
        b,
  ];
}

/// Təcili elan: compose and send an emergency message (importance, text,
/// all buildings or a picked set) and browse the history with the buildings
/// that acknowledged each message. Pure view — [onSend] runs after the user
/// confirmed and resolves to whether the message went out.
class AdminEmergencyView extends StatelessWidget {
  static const String _title = 'Təcili elan';

  final String? subtitle;
  final EmergencyTab tab;
  final ValueChanged<EmergencyTab> onTabChanged;
  final EmergencyDraft draft;

  /// Buildings of the active exam; null until loaded.
  final List<EmergencyBuilding>? buildings;
  final String? buildingsError;
  final bool hasExam;
  final VoidCallback? onReloadBuildings;

  final bool sending;
  final Future<void> Function() onSend;

  /// Sent messages; null until loaded.
  final List<EmergencyHistoryItem>? history;
  final String? historyError;
  final Future<void> Function() onRefreshHistory;

  const AdminEmergencyView({
    super.key,
    this.subtitle,
    required this.tab,
    required this.onTabChanged,
    required this.draft,
    this.buildings,
    this.buildingsError,
    this.hasExam = true,
    this.onReloadBuildings,
    this.sending = false,
    required this.onSend,
    this.history,
    this.historyError,
    required this.onRefreshHistory,
  });

  @override
  Widget build(BuildContext context) {
    final header = AdminSegmented<EmergencyTab>(
      selected: tab,
      onChanged: onTabChanged,
      segments: const [
        AdminSegment(
          value: EmergencyTab.send,
          label: 'Göndər',
          icon: Icons.campaign,
        ),
        AdminSegment(
          value: EmergencyTab.history,
          label: 'Tarixçə',
          icon: Icons.history,
        ),
      ],
    );

    if (tab == EmergencyTab.history) return _buildHistory(header);

    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => AdminPage.list(
        title: _title,
        subtitle: subtitle,
        headerBottom: header,
        children: [
          _MessageCard(draft: draft),
          _RecipientsCard(
            draft: draft,
            buildings: buildings,
            buildingsError: buildingsError,
            hasExam: hasExam,
            onReload: onReloadBuildings,
          ),
          AdminActionButton(
            label: 'Göndər',
            icon: Icons.send,
            loading: sending,
            onPressed: draft.canSend && !sending
                ? () => _confirmAndSend(context)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSend(BuildContext context) async {
    final recipients = draft.sendToAll
        ? 'Bütün binalar'
        : '${draft.selected.length} bina seçilib';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mesajı göndər'),
        content: SingleChildScrollView(
          child: Text(
            '"${draft.title.text.trim()}"\n\n'
            'Əhəmiyyət: ${draft.importance.label}\n'
            'Alıcılar: $recipients\n\n'
            'Mesaj dərhal göndəriləcək.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ləğv et'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Göndər'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onSend();
  }

  Widget _buildHistory(Widget header) {
    final items = history;
    if (items == null) {
      return AdminPage(
        title: _title,
        subtitle: subtitle,
        headerBottom: header,
        body: historyError != null
            ? AdminErrorState(
                message: historyError!,
                onRetry: onRefreshHistory,
              )
            : const AdminLoading(),
      );
    }
    if (items.isEmpty) {
      return AdminPage(
        title: _title,
        subtitle: subtitle,
        headerBottom: header,
        onRefresh: onRefreshHistory,
        body: const AdminEmptyState(
          icon: Icons.campaign_outlined,
          title: 'Hələ mesaj göndərilməyib',
        ),
      );
    }
    return AdminPage.builder(
      title: _title,
      subtitle: subtitle,
      headerBottom: header,
      onRefresh: onRefreshHistory,
      itemCount: items.length,
      itemBuilder: (context, index) => _HistoryCard(item: items[index]),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final EmergencyDraft draft;

  const _MessageCard({required this.draft});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      title: 'Mesaj',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final importance in EmergencyImportance.values) ...[
            _ImportanceOption(
              importance: importance,
              selected: draft.importance == importance,
              onTap: () => draft.setImportance(importance),
            ),
            AppSpacing.verticalGapSM,
          ],
          AppSpacing.verticalGapXS,
          TextField(
            controller: draft.title,
            maxLength: EmergencyDraft.maxTitleLength,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Başlıq',
              border: OutlineInputBorder(),
            ),
          ),
          AppSpacing.verticalGapSM,
          TextField(
            controller: draft.body,
            maxLength: EmergencyDraft.maxBodyLength,
            minLines: 4,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Mesajın mətni',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportanceOption extends StatelessWidget {
  final EmergencyImportance importance;
  final bool selected;
  final VoidCallback onTap;

  const _ImportanceOption({
    required this.importance,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = emergencyColor(importance);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
          side: BorderSide(
            color: selected ? color : AdminStyle.divider(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(emergencyIcon(importance), color: color),
                  AppSpacing.horizontalGapMD,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          importance.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AdminStyle.textPrimary(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          importance.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AdminStyle.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientsCard extends StatelessWidget {
  final EmergencyDraft draft;
  final List<EmergencyBuilding>? buildings;
  final String? buildingsError;
  final bool hasExam;
  final VoidCallback? onReload;

  const _RecipientsCard({
    required this.draft,
    required this.buildings,
    required this.buildingsError,
    required this.hasExam,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      title: 'Alıcılar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: draft.sendToAll,
            onChanged: draft.setSendToAll,
            title: Text(
              'Bütün binalara göndər',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AdminStyle.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!draft.sendToAll) ..._buildPicker(context),
        ],
      ),
    );
  }

  List<Widget> _buildPicker(BuildContext context) {
    final secondary = AppTextStyles.bodySmall.copyWith(
      color: AdminStyle.textSecondary(context),
    );
    if (!hasExam) {
      return [Text('Bina siyahısı üçün imtahan seçin', style: secondary)];
    }
    final all = buildings;
    if (all == null) {
      if (buildingsError == null) {
        return [const Center(child: CircularProgressIndicator())];
      }
      return [
        Text(buildingsError!, style: secondary),
        if (onReload != null)
          TextButton.icon(
            onPressed: onReload,
            icon: const Icon(Icons.refresh),
            label: const Text('Yenidən cəhd et'),
          ),
      ];
    }

    final shown = filterEmergencyBuildings(all, draft.buildingQuery);
    final allShownSelected =
        shown.isNotEmpty && shown.every((b) => draft.selected.contains(b.code));
    return [
      TextField(
        onChanged: draft.setBuildingQuery,
        decoration: const InputDecoration(
          hintText: 'Bina kodu və ya adı',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
      ),
      AppSpacing.verticalGapSM,
      Wrap(
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Seçilmiş: ${draft.selected.length}', style: secondary),
          TextButton(
            onPressed:
                shown.isEmpty ? null : () => draft.toggleAll(shown.map((b) => b.code)),
            child: Text(allShownSelected ? 'Seçimi ləğv et' : 'Hamısını seç'),
          ),
          if (draft.selected.isNotEmpty)
            TextButton(
              onPressed: draft.clearSelection,
              child: const Text('Təmizlə'),
            ),
        ],
      ),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Text('Bina tapılmadı', style: secondary),
        )
      else
        SizedBox(
          height: 320,
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (context, index) {
              final building = shown[index];
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: draft.selected.contains(building.code),
                onChanged: (_) => draft.toggle(building.code),
                title: Text(
                  building.name.isEmpty ? building.code : building.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AdminStyle.textPrimary(context),
                  ),
                ),
                subtitle: Text('Bina ${building.code}', style: secondary),
              );
            },
          ),
        ),
    ];
  }
}

class _HistoryCard extends StatefulWidget {
  final EmergencyHistoryItem item;

  const _HistoryCard({required this.item});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = emergencyColor(item.importance);
    final secondary = AppTextStyles.bodySmall.copyWith(
      color: AdminStyle.textSecondary(context),
    );
    final acks = [...item.acks]..sort((a, b) {
        final ta = a.acknowledgedAt;
        final tb = b.acknowledgedAt;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });

    return AdminCard(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(emergencyIcon(item.importance), color: color),
              AppSpacing.horizontalGapSM,
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AdminStyle.textPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: AdminStyle.textSecondary(context),
              ),
            ],
          ),
          AppSpacing.verticalGapXS,
          Text(
            [
              item.importance.label,
              if (item.sentAt != null)
                DateFormatter.formatDateTimeToAz(item.sentAt!),
              item.isForAll ? 'Bütün binalar' : 'Seçilmiş binalar',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: secondary,
          ),
          AppSpacing.verticalGapSM,
          Text(
            item.body,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AdminStyle.textPrimary(context),
            ),
          ),
          AppSpacing.verticalGapSM,
          Text(
            'Təsdiqləyən binalar: ${item.ackCount}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AdminStyle.accent(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_expanded) ...[
            AppSpacing.verticalGapSM,
            if (acks.isEmpty)
              Text('Hələ təsdiq yoxdur', style: secondary)
            else
              for (final ack in acks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${ack.buildingCode} · ${ack.buildingName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AdminStyle.textPrimary(context),
                          ),
                        ),
                      ),
                      if (ack.acknowledgedAt != null) ...[
                        AppSpacing.horizontalGapSM,
                        Text(
                          DateFormatter.formatDateTimeToAz(ack.acknowledgedAt!),
                          style: secondary,
                        ),
                      ],
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
