/// Модель для информации о İmtahan rəhbəri (monitor/exam leader)
class Monitor {
  final int workNumber;
  final String firstName;
  final String lastName;
  final String middleName;
  final String idCardPin;
  final int buildingCode;
  final String buildingName;
  final int roomId;
  final String roomName;
  final String examDate;
  final String registerDate;
  final String image;
  final bool? online;

  const Monitor({
    required this.workNumber,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.idCardPin,
    required this.buildingCode,
    required this.buildingName,
    required this.roomId,
    required this.roomName,
    required this.examDate,
    required this.registerDate,
    required this.image,
    this.online,
  });

  /// Получить полное имя monitor
  String get fullName => '$lastName $firstName $middleName';

  /// Проверка наличия фото
  bool get hasPhoto => image.isNotEmpty;

  /// Проверка регистрации
  bool get isRegistered => registerDate.isNotEmpty;

  factory Monitor.fromJson(Map<String, dynamic> json) {
    return Monitor(
      workNumber: json['workNumber'] as int? ?? 0,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      middleName: json['middleName'] as String? ?? '',
      idCardPin: json['idCardPin'] as String? ?? '',
      buildingCode: json['buildingCode'] as int? ?? 0,
      buildingName: json['buildingName'] as String? ?? '',
      roomId: json['roomId'] as int? ?? 0,
      roomName: json['roomName'] as String? ?? '',
      examDate: json['examDate'] as String? ?? '',
      registerDate: json['registerDate'] as String? ?? '',
      image: json['image'] as String? ?? '',
      online: json['online'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workNumber': workNumber,
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'idCardPin': idCardPin,
      'buildingCode': buildingCode,
      'buildingName': buildingName,
      'roomId': roomId,
      'roomName': roomName,
      'examDate': examDate,
      'registerDate': registerDate,
      'image': image,
      if (online != null) 'online': online,
    };
  }

  @override
  String toString() {
    return 'Monitor(workNumber: $workNumber, fullName: $fullName, building: $buildingName, room: $roomName)';
  }
}

/// Ответ API для получения информации о monitor
class MonitorResponse {
  final Monitor? data;
  final bool success;
  final String message;

  const MonitorResponse({
    this.data,
    required this.success,
    required this.message,
  });

  factory MonitorResponse.fromJson(Map<String, dynamic> json) {
    return MonitorResponse(
      data: json['data'] != null ? Monitor.fromJson(json['data']) : null,
      success: json['success'] as bool? ??
          (json['data'] != null), // If no success field, use presence of data
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

/// Ответ API для получения списка monitors
class MonitorsResponse {
  final List<Monitor> data;
  final bool success;
  final String message;

  const MonitorsResponse({
    required this.data,
    required this.success,
    required this.message,
  });

  factory MonitorsResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List?;
    return MonitorsResponse(
      data: dataList?.map((item) => Monitor.fromJson(item)).toList() ?? [],
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((monitor) => monitor.toJson()).toList(),
      'success': success,
      'message': message,
    };
  }
}

/// Краткая информация о monitor (для локального хранения, если понадобится)
class MonitorShort {
  final int workNumber;
  final int buildingCode;
  final String examDate;
  final String registerDate;
  final bool? online;

  const MonitorShort({
    required this.workNumber,
    required this.buildingCode,
    required this.examDate,
    required this.registerDate,
    this.online,
  });

  factory MonitorShort.fromJson(Map<String, dynamic> json) {
    return MonitorShort(
      workNumber: json['workNumber'] as int? ?? 0,
      buildingCode: json['buildingCode'] as int? ?? 0,
      examDate: json['examDate'] as String? ?? '',
      registerDate: json['registerDate'] as String? ?? '',
      online: json['online'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workNumber': workNumber,
      'buildingCode': buildingCode,
      'examDate': examDate,
      'registerDate': registerDate,
      if (online != null) 'online': online,
    };
  }
}
