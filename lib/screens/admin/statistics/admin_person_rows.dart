import '../../../models/monitor_models.dart';
import '../../../models/participant_light_dto.dart';
import '../../../models/supervisor_detail_dto.dart';
import '../../../services/statistics_service.dart';
import '../../../utils/date_formatter.dart';

/// Registration filter of the building lists.
enum AdminRegFilter { all, registered, notRegistered, violators }

/// One person line of a building / room list. Pure data built from the API
/// models; [source] is handed back on tap.
class AdminPersonRow {
  final AdminPersonKind kind;
  final String name;
  final String identifier;
  final String? detail;
  final bool registered;
  final bool violator;
  final String searchText;
  final Object source;

  const AdminPersonRow({
    required this.kind,
    required this.name,
    required this.identifier,
    required this.registered,
    required this.searchText,
    required this.source,
    this.detail,
    this.violator = false,
  });

  static String _join(Iterable<String?> parts, [String separator = ' · ']) =>
      parts.where((p) => p != null && p.isNotEmpty).join(separator);

  static List<AdminPersonRow> participants(
    List<ParticipantLightDto> people, {
    Set<int> violators = const {},
    bool showBuilding = false,
  }) =>
      [
        for (final p in people)
          AdminPersonRow(
            kind: AdminPersonKind.participant,
            name: p.fullName.isEmpty ? '—' : p.fullName,
            identifier: 'İş №: ${p.cardNumber ?? '—'}',
            detail: _join([
              if (showBuilding && (p.buildingCode ?? '').isNotEmpty)
                'Bina: ${p.buildingCode}',
              if ((p.hall ?? '').isNotEmpty) 'Zal: ${p.hall}',
              if ((p.floor ?? '').isNotEmpty) 'Mərtəbə: ${p.floor}',
              if ((p.row ?? '').isNotEmpty) 'Sıra: ${p.row}',
              if ((p.seat ?? '').isNotEmpty) 'Yer: ${p.seat}',
            ]),
            registered: p.isRegistered,
            violator: p.cardNumber != null && violators.contains(p.cardNumber),
            searchText: '${p.fullName} ${p.cardNumber ?? ''} '
                    '${p.idCardSeries ?? ''}${p.idCardNumber ?? ''}'
                .toLowerCase(),
            source: p,
          ),
      ];

  static String supervisorRole(int? action) =>
      action == 2 ? 'Əsas' : 'Ehtiyyat';

  static List<AdminPersonRow> supervisors(List<SupervisorDetailDto> people) => [
        for (final s in people)
          AdminPersonRow(
            kind: AdminPersonKind.supervisor,
            name: s.fullName.isEmpty ? '—' : s.fullName,
            identifier: 'Vəsiqə №: ${s.cardNumber ?? '—'}',
            detail: _join([
              supervisorRole(s.supervisorAction),
              s.phone,
            ]),
            registered: s.isRegistered,
            searchText: '${s.fullName} ${s.cardNumber ?? ''} '
                    '${s.pinCode ?? ''} ${s.phone ?? ''}'
                .toLowerCase(),
            source: s,
          ),
      ];

  static List<AdminPersonRow> monitors(List<Monitor> people) => [
        for (final m in people)
          AdminPersonRow(
            kind: AdminPersonKind.monitor,
            name: m.fullName.trim().isEmpty ? '—' : m.fullName.trim(),
            identifier: 'İş №: ${m.workNumber}',
            detail: _join([
              if (m.roomName.isNotEmpty) m.roomName,
              if (m.isRegistered) DateFormatter.formatISOToAz(m.registerDate),
            ]),
            registered: m.isRegistered,
            searchText: '${m.fullName} ${m.workNumber} ${m.idCardPin} '
                    '${m.phone ?? ''}'
                .toLowerCase(),
            source: m,
          ),
      ];

  /// Applies the registration filter and the free-text search.
  static List<AdminPersonRow> filter(
    List<AdminPersonRow> rows, {
    AdminRegFilter filter = AdminRegFilter.all,
    String query = '',
  }) {
    final needle = query.trim().toLowerCase();
    return rows.where((row) {
      switch (filter) {
        case AdminRegFilter.all:
          break;
        case AdminRegFilter.registered:
          if (!row.registered) return false;
        case AdminRegFilter.notRegistered:
          if (row.registered) return false;
        case AdminRegFilter.violators:
          if (!row.violator) return false;
      }
      return needle.isEmpty || row.searchText.contains(needle);
    }).toList();
  }
}
