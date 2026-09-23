import 'dart:convert';
import 'dart:typed_data';

class Participant {
  final int isN; // İş nömrəsi
  final String adi; // Ad
  final String soy; // Soyad
  final String baba; // Ata adı
  final String mertebe; // Mərtəbə
  final String zal; // Zal
  final String sira; // Sıra
  final String yer; // Yer
  final String? photo; // Şəkil (base64, onlayn skan və s.)
  final Uint8List? photoBytes; // Şəkil (BLOB, oflayn baza)
  final String? qeydiyyat; // Qeydiyyat tarixi
  final String bina; // Bina
  final String imtTarix; // İmtahan tarixi
  final int gins; // Cins: 1 = kişi, 2 = qadın

  Participant({
    required this.isN,
    required this.adi,
    required this.soy,
    required this.baba,
    required this.mertebe,
    required this.zal,
    required this.sira,
    required this.yer,
    this.photo,
    this.photoBytes,
    this.qeydiyyat,
    required this.bina,
    required this.imtTarix,
    this.gins = 0,
  });

  /// Фото как base64 (для мест, где нужна строка): из photo, либо из photoBytes.
  String? get photoBase64 =>
      photo ?? (photoBytes != null ? base64Encode(photoBytes!) : null);

  bool get hasPhoto =>
      (photo != null && photo!.isNotEmpty) ||
      (photoBytes != null && photoBytes!.isNotEmpty);

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      isN: json['is_N'] as int,
      adi: json['adi'] as String,
      soy: json['soy'] as String,
      baba: json['baba'] as String,
      mertebe: json['mertebe'] as String,
      zal: json['zal'] as String,
      sira: json['sira'] as String,
      yer: json['yer'] as String,
      photo: json['photo'] as String?,
      qeydiyyat: json['qeydiyyat'] as String?,
      bina: json['bina'] as String? ?? '',
      imtTarix: json['imt_Tarix'] as String? ?? '',
      gins: (json['gins'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_N': isN,
      'adi': adi,
      'soy': soy,
      'baba': baba,
      'mertebe': mertebe,
      'zal': zal,
      'sira': sira,
      'yer': yer,
      'photo': photo,
      'qeydiyyat': qeydiyyat,
      'bina': bina,
      'imt_Tarix': imtTarix,
      'gins': gins,
    };
  }

  String get fullName => '$soy $adi $baba';
}

/// Lightweight summary of one session (shift) of the currently selected
/// exam, as stashed on [ExamDetails.sessions] so the dashboard's session
/// switcher doesn't need a fresh `GET /exams/{id}` call just to list them.
class ExamSessionSummary {
  final int id;
  final String label;
  final String? legacyImtTarix;

  ExamSessionSummary({
    required this.id,
    required this.label,
    this.legacyImtTarix,
  });

