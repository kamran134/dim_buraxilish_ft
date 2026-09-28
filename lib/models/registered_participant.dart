class RegisteredParticipant {
  final int cardNumber; // ID number
  final String lastName; // Last name
  final String firstName; // First name
  final String fatherName; // Father name
  final int gender; // Gender (1-male, 0-female)
  final String buildingCode; // Building
  final String hall; // Room
  final String floor; // Floor
  final String row; // Row
  final String seat; // Seat
  final String imtTarix; // Exam date
  final String photo; // Base64 photo
  final String registeredAt; // Registration date/time
  final bool online; // If synced with server

  const RegisteredParticipant({
    required this.cardNumber,
    required this.lastName,
    required this.firstName,
    required this.fatherName,
    required this.gender,
    required this.buildingCode,
    required this.hall,
    required this.floor,
    required this.row,
    required this.seat,
    required this.imtTarix,
    required this.photo,
    required this.registeredAt,
    this.online = false,
  });

  factory RegisteredParticipant.fromJson(Map<String, dynamic> json) {
    return RegisteredParticipant(
      cardNumber: json['cardNumber'] ?? 0,
      lastName: json['lastName'] ?? '',
      firstName: json['firstName'] ?? '',
      fatherName: json['fatherName'] ?? '',
      gender: json['gender'] ?? 1,
      buildingCode: json['buildingCode']?.toString() ?? '',
      hall: json['hall']?.toString() ?? '',
      floor: json['floor']?.toString() ?? '',
      row: json['row']?.toString() ?? '',
      seat: json['seat']?.toString() ?? '',
      imtTarix: json['imt_Tarix'] ?? '',
      photo: json['photo'] ?? '',
      registeredAt: json['registeredAt'] ?? '',
      online: (json['online'] == 1 || json['online'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cardNumber': cardNumber,
      'lastName': lastName,
      'firstName': firstName,
      'fatherName': fatherName,
      'gender': gender,
      'buildingCode': buildingCode,
      'hall': hall,
      'floor': floor,
      'row': row,
      'seat': seat,
      'imt_Tarix': imtTarix,
      'photo': photo,
      'registeredAt': registeredAt,
      'online': online ? 1 : 0,
    };
  }

  String get fullName => '$lastName $firstName $fatherName'.trim();
  String get genderText => gender == 1 ? 'Kişi' : 'Qadın';
}
