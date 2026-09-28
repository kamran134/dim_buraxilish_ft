/// Модель для участника (облегченная версия)
class ParticipantLightDto {
  final int? cardNumber;
  final String? lastName;
  final String? firstName;
  final String? fatherName;
  final DateTime? birthDate;
  final int? gender;
  final String? idCardSeries;
  final String? idCardNumber;
  final String? buildingCode;
  final String? hall;
  final String? floor;
  final String? row;
  final String? seat;
  final String? buildingName;
  final DateTime? registeredAt;
  final int? id;
  final int? examSessionId;

  ParticipantLightDto({
    this.cardNumber,
    this.lastName,
    this.firstName,
    this.fatherName,
    this.birthDate,
    this.gender,
    this.idCardSeries,
    this.idCardNumber,
    this.buildingCode,
    this.hall,
    this.floor,
    this.row,
    this.seat,
    this.buildingName,
    this.registeredAt,
    this.id,
    this.examSessionId,
  });

  factory ParticipantLightDto.fromJson(Map<String, dynamic> json) {
    return ParticipantLightDto(
      cardNumber: json['cardNumber'] as int?,
      lastName: json['lastName'] as String?,
      firstName: json['firstName'] as String?,
      fatherName: json['fatherName'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'])
          : null,
      gender: json['gender'] as int?,
      idCardSeries: json['idCardSeries'] as String?,
      idCardNumber: json['idCardNumber'] as String?,
      buildingCode: json['buildingCode'] as String?,
      hall: json['hall'] as String?,
      floor: json['floor'] as String?,
      row: json['row'] as String?,
      seat: json['seat'] as String?,
      buildingName: json['buildingName'] as String?,
      registeredAt: json['registeredAt'] != null
          ? DateTime.tryParse(json['registeredAt'])
          : null,
      id: json['id'] as int?,
      examSessionId: json['examSessionId'] as int?,
    );
  }

  /// Полное имя участника
  String get fullName {
    final parts = <String>[];
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (fatherName != null && fatherName!.isNotEmpty) parts.add(fatherName!);
    return parts.join(' ');
  }

  /// Проверяет, зарегистрирован ли участник
  bool get isRegistered => registeredAt != null;

  @override
  String toString() {
    return 'ParticipantLightDto{id: $id, fullName: $fullName, isRegistered: $isRegistered}';
  }
}
