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

/// One exam contributing to a slot (see [SlotDto.exams]) — kept for display
/// ("<examName>, <examName>, ...") and for admin bookkeeping ("by exam"
/// stats), never for building the request header (that's [SlotDto.key]).
class SlotExamRef {
  final int examId;
  final String examName;
  final int sessionId;
  final String sessionLabel;

  SlotExamRef({
    required this.examId,
    required this.examName,
    required this.sessionId,
    required this.sessionLabel,
  });

  factory SlotExamRef.fromJson(Map<String, dynamic> json) {
    return SlotExamRef(
      examId: json['examId'] as int? ?? 0,
      examName: json['examName'] as String? ?? '',
      sessionId: json['sessionId'] as int? ?? 0,
      sessionLabel: json['sessionLabel'] as String? ?? '',
    );
  }
}

/// A slot — date + start time, computed server-side from every exam's
/// sessions sharing that date (see API_slots.md; there is no backing table).
/// Building entry is scanned per slot+building, never per exam: [key] is
/// what the dio interceptor sends as `X-Exam-Slot`, [legacyDate] is what the
/// pre-existing endpoints still expect as `examDate`.
class SlotDto {
  final String key; // "2026-09-24T10:00"
  final String examDate; // ISO, e.g. "2026-09-24T00:00:00"
  final String startTime; // "10:00"
  final String label; // "24 sentyabr 2026 · 10:00"
  final String legacyDate; // "24 sentyabr 2026 10:00"
  final List<SlotExamRef> exams;

  SlotDto({
    required this.key,
    required this.examDate,
    required this.startTime,
    required this.label,
    required this.legacyDate,
    this.exams = const [],
  });

  factory SlotDto.fromJson(Map<String, dynamic> json) {
    final examsJson = json['exams'] as List<dynamic>? ?? const [];
    return SlotDto(
      key: json['key'] as String? ?? '',
      examDate: json['examDate'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      label: json['label'] as String? ?? '',
      legacyDate: json['legacyDate'] as String? ?? '',
      exams: examsJson
          .map((e) => SlotExamRef.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Comma-joined exam names of this slot, for the slot card's subtitle.
  String get examNamesJoined => exams.map((e) => e.examName).join(', ');
}

/// Response wrapper for `GET slots` / `GET slots/all`.
class SlotsResponse {
  final bool success;
  final String message;
  final List<SlotDto> data;

  SlotsResponse({
    required this.success,
    required this.message,
    required this.data,
  });
}
