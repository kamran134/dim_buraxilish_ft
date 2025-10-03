/// DTO для объединенной статистики экзаменов (участники + наблюдатели)
class ExamStatisticsDto {
  final String? building;
  final String? examDate;
  final int? totalParticipants;
  final int? registeredParticipants;
  final int? unregisteredParticipants;
  final int? supervisorCount;
  final int? regSupervisorCount;

  ExamStatisticsDto({
    this.building,
    this.examDate,
    this.totalParticipants,
    this.registeredParticipants,
    this.unregisteredParticipants,
    this.supervisorCount,
    this.regSupervisorCount,
  });

  factory ExamStatisticsDto.fromJson(Map<String, dynamic> json) {
    return ExamStatisticsDto(
      building: json['building'] as String?,
      examDate: json['examDate'] as String?,
      totalParticipants: json['totalParticipants'] as int?,
      registeredParticipants: json['registeredParticipants'] as int?,
      unregisteredParticipants: json['unregisteredParticipants'] as int?,
      supervisorCount: json['supervisorCount'] as int?,
      regSupervisorCount: json['regSupervisorCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'building': building,
      'examDate': examDate,
      'totalParticipants': totalParticipants,
      'registeredParticipants': registeredParticipants,
      'unregisteredParticipants': unregisteredParticipants,
      'supervisorCount': supervisorCount,
      'regSupervisorCount': regSupervisorCount,
    };
  }

  @override
  String toString() {
    return 'ExamStatisticsDto{building: $building, examDate: $examDate, totalParticipants: $totalParticipants, registeredParticipants: $registeredParticipants, unregisteredParticipants: $unregisteredParticipants, supervisorCount: $supervisorCount, regSupervisorCount: $regSupervisorCount}';
  }
}
