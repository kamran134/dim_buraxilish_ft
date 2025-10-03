/// Модель для участника (облегченная версия)
class ParticipantLightDto {
  final String? erize;
  final int? isN;
  final String? soy;
  final String? adi;
  final String? baba;
  final DateTime? tev;
  final int? gins;
  final String? svSeriya;
  final String? sVes;
  final String? bina;
  final String? zal;
  final String? mertebe;
  final String? sira;
  final String? yer;
  final String? imtTarix;
  final String? imtBegin;
  final String? adBina;
  final DateTime? qeydiyyat;
  final int? sNomer;
  final int? id;

  ParticipantLightDto({
    this.erize,
    this.isN,
    this.soy,
    this.adi,
    this.baba,
    this.tev,
    this.gins,
    this.svSeriya,
    this.sVes,
    this.bina,
    this.zal,
    this.mertebe,
    this.sira,
    this.yer,
    this.imtTarix,
    this.imtBegin,
    this.adBina,
    this.qeydiyyat,
    this.sNomer,
    this.id,
  });

  factory ParticipantLightDto.fromJson(Map<String, dynamic> json) {
    return ParticipantLightDto(
      erize: json['erize'] as String?,
      isN: json['is_N'] as int?,
      soy: json['soy'] as String?,
      adi: json['adi'] as String?,
      baba: json['baba'] as String?,
      tev: json['tev'] != null ? DateTime.tryParse(json['tev']) : null,
      gins: json['gins'] as int?,
      svSeriya: json['sv_Seriya'] as String?,
      sVes: json['s_Ves'] as String?,
      bina: json['bina'] as String?,
      zal: json['zal'] as String?,
      mertebe: json['mertebe'] as String?,
      sira: json['sira'] as String?,
      yer: json['yer'] as String?,
      imtTarix: json['imt_Tarix'] as String?,
      imtBegin: json['imt_Begin'] as String?,
      adBina: json['ad_Bina'] as String?,
      qeydiyyat: json['qeydiyyat'] != null
          ? DateTime.tryParse(json['qeydiyyat'])
          : null,
      sNomer: json['s_Nomer'] as int?,
      id: json['id'] as int?,
    );
  }

  /// Полное имя участника
  String get fullName {
    final parts = <String>[];
    if (soy != null && soy!.isNotEmpty) parts.add(soy!);
    if (adi != null && adi!.isNotEmpty) parts.add(adi!);
    if (baba != null && baba!.isNotEmpty) parts.add(baba!);
    return parts.join(' ');
  }

  /// Проверяет, зарегистрирован ли участник
  bool get isRegistered => qeydiyyat != null;

  @override
  String toString() {
    return 'ParticipantLightDto{id: $id, fullName: $fullName, isRegistered: $isRegistered}';
  }
}
