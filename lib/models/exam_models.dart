/// A session (shift) of an exam, as returned by `GET /exams` (nested inside
/// [ExamDto.sessions]).
///
/// [legacyImtTarix] is the Azerbaijani-worded date+time string ("24 sentyabr
/// 2026 10:00") that every pre-existing endpoint (participants/supervisors/
/// monitors) still expects — it already carries the session time as its last
/// word, so `DateFormatter.dateToAzToDate`/`dateToAzToDateWithSession` keep
/// working unmodified once this string is stored as `ExamDetails.imtTarix`.
/// It is null when the session hasn't been linked to the legacy system yet —
/// such a session cannot be selected.
class ExamSessionDto {
  final int id;
  final int examId;
  final String startTime; // "10:00"
  final int examQueue; // shift number: 1, 2, ...
  final String label; // "I növbə · 10:00", ready to display
  final String? legacyImtTarix;

  ExamSessionDto({
    required this.id,
    required this.examId,
    required this.startTime,
    required this.examQueue,
    required this.label,
    this.legacyImtTarix,
  });

  factory ExamSessionDto.fromJson(Map<String, dynamic> json) {
    return ExamSessionDto(
      id: json['id'] as int,
      examId: json['examId'] as int? ?? 0,
      startTime: json['startTime'] as String? ?? '',
      examQueue: json['examQueue'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      legacyImtTarix: json['legacyImtTarix'] as String?,
    );
  }
}

/// A published exam, as returned by `GET /exams`.
class ExamDto {
  final int id;
  final String name;
  final String? shortName;
  final String examDate; // ISO, e.g. "2026-09-24T00:00:00"
  final String? typeCode; // legacy "erize", e.g. "dovq"
  final bool isPublished;
  final List<ExamSessionDto> sessions; // sorted by startTime

  ExamDto({
    required this.id,
    required this.name,
    this.shortName,
    required this.examDate,
    this.typeCode,
    required this.isPublished,
    this.sessions = const [],
  });

  factory ExamDto.fromJson(Map<String, dynamic> json) {
    final sessionsJson = json['sessions'] as List<dynamic>? ?? const [];
    return ExamDto(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      shortName: json['shortName'] as String?,
      examDate: json['examDate'] as String? ?? '',
      typeCode: json['typeCode'] as String?,
      isPublished: json['isPublished'] as bool? ?? false,
      sessions: sessionsJson
          .map((e) => ExamSessionDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// True when at least one session is linked to the legacy system and can
  /// therefore be selected.
  bool get hasSelectableSession =>
      sessions.any((s) => s.legacyImtTarix != null);
}

/// Response wrapper for `GET /exams`.
class ExamsResponse {
  final bool success;
  final String message;
  final List<ExamDto> data;

  ExamsResponse({
    required this.success,
    required this.message,
    required this.data,
  });
}
