import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../models/participant_models.dart';
import '../models/supervisor_models.dart';
import '../utils/date_formatter.dart';

class HttpService {
  static const String baseUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/api';
  static const String jwtTokenKey = 'jwt_token';
  static const String authKey = 'auth';

  late final Dio _dio;

  HttpService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptor for JWT token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await removeToken();
        }
        handler.next(error);
      },
    ));
  }

  // Get stored JWT token
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenData = prefs.getString(jwtTokenKey);

      if (tokenData != null) {
        final tokenJson = jsonDecode(tokenData) as Map<String, dynamic>;
        final token = AccessTokenModel.fromJson(tokenJson);

        if (!token.isExpired) {
          return token.token;
        } else {
          // Token expired, remove it
          await removeToken();
          return null;
        }
      }
      return null;
    } catch (error) {
      print('Error getting token: $error');
      return null;
    }
  }

  // Store JWT token
  Future<void> storeToken(AccessTokenModel token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(jwtTokenKey, jsonEncode(token.toJson()));
    } catch (error) {
      print('Error storing token: $error');
    }
  }

  // Remove JWT token
  Future<void> removeToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(jwtTokenKey);
      await prefs.remove(authKey);
    } catch (error) {
      print('Error removing token: $error');
    }
  }

  // Store auth status
  Future<void> storeAuth(bool isAuthenticated) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(authKey, isAuthenticated);
    } catch (error) {
      print('Error storing auth: $error');
    }
  }

  // Get auth status
  Future<bool> getAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(authKey) ?? false;
    } catch (error) {
      print('Error getting auth: $error');
      return false;
    }
  }

  // Login request (no token needed)
  Future<LoginResponse> login(
      String userName, String password, String examDate) async {
    try {
      final loginData = LoginModel(
        userName: userName,
        password: password,
        examDate: examDate,
      );

      final response = await _dio.post(
        '/auth/login',
        data: loginData.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      return LoginResponse.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        final errorData = e.response!.data as Map<String, dynamic>? ?? {};
        return LoginResponse(
          data: AccessTokenModel(token: '', expiration: ''),
          success: false,
          message: errorData['message'] ?? 'Giriş məlumatları səhvdir!',
        );
      } else {
        return LoginResponse(
          data: AccessTokenModel(token: '', expiration: ''),
          success: false,
          message: 'Əlaqə xətası baş verdi',
        );
      }
    }
  }

  // Get exam dates
  Future<ExamDates> getExamDates() async {
    try {
      final response = await _dio.get('/buraxilishes/getallexamdate');
      print('getExamDates response: ${response.data}'); // Добавляем логирование

      // Проверяем структуру ответа как в React Native
      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['success'] == true && data['data'] != null) {
          return ExamDates.fromJson(data);
        } else {
          print('Invalid response structure: $data');
          return ExamDates(
            data: [],
            success: false,
            message: data?['message'] ??
                'İmtahan tarixlərini əldə etmək mümkün olmadı!',
          );
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return ExamDates(
          data: [],
          success: false,
          message: 'İmtahan tarixlərini əldə etmək mümkün olmadı!',
        );
      }
    } on DioException catch (e) {
      print('DioException: ${e.message}');
      print('Response data: ${e.response?.data}');
      return ExamDates(
        data: [],
        success: false,
        message: e.response?.data?['message'] ?? 'İnternet bağlantı yoxdur!',
      );
    } catch (e) {
      print('General error: $e');
      return ExamDates(
        data: [],
        success: false,
        message: 'İmtahan tarixlərini əldə etmək mümkün olmadı!',
      );
    }
  }

  // Change password request (requires authentication)
  Future<ResponseModel> changePassword(
      ChangePasswordModel changePasswordData) async {
    try {
      final response = await _dio.post(
        '/password/changepassword',
        data: changePasswordData.toJson(),
      );

      return ResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      final errorData = e.response?.data as Map<String, dynamic>? ?? {};
      return ResponseModel(
        success: false,
        message: errorData['message'] ?? 'Parol dəyişdirilərkən xəta baş verdi',
      );
    }
  }

  // TParol endpoints (require authentication)
  Future<Response> getAllTParols() async {
    return await _dio.get('/tparols/getall');
  }

  Future<Response> getTParolByBina(int bina) async {
    return await _dio.get('/tparols/getbybina?bina=$bina');
  }

  Future<Response> getAllBuildingInExamDate(String examDate) async {
    return await _dio
        .get('/tparols/getallbuildinginexamdate?examDate=$examDate');
  }

  // SupervisorBuilding endpoints (require authentication)
  Future<Response> getAllSupervisorBuildings() async {
    return await _dio.get('/supervisorbuildings/getall');
  }

  Future<Response> getSupervisorBuildingByCode(int buildingCode) async {
    return await _dio.get(
        '/supervisorbuildings/getbybuildingcode?buildingCode=$buildingCode');
  }

  Future<Response> addSupervisorBuilding(
      Map<String, dynamic> supervisorBuilding) async {
    return await _dio.post('/supervisorbuildings/add',
        data: supervisorBuilding);
  }

  Future<Response> updateSupervisorBuilding(
      Map<String, dynamic> supervisorBuilding) async {
    return await _dio.post('/supervisorbuildings/update',
        data: supervisorBuilding);
  }

  Future<Response> deleteSupervisorBuilding(
      Map<String, dynamic> supervisorBuilding) async {
    return await _dio.post('/supervisorbuildings/delete',
        data: supervisorBuilding);
  }

  // Participant scanning methods

  // Scan participant online (from React Native: checkjobnoatbinaandexamdate)
  Future<ParticipantResponse> scanParticipant({
    required String jobNo,
    required String building,
    required String examDate,
  }) async {
    try {
      print(
          'Scanning participant: jobNo=$jobNo, building=$building, examDate=$examDate');

      final response = await _dio.get(
        '/buraxilishes/checkjobnoatbinaandexamdate',
        queryParameters: {
          'jobNo': jobNo,
          'bina': building,
          'examDate': examDate,
        },
      );

      if (response.statusCode == 200) {
        return ParticipantResponse.fromJson(response.data);
      } else {
        return ParticipantResponse(
          success: false,
          message: 'İştiraki tapılmadı',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return ParticipantResponse(
          success: false,
          message: 'Axtarılan şəxs tapılmadı!',
        );
      } else if (e.response?.statusCode == 401) {
        return ParticipantResponse(
          success: false,
          message: 'Avtorizasiya vaxtı bitib. Yenidən daxil olun!',
        );
      } else {
        return ParticipantResponse(
          success: false,
          message: 'İnternet bağlantı yoxdur!',
        );
      }
    } catch (e) {
      print('Error scanning participant: $e');
      return ParticipantResponse(
        success: false,
        message: 'Skan zamanı xəta baş verdi',
      );
    }
  }

  /// Get exam details/statistics from API
  Future<ExamDetails?> getExamDetails({
    required int bina,
    required String examDate,
  }) async {
    try {
      print('Getting exam details: bina=$bina, examDate=$examDate');

      final response = await _dio.get(
        '/buraxilishes/getexamdetailsinexamdate',
        queryParameters: {
          'bina': bina,
          'examDate': examDate,
        },
      );

      print('Exam details response status: ${response.statusCode}');
      print('Exam details response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null) {
          final details = ExamDetails.fromJson(data);
          // Store in local storage
          await storeExamDetails(details);
          return details;
        }
      }

      return null;
    } catch (e) {
      print('Error getting exam details: $e');
      return null;
    }
  }

  // Get exam details from storage
  Future<ExamDetails?> getExamDetailsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final examDetailsJson = prefs.getString('exam_details');

      if (examDetailsJson != null) {
        final examDetailsData =
            jsonDecode(examDetailsJson) as Map<String, dynamic>;
        return ExamDetails.fromJson(examDetailsData);
      }
      return null;
    } catch (error) {
      print('Error getting exam details from storage: $error');
      return null;
    }
  }

  // Store exam details
  Future<void> storeExamDetails(ExamDetails examDetails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('exam_details', jsonEncode(examDetails.toJson()));
    } catch (error) {
      print('Error storing exam details: $error');
    }
  }

  // Offline participant methods (placeholder - would need SQLite integration)
  Future<Participant?> getParticipantFromOfflineDB(int workNumber) async {
    try {
      // TODO: Implement SQLite query
      // This would query: SELECT * FROM enrollees WHERE is_N = $workNumber
      print('Searching participant offline: $workNumber');

      // For now, return null to indicate offline DB is not implemented
      return null;
    } catch (e) {
      print('Error getting participant from offline DB: $e');
      return null;
    }
  }

  Future<void> registerParticipantOffline(int workNumber) async {
    try {
      // TODO: Implement SQLite update
      // This would update: UPDATE registered_enrollees SET qeydiyyat = ? WHERE is_N = ?
      print('Registering participant offline: $workNumber');
    } catch (e) {
      print('Error registering participant offline: $e');
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (error) {
      print('Error clearing data: $error');
    }
  }

  // =========== SUPERVISOR METHODS ===========

  /// Scan supervisor QR code and get supervisor info (online mode)
  Future<SupervisorResponse> scanSupervisor({
    required String cardNumber,
    required int buildingCode,
    required String examDate,
  }) async {
    try {
      // Convert date format from "29 sentyabr 2025-ci il" to "09/29/2025"
      final formattedDate = DateFormatter.dateToAzToDate(examDate);

      print(
          'Scanning supervisor: cardNumber=$cardNumber, buildingCode=$buildingCode, examDate=$examDate -> $formattedDate');

      final response = await _dio.get(
        '/supervisors/checksupervisor',
        queryParameters: {
          'cardNumber': cardNumber,
          'buildingCode': buildingCode,
          'examDate': formattedDate,
        },
      );

      print('Supervisor scan response status: ${response.statusCode}');
      print('Supervisor scan response data: ${response.data}');

      if (response.statusCode == 200) {
        return SupervisorResponse.fromJson(response.data);
      } else {
        return SupervisorResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('Dio error scanning supervisor: $e');
      if (e.response != null) {
        print('Error response data: ${e.response!.data}');
        try {
          return SupervisorResponse.fromJson(e.response!.data);
        } catch (parseError) {
          print('Error parsing error response: $parseError');
          return SupervisorResponse(
            success: false,
            message: 'Nəzarətçi məlumatları oxunarkən xəta baş verdi',
          );
        }
      } else {
        return SupervisorResponse(
          success: false,
          message: 'Şəbəkə xətası. İnternet bağlantınızı yoxlayın.',
        );
      }
    } catch (error) {
      print('General error scanning supervisor: $error');
      return SupervisorResponse(
        success: false,
        message: 'Gözlənilməz xəta baş verdi',
      );
    }
  }

  /// Get supervisor from offline database
  Future<SupervisorResponse> getSupervisorFromOfflineDB(
      String cardNumber) async {
    try {
      print('Getting supervisor from offline DB: $cardNumber');

      // For now, return a mock response indicating offline mode is not implemented
      // In React Native, this would query the local SQLite database
      return SupervisorResponse(
        success: false,
        message: 'Oflayn rejim hələ hazırda əlçatan deyil',
      );
    } catch (error) {
      print('Error getting supervisor from offline DB: $error');
      return SupervisorResponse(
        success: false,
        message: 'Lokal bazadan məlumat oxunarkən xəta baş verdi',
      );
    }
  }

  /// Get supervisor details/statistics from API
  Future<SupervisorDetails?> getSupervisorDetails({
    required int buildingCode,
    required String examDate,
  }) async {
    try {
      // Convert date format from "29 sentyabr 2025-ci il" to "09/29/2025"
      final formattedDate = DateFormatter.dateToAzToDate(examDate);

      print(
          'Getting supervisor details: buildingCode=$buildingCode, examDate=$examDate -> $formattedDate');

      final response = await _dio.get(
        '/supervisors/GetExamDetailsInExamDate',
        queryParameters: {
          'buildingCode': buildingCode,
          'examDate': formattedDate,
        },
      );

      print('Supervisor details response status: ${response.statusCode}');
      print('Supervisor details response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data != null) {
          final details = SupervisorDetails.fromJson(data);
          // Store in local storage
          await storeSupervisorDetails(details);
          return details;
        }
      }

      return null;
    } catch (e) {
      print('Error getting supervisor details: $e');
      return null;
    }
  }

  /// Get supervisor details/statistics from storage
  Future<SupervisorDetails?> getSupervisorDetailsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final detailsData = prefs.getString('supervisor_details');

      if (detailsData != null) {
        final detailsJson = jsonDecode(detailsData) as Map<String, dynamic>;
        return SupervisorDetails.fromJson(detailsJson);
      }

      return null;
    } catch (error) {
      print('Error getting supervisor details from storage: $error');
      return null;
    }
  }

  /// Store supervisor details/statistics
  Future<void> storeSupervisorDetails(SupervisorDetails details) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supervisor_details', jsonEncode(details.toJson()));
    } catch (error) {
      print('Error storing supervisor details: $error');
    }
  }
}
