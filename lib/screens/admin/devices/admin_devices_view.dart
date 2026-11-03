import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../models/admin_models.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/common/message_display.dart';
import 'admin_devices_logic.dart';

enum _Segment { devices, buildings }

typedef RevokeCallback = Future<void> Function(
  RevokeScope scope, {
  String? buildingCode,
  String? deviceId,
});

/// Cihazların statusu: the registered devices with their session state and
/// unsent records (revocable one by one, per building or all at once), and
/// the offline-database download state per building. Search, status filter,
/// sort and the "unsent" summary are local; the loader supplies the data.
class AdminDevicesView extends StatefulWidget {
  final String? subtitle;

  /// Devices; null until the first answer arrived.
  final List<DeviceLogin>? logins;
  final String? error;

  /// Download state per building; null until loaded.
  final DownloadStatusReport? report;
  final String? reportError;

  /// false when no exam is selected (the building statuses need one).
  final bool hasExam;

  /// Day the shown downloads are limited to (null = latest).
  final DateTime? date;
  final bool revoking;
  final DateTime Function() clock;

  final Future<void> Function() onRefresh;
  final VoidCallback? onRetry;
  final ValueChanged<DateTime?> onDateChanged;
  final RevokeCallback onRevoke;

  const AdminDevicesView({
    super.key,
    this.subtitle,
    this.logins,
    this.error,
    this.report,
    this.reportError,
    this.hasExam = true,
    this.date,
    this.revoking = false,
    this.clock = DateTime.now,
    required this.onRefresh,
    this.onRetry,
    required this.onDateChanged,
    required this.onRevoke,
  });

  @override
  State<AdminDevicesView> createState() => _AdminDevicesViewState();
}

class _AdminDevicesViewState extends State<AdminDevicesView> {
  static const String _title = 'Cihazların statusu';

  _Segment _segment = _Segment.devices;
  String _query = '';
  DeviceFilter _filter = DeviceFilter.all;
  BuildingFilter _buildingFilter = BuildingFilter.all;
  DeviceSort _sort = DeviceSort.downloadedAt;
  bool _ascending = false;

