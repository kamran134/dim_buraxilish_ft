class RegisteredSupervisor {
  final String cardNumber; // Card number/ID
  final String firstName; // First name
  final String lastName; // Last name
  final String fatherName; // Father name
  final String buildingCode; // Building code
  final String examDate; // Exam date
  final String registerDate; // Registration date/time
  final String image; // Base64 photo
  final bool online; // If synced with server

  const RegisteredSupervisor({
    required this.cardNumber,
    required this.firstName,
    required this.lastName,
    required this.fatherName,
    required this.buildingCode,
    required this.examDate,
    required this.registerDate,
    required this.image,
    this.online = false,
  });

  factory RegisteredSupervisor.fromJson(Map<String, dynamic> json) {
    return RegisteredSupervisor(
      cardNumber: json['cardNumber']?.toString() ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      fatherName: json['fatherName'] ?? '',
      buildingCode: json['buildingCode']?.toString() ?? '',
      examDate: json['examDate'] ?? '',
      registerDate: json['registerDate'] ?? '',
      image: json['image'] ?? '',
      online: (json['online'] == 1 || json['online'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cardNumber': cardNumber,
      'firstName': firstName,
      'lastName': lastName,
      'fatherName': fatherName,
      'buildingCode': buildingCode,
      'examDate': examDate,
      'registerDate': registerDate,
      'image': image,
      'online': online ? 1 : 0,
    };
  }

  String get fullName => '$lastName $firstName $fatherName'.trim();
}
