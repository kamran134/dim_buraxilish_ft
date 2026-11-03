import '../../../models/exam_statistics_dto.dart';
import '../../../models/monitor_room_statistics.dart';

/// Segments of the Statistika tab.
enum AdminStatsSegment { participants, supervisors, monitors }

enum AdminStatsSort { code, name, rate }

/// One line of the Statistika list: a building (participants, supervisors) or
/// a room (imtahan rəhbərləri). Pure data, built from the API models.
class AdminStatsRow {
  final String code;
  final String title;
  final int done;
  final int total;

  /// Extra line under the progress bar (halls / supervisors balance).
  final String? note;

  /// Supervisors only: fewer registered supervisors than halls.
  final bool shortage;

  /// The model the row was built from — handed back on tap.
  final Object source;

  const AdminStatsRow({
    required this.code,
    required this.title,
    required this.done,
    required this.total,
    required this.source,
    this.note,
    this.shortage = false,
  });

  double get rate => total <= 0 ? 0 : done / total * 100;

  static String buildingTitle(String? code, String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? 'Bina ${code ?? ''}'.trim() : trimmed;
  }

  static List<AdminStatsRow> participants(List<ExamStatisticsDto> buildings) =>
      [
        for (final b in buildings)
          AdminStatsRow(
            code: b.buildingCode ?? '',
            title: buildingTitle(b.buildingCode, b.buildingName),
            done: b.registeredParticipants,
            total: b.totalParticipants,
            source: b,
          ),
      ];

  static List<AdminStatsRow> supervisors(List<ExamStatisticsDto> buildings) => [
        for (final b in buildings)
          AdminStatsRow(
            code: b.buildingCode ?? '',
            title: buildingTitle(b.buildingCode, b.buildingName),
            done: b.regSupervisorCount ?? 0,
            total: b.supervisorCount ?? 0,
            note: 'Zal sayı: ${b.hallCount ?? 0}',
            shortage: !b.hasEnoughSupervisors,
            source: b,
          ),
      ];

  static List<AdminStatsRow> rooms(List<MonitorRoomStatistics> rooms) => [
        for (final r in rooms)
          AdminStatsRow(
            code: '${r.roomId}',
            title: r.roomName.isEmpty ? 'Otaq ${r.roomId}' : r.roomName,
            done: r.regPersonCount,
            total: r.allPersonCount,
            source: r,
          ),
      ];

  /// Keeps rows whose code or title contains [query], then sorts them.
  static List<AdminStatsRow> filterAndSort(
    List<AdminStatsRow> rows, {
    String query = '',
    AdminStatsSort sort = AdminStatsSort.code,
    bool ascending = true,
  }) {
    final needle = query.trim().toLowerCase();
    final result = needle.isEmpty
        ? List<AdminStatsRow>.of(rows)
        : rows
            .where(
              (row) =>
                  row.code.toLowerCase().contains(needle) ||
                  row.title.toLowerCase().contains(needle),
            )
            .toList();

    int compare(AdminStatsRow a, AdminStatsRow b) {
      switch (sort) {
        case AdminStatsSort.code:
          final x = int.tryParse(a.code);
          final y = int.tryParse(b.code);
          if (x != null && y != null) return x.compareTo(y);
          return a.code.compareTo(b.code);
        case AdminStatsSort.name:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case AdminStatsSort.rate:
          return a.rate.compareTo(b.rate);
      }
    }

    result.sort((a, b) => ascending ? compare(a, b) : compare(b, a));
    return result;
  }
}
