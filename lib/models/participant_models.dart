class Participant {
  final int isN; // İş nömrəsi
  final String adi; // Ad
  final String soy; // Soyad
  final String baba; // Ata adı
  final String mertebe; // Mərtəbə
  final String zal; // Zal
  final String sira; // Sıra
  final String yer; // Yer
  final String? photo; // Şəkil
  final String? qeydiyyat; // Qeydiyyat tarixi
  final String bina; // Bina
  final String imtTarix; // İmtahan tarixi

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
    this.qeydiyyat,
    required this.bina,
    required this.imtTarix,
  });

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
    };
  }

  String get fullName => '$soy $adi $baba';
}

class ExamDetails {
  final String? adBina; // Ad Bina
  final String? kodBina; // Kod Bina
  final String? imtTarix; // İmtahan tarixi
  final int? regManCount; // Qeydiyyatlı kişi sayı
  final int? regWomanCount; // Qeydiyyatlı qadın sayı
  final int? allManCount; // Ümumi kişi sayı
  final int? allWomanCount; // Ümumi qadın sayı

  ExamDetails({
    this.adBina,
    this.kodBina,
    this.imtTarix,
    this.regManCount,
    this.regWomanCount,
    this.allManCount,
    this.allWomanCount,
  });

  factory ExamDetails.fromJson(Map<String, dynamic> json) {
    return ExamDetails(
      adBina: json['ad_Bina'] as String?,
      kodBina: json['kod_Bina'] as String?,
      imtTarix: json['imt_Tarix'] as String?,
      regManCount: json['regManCount'] as int?,
      regWomanCount: json['regWomanCount'] as int?,
      allManCount: json['allManCount'] as int?,
      allWomanCount: json['allWomanCount'] as int?,
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
