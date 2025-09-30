/// Модель для информации о нəzarətçi (supervisor)
class Supervisor {
  final int buildingCode;
  final String buildingName;
  final String cardNumber;
  final int districtCode;
  final String examDate;
  final String fatherName;
  final String firstName;
  final String lastName;
  final String image;
  final String pinCode;
  final String registerDate;
  final int supervisorAction;
  final bool? online;

  const Supervisor({
    required this.buildingCode,
    required this.buildingName,
    required this.cardNumber,
    required this.districtCode,
    required this.examDate,
    required this.fatherName,
    required this.firstName,
    required this.lastName,
    required this.image,
    required this.pinCode,
    required this.registerDate,
    required this.supervisorAction,
    this.online,
  });

  /// Получить полное имя нəzarətçi
  String get fullName => '$lastName $firstName $fatherName';

  factory Supervisor.fromJson(Map<String, dynamic> json) {
    return Supervisor(
      buildingCode: json['buildingCode'] as int? ?? 0,
      buildingName: json['buildingName'] as String? ?? '',
      cardNumber: json['cardNumber'] as String? ?? '',
      districtCode: json['districtCode'] as int? ?? 0,
      examDate: json['examDate'] as String? ?? '',
      fatherName: json['fatherName'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      image: json['image'] as String? ?? '',
      pinCode: json['pinCode'] as String? ?? '',
      registerDate: json['registerDate'] as String? ?? '',
      supervisorAction: json['supervisorAction'] as int? ?? 0,
      online: json['online'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'buildingCode': buildingCode,
      'buildingName': buildingName,
      'cardNumber': cardNumber,
      'districtCode': districtCode,
      'examDate': examDate,
      'fatherName': fatherName,
      'firstName': firstName,
      'lastName': lastName,
      'image': image,
      'pinCode': pinCode,
      'registerDate': registerDate,
      'supervisorAction': supervisorAction,
      if (online != null) 'online': online,
    };
  }

  @override
  String toString() {
    return 'Supervisor(cardNumber: $cardNumber, fullName: $fullName)';
  }
}

/// Ответ API для получения информации о нəzarətçi
class SupervisorResponse {
  final Supervisor? data;
  final bool success;
  final String message;

  const SupervisorResponse({
    this.data,
    required this.success,
    required this.message,
  });

  factory SupervisorResponse.fromJson(Map<String, dynamic> json) {
    return SupervisorResponse(
      data: json['data'] != null ? Supervisor.fromJson(json['data']) : null,
      success: json['success'] as bool? ?? false,
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

/// Ответ API для получения списка нəzarətçi
class SupervisorsResponse {
  final List<Supervisor> data;
  final bool success;
  final String message;

  const SupervisorsResponse({
    required this.data,
    required this.success,
    required this.message,
  });

  factory SupervisorsResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List?;
    return SupervisorsResponse(
      data: dataList?.map((item) => Supervisor.fromJson(item)).toList() ?? [],
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((supervisor) => supervisor.toJson()).toList(),
      'success': success,
      'message': message,
    };
  }
}

/// Краткая информация о нəzarətçi (для локального хранения)
class SupervisorShort {
  final String cardNumber;
  final int buildingCode;
  final String examDate;
  final String registerDate;
  final bool? online;

  const SupervisorShort({
    required this.cardNumber,
    required this.buildingCode,
    required this.examDate,
    required this.registerDate,
    this.online,
  });

  factory SupervisorShort.fromJson(Map<String, dynamic> json) {
    return SupervisorShort(
      cardNumber: json['cardNumber'] as String? ?? '',
      buildingCode: json['buildingCode'] as int? ?? 0,
      examDate: json['examDate'] as String? ?? '',
      registerDate: json['registerDate'] as String? ?? '',
      online: json['online'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cardNumber': cardNumber,
      'buildingCode': buildingCode,
      'examDate': examDate,
      'registerDate': registerDate,
      if (online != null) 'online': online,
    };
  }

  /// Создать SupervisorShort из полной модели Supervisor
  factory SupervisorShort.fromSupervisor(Supervisor supervisor) {
    return SupervisorShort(
      cardNumber: supervisor.cardNumber,
      buildingCode: supervisor.buildingCode,
      examDate: supervisor.examDate,
      registerDate: supervisor.registerDate,
      online: supervisor.online,
    );
  }
}

/// Детали статистики по нəzarətçi (аналогично ISupervisorDetails)
class SupervisorDetails {
  final int allPersonCount;
  final int regPersonCount;

  const SupervisorDetails({
    required this.allPersonCount,
    required this.regPersonCount,
  });

  /// Количество незарегистрированных нəzarətçi
  int get unregisteredCount => allPersonCount - regPersonCount;

  factory SupervisorDetails.fromJson(Map<String, dynamic> json) {
    return SupervisorDetails(
      allPersonCount: json['allPersonCount'] as int? ?? 0,
      regPersonCount: json['regPersonCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allPersonCount': allPersonCount,
      'regPersonCount': regPersonCount,
    };
  }
}
