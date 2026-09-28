import 'dart:convert';
import 'dart:typed_data';

class Participant {
  final int cardNumber; // İş nömrəsi
  final String firstName; // Ad
  final String lastName; // Soyad
  final String fatherName; // Ata adı
  final String floor; // Mərtəbə
  final String hall; // Zal
  final String row; // Sıra
  final String seat; // Yer
  final String? photo; // Şəkil (base64, onlayn skan və s.)
  final Uint8List? photoBytes; // Şəkil (BLOB, oflayn baza)
  final String? registeredAt; // Qeydiyyat tarixi
  final String buildingCode; // Bina
  final int gender; // Cins: 1 = kişi, 2 = qadın
  // Full-switch (9.2, contract §1.2/§1.3): server identity, replaces the old
  // (is_N, legacy exam-date string) pair. [id] is `Participants.Id` — used
  // for cancel-by-id and the preferred sync branch. Null only for a v8 offline
  // queue row migrated to the v9 schema before it ever reached the server
  // (see DatabaseService's v9 migration) — such rows sync via the
  // cardNumber+buildingCode+slotKey fallback branch instead (contract §1.3).
  final int? id;
  // Server `ExamSessionId` this participant belongs to.
  final int? examSessionId;
  // Sync-queue fallback only (never sent to the server as part of the
  // participant payload itself): the slot key to sync by when [id] is null
  // — i.e. a v8 offline-queue row migrated to v9 (see DatabaseService's v9
  // migration). Populated only when reading a queued row back out of
  // `registered_participants`.
  final String? slotKey;

  Participant({
    required this.cardNumber,
    required this.firstName,
    required this.lastName,
    required this.fatherName,
    required this.floor,
    required this.hall,
    required this.row,
    required this.seat,
    this.photo,
    this.photoBytes,
    this.registeredAt,
    required this.buildingCode,
    this.gender = 0,
    this.id,
    this.examSessionId,
    this.slotKey,
  });

  /// Фото как base64 (для мест, где нужна строка): из photo, либо из photoBytes.
  String? get photoBase64 =>
      photo ?? (photoBytes != null ? base64Encode(photoBytes!) : null);

  bool get hasPhoto =>
      (photo != null && photo!.isNotEmpty) ||
      (photoBytes != null && photoBytes!.isNotEmpty);

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      cardNumber: json['cardNumber'] as int,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      fatherName: json['fatherName'] as String,
      floor: json['floor'] as String,
      hall: json['hall'] as String,
      row: json['row'] as String,
      seat: json['seat'] as String,
      photo: json['photo'] as String?,
      registeredAt: json['registeredAt'] as String?,
      buildingCode: json['buildingCode'] as String? ?? '',
      gender: (json['gender'] as num?)?.toInt() ?? 0,
      id: json['id'] as int?,
      examSessionId: json['examSessionId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cardNumber': cardNumber,
      'firstName': firstName,
      'lastName': lastName,
      'fatherName': fatherName,
      'floor': floor,
      'hall': hall,
      'row': row,
      'seat': seat,
      'photo': photo,
      'registeredAt': registeredAt,
      'buildingCode': buildingCode,
      'gender': gender,
      if (id != null) 'id': id,
      if (examSessionId != null) 'examSessionId': examSessionId,
    };
  }

  String get fullName => '$lastName $firstName $fatherName';
}

/// Lightweight summary of one slot available at the time an exam/slot was
/// picked, stashed on [ExamDetails.slots] so the switcher (home screen /
/// admin dashboard) doesn't need a fresh `GET slots` call just to list them.
class SlotSummary {
  final String key;
  final String label;

  SlotSummary({
    required this.key,
    required this.label,
  });

  factory SlotSummary.fromJson(Map<String, dynamic> json) {
    return SlotSummary(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
      };
}

class ExamDetails {
  final String? buildingName; // Ad Bina
  final String? buildingCode; // Kod Bina
  final int? regManCount; // Qeydiyyatlı kişi sayı
  final int? regWomanCount; // Qeydiyyatlı qadın sayı
  final int? allManCount; // Ümumi kişi sayı
  final int? allWomanCount; // Ümumi qadın sayı
  // Slot fields (current flow — see API_slots.md). [slotKey] is what the dio
  // interceptor sends as `X-Exam-Slot`; [slotLabel] is shown by the
  // switcher; [slots] is the full slot list available at pick time so the
  // switcher can list them without a fresh `GET slots` call.
  final String? slotKey;
  final String? slotLabel;
  final List<SlotSummary> slots;

  ExamDetails({
    this.buildingName,
    this.buildingCode,
    this.regManCount,
    this.regWomanCount,
    this.allManCount,
    this.allWomanCount,
    this.slotKey,
    this.slotLabel,
    this.slots = const [],
  });

  factory ExamDetails.fromJson(Map<String, dynamic> json) {
    final slotsJson = json['slots'] as List<dynamic>? ?? const [];
    return ExamDetails(
      buildingName: json['buildingName'] as String?,
      buildingCode: json['buildingCode'] as String?,
      regManCount: json['regManCount'] as int?,
      regWomanCount: json['regWomanCount'] as int?,
      allManCount: json['allManCount'] as int?,
      allWomanCount: json['allWomanCount'] as int?,
      slotKey: json['slotKey'] as String?,
      slotLabel: json['slotLabel'] as String?,
      slots: slotsJson
          .map((e) => SlotSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'buildingName': buildingName,
      'buildingCode': buildingCode,
      'regManCount': regManCount,
      'regWomanCount': regWomanCount,
      'allManCount': allManCount,
      'allWomanCount': allWomanCount,
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
