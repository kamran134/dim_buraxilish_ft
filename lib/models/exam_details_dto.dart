/// DTO для статистики экзаменов
class ExamDetailsDto {
  final String? kodBina;
  final String? adBina;
  final String? erize;
  final String? imtTarix;
  final String? imtBegin;
  final int? allManCount;
  final int? regManCount;
  final int? allWomanCount;
  final int? regWomanCount;

  ExamDetailsDto({
    this.kodBina,
    this.adBina,
    this.erize,
    this.imtTarix,
    this.imtBegin,
    this.allManCount,
    this.regManCount,
    this.allWomanCount,
    this.regWomanCount,
  });

  factory ExamDetailsDto.fromJson(Map<String, dynamic> json) {
    return ExamDetailsDto(
      kodBina: json['kod_Bina'] as String?,
      adBina: json['ad_Bina'] as String?,
      erize: json['erize'] as String?,
      imtTarix: json['imt_Tarix'] as String?,
      imtBegin: json['imt_Begin'] as String?,
      allManCount: json['allManCount'] as int? ?? 0,
      regManCount: json['regManCount'] as int? ?? 0,
      allWomanCount: json['allWomanCount'] as int? ?? 0,
      regWomanCount: json['regWomanCount'] as int? ?? 0,
    );
  }

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
    };
  }

  /// Получает общее количество участников
  int get totalParticipants => (allManCount ?? 0) + (allWomanCount ?? 0);

  /// Получает общее количество зарегистрированных участников
  int get totalRegistered => (regManCount ?? 0) + (regWomanCount ?? 0);

  /// Получает общее количество незарегистрированных участников
  int get totalUnregistered => totalParticipants - totalRegistered;

  /// Получает процент регистрации
  double get registrationRate {
    if (totalParticipants == 0) return 0.0;
    return (totalRegistered / totalParticipants) * 100;
  }

  /// Получает процент нерегистрации
  double get unregistrationRate {
    if (totalParticipants == 0) return 0.0;
    return (totalUnregistered / totalParticipants) * 100;
  }
}

/// Модель для итоговой статистики
class ExamStatisticsSum {
  final int allManCount;
  final int allWomanCount;
  final int regManCount;
  final int regWomanCount;

  ExamStatisticsSum({
    required this.allManCount,
    required this.allWomanCount,
    required this.regManCount,
    required this.regWomanCount,
  });

  /// Получает общее количество участников
  int get totalParticipants => allManCount + allWomanCount;

  /// Получает общее количество зарегистрированных участников
  int get totalRegistered => regManCount + regWomanCount;

  /// Получает общее количество незарегистрированных участников
  int get totalUnregistered => totalParticipants - totalRegistered;

  /// Получает процент регистрации
  double get registrationRate {
    if (totalParticipants == 0) return 0.0;
    return (totalRegistered / totalParticipants) * 100;
  }

  /// Получает процент нерегистрации
  double get unregistrationRate {
    if (totalParticipants == 0) return 0.0;
    return (totalUnregistered / totalParticipants) * 100;
  }

  /// Создает сумму из списка ExamDetailsDto
  factory ExamStatisticsSum.fromExamDetailsList(
      List<ExamDetailsDto> examDetails) {
    int allManCount = 0;
    int allWomanCount = 0;
    int regManCount = 0;
    int regWomanCount = 0;

    for (final examDetail in examDetails) {
      allManCount += examDetail.allManCount ?? 0;
      allWomanCount += examDetail.allWomanCount ?? 0;
      regManCount += examDetail.regManCount ?? 0;
      regWomanCount += examDetail.regWomanCount ?? 0;
    }

    return ExamStatisticsSum(
      allManCount: allManCount,
      allWomanCount: allWomanCount,
      regManCount: regManCount,
      regWomanCount: regWomanCount,
    );
  }
}
