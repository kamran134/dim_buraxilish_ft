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
/// what the dio interceptor sends as `X-Exam-Slot`.
class SlotDto {
  final String key; // "2026-09-24T10:00"
  final String examDate; // ISO, e.g. "2026-09-24T00:00:00"
  final String startTime; // "10:00"
  final String label; // "24 sentyabr 2026 · 10:00"
  final List<SlotExamRef> exams;

  SlotDto({
    required this.key,
    required this.examDate,
    required this.startTime,
    required this.label,
    this.exams = const [],
  });

  factory SlotDto.fromJson(Map<String, dynamic> json) {
    final examsJson = json['exams'] as List<dynamic>? ?? const [];
    return SlotDto(
      key: json['key'] as String? ?? '',
      examDate: json['examDate'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      label: json['label'] as String? ?? '',
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
