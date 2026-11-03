import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../models/monitor_models.dart';
import '../../../models/participant_light_dto.dart';
import '../../../models/participant_protocol_dto.dart';
import '../../../models/supervisor_detail_dto.dart';
import '../../../services/statistics_service.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/admin/admin_widgets.dart';
import 'admin_person_rows.dart';

/// Everything the detail screen shows about one person. Pure data built from
/// the API models, so the view needs no knowledge of their shapes.
class AdminPersonDetailData {
  final AdminPersonKind kind;
  final String name;
  final String? identifier;
  final String? photo;
  final String? building;

  /// Server row id, needed to cancel the registration.
  final int? id;
  final DateTime? registeredAt;
  final List<AdminKeyValue> fields;
  final List<AdminKeyValue> seat;
  final List<AdminKeyValue> protocol;
  final List<String> phones;

  const AdminPersonDetailData({
    required this.kind,
    required this.name,
    required this.fields,
    this.identifier,
    this.photo,
    this.building,
    this.id,
    this.registeredAt,
    this.seat = const [],
    this.protocol = const [],
    this.phones = const [],
  });

  bool get isRegistered => registeredAt != null;

  static String formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    final local = value.toLocal();
    return '${DateFormatter.formatDateToAz(local)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  /// Splits a phone string that may hold several numbers.
  static List<String> splitPhones(String? phones) => (phones ?? '')
      .split(RegExp(r'[,،;]\s*'))
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty)
      .toList();

  static AdminKeyValue? _kv(String label, String? value) =>
      value == null || value.trim().isEmpty
          ? null
          : AdminKeyValue(label, value.trim());

  static List<AdminKeyValue> _list(Iterable<AdminKeyValue?> items) =>
      items.whereType<AdminKeyValue>().toList();

  static String _name(Iterable<String?> parts) =>
      parts.where((p) => p != null && p.isNotEmpty).join(' ');

  factory AdminPersonDetailData.participant(
    ParticipantLightDto p, {
    ParticipantProtocolDto? protocol,
  }) {
    final idCard = '${p.idCardSeries ?? ''} ${p.idCardNumber ?? ''}'.trim();
    return AdminPersonDetailData(
      kind: AdminPersonKind.participant,
      name: _name([p.lastName, p.firstName, p.fatherName]),
      identifier: p.cardNumber == null ? null : 'İş №: ${p.cardNumber}',
      photo: p.photo,
      building: p.buildingName,
      id: p.id,
      registeredAt: p.registeredAt,
      fields: _list([
        _kv('İş nömrəsi', p.cardNumber?.toString()),
        _kv('Şəxsiyyət vəsiqəsi', idCard),
        _kv('Soyadı', p.lastName),
        _kv('Adı', p.firstName),
        _kv('Atasının adı', p.fatherName),
        _kv(
          'Doğum tarixi',
          p.birthDate == null
              ? null
              : DateFormatter.formatDateToAz(p.birthDate!),
        ),
      ]),
      seat: _list([
        _kv('Mərtəbə', p.floor),
        _kv('Zal', p.hall),
        _kv('Sıra', p.row),
        _kv('Yer', p.seat),
      ]),
      protocol: protocol == null || !protocol.hasContent
          ? const []
          : _list([
              _kv('Qayda pozulan imtahan', protocol.examName),
              _kv(
                'Qayda pozulan imtahanın tarixi',
                protocol.examDate == null
                    ? null
                    : DateFormatter.formatDateToAz(protocol.examDate!),
              ),
              _kv('Kateqoriya', protocol.katName),
              _kv('Alt kateqoriya', protocol.altKatName),
              _kv('Qeyd', protocol.qeyd),
              _kv(
                'Dəyişiklik tarixi',
                protocol.changeActivityDate == null
                    ? null
                    : DateFormatter.formatDateTimeToAz(
                        protocol.changeActivityDate!,
                      ),
              ),
              _kv('Dəyişiklik məlumatı', protocol.changeActivityInfo),
            ]),
    );
  }

  factory AdminPersonDetailData.supervisor(SupervisorDetailDto s) {
    return AdminPersonDetailData(
      kind: AdminPersonKind.supervisor,
      name: _name([s.lastName, s.firstName, s.fatherName]),
      identifier: s.cardNumber == null ? null : 'Vəsiqə №: ${s.cardNumber}',
      photo: s.image,
      building: s.buildingName,
      id: s.id,
      registeredAt: s.registerDate,
      phones: splitPhones(s.phone),
      fields: _list([
        _kv('Vəzifəsi', AdminPersonRow.supervisorRole(s.supervisorAction)),
        _kv('Vəsiqə nömrəsi', s.cardNumber),
        _kv('FİN', s.pinCode),
        _kv('Bina kodu', s.buildingCode?.toString()),
        _kv('Bina', s.buildingName),
      ]),
    );
  }

  factory AdminPersonDetailData.monitor(Monitor m) {
    return AdminPersonDetailData(
      kind: AdminPersonKind.monitor,
      name: _name([m.lastName, m.firstName, m.middleName]),
      identifier: 'İş №: ${m.workNumber}',
      photo: m.image.isEmpty || m.image == 'null' ? null : m.image,
      building: m.buildingName,
      id: m.id,
      registeredAt: m.isRegistered ? DateTime.tryParse(m.registerDate) : null,
      phones: splitPhones(m.phone),
      fields: _list([
        _kv('İş nömrəsi', '${m.workNumber}'),
        _kv('FİN', m.idCardPin),
        _kv('Bina kodu', '${m.buildingCode}'),
        _kv('Bina', m.buildingName),
        _kv('Otaq', m.roomName),
      ]),
    );
  }
}