  factory ExamSessionSummary.fromJson(Map<String, dynamic> json) {
    return ExamSessionSummary(
      id: json['id'] as int,
      label: json['label'] as String? ?? '',
      legacyImtTarix: json['legacyImtTarix'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (legacyImtTarix != null) 'legacyImtTarix': legacyImtTarix,
      };
}

/// Lightweight summary of one slot available at the time an exam/slot was
/// picked, stashed on [ExamDetails.slots] so the switcher (home screen /
/// admin dashboard) doesn't need a fresh `GET slots` call just to list them.
class SlotSummary {
  final String key;
  final String label;
  final String legacyDate;

  SlotSummary({
    required this.key,
    required this.label,
    required this.legacyDate,
  });

  factory SlotSummary.fromJson(Map<String, dynamic> json) {
    return SlotSummary(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      legacyDate: json['legacyDate'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'legacyDate': legacyDate,
      };
}

class ExamDetails {
  final String? adBina; // Ad Bina
  final String? kodBina; // Kod Bina
  final String? imtTarix; // İmtahan tarixi (legacy string — kept for all existing endpoints)
  final int? regManCount; // Qeydiyyatlı kişi sayı
  final int? regWomanCount; // Qeydiyyatlı qadın sayı
  final int? allManCount; // Ümumi kişi sayı
  final int? allWomanCount; // Ümumi qadın sayı
  // Legacy /exams-based exam+session picker fields. No longer written by the
  // current (slot-based) flow — kept ONLY so a JSON blob saved by an older
  // app version still deserializes without loss.
  final int? examId;
  final String? examName;
  final int? sessionId;
  final String? sessionLabel;
  final List<ExamSessionSummary> sessions;
  // Slot fields (current flow — see API_slots.md). [slotKey] is what the dio
  // interceptor sends as `X-Exam-Slot`; [slotLabel] is shown by the
  // switcher; [slots] is the full slot list available at pick time so the
  // switcher can list them without a fresh `GET slots` call.
  final String? slotKey;
  final String? slotLabel;
  final List<SlotSummary> slots;

  ExamDetails({
    this.adBina,
    this.kodBina,
    this.imtTarix,
    this.regManCount,
    this.regWomanCount,
    this.allManCount,
    this.allWomanCount,
    this.examId,
    this.examName,
    this.sessionId,
    this.sessionLabel,
    this.sessions = const [],
    this.slotKey,
    this.slotLabel,
    this.slots = const [],
  });

  factory ExamDetails.fromJson(Map<String, dynamic> json) {
    final sessionsJson = json['sessions'] as List<dynamic>? ?? const [];
    final slotsJson = json['slots'] as List<dynamic>? ?? const [];
    return ExamDetails(
      adBina: json['ad_Bina'] as String?,
      kodBina: json['kod_Bina'] as String?,
      imtTarix: json['imt_Tarix'] as String?,
      regManCount: json['regManCount'] as int?,
      regWomanCount: json['regWomanCount'] as int?,
      allManCount: json['allManCount'] as int?,
      allWomanCount: json['allWomanCount'] as int?,
      examId: json['examId'] as int?,
      examName: json['examName'] as String?,
      sessionId: json['sessionId'] as int?,
      sessionLabel: json['sessionLabel'] as String?,
      sessions: sessionsJson
          .map((e) => ExamSessionSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      slotKey: json['slotKey'] as String?,
      slotLabel: json['slotLabel'] as String?,
      slots: slotsJson
          .map((e) => SlotSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ad_Bina': adBina,
      'kod_Bina': kodBina,
      'imt_Tarix': imtTarix,
      'regManCount': regManCount,
      'regWomanCount': regWomanCount,
      'allManCount': allManCount,
      'allWomanCount': allWomanCount,
      if (examId != null) 'examId': examId,
      if (examName != null) 'examName': examName,
      if (sessionId != null) 'sessionId': sessionId,
      if (sessionLabel != null) 'sessionLabel': sessionLabel,
      if (sessions.isNotEmpty)
        'sessions': sessions.map((s) => s.toJson()).toList(),
      if (slotKey != null) 'slotKey': slotKey,
      if (slotLabel != null) 'slotLabel': slotLabel,
      if (slots.isNotEmpty) 'slots': slots.map((s) => s.toJson()).toList(),
    };
  }

  int get totalRegisteredCount => (regManCount ?? 0) + (regWomanCount ?? 0);
  int get totalCount => (allManCount ?? 0) + (allWomanCount ?? 0);
  int get notRegisteredCount => totalCount - totalRegisteredCount;
}

class ParticipantResponse {
  final Participant? data;
  final bool success;
  final String message;

  ParticipantResponse({
    this.data,
    required this.success,
    required this.message,
  });

  factory ParticipantResponse.fromJson(Map<String, dynamic> json) {
    return ParticipantResponse(
      data: json['data'] != null ? Participant.fromJson(json['data']) : null,
      success: json['success'] as bool,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data?.toJson(),
      'success': success,
      'message': message,
    };
  }
}

enum ParticipantScreenState {
  initial, // Начальный экран с кнопками
  scanning, // Сканирование QR кода
  scanned, // Результат сканирования
  error, // Ошибка сканирования
}
