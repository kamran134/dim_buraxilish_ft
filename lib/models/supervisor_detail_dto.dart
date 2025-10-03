/// Модель для наблюдателя (детальная версия)
class SupervisorDetailDto {
  final int? id;
  final String? cardNumber;
  final String? firstName;
  final String? lastName;
  final String? fatherName;
  final String? pinCode;
  final int? districtCode;
  final int? supervisorAction;
  final DateTime? examDate;
  final int? buildingCode;
  final String? buildingName;
  final String? phone;
  final String? image;
  final DateTime? registerDate;

  SupervisorDetailDto({
    this.id,
    this.cardNumber,
    this.firstName,
    this.lastName,
    this.fatherName,
    this.pinCode,
    this.districtCode,
    this.supervisorAction,
    this.examDate,
    this.buildingCode,
    this.buildingName,
    this.phone,
    this.image,
    this.registerDate,
  });

  factory SupervisorDetailDto.fromJson(Map<String, dynamic> json) {
    return SupervisorDetailDto(
      id: json['id'] as int?,
      cardNumber: json['cardNumber'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      fatherName: json['fatherName'] as String?,
      pinCode: json['pinCode'] as String?,
      districtCode: json['districtCode'] as int?,
      supervisorAction: json['supervisorAction'] as int?,
      examDate:
          json['examDate'] != null ? DateTime.tryParse(json['examDate']) : null,
      buildingCode: json['buildingCode'] as int?,
      buildingName: json['buildingName'] as String?,
      phone: json['phone'] as String?,
      image: json['image'] as String?,
      registerDate: json['registerDate'] != null
          ? DateTime.tryParse(json['registerDate'])
          : null,
    );
  }

  /// Полное имя наблюдателя
  String get fullName {
    final parts = <String>[];
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (fatherName != null && fatherName!.isNotEmpty) parts.add(fatherName!);
    return parts.join(' ');
  }

  /// Проверяет, зарегистрирован ли наблюдатель
  bool get isRegistered => registerDate != null;

  @override
  String toString() {
    return 'SupervisorDetailDto{id: $id, fullName: $fullName, isRegistered: $isRegistered, cardNumber: $cardNumber}';
  }
}
