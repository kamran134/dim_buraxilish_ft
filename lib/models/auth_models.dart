import 'participant_models.dart';

class Auth {
  final int bina;
  final String examDate;

  Auth({
    required this.bina,
    required this.examDate,
  });

  factory Auth.fromJson(Map<String, dynamic> json) {
    return Auth(
      bina: json['bina'] as int,
      examDate: json['examDate'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bina': bina,
      'examDate': examDate,
    };
  }
}

class AuthData {
  final int bina;
  final String userName;
  final String userPassword;

  AuthData({
    required this.bina,
    required this.userName,
    required this.userPassword,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      bina: json['bina'] as int,
      userName: json['user_Name'] as String,
      userPassword: json['user_Parol'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bina': bina,
      'user_Name': userName,
      'user_Parol': userPassword,
    };
  }
}

class ExamDates {
  final List<String> data;
  final bool success;
  final String message;

  ExamDates({
    required this.data,
    required this.success,
    required this.message,
  });

  factory ExamDates.fromJson(Map<String, dynamic> json) {
    return ExamDates(
      data: List<String>.from(json['data'] as List),
      success: json['success'] as bool,
      message: (json['message'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'success': success,
      'message': message,
    };
  }
}

class LoginModel {
  final String userName;
  final String password;
  final String examDate;

  LoginModel({
    required this.userName,
    required this.password,
    required this.examDate,
  });

  factory LoginModel.fromJson(Map<String, dynamic> json) {
    return LoginModel(
      userName: json['userName'] as String,
      password: json['password'] as String,
      examDate: json['examDate'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      'password': password,
      'examDate': examDate,
    };
  }
}

class AccessTokenModel {
  final String token;
  final String expiration;
  final String? role;

  AccessTokenModel({
    required this.token,
    required this.expiration,
    this.role,
  });

  factory AccessTokenModel.fromJson(Map<String, dynamic> json) {
    return AccessTokenModel(
      token: json['token'] as String,
      expiration: json['expiration'] as String,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'expiration': expiration,
      if (role != null) 'role': role,
    };
  }

  bool get isExpired {
    try {
      final expirationDate = DateTime.parse(expiration);
      return DateTime.now().isAfter(expirationDate);
    } catch (e) {
      return true;
    }
  }
}

class ResponseModel {
  final bool success;
  final String message;

  ResponseModel({
    required this.success,
    required this.message,
  });

  factory ResponseModel.fromJson(Map<String, dynamic> json) {
    return ResponseModel(
      success: json['success'] as bool,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
    };
  }
}

class LoginResponse extends ResponseModel {
  final AccessTokenModel data;
  final String? token;
  final UserProfile? user;
  final ExamDetails? examDetails;

  LoginResponse({
    required this.data,
    required bool success,
    required String message,
    this.token,
    this.user,
    this.examDetails,
  }) : super(success: success, message: message);

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      data: AccessTokenModel.fromJson(json['data'] as Map<String, dynamic>),
      success: json['success'] as bool,
      message: json['message'] as String,
      token: json['token'] as String?,
      user: json['user'] != null
          ? UserProfile.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      examDetails: json['examDetails'] != null
          ? ExamDetails.fromJson(json['examDetails'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'data': data.toJson(),
      'success': success,
      'message': message,
      if (token != null) 'token': token,
      if (user != null) 'user': user!.toJson(),
      if (examDetails != null) 'examDetails': examDetails!.toJson(),
    };
  }
}

class ChangePasswordModel {
  final String userName;
  final String currentPassword;
  final String newPassword;

  ChangePasswordModel({
    required this.userName,
    required this.currentPassword,
    required this.newPassword,
  });

  factory ChangePasswordModel.fromJson(Map<String, dynamic> json) {
    return ChangePasswordModel(
      userName: json['userName'] as String,
      currentPassword: json['currentPassword'] as String,
      newPassword: json['newPassword'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };
  }
}

class UserProfile {
  final String userName;
  final String? fullName;
  final String? role;
  final int? bina;
  final String? examDate;

  UserProfile({
    required this.userName,
    this.fullName,
    this.role,
    this.bina,
    this.examDate,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userName: json['userName'] as String,
      fullName: json['fullName'] as String?,
      role: json['role'] as String?,
      bina: json['bina'] as int?,
      examDate: json['examDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      if (fullName != null) 'fullName': fullName,
      if (role != null) 'role': role,
      if (bina != null) 'bina': bina,
      if (examDate != null) 'examDate': examDate,
    };
  }
}