/// Detail of one person (participant, supervisor, imtahan rəhbəri): photo,
/// data, protocol and the "cancel registration" action. Pure view.
class AdminPersonDetailView extends StatelessWidget {
  final AdminPersonKind kind;
  final AdminPersonDetailData? data;
  final bool loading;
  final String? error;
  final bool cancelling;

  final Future<void> Function() onRefresh;
  final VoidCallback? onRetry;
  final VoidCallback? onCancelRegistration;
  final ValueChanged<String>? onCallPhone;

  const AdminPersonDetailView({
    super.key,
    required this.kind,
    required this.onRefresh,
    this.data,
    this.loading = false,
    this.error,
    this.cancelling = false,
    this.onRetry,
    this.onCancelRegistration,
    this.onCallPhone,
  });

  String get _title => switch (kind) {
        AdminPersonKind.participant => 'İmtahan iştirakçısı',
        AdminPersonKind.supervisor => 'Nəzarətçi',
        AdminPersonKind.monitor => 'İmtahan rəhbəri',
      };

  IconData get _placeholderIcon => switch (kind) {
        AdminPersonKind.participant => Icons.person,
        AdminPersonKind.supervisor => Icons.supervisor_account,
        AdminPersonKind.monitor => Icons.badge,
      };

  @override
  Widget build(BuildContext context) {
    final detail = data;
    if (detail == null) {
      return AdminPage(
        title: _title,
        onRefresh: onRefresh,
        body: error != null && !loading
            ? AdminErrorState(message: error!, onRetry: onRetry)
            : const AdminLoading(),
      );
    }

    return AdminPage.list(
      title: _title,
      subtitle: detail.building,
      onRefresh: onRefresh,
      children: [
        AdminCard(child: _buildHeader(detail)),
        AdminGrid.cards(
          children: [
            if (detail.fields.isNotEmpty)
              AdminCard(
                title: 'Məlumatlar',
                child: AdminKeyValueList(items: detail.fields),
              ),
            if (detail.seat.isNotEmpty)
              AdminCard(
                title: 'Oturma yeri',
                child: AdminKeyValueList(items: detail.seat),
              ),
            if (detail.protocol.isNotEmpty)
              AdminCard(
                title: 'Protokol məlumatları',
                trailing: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                ),
                child: AdminKeyValueList(items: detail.protocol),
              ),
            if (detail.phones.isNotEmpty)
              AdminCard(
                title: 'Telefon',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final phone in detail.phones)
                      ActionChip(
                        avatar: const Icon(Icons.phone, size: 18),
                        label: Text(phone, overflow: TextOverflow.ellipsis),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onPressed: onCallPhone == null
                            ? null
                            : () => onCallPhone!(phone),
                      ),
                  ],
                ),
              ),
          ],
        ),
        if (detail.isRegistered &&
            detail.id != null &&
            onCancelRegistration != null)
          _buildCancelButton(),
      ],
    );
  }

  Widget _buildHeader(AdminPersonDetailData detail) {
    final registered = detail.isRegistered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminPersonHeader(
          photoData: detail.photo,
          placeholderIcon: _placeholderIcon,
          name: detail.name.isEmpty ? '—' : detail.name,
          identifier: detail.identifier,
        ),
        AppSpacing.verticalGapMD,
        AdminStatusBadge(
          status:
              registered ? AdminStatus.registered : AdminStatus.notRegistered,
          label: registered
              ? 'Qeydiyyat: ${AdminPersonDetailData.formatDateTime(detail.registeredAt!)}'
              : 'Qeydiyyatdan keçməyib',
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return FilledButton.icon(
      onPressed: cancelling ? null : onCancelRegistration,
      icon: const Icon(Icons.cancel_outlined),
      label: Text(cancelling ? 'Gözləyin...' : 'Qeydiyyatını ləğv et'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
      ),
    );
  }
}
