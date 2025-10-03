/// DTO для объединенной статистики экзаменов (участники + наблюдатели)
class ExamStatisticsDto {
  final String? kodBina;
  final String? adBina;
  final String? erize;
  final String? imtTarix;
  final String? imtBegin;
  final int? allManCount;
  final int? regManCount;
  final int? allWomanCount;
  final int? regWomanCount;
  final int? supervisorCount;
  final int? regSupervisorCount;

  ExamStatisticsDto({
    this.kodBina,
    this.adBina,
    this.erize,
    this.imtTarix,
    this.imtBegin,
    this.allManCount,
    this.regManCount,
    this.allWomanCount,
    this.regWomanCount,
    this.supervisorCount,
    this.regSupervisorCount,
  });

  factory ExamStatisticsDto.fromJson(Map<String, dynamic> json) {
    return ExamStatisticsDto(
      kodBina: json['kod_Bina'] as String?,
      adBina: json['ad_Bina'] as String?,
      erize: json['erize'] as String?,
      imtTarix: json['imt_Tarix'] as String?,
      imtBegin: json['imt_Begin'] as String?,
      allManCount: json['allManCount'] as int?,
      regManCount: json['regManCount'] as int?,
      allWomanCount: json['allWomanCount'] as int?,
      regWomanCount: json['regWomanCount'] as int?,
      supervisorCount: json['supervisorCount'] as int?,
      regSupervisorCount: json['regSupervisorCount'] as int?,
    );
  }

  // Вычисляемые свойства для обратной совместимости
  int get totalParticipants => (allManCount ?? 0) + (allWomanCount ?? 0);
  int get registeredParticipants => (regManCount ?? 0) + (regWomanCount ?? 0);
  int get unregisteredParticipants =>
      totalParticipants - registeredParticipants;

  Map<String, dynamic> toJson() {
    return {
      'kod_Bina': kodBina,
      'ad_Bina': adBina,
      'erize': erize,
      'imt_Tarix': imtTarix,
      'imt_Begin': imtBegin,
      'allManCount': allManCount,
      'regManCount': regManCount,
      'allWomanCount': allWomanCount,
      'regWomanCount': regWomanCount,
      'supervisorCount': supervisorCount,
      'regSupervisorCount': regSupervisorCount,
    };
  }

  @override
  String toString() {
    return 'ExamStatisticsDto{kodBina: $kodBina, adBina: $adBina, totalParticipants: $totalParticipants, registeredParticipants: $registeredParticipants, allManCount: $allManCount, regManCount: $regManCount, allWomanCount: $allWomanCount, regWomanCount: $regWomanCount, supervisorCount: $supervisorCount, regSupervisorCount: $regSupervisorCount}';
  }
}
