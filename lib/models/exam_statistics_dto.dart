/// DTO для объединенной статистики экзаменов (участники + наблюдатели)
class ExamStatisticsDto {
  final String? buildingCode;
  final String? buildingName;
  final int? allManCount;
  final int? regManCount;
  final int? allWomanCount;
  final int? regWomanCount;
  final int? supervisorCount;
  final int? regSupervisorCount;
  final int? hallCount;
  final int? monitorCount;
  final int? regMonitorCount;

  ExamStatisticsDto({
    this.buildingCode,
    this.buildingName,
    this.allManCount,
    this.regManCount,
    this.allWomanCount,
    this.regWomanCount,
    this.supervisorCount,
    this.regSupervisorCount,
    this.hallCount,
    this.monitorCount,
    this.regMonitorCount,
  });

  factory ExamStatisticsDto.fromJson(Map<String, dynamic> json) {
    return ExamStatisticsDto(
      buildingCode: json['buildingCode']?.toString(),
      buildingName: json['buildingName'] as String?,
      allManCount: json['allManCount'] as int?,
      regManCount: json['regManCount'] as int?,
      allWomanCount: json['allWomanCount'] as int?,
      regWomanCount: json['regWomanCount'] as int?,
      supervisorCount: json['supervisorCount'] as int?,
      regSupervisorCount: json['regSupervisorCount'] as int?,
      hallCount: json['hallCount'] as int?,
      monitorCount: json['monitorCount'] as int?,
      regMonitorCount: json['regMonitorCount'] as int?,
    );
  }

  // Вычисляемые свойства для обратной совместимости
  int get totalParticipants => (allManCount ?? 0) + (allWomanCount ?? 0);
  int get registeredParticipants => (regManCount ?? 0) + (regWomanCount ?? 0);
  int get unregisteredParticipants =>
      totalParticipants - registeredParticipants;

  // Новые свойства для расчета Yetərsay
  /// Проверяет, достаточно ли супервизоров для залов
  bool get hasEnoughSupervisors {
    if (hallCount == null || regSupervisorCount == null) return true;
    return regSupervisorCount! >= hallCount!;
  }

  /// Возвращает разность между зарегистрированными супервизорами и количеством залов
  int get supervisorDifference {
    if (hallCount == null || regSupervisorCount == null) return 0;
    return regSupervisorCount! - hallCount!;
  }

  /// Возвращает статус Yetərsay как строку
  String get yetarsayStatus {
    if (hallCount == null || regSupervisorCount == null) {
      return 'Məlumat yoxdur';
    }

    final difference = supervisorDifference;

    if (difference >= 0) {
      return difference == 0 ? 'Yetərsay var' : 'Yetərsay var (+$difference)';
    } else {
      return 'Yetərsay yoxdur ($difference)';
    }
  }

  /// Возвращает цвет для отображения статуса Yetərsay
  bool get yetarsayIsGood => hasEnoughSupervisors;

  Map<String, dynamic> toJson() {
    return {
      'buildingCode': buildingCode,
      'buildingName': buildingName,
      'allManCount': allManCount,
      'regManCount': regManCount,
      'allWomanCount': allWomanCount,
      'regWomanCount': regWomanCount,
      'supervisorCount': supervisorCount,
      'regSupervisorCount': regSupervisorCount,
      'hallCount': hallCount,
      'monitorCount': monitorCount,
      'regMonitorCount': regMonitorCount,
    };
  }

  @override
  String toString() {
    return 'ExamStatisticsDto{buildingCode: $buildingCode, buildingName: $buildingName, totalParticipants: $totalParticipants, registeredParticipants: $registeredParticipants, allManCount: $allManCount, regManCount: $regManCount, allWomanCount: $allWomanCount, regWomanCount: $regWomanCount, supervisorCount: $supervisorCount, regSupervisorCount: $regSupervisorCount, hallCount: $hallCount, yetarsayStatus: $yetarsayStatus}';
  }
}