  Future<void> _pickDate() async {
    final now = widget.clock();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.date ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) widget.onDateChanged(picked);
  }

  Future<void> _confirmRevoke({
    required RevokeScope scope,
    required String title,
    required String question,
    required List<DeviceLogin> affected,
    String? buildingCode,
    String? deviceId,
  }) async {
    final text = revokeConfirmationText(
      question: question,
      devices: affected,
      now: widget.clock(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ləğv et'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Deaktiv et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onRevoke(scope, buildingCode: buildingCode, deviceId: deviceId);
  }

  void _revokeDevice(DeviceLogin device) {
    final id = device.deviceId;
    if (id == null || id.isEmpty) return;
    final name = device.deviceName ?? 'Naməlum cihaz';
    _confirmRevoke(
      scope: RevokeScope.device,
      title: 'Cihazı deaktiv et',
      question: '"$name" cihazı (bina ${device.buildingCode}) deaktiv edilsin?',
      affected: [device],
      buildingCode: device.buildingCode,
      deviceId: id,
    );
  }

  void _revokeBuilding(DeviceLogin device) {
    final devices = [
      for (final d in widget.logins ?? const <DeviceLogin>[])
        if (d.buildingCode == device.buildingCode) d,
    ];
    final name = device.buildingName;
    _confirmRevoke(
      scope: RevokeScope.building,
      title: 'Binanı deaktiv et',
      question: 'Bina ${device.buildingCode}'
          '${name == null || name.isEmpty ? '' : ' ($name)'} üzrə bütün '
          'cihazlar (${devices.length}) deaktiv edilsin?',
      affected: devices,
      buildingCode: device.buildingCode,
    );
  }

  void _revokeAll() {
    final devices = widget.logins ?? const <DeviceLogin>[];
    _confirmRevoke(
      scope: RevokeScope.all,
      title: 'Bütün cihazları deaktiv et',
      question: 'BÜTÜN binaların cihazları (${devices.length}) deaktiv '
          'edilsin? Admin hesabları çıxarılmır.',
      affected: devices,
    );
  }

  @override
  Widget build(BuildContext context) {
    final logins = widget.logins;
    final canRevokeAll =
        !widget.revoking && logins != null && logins.isNotEmpty;

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminSearchField(
          hint: 'Bina, cihaz, tarix...',
          onChanged: (value) => setState(() => _query = value),
        ),
        AppSpacing.verticalGapSM,
        AdminSegmented<_Segment>(
          selected: _segment,
          onChanged: (value) => setState(() => _segment = value),
          segments: const [
            AdminSegment(
              value: _Segment.devices,
              label: 'Cihazlar',
              icon: Icons.phone_android,
            ),
            AdminSegment(
              value: _Segment.buildings,
              label: 'Binalar (baza yükləməsi)',
              icon: Icons.apartment,
            ),
          ],
        ),
      ],
    );

    final actions = [
      PopupMenuButton<String>(
        tooltip: 'Daha çox',
        icon: const Icon(Icons.more_vert, color: Colors.white),
        enabled: canRevokeAll,
        onSelected: (_) => _revokeAll(),
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'revoke_all',
            child: Text('Bütün cihazları deaktiv et'),
          ),
        ],
      ),
    ];

    if (_segment == _Segment.buildings) {
      return _buildBuildings(header, actions);
    }

    if (logins == null) {
      return AdminPage(
        title: _title,
        subtitle: widget.subtitle,
        headerBottom: header,
        actions: actions,
        body: widget.error != null
            ? AdminErrorState(message: widget.error!, onRetry: widget.onRetry)
            : const AdminLoading(),
      );
    }

    final now = widget.clock();
    final shown = sortDevices(
      filterDevices(logins, query: _query, filter: _filter, now: now),
      _sort,
      ascending: _ascending,
    );
    final counts = DeviceCounts.of(logins, now);
    final deviceCountByBuilding = <String, int>{};
    for (final d in logins) {
      deviceCountByBuilding[d.buildingCode] =
          (deviceCountByBuilding[d.buildingCode] ?? 0) + 1;
    }

    return AdminPage.builder(
      title: _title,
      subtitle: widget.subtitle,
      headerBottom: header,
      actions: actions,
      onRefresh: widget.onRefresh,
      itemCount: 1 + shown.length + (shown.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) return _buildDevicesHeader(counts, shown.length);
        if (shown.isEmpty) {
          return const _EmptyNote(text: 'Heç bir giriş tapılmadı');
        }
        final device = shown[index - 1];
        return _DeviceCard(
          device: device,
          now: now,
          buildingDeviceCount: deviceCountByBuilding[device.buildingCode] ?? 1,
          busy: widget.revoking,
          onRevokeDevice: () => _revokeDevice(device),
          onRevokeBuilding: () => _revokeBuilding(device),
        );
      },
    );
  }

  Widget _buildDevicesHeader(DeviceCounts counts, int shownCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.error != null) ...[
          MessageDisplay(
            message: widget.error!,
            type: MessageType.error,
            margin: EdgeInsets.zero,
          ),
          AppSpacing.verticalGapSM,
        ],
        AdminGrid.tiles(
          children: [
            AdminStatTile(
              value: '${counts.total}',
              label: 'Cəmi',
              icon: Icons.phone_android,
            ),
            AdminStatTile(
              value: '${counts.online}',
              label: 'Onlayn',
              icon: Icons.wifi,
              color: AppColors.success,
            ),
            AdminStatTile(
              value: '${counts.revoked}',
              label: 'Deaktiv',
              icon: Icons.block,
              color: AppColors.error,
            ),
            AdminStatTile(
              value: '${counts.withPending}',
              label: 'Göndərilməmiş qeydli',
              icon: Icons.cloud_upload_outlined,
              color: AppColors.warning,
            ),
          ],
        ),
        AppSpacing.verticalGapMD,
        AdminFilterChips<DeviceFilter>(
          selected: _filter,
          onChanged: (value) => setState(() => _filter = value),
          options: const [
            AdminFilterOption(value: DeviceFilter.all, label: 'Hamısı'),
            AdminFilterOption(value: DeviceFilter.online, label: 'Onlayn'),
            AdminFilterOption(value: DeviceFilter.offline, label: 'Oflayn'),
            AdminFilterOption(value: DeviceFilter.revoked, label: 'Deaktiv'),
            AdminFilterOption(
              value: DeviceFilter.pending,
              label: 'Göndərilməmiş',
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Cihazlar: $shownCount'
                '${widget.date == null ? '' : ' · ${DateFormatter.formatDateToAz(widget.date!)}'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AdminSortMenu<DeviceSort>(
              selected: _sort,
              ascending: _ascending,
              onChanged: (value, ascending) => setState(() {
                _sort = value;
                _ascending = ascending;
              }),
              options: const [
                AdminSortOption(
                  value: DeviceSort.downloadedAt,
                  label: 'Daxil olma tarixi',
                ),
                AdminSortOption(
                  value: DeviceSort.buildingCode,
                  label: 'Bina kodu',
                ),
                AdminSortOption(
                  value: DeviceSort.buildingName,
                  label: 'Bina adı',
                ),
                AdminSortOption(value: DeviceSort.deviceName, label: 'Cihaz'),
                AdminSortOption(
                  value: DeviceSort.pending,
                  label: 'Göndərilməmiş',
                ),
              ],
            ),
            if (widget.date != null)
              IconButton(
                tooltip: 'Tarix filterini sil',
                onPressed: () => widget.onDateChanged(null),
                icon: const Icon(Icons.event_busy, color: Colors.white),
              ),
            IconButton(
              tooltip: 'Tarixə görə filtr',
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBuildings(Widget header, List<Widget> actions) {
    if (!widget.hasExam) {
      return AdminPage(
        title: _title,
        subtitle: widget.subtitle,
        headerBottom: header,
        actions: actions,
        body: const AdminEmptyState(
          icon: Icons.event_busy,
          title: 'İmtahan seçilməyib',
          message: 'Bina statuslarını görmək üçün imtahan seçin',
        ),
      );
    }
    final report = widget.report;
    if (report == null) {
      return AdminPage(
        title: _title,
        subtitle: widget.subtitle,
        headerBottom: header,
        actions: actions,
        body: widget.reportError != null
            ? AdminErrorState(
                message: widget.reportError!,
                onRetry: widget.onRetry,
              )
            : const AdminLoading(),
      );
    }

    final shown = filterBuildings(
      report.buildings,
      query: _query,
      filter: _buildingFilter,
    );
    final summary = report.summary;
    return AdminPage.builder(
      title: _title,
      subtitle: widget.subtitle,
      headerBottom: header,
      actions: actions,
      onRefresh: widget.onRefresh,
      itemCount: 1 + shown.length + (shown.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) return _buildBuildingsHeader(summary);
        if (shown.isEmpty) {
          return const _EmptyNote(text: 'Heç bir bina tapılmadı');
        }
        return _BuildingStatusTile(building: shown[index - 1]);
      },
    );
  }

  Widget _buildBuildingsHeader(DownloadStatusSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.reportError != null) ...[
          MessageDisplay(
            message: widget.reportError!,
            type: MessageType.error,
            margin: EdgeInsets.zero,
          ),
          AppSpacing.verticalGapSM,
        ],
        AdminGrid.tiles(
          children: [
            AdminStatTile(
              value: '${summary.total}',
              label: 'Cəmi bina',
              icon: Icons.apartment,
            ),
            AdminStatTile(
              value: '${summary.downloaded}',
              label: 'Baza yüklənib',
              icon: Icons.download_done,
              color: AppColors.success,
            ),
            AdminStatTile(
              value: '${summary.notDownloaded}',
              label: 'Yüklənməyib',
              icon: Icons.download_for_offline_outlined,
              color: AppColors.warning,
            ),
            AdminStatTile(
              value: '${summary.noDevice}',
              label: 'Cihaz yoxdur',
              icon: Icons.phonelink_erase,
              color: AppColors.error,
            ),
          ],
        ),
        AppSpacing.verticalGapMD,
        AdminFilterChips<BuildingFilter>(
          selected: _buildingFilter,
          onChanged: (value) => setState(() => _buildingFilter = value),
          options: const [
            AdminFilterOption(value: BuildingFilter.all, label: 'Hamısı'),
            AdminFilterOption(
              value: BuildingFilter.downloaded,
              label: 'Yüklənib',
            ),
            AdminFilterOption(
              value: BuildingFilter.notDownloaded,
              label: 'Yüklənməyib',
            ),
            AdminFilterOption(
              value: BuildingFilter.noDevice,
              label: 'Cihaz yoxdur',
            ),
          ],
        ),
      ],
    );
  }
}

