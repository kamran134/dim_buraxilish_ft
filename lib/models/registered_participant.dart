class RegisteredParticipant {
  final int isN; // ID number
  final String soy; // Last name
  final String adi; // First name
  final String baba; // Father name
  final int gins; // Gender (1-male, 0-female)
  final String bina; // Building
  final String zal; // Room
  final String mertebe; // Floor
  final String sira; // Row
  final String yer; // Seat
  final String imtTarix; // Exam date
  final String photo; // Base64 photo
  final String qeydiyyat; // Registration date/time
  final bool online; // If synced with server

  const RegisteredParticipant({
    required this.isN,
    required this.soy,
    required this.adi,
    required this.baba,
    required this.gins,
    required this.bina,
    required this.zal,
    required this.mertebe,
    required this.sira,
    required this.yer,
    required this.imtTarix,
    required this.photo,
    required this.qeydiyyat,
    this.online = false,
  });

  factory RegisteredParticipant.fromJson(Map<String, dynamic> json) {
    return RegisteredParticipant(
      isN: json['is_N'] ?? 0,
      soy: json['soy'] ?? '',
      adi: json['adi'] ?? '',
      baba: json['baba'] ?? '',
      gins: json['gins'] ?? 1,
      bina: json['bina']?.toString() ?? '',
      zal: json['zal']?.toString() ?? '',
      mertebe: json['mertebe']?.toString() ?? '',
      sira: json['sira']?.toString() ?? '',
      yer: json['yer']?.toString() ?? '',
      imtTarix: json['imt_Tarix'] ?? '',
      photo: json['photo'] ?? '',
      qeydiyyat: json['qeydiyyat'] ?? '',
      online: (json['online'] == 1 || json['online'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_N': isN,
      'soy': soy,
      'adi': adi,
      'baba': baba,
      'gins': gins,
      'bina': bina,
      'zal': zal,
      'mertebe': mertebe,
      'sira': sira,
      'yer': yer,
      'imt_Tarix': imtTarix,
      'photo': photo,
      'qeydiyyat': qeydiyyat,
      'online': online ? 1 : 0,
    };
  }

  String get fullName => '$soy $adi $baba'.trim();
  String get genderText => gins == 1 ? 'Kişi' : 'Qadın';
}
