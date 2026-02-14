/// Model for monitor room statistics
class MonitorRoomStatistics {
  final int roomId;
  final String roomName;
  final String examDate;
  final int allPersonCount; // Total monitors
  final int regPersonCount; // Registered monitors

  MonitorRoomStatistics({
    required this.roomId,
    required this.roomName,
    required this.examDate,
    required this.allPersonCount,
    required this.regPersonCount,
  });

  // Calculated properties
  int get unregisteredCount => allPersonCount - regPersonCount;
  double get registrationPercentage =>
      allPersonCount > 0 ? (regPersonCount / allPersonCount) * 100 : 0.0;
  double get unregisteredPercentage =>
      allPersonCount > 0 ? (unregisteredCount / allPersonCount) * 100 : 0.0;

  factory MonitorRoomStatistics.fromJson(Map<String, dynamic> json) {
    return MonitorRoomStatistics(
      roomId: json['roomId'] ?? 0,
      roomName: json['roomName'] ?? '',
      examDate: json['examDate'] ?? '',
      allPersonCount: json['allPersonCount'] ?? 0,
      regPersonCount: json['regPersonCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'roomName': roomName,
      'examDate': examDate,
      'allPersonCount': allPersonCount,
      'regPersonCount': regPersonCount,
    };
  }
}

/// Response model for list of monitor room statistics
class MonitorRoomStatisticsResponse {
  final bool success;
  final String message;
  final List<MonitorRoomStatistics> data;

  MonitorRoomStatisticsResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory MonitorRoomStatisticsResponse.fromJson(Map<String, dynamic> json) {
    return MonitorRoomStatisticsResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => MonitorRoomStatistics.fromJson(item))
              .toList() ??
          [],
    );
  }
}