/// White text line on the gradient (empty list notice).
class _EmptyNote extends StatelessWidget {
  final String text;

  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.paddingLG,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
      ),
    );
  }
}

class _BuildingStatusTile extends StatelessWidget {
  final BuildingDownloadStatus building;

  const _BuildingStatusTile({required this.building});

  @override
  Widget build(BuildContext context) {
    final (AdminStatus status, String label) = switch (building.state) {
      BuildingDownloadState.downloaded => (AdminStatus.registered, 'Yüklənib'),
      BuildingDownloadState.notDownloaded => (
          AdminStatus.warning,
          'Yüklənməyib',
        ),
      BuildingDownloadState.noDevice => (
          AdminStatus.notRegistered,
          'Cihaz yoxdur',
        ),
    };
    final parts = [
      if (building.downloadedAt != null)
        DateFormatter.formatDateTimeToAz(building.downloadedAt!),
      if (building.participantCount != null)
        'İştirakçı: ${building.participantCount}',
      if (building.supervisorCount != null)
        'Nəzarətçi: ${building.supervisorCount}',
    ];
    return AdminListTile(
      leading: AdminListTile.codeLeading(context, building.buildingCode),
      title: building.buildingName ?? '—',
      subtitle: parts.join(' · '),
      trailing: AdminStatusBadge(status: status, label: label),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceLogin device;
  final DateTime now;
  final int buildingDeviceCount;
  final bool busy;
  final VoidCallback onRevokeDevice;
  final VoidCallback onRevokeBuilding;

  const _DeviceCard({
    required this.device,
    required this.now,
    required this.buildingDeviceCount,
    required this.busy,
    required this.onRevokeDevice,
    required this.onRevokeBuilding,
  });

  @override
  Widget build(BuildContext context) {
    final pending = device.pendingTotal;
    final canRevokeDevice =
        !busy && !device.isRevoked && (device.deviceId ?? '').isNotEmpty;

    final lastSeen = device.lastSeenAt == null
        ? 'əlaqə məlum deyil'
        : 'son əlaqə ${DateFormatter.formatDateTimeToAz(device.lastSeenAt!)}';
    final pendingDetail = pending == null
        ? 'naməlum'
        : '$pending (${device.pendingParticipants ?? 0} iştirakçı, '
            '${device.pendingSupervisors ?? 0} nəzarətçi)';

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AdminListTile.codeLeading(context, device.buildingCode),
              AppSpacing.horizontalGapMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.buildingName ?? '—',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AdminStyle.textPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      device.deviceName ??
                          'Naməlum cihaz (köhnə tətbiq versiyası)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AdminStyle.textSecondary(context),
                      ),
                    ),
                    if (buildingDeviceCount > 1)
                      Text(
                        'Binada $buildingDeviceCount cihaz',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AdminStyle.textSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapSM,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (device.isRevoked)
                const AdminStatusBadge(
                  status: AdminStatus.offline,
                  label: 'Deaktiv',
                )
              else if (device.isRecentlySeen(now))
                const AdminStatusBadge(status: AdminStatus.online)
              else
                const AdminStatusBadge(status: AdminStatus.warning, label: 'Oflayn'),
              if (device.hasPending)
                AdminStatusBadge(
                  status: AdminStatus.warning,
                  label: '$pending göndərilməmiş',
                ),
            ],
          ),
          AppSpacing.verticalGapXS,
          Text(
            device.isRevoked && device.revokedAt != null
                ? 'Deaktiv edilib: '
                    '${DateFormatter.formatDateTimeToAz(device.revokedAt!)}'
                : lastSeen,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AdminStyle.textSecondary(context),
            ),
          ),
          AppSpacing.verticalGapSM,
          AdminKeyValueList(
            items: [
              AdminKeyValue('İmtahan tarixi', device.examDateRaw ?? ''),
              AdminKeyValue(
                'Daxil olma tarixi',
                device.downloadedAt == null
                    ? ''
                    : DateFormatter.formatDateTimeToAz(device.downloadedAt!),
              ),
              AdminKeyValue('İştirakçı', '${device.participantCount ?? ''}'),
              AdminKeyValue('Nəzarətçi', '${device.supervisorCount ?? ''}'),
              AdminKeyValue(
                'Versiya',
                device.appVersion == null
                    ? 'versiya müəyyən edilməyib'
                    : 'v${device.appVersion}',
              ),
              AdminKeyValue('Göndərilməmiş', pendingDetail),
            ],
          ),
          AppSpacing.verticalGapSM,
          AdminActionButton(
            label: 'Cihazı deaktiv et',
            icon: Icons.block,
            style: AdminActionStyle.outlined,
            onPressed: canRevokeDevice ? onRevokeDevice : null,
          ),
          AppSpacing.verticalGapSM,
          AdminActionButton(
            label: 'Binanın bütün cihazlarını deaktiv et',
            icon: Icons.apartment,
            style: AdminActionStyle.outlined,
            onPressed: busy ? null : onRevokeBuilding,
          ),
        ],
      ),
    );
  }
}
