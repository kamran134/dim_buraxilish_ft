/// Перечисление ролей пользователей в системе
enum UserRole {
  superadmin('superadmin', 'Super Administrator'),
  admin('admin', 'Administrator'),
  monitor('monitor', 'Monitor');

  const UserRole(this.value, this.displayName);

  final String value;
  final String displayName;

  /// Преобразует строку в enum роли
  static UserRole fromString(String? roleString) {
    if (roleString == null) return UserRole.monitor;

    switch (roleString.toLowerCase()) {
      case 'superadmin':
        return UserRole.superadmin;
      case 'admin':
        return UserRole.admin;
      case 'monitor':
        return UserRole.monitor;
      default:
        return UserRole.monitor;
    }
  }

  /// Проверяет, является ли роль административной
  bool get isAdmin => this == UserRole.admin || this == UserRole.superadmin;

  /// Проверяет, является ли роль супер-админом
  bool get isSuperAdmin => this == UserRole.superadmin;

  /// Проверяет, является ли роль монитором
  bool get isMonitor => this == UserRole.monitor;
}

/// Информация о роли пользователя
class UserRoleInfo {
  final String role;
  final bool isAdmin;
  final bool isMonitor;
  final bool isSuperAdmin;

  UserRoleInfo({
    required this.role,
    required this.isAdmin,
    required this.isMonitor,
    required this.isSuperAdmin,
  });

  factory UserRoleInfo.fromJson(Map<String, dynamic> json) {
    return UserRoleInfo(
      role: json['role'] as String,
      isAdmin: json['isAdmin'] as bool,
      isMonitor: json['isMonitor'] as bool,
      isSuperAdmin: json['isSuperAdmin'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'isAdmin': isAdmin,
      'isMonitor': isMonitor,
      'isSuperAdmin': isSuperAdmin,
    };
  }

  UserRole get userRole => UserRole.fromString(role);
}

/// Статистические данные для dashboard админа
class DashboardStats {
  final int totalParticipants;
  final int totalSupervisors;
  final int totalBuildings;
  final int activeExams;
  final List<ExamStatistic> examStatistics;
  final List<BuildingStatistic> buildingStatistics;

  DashboardStats({
    required this.totalParticipants,
    required this.totalSupervisors,
    required this.totalBuildings,
    required this.activeExams,
    required this.examStatistics,
    required this.buildingStatistics,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalParticipants: json['totalParticipants'] as int? ?? 0,
      totalSupervisors: json['totalSupervisors'] as int? ?? 0,
      totalBuildings: json['totalBuildings'] as int? ?? 0,
      activeExams: json['activeExams'] as int? ?? 0,
      examStatistics: (json['examStatistics'] as List?)
              ?.map((e) => ExamStatistic.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      buildingStatistics: (json['buildingStatistics'] as List?)
              ?.map(
                  (e) => BuildingStatistic.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalParticipants': totalParticipants,
      'totalSupervisors': totalSupervisors,
      'totalBuildings': totalBuildings,
      'activeExams': activeExams,
      'examStatistics': examStatistics.map((e) => e.toJson()).toList(),
      'buildingStatistics': buildingStatistics.map((e) => e.toJson()).toList(),
    };
  }
}

/// Статистика по экзамену
class ExamStatistic {
  final String examDate;
  final int participantCount;
  final int supervisorCount;
  final int completedCount;
  final double completionRate;

  ExamStatistic({
    required this.examDate,
    required this.participantCount,
    required this.supervisorCount,
    required this.completedCount,
    required this.completionRate,
  });

  factory ExamStatistic.fromJson(Map<String, dynamic> json) {
    return ExamStatistic(
      examDate: json['examDate'] as String,
      participantCount: json['participantCount'] as int? ?? 0,
      supervisorCount: json['supervisorCount'] as int? ?? 0,
      completedCount: json['completedCount'] as int? ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'examDate': examDate,
      'participantCount': participantCount,
      'supervisorCount': supervisorCount,
      'completedCount': completedCount,
      'completionRate': completionRate,
    };
  }
}

/// Статистика по зданию
class BuildingStatistic {
  final int buildingId;
  final String buildingName;
  final int participantCount;
  final int supervisorCount;
  final int completedCount;
  final double completionRate;

  BuildingStatistic({
    required this.buildingId,
    required this.buildingName,
    required this.participantCount,
    required this.supervisorCount,
    required this.completedCount,
    required this.completionRate,
  });

  factory BuildingStatistic.fromJson(Map<String, dynamic> json) {
    return BuildingStatistic(
      buildingId: json['buildingId'] as int,
      buildingName: json['buildingName'] as String,
      participantCount: json['participantCount'] as int? ?? 0,
      supervisorCount: json['supervisorCount'] as int? ?? 0,
      completedCount: json['completedCount'] as int? ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'buildingId': buildingId,
      'buildingName': buildingName,
      'participantCount': participantCount,
      'supervisorCount': supervisorCount,
      'completedCount': completedCount,
      'completionRate': completionRate,
    };
  }
}
