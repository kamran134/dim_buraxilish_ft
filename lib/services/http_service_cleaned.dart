import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../models/participant_models.dart';
import '../models/supervisor_models.dart';
import '../models/monitor_models.dart';
import '../utils/date_formatter.dart';
import 'database_service.dart';

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
      return null;
    }
  }

  // Store JWT token
  Future<void> storeToken(AccessTokenModel token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(jwtTokenKey, jsonEncode(token.toJson()));
    } catch (error) {
      // Silently handle error
    }
  }

  // Remove JWT token
  Future<void> removeToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(jwtTokenKey);
      await prefs.remove(authKey);
    } catch (error) {
      // Silently handle error
    }
  }

  // Store auth status
  Future<void> storeAuth(bool isAuthenticated) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(authKey, isAuthenticated);
    } catch (error) {
      // Silently handle error
    }
  }

  // Get auth status
  Future<bool> getAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(authKey) ?? false;
    } catch (error) {
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

      // Проверяем структуру ответа как в React Native
      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['success'] == true && data['data'] != null) {
          return ExamDates.fromJson(data);
        } else {
          return ExamDates(
            data: [],
            success: false,
            message: data?['message'] ??
                'İmtahan tarixlərini əldə etmək mümkün olmadı!',
          );
        }
      } else {
        return ExamDates(
          data: [],
          success: false,
          message: 'İmtahan tarixlərini əldə etmək mümkün olmadı!',
        );
      }
    } on DioException catch (e) {
      return ExamDates(
        data: [],
        success: false,
        message: e.response?.data?['message'] ?? 'İnternet bağlantı yoxdur!',
      );
    } catch (e) {
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
      final response = await _dio.get(
        '/buraxilishes/checkjobnoatbinaandexamdate',
        queryParameters: {
          'jobNo': jobNo,
          'bina': building,
          'examDate': examDate,
        },
      );

      if (response.statusCode == 200) {
        final participantResponse = ParticipantResponse.fromJson(response.data);
        return participantResponse;
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
      final response = await _dio.get(
        '/buraxilishes/getexamdetailsinexamdate',
        queryParameters: {
          'bina': bina,
          'examDate': examDate,
        },
      );

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
      return null;
    }
  }

  // Store exam details
  Future<void> storeExamDetails(ExamDetails examDetails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('exam_details', jsonEncode(examDetails.toJson()));
    } catch (error) {
      // Silently handle error
    }
  }

  // Offline participant methods
  Future<Participant?> getParticipantFromOfflineDB(int workNumber) async {
    try {
      return await DatabaseService.getParticipantByWorkNumber(workNumber);
    } catch (e) {
      return null;
    }
  }

  Future<void> registerParticipantOffline(int workNumber) async {
    try {
      final participant =
          await DatabaseService.getParticipantByWorkNumber(workNumber);
      if (participant != null) {
        final now = DateTime.now().toIso8601String();
        await DatabaseService.registerParticipant(participant, now);
      }
    } catch (e) {
      // Silently handle error
    }
  }

  /// Get all registered participants from database
  Future<List<Participant>> getRegisteredParticipants() async {
    try {
      return await DatabaseService.getRegisteredParticipants();
    } catch (e) {
      return [];
    }
  }

  /// Save participants to offline database
  Future<void> saveParticipantsOffline(List<Participant> participants) async {
    try {
      await DatabaseService.saveParticipants(participants);
    } catch (e) {
      // Silently handle error
    }
  }

  /// Check if offline database has data
  Future<bool> hasOfflineData() async {
    try {
      return await DatabaseService.hasOfflineData();
    } catch (e) {
      return false;
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (error) {
      // Silently handle error
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

      final response = await _dio.get(
        '/supervisors/checksupervisor',
        queryParameters: {
          'cardNumber': cardNumber,
          'buildingCode': buildingCode,
          'examDate': formattedDate,
        },
      );

      if (response.statusCode == 200) {
        return SupervisorResponse.fromJson(response.data);
      } else {
        return SupervisorResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        try {
          return SupervisorResponse.fromJson(e.response!.data);
        } catch (parseError) {
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
      final supervisor =
          await DatabaseService.getSupervisorByCardNumber(cardNumber);

      if (supervisor != null) {
        return SupervisorResponse(
          success: true,
          message: 'Nəzarətçi tapıldı',
          data: supervisor,
        );
      } else {
        return SupervisorResponse(
          success: false,
          message: 'Nəzarətçi tapılmadı',
        );
      }
    } catch (error) {
      return SupervisorResponse(
        success: false,
        message: 'Lokal bazadan məlumat oxunarkən xəta baş verdi',
      );
    }
  }

  /// Register supervisor offline
  Future<void> registerSupervisorOffline(String cardNumber) async {
    try {
      final supervisor =
          await DatabaseService.getSupervisorByCardNumber(cardNumber);
      if (supervisor != null) {
        final now = DateTime.now().toIso8601String();
        await DatabaseService.registerSupervisor(supervisor, now);
      }
    } catch (e) {
      // Silently handle error
    }
  }

  /// Get all registered supervisors from database
  Future<List<Supervisor>> getRegisteredSupervisors() async {
    try {
      return await DatabaseService.getRegisteredSupervisors();
    } catch (e) {
      return [];
    }
  }

  /// Save supervisors to offline database
  Future<void> saveSupervisorsOffline(List<Supervisor> supervisors) async {
    try {
      await DatabaseService.saveSupervisors(supervisors);
    } catch (e) {
      // Silently handle error
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

      final response = await _dio.get(
        '/supervisors/GetExamDetailsInExamDate',
        queryParameters: {
          'buildingCode': buildingCode,
          'examDate': formattedDate,
        },
      );

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
      return null;
    }
  }

  /// Store supervisor details/statistics
  Future<void> storeSupervisorDetails(SupervisorDetails details) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supervisor_details', jsonEncode(details.toJson()));
    } catch (error) {
      // Silently handle error
    }
  }

  /// Get all participants by building and exam date (for offline download)
  Future<List<Participant>> getParticipantsByBuilding({
    required String buildingCode,
    required String examDate,
  }) async {
    try {
      final response = await _dio.get(
        '/buraxilishes/GetAllParticipantInBuildingAndExamDate',
        queryParameters: {
          'bina': buildingCode,
          'examDate': examDate, // Use original date format like React Native
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Participant.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get all supervisors by building and exam date (for offline download)
  Future<List<Supervisor>> getSupervisorsByBuilding({
    required String buildingCode,
    required String examDate,
  }) async {
    try {
      // For supervisors, React Native FORMATS the date using dateToAzToDate
      final formattedDate = _formatExamDateForApi(examDate);

      final response = await _dio.get(
        '/supervisors/GetAllSupervisorDetailDtoInExamDateAndBuilding',
        queryParameters: {
          'buildingCode': buildingCode,
          'examDate': formattedDate, // Use formatted date like React Native
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Supervisor.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Convert exam date from Azerbaijani format to API format
  String _formatExamDateForApi(String examDate) {
    try {
      // Example: "29 sentyabr 2025-ci il" -> "09/29/2025"
      final monthsMap = {
        'yanvar': '01',
        'fevral': '02',
        'mart': '03',
        'aprel': '04',
        'may': '05',
        'iyun': '06',
        'iyul': '07',
        'avqust': '08',
        'sentyabr': '09',
        'oktyabr': '10',
        'noyabr': '11',
        'dekabr': '12'
      };

      final parts = examDate.toLowerCase().split(' ');
      if (parts.length >= 3) {
        final day = parts[0].padLeft(2, '0');
        final month = monthsMap[parts[1]] ?? '01';
        final year = parts[2].replaceAll(RegExp(r'[^\d]'), '');

        return '$month/$day/$year';
      }

      return examDate;
    } catch (e) {
      return examDate;
    }
  }

  // =========== SYNC METHODS ===========

  /// Sync registered participants to server
  Future<ResponseModel> syncParticipants(List<Participant> participants) async {
    try {
      // Convert to short format like React Native
      final participantsData = participants
          .map((p) => {
                'is_N': p.isN,
                'bina': p.bina,
                'imt_Tarix': p.imtTarix,
                'qeydiyyat': p.qeydiyyat ?? '',
              })
          .toList();

      final response = await _dio.post(
        '/buraxilishes/syncburaxilish',
        data: participantsData,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ResponseModel(
          success: true,
          message: 'İştirakçılar uğurla sinxronizasiya edildi',
        );
      } else {
        return ResponseModel(
          success: false,
          message: response.data['message'] ??
              'Sinxronizasiya zamanı xəta baş verdi',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return ResponseModel(
          success: false,
          message: 'Avtorizasiya vaxtı bitib. Yenidən daxil olun!',
        );
      } else {
        return ResponseModel(
          success: false,
          message: 'Sinxronizasiyada xəta. İnternetə qoşulmanı yoxlayın',
        );
      }
    } catch (e) {
      return ResponseModel(
        success: false,
        message: 'İştirakçıları sinxronizasiya etməkdə xəta baş verdi',
      );
    }
  }

  /// Sync registered supervisors to server
  Future<ResponseModel> syncSupervisors(List<Supervisor> supervisors) async {
    try {
      // Convert to short format like React Native
      final supervisorsData = supervisors
          .map((s) => {
                'cardNumber': s.cardNumber,
                'buildingCode': s.buildingCode,
                'examDate': s.examDate,
                'registerDate': s.registerDate,
              })
          .toList();

      final response = await _dio.post(
        '/supervisors/syncsupervisors',
        data: supervisorsData,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ResponseModel(
          success: true,
          message: 'Nəzarətçilər uğurla sinxronizasiya edildi',
        );
      } else {
        return ResponseModel(
          success: false,
          message: response.data['message'] ??
              'Sinxronizasiya zamanı xəta baş verdi',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return ResponseModel(
          success: false,
          message: 'Avtorizasiya vaxtı bitib. Yenidən daxil olun!',
        );
      } else {
        return ResponseModel(
          success: false,
          message: 'Nəzarətçilərdə sinxronizasiya getmədi. Məlumatlarda xəta',
        );
      }
    } catch (e) {
      return ResponseModel(
        success: false,
        message: 'Nəzarətçiləri sinxronizasiya etməkdə xəta baş verdi',
      );
    }
  }

  /// Cancel participant registration (set Qeydiyyat to null)
  Future<ResponseModel> cancelParticipantRegistration({
    required int isN,
    required String bina,
    required String examDate,
  }) async {
    try {
      // Convert date format from "29 sentyabr 2025-ci il" to "09/29/2025"
      final formattedDate = DateFormatter.dateToAzToDate(examDate);

      final response = await _dio.post(
        '/buraxilishes/cancelregistration',
        queryParameters: {
          'isN': isN,
          'bina': bina,
          'examDate': formattedDate,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ResponseModel(
          success: true,
          message: response.data['message'] ?? 'Qeydiyyat ləğv edildi',
        );
      } else {
        return ResponseModel(
          success: false,
          message:
              response.data['message'] ?? 'Qeydiyyatı ləğv etmək mümkün olmadı',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        // Handle BadRequest (400) from backend
        if (e.response!.data != null && e.response!.data is Map) {
          return ResponseModel(
            success: false,
            message: e.response!.data['message'] ??
                'Qeydiyyatı ləğv etmək mümkün olmadı',
          );
        }
        return ResponseModel(
          success: false,
          message: 'Qeydiyyatı ləğv etmək mümkün olmadı',
        );
      }
      return ResponseModel(
        success: false,
        message: 'Şəbəkə xətası. İnternet bağlantınızı yoxlayın.',
      );
    } catch (e) {
      return ResponseModel(
        success: false,
        message: 'Xəta baş verdi',
      );
    }
  }

  /// Cancel supervisor registration (set RegisterDate to null)
  Future<ResponseModel> cancelSupervisorRegistration({
    required String cardNumber,
    required int buildingCode,
    required String examDate,
  }) async {
    try {
      // Convert date format from "29 sentyabr 2025-ci il" to "09/29/2025"
      final formattedDate = DateFormatter.dateToAzToDate(examDate);

      final response = await _dio.post(
        '/supervisors/cancelregistration',
        queryParameters: {
          'cardNumber': cardNumber,
          'buildingCode': buildingCode,
          'examDate': formattedDate,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ResponseModel(
          success: true,
          message: response.data['message'] ?? 'Qeydiyyat ləğv edildi',
        );
      } else {
        return ResponseModel(
          success: false,
          message:
              response.data['message'] ?? 'Qeydiyyatı ləğv etmək mümkün olmadı',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        // Handle BadRequest (400) from backend
        if (e.response!.data != null && e.response!.data is Map) {
          return ResponseModel(
            success: false,
            message: e.response!.data['message'] ??
                'Qeydiyyatı ləğv etmək mümkün olmadı',
          );
        }
        return ResponseModel(
          success: false,
          message: 'Qeydiyyatı ləğv etmək mümkün olmadı',
        );
      }
      return ResponseModel(
        success: false,
        message: 'Şəbəkə xətası. İnternet bağlantınızı yoxlayın.',
      );
    } catch (e) {
      return ResponseModel(
        success: false,
        message: 'Xəta baş verdi',
      );
    }
  }

  // =========== MONITOR METHODS ===========

  /// Scan monitor (İmtahan rəhbəri) by work number
  Future<MonitorResponse> scanMonitor({
    required String workNumber,
    required String examDate,
  }) async {
    try {
      // Convert date format from "29 sentyabr 2025-ci il" to "09/29/2025"
      final formattedDate = DateFormatter.dateToAzToDate(examDate);

      final response = await _dio.get(
        '/monitors/checkmonitor',
        queryParameters: {
          'workNumber': workNumber,
          'examDate': formattedDate,
        },
      );

      if (response.statusCode == 200) {
        return MonitorResponse.fromJson(response.data);
      } else {
        return MonitorResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        try {
          return MonitorResponse.fromJson(e.response!.data);
        } catch (parseError) {
          return MonitorResponse(
            success: false,
            message: 'İmtahan rəhbəri məlumatları oxunarkən xəta baş verdi',
          );
        }
      } else {
        return MonitorResponse(
          success: false,
          message: 'Şəbəkə xətası. İnternet bağlantınızı yoxlayın.',
        );
      }
    } catch (error) {
      return MonitorResponse(
        success: false,
        message: 'Gözlənilməz xəta baş verdi',
      );
    }
  }

  /// Cancel monitor registration (set RegisterDate to null)
  Future<ResponseModel> cancelMonitorRegistration({
    required int workNumber,
    required int buildingCode,
    required String examDate,
  }) async {
    try {
      // Convert date format from "29 sentyabr 2025-ci il" to "09/29/2025"
      final formattedDate = DateFormatter.dateToAzToDate(examDate);

      final response = await _dio.post(
        '/monitors/cancelregistration',
        queryParameters: {
          'workNumber': workNumber,
          'buildingCode': buildingCode,
          'examDate': formattedDate,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ResponseModel(
          success: true,
          message: response.data['message'] ?? 'Qeydiyyat ləğv edildi',
        );
      } else {
        return ResponseModel(
          success: false,
          message:
              response.data['message'] ?? 'Qeydiyyatı ləğv etmək mümkün olmadı',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        // Handle BadRequest (400) from backend
        if (e.response!.data != null && e.response!.data is Map) {
          return ResponseModel(
            success: false,
            message: e.response!.data['message'] ??
                'Qeydiyyatı ləğv etmək mümkün olmadı',
          );
        }
        return ResponseModel(
          success: false,
          message: 'Qeydiyyatı ləğv etmək mümkün olmadı',
        );
      }
      return ResponseModel(
        success: false,
        message: 'Şəbəkə xətası. İnternet bağlantınızı yoxlayın.',
      );
    } catch (e) {
      return ResponseModel(
        success: false,
        message: 'Xəta baş verdi',
      );
    }
  }
}
