import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_models.dart';
import 'device_identity_service.dart';
import '../models/participant_models.dart';
import '../models/supervisor_models.dart';
import '../models/monitor_models.dart';
import '../models/violator_models.dart';
import '../models/exam_models.dart';
import '../utils/date_formatter.dart';
import 'database_service.dart';

class HttpService {
  static const String baseUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/api';
  static const String jwtTokenKey = 'jwt_token';
  static const String authKey = 'auth';

  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Separate client (no auth interceptor) used only for /auth/refresh calls,
  // so refreshing the token never recurses back into getToken().
  static final Dio _plainDio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // Shared across all HttpService instances so concurrent 401s don't each
  // burn the single-use refresh token racing one another.
  static Future<AccessTokenModel?>? _refreshInFlight;

  HttpService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
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
        // Tell the server which slot (date+time) the request is for, once
        // one has been picked — see API_slots.md. The server filters legacy
        // endpoints by this header when present; without it (old clients)
        // they keep working off the `examDate` query parameter alone.
        final examDetails = await getExamDetailsFromStorage();
        final slotKey = examDetails?.slotKey;
        if (slotKey != null && slotKey.isNotEmpty) {
          options.headers['X-Exam-Slot'] = slotKey;
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

  // Get stored JWT token. If it has expired, transparently try to renew it
  // via the refresh token before giving up — otherwise a phone left logged
  // in past the access-token lifetime silently stops working (including FCM
  // token uploads, which is what caused emergency notifications to go dead).
  Future<String?> getToken() async {
    try {
      final tokenData = await _secureStorage.read(key: jwtTokenKey);

      if (tokenData != null) {
        final tokenJson = jsonDecode(tokenData) as Map<String, dynamic>;
        final token = AccessTokenModel.fromJson(tokenJson);

        if (!token.isExpired) {
          return token.token;
        }

        final refreshed = await _refreshAccessToken(token.refreshToken);
        if (refreshed != null) return refreshed.token;

        await removeToken();
        return null;
      }
      return null;
    } catch (error) {
      if (kDebugMode) print('Error getting token: $error');
      return null;
    }
  }

  Future<AccessTokenModel?> _refreshAccessToken(String? refreshToken) {
    if (refreshToken == null || refreshToken.isEmpty) {
      return Future.value(null);
    }
    return _refreshInFlight ??=
        _performRefresh(refreshToken).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<AccessTokenModel?> _performRefresh(String refreshToken) async {
    try {
      final deviceId = await DeviceIdentityService.instance.getDeviceId();
      final response = await _plainDio.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
        'deviceId': deviceId,
      });

      final body = response.data;
      if (body is Map && body['success'] == true && body['data'] != null) {
        final newToken =
            AccessTokenModel.fromJson(body['data'] as Map<String, dynamic>);
        await storeToken(newToken);
        return newToken;
      }
    } catch (error) {
      if (kDebugMode) print('Token refresh failed: $error');
    }
    return null;
  }

  // Get full stored AccessToken model
  Future<AccessTokenModel?> getStoredAccessToken() async {
    try {
      final tokenData = await _secureStorage.read(key: jwtTokenKey);
      if (tokenData != null) {
        return AccessTokenModel.fromJson(
            jsonDecode(tokenData) as Map<String, dynamic>);
      }
      return null;
    } catch (error) {
      return null;
    }
  }

  // Store JWT token
  Future<void> storeToken(AccessTokenModel token) async {
    try {
      await _secureStorage.write(
          key: jwtTokenKey, value: jsonEncode(token.toJson()));
    } catch (error) {
      if (kDebugMode) print('Error storing token: $error');
    }
  }

  // Remove JWT token
  Future<void> removeToken() async {
    try {
      await _secureStorage.delete(key: jwtTokenKey);
      await _secureStorage.delete(key: authKey);
    } catch (error) {
      if (kDebugMode) print('Error removing token: $error');
    }
  }

  // Store auth status
  Future<void> storeAuth(bool isAuthenticated) async {
    try {
      await _secureStorage.write(
          key: authKey, value: isAuthenticated.toString());
    } catch (error) {
      if (kDebugMode) print('Error storing auth: $error');
    }
  }

  // Get auth status
  Future<bool> getAuth() async {
    try {
      final value = await _secureStorage.read(key: authKey);
      return value == 'true';
    } catch (error) {
      if (kDebugMode) print('Error getting auth: $error');
      return false;
    }
  }

  // Login request (no token needed). examDate is no longer part of login —
  // the exam is picked afterwards on a dedicated screen (see getExams()).
  Future<LoginResponse> login(String userName, String password) async {
    try {
      final loginData = LoginModel(
        userName: userName,
        password: password,
        deviceId: await DeviceIdentityService.instance.getDeviceId(),
        deviceName: await DeviceIdentityService.instance.getDeviceName(),
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

  /// Get published exams for the exam-select screen. Requires JWT (attached
  /// automatically by the request interceptor).
  Future<ExamsResponse> getExams() async {
    try {
      final response = await _dio.get('/exams');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] != null) {
          final List<dynamic> list = data['data'] as List;
          return ExamsResponse(
            success: true,
            message: data['message'] as String? ?? '',
            data: list
                .map((e) => ExamDto.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        }
        return ExamsResponse(
          success: false,
          message:
              (data is Map ? data['message'] as String? : null) ??
                  'İmtahanları əldə etmək mümkün olmadı!',
          data: [],
        );
      }
      return ExamsResponse(
        success: false,
        message: 'İmtahanları əldə etmək mümkün olmadı!',
        data: [],
      );
    } on DioException catch (e) {
      if (kDebugMode) print('getExams DioException: ${e.message}');
      final responseData = e.response?.data;
      return ExamsResponse(
        success: false,
        message: (responseData is Map ? responseData['message'] as String? : null) ??
            'İnternet bağlantı yoxdur!',
        data: [],
      );
    } catch (e) {
      if (kDebugMode) print('getExams general error: $e');
      return ExamsResponse(
        success: false,
        message: 'İmtahanları əldə etmək mümkün olmadı!',
        data: [],
      );
    }
  }

  /// Get slots for the exam-select screen. For role `monitor` the server
  /// returns only slots where the caller's building (JWT `bina` claim) has
  /// participants or supervisors. Requires JWT (attached automatically by
  /// the request interceptor). See API_slots.md.
  Future<SlotsResponse> getSlots() => _getSlots('/slots');

  /// Get ALL slots across all buildings — superadmin/admin only ("Vaxt
  /// üzrə" mode). See API_slots.md.
  Future<SlotsResponse> getAllSlots() => _getSlots('/slots/all');

  Future<SlotsResponse> _getSlots(String path) async {
    try {
      final response = await _dio.get(path);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true && data['data'] != null) {
          final List<dynamic> list = data['data'] as List;
          return SlotsResponse(
            success: true,
            message: data['message'] as String? ?? '',
            data: list
                .map((e) => SlotDto.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        }
        return SlotsResponse(
          success: false,
          message:
              (data is Map ? data['message'] as String? : null) ??
                  'Slotları əldə etmək mümkün olmadı!',
          data: [],
        );
      }
      return SlotsResponse(
        success: false,
        message: 'Slotları əldə etmək mümkün olmadı!',
        data: [],
      );
    } on DioException catch (e) {
      if (kDebugMode) print('getSlots DioException: ${e.message}');
      final responseData = e.response?.data;
      return SlotsResponse(
        success: false,
        message: (responseData is Map ? responseData['message'] as String? : null) ??
            'İnternet bağlantı yoxdur!',
        data: [],
      );
    } catch (e) {
      if (kDebugMode) print('getSlots general error: $e');
      return SlotsResponse(
        success: false,
        message: 'Slotları əldə etmək mümkün olmadı!',
        data: [],
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
        print('API response data: ${response.data}');
        final participantResponse = ParticipantResponse.fromJson(response.data);
        print('Parsed participant photo: "${participantResponse.data?.photo}"');
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
      } else if (e.response?.statusCode == 400) {
        return ParticipantResponse(
          success: false,
          message: 'Axtarılan şəxs haqqında məlumat tapılmadı',
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

  /// Get exam details/statistics from API.
  /// [persist] controls whether the result is written to secure storage.
  /// Pass false for periodic stats polling to avoid unnecessary storage writes.
  Future<ExamDetails?> getExamDetails({
    required int bina,
    required String examDate,
    bool persist = true,
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
          // Store in local storage (skipped for periodic stats polling)
          if (persist) await storeExamDetails(details);
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
      final examDetailsJson = await _secureStorage.read(key: 'exam_details');

      if (examDetailsJson != null) {
        final examDetailsData =
            jsonDecode(examDetailsJson) as Map<String, dynamic>;
        return ExamDetails.fromJson(examDetailsData);
      }
      return null;
    } catch (error) {
      if (kDebugMode) print('Error getting exam details from storage: $error');
      return null;
    }
  }

  // Store exam details
  Future<void> storeExamDetails(ExamDetails examDetails) async {
    try {
      await _secureStorage.write(
          key: 'exam_details', value: jsonEncode(examDetails.toJson()));
    } catch (error) {
      if (kDebugMode) print('Error storing exam details: $error');
    }
  }

  // Offline participant methods
  Future<Participant?> getParticipantFromOfflineDB(int workNumber) async {
    try {
      print('Searching participant offline: $workNumber');
      return await DatabaseService.getParticipantByWorkNumber(workNumber);
    } catch (e) {
      print('Error getting participant from offline DB: $e');
      return null;
    }
  }

  Future<void> registerParticipantOffline(int workNumber) async {
    final participant =
        await DatabaseService.getParticipantByWorkNumber(workNumber);
    if (participant != null) {
      final now = DateTime.now().toIso8601String();
      await DatabaseService.registerParticipant(participant, now);
    }
  }

  /// Get all registered participants from database
  Future<List<Participant>> getRegisteredParticipants() async {
    try {
      return await DatabaseService.getRegisteredParticipants();
    } catch (e) {
      print('Error getting registered participants: $e');
      return [];
    }
  }

  /// Save participants to offline database
  Future<void> saveParticipantsOffline(List<Participant> participants) async {
    try {
      await DatabaseService.saveParticipants(participants);
      print('Saved ${participants.length} participants to offline database');
    } catch (e) {
      print('Error saving participants offline: $e');
    }
  }

  /// Check if offline database has data
  Future<bool> hasOfflineData() async {
    try {
      return await DatabaseService.hasOfflineData();
    } catch (e) {
      print('Error checking offline data: $e');
      return false;
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: jwtTokenKey),
        _secureStorage.delete(key: authKey),
        _secureStorage.delete(key: 'exam_details'),
        _secureStorage.delete(key: 'supervisor_details'),
      ]);
    } catch (error) {
      if (kDebugMode) print('Error clearing data: $error');
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
      final formattedDate = DateFormatter.dateToAzToDateWithSession(examDate);

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
      if (e.response?.statusCode == 400) {
        return SupervisorResponse(
          success: false,
          message: 'Axtarılan şəxs haqqında məlumat tapılmadı',
        );
      } else if (e.response != null) {
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
      print('Error getting supervisor from offline DB: $error');
      return SupervisorResponse(
        success: false,
        message: 'Lokal bazadan məlumat oxunarkən xəta baş verdi',
      );
    }
  }

  /// Register supervisor offline
  Future<void> registerSupervisorOffline(String cardNumber) async {
    final supervisor =
        await DatabaseService.getSupervisorByCardNumber(cardNumber);
    if (supervisor != null) {
      final now = DateTime.now().toIso8601String();
      await DatabaseService.registerSupervisor(supervisor, now);
    }
  }

  /// Get all registered supervisors from database
  Future<List<Supervisor>> getRegisteredSupervisors() async {
    try {
      return await DatabaseService.getRegisteredSupervisors();
    } catch (e) {
      print('Error getting registered supervisors: $e');
      return [];
    }
  }

  /// Save supervisors to offline database
  Future<void> saveSupervisorsOffline(List<Supervisor> supervisors) async {
    try {
      await DatabaseService.saveSupervisors(supervisors);
      print('Saved ${supervisors.length} supervisors to offline database');
    } catch (e) {
      print('Error saving supervisors offline: $e');
    }
  }

  /// Get supervisor details/statistics from API.
  /// [persist] controls whether the result is written to secure storage.
  Future<SupervisorDetails?> getSupervisorDetails({
    required int buildingCode,
    required String examDate,
    bool persist = true,
  }) async {
    try {
      // Convert date format from "29 sentyabr 2025-ci il" to "09/29/2025"
      final formattedDate = DateFormatter.dateToAzToDateWithSession(examDate);

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
          // Store in local storage (skipped for periodic stats polling)
          if (persist) await storeSupervisorDetails(details);
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
      final detailsData = await _secureStorage.read(key: 'supervisor_details');

      if (detailsData != null) {
        final detailsJson = jsonDecode(detailsData) as Map<String, dynamic>;
        return SupervisorDetails.fromJson(detailsJson);
      }

      return null;
    } catch (error) {
      if (kDebugMode)
        print('Error getting supervisor details from storage: $error');
      return null;
    }
  }

  /// Store supervisor details/statistics
  Future<void> storeSupervisorDetails(SupervisorDetails details) async {
    try {
      await _secureStorage.write(
          key: 'supervisor_details', value: jsonEncode(details.toJson()));
    } catch (error) {
      if (kDebugMode) print('Error storing supervisor details: $error');
    }
  }

  /// Get all participants by building and exam date (for offline download)
  Future<List<Participant>> getParticipantsByBuilding({
    required String buildingCode,
    required String examDate,
  }) async {
    try {
      // DON'T FORMAT DATE - React Native sends original date string
      print('getParticipantsByBuilding - Original date: $examDate');
      print('getParticipantsByBuilding - Building code: $buildingCode');
      print(
          'getParticipantsByBuilding - Making request to: /buraxilishes/GetAllParticipantInBuildingAndExamDate');

      final response = await _dio.get(
        '/buraxilishes/GetAllParticipantInBuildingAndExamDate',
        queryParameters: {
          'bina': buildingCode,
          'examDate': examDate, // Use original date format like React Native
        },
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );

      print(
          'getParticipantsByBuilding - Response status: ${response.statusCode}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        print(
            'getParticipantsByBuilding - Success! Found ${data.length} participants');
        return data.map((json) => Participant.fromJson(json)).toList();
      }

      print('getParticipantsByBuilding - No success or no data found');
      print(
          'getParticipantsByBuilding - Response success: ${response.data['success']}');
      return [];
    } catch (e) {
      print('Error getting participants by building: $e');
      return [];
    }
  }

  /// Get all participants by building and exam date, WITHOUT photos (for
  /// offline download). Same response fields as [getParticipantsByBuilding],
  /// just lighter — photos are downloaded separately in bulk via
  /// [downloadParticipantPhotos] and merged into SQLite afterwards.
  ///
  /// Unlike [getParticipantsByBuilding], errors are NOT swallowed here — they
  /// propagate to the caller (OfflineDatabaseProvider already wraps this call
  /// in its own try/catch that logs and flags the network error).
  Future<List<Participant>> getParticipantsLightByBuilding({
    required String buildingCode,
    required String examDate,
  }) async {
    // DON'T FORMAT DATE - same as getParticipantsByBuilding
    final response = await _dio.get(
      '/buraxilishes/getallparticipantlightinbuildingandexamdate',
      queryParameters: {
        'bina': buildingCode,
        'examDate': examDate, // Use original date format like React Native
      },
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final List<dynamic> data = response.data['data'] ?? [];
      return data.map((json) => Participant.fromJson(json)).toList();
    }

    return [];
  }

  /// Download participant photos as a binary stream (BXP1 protocol) and hand
  /// them to [onBatch] in batches, instead of loading everything into memory.
  ///
  /// Wire format (little-endian):
  /// ```
  /// magic  : 4 bytes ASCII "BXP1"
  /// count  : int32
  /// record x count:
  ///   isN  : int64
  ///   len  : int32  (> 0)
  ///   data : len bytes
  /// ```
  /// Returns the number of photos actually received. If the stream ends
  /// early (server-side race), that's not an error — whatever was read is
  /// returned. An EOF in the middle of a record is a [FormatException].
  Future<int> downloadParticipantPhotos({
    required String buildingCode,
    required String examDate,
    required Future<void> Function(List<MapEntry<int, Uint8List>> batch)
        onBatch,
    void Function(int done, int total)? onProgress,
  }) async {
    final response = await _dio.get(
      '/buraxilishes/getparticipantphotosstream',
      queryParameters: {
        'bina': buildingCode,
        'examDate': examDate,
      },
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    final stream = (response.data as ResponseBody).stream;

    // Accumulator: a queue of not-yet-consumed chunks plus an offset into
    // the first one. take(n) only consumes bytes once at least n are
    // available, so a short read never corrupts the parse state.
    final chunks = <Uint8List>[];
    int chunkOffset = 0;
    int available = 0;

    void addChunk(Uint8List chunk) {
      if (chunk.isEmpty) return;
      chunks.add(chunk);
      available += chunk.length;
    }

    Uint8List? take(int n) {
      if (available < n) return null;
      final result = Uint8List(n);
      var written = 0;
      while (written < n) {
        final chunk = chunks.first;
        final remainingInChunk = chunk.length - chunkOffset;
        final needed = n - written;
        final toCopy = remainingInChunk < needed ? remainingInChunk : needed;
        result.setRange(written, written + toCopy, chunk, chunkOffset);
        written += toCopy;
        chunkOffset += toCopy;
        if (chunkOffset >= chunk.length) {
          chunks.removeAt(0);
          chunkOffset = 0;
        }
      }
      available -= n;
      return result;
    }

    bool magicChecked = false;
    int? count;
    int? pendingIsN;
    int? pendingLen;
    int received = 0;
    var batch = <MapEntry<int, Uint8List>>[];

    await for (final rawChunk in stream) {
      addChunk(rawChunk);

      while (true) {
        if (!magicChecked) {
          final magic = take(4);
          if (magic == null) break;
          if (String.fromCharCodes(magic) != 'BXP1') {
            throw const FormatException(
                'Invalid photo stream magic (expected BXP1)');
          }
          magicChecked = true;
        }

        if (count == null) {
          final countBytes = take(4);
          if (countBytes == null) break;
          count = ByteData.sublistView(countBytes).getInt32(0, Endian.little);
        }

        if (received >= count) break;

        if (pendingLen == null) {
          final header = take(12);
          if (header == null) break;
          final bd = ByteData.sublistView(header);
          pendingIsN = bd.getInt64(0, Endian.little);
          pendingLen = bd.getInt32(8, Endian.little);
          if (pendingLen <= 0) {
            throw FormatException('Invalid photo record length: $pendingLen');
          }
        }

        final data = take(pendingLen);
        if (data == null) break; // wait for more chunks

        batch.add(MapEntry(pendingIsN!, data));
        pendingIsN = null;
        pendingLen = null;
        received++;

        if (batch.length >= 100) {
          await onBatch(batch);
          batch = <MapEntry<int, Uint8List>>[];
          onProgress?.call(received, count);
        }
      }

      if (count != null && received >= count) break;
    }

    if (batch.isNotEmpty) {
      await onBatch(batch);
      batch = <MapEntry<int, Uint8List>>[];
    }
    if (count != null) onProgress?.call(received, count);

    if (!magicChecked) {
      throw const FormatException('Photo stream ended before magic header');
    }
    if (count == null) {
      throw const FormatException('Photo stream ended before count header');
    }
    if (pendingLen != null) {
      // EOF in the middle of a record's data — genuinely corrupt.
      throw const FormatException('Photo stream ended mid-record');
    }
    if (received < count && available > 0) {
      // Leftover bytes that never formed a complete record header — cut
      // mid-header, not a clean boundary between records.
      throw const FormatException('Photo stream ended mid-record header');
    }

    return received;
  }

  /// Get all supervisors by building and exam date (for offline download)
  Future<List<Supervisor>> getSupervisorsByBuilding({
    required String buildingCode,
    required String examDate,
  }) async {
    try {
      // For supervisors, React Native FORMATS the date using dateToAzToDate
      final formattedDate = _formatExamDateWithSessionForApi(examDate);
      print('getSupervisorsByBuilding - Original date: $examDate');
      print('getSupervisorsByBuilding - Formatted date: $formattedDate');
      print('getSupervisorsByBuilding - Building code: $buildingCode');
      print(
          'getSupervisorsByBuilding - Making request to: /supervisors/GetAllSupervisorDetailDtoInExamDateAndBuilding?buildingCode=$buildingCode&examDate=$formattedDate');

      final response = await _dio.get(
        '/supervisors/GetAllSupervisorDetailDtoInExamDateAndBuilding',
        queryParameters: {
          'buildingCode': buildingCode,
          'examDate': formattedDate, // Use formatted date like React Native
        },
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Supervisor.fromJson(json)).toList();
      }

      return [];
    } on DioException catch (e) {
      // A 400 here means the `X-Exam-Slot` header was rejected (invalid
      // slot) — let it propagate so the caller can tell that apart from
      // "no data" and refuse to save a silently-partial offline database
      // (see API_slots.md and OfflineDatabaseProvider.downloadOfflineDatabase).
      if (e.response?.statusCode == 400) rethrow;
      print('Error getting supervisors by building: $e');
      return [];
    } catch (e) {
      print('Error getting supervisors by building: $e');
      return [];
    }
  }

  /// Get all monitors for a building and exam date (used for admin offline download)
  Future<List<Monitor>> getMonitorsByBuilding({
    required String buildingCode,
    required String examDate,
  }) async {
    try {
      final formattedDate = _formatExamDateForApi(examDate);
      print(
          'getMonitorsByBuilding - buildingCode: $buildingCode, examDate: $formattedDate');

      final response = await _dio.get(
        '/monitors/GetByBuildingCodeAndExamDate',
        queryParameters: {
          'buildingCode': buildingCode,
          'examDate': formattedDate,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Monitor.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting monitors by building: $e');
      return [];
    }
  }

  /// Get ALL monitors with images for an exam date (admin — no building code needed)
  Future<List<Monitor>> getAllMonitorsInExamDate(String examDate) async {
    try {
      final formattedDate = DateFormatter.dateToAzToDate(examDate);
      print('getAllMonitorsInExamDate - examDate: $examDate -> $formattedDate');

      final response = await _dio.get(
        '/monitors/GetAllMonitorDetailDtoInExamDate',
        queryParameters: {'examDate': formattedDate},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Monitor.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      // A 400 means the `X-Exam-Slot` header was rejected — propagate so
      // OfflineDatabaseProvider can show an explicit error instead of the
      // generic "no data for this date" message.
      if (e.response?.statusCode == 400) rethrow;
      print('Error getting all monitors in exam date: $e');
      return [];
    } catch (e) {
      print('Error getting all monitors in exam date: $e');
      return [];
    }
  }

  /// Get monitors for a specific room and exam date (admin — no building code needed)
  Future<List<Monitor>> getMonitorsByRoomId({
    required int roomId,
    required String examDate,
  }) async {
    try {
      final formattedDate = DateFormatter.dateToAzToDate(examDate);
      print(
          'getMonitorsByRoomId - roomId: $roomId, examDate: $examDate -> $formattedDate');

      final response = await _dio.get(
        '/monitors/GetByRoomIdAndExamDate',
        queryParameters: {
          'roomId': roomId,
          'examDate': formattedDate,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Monitor.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting monitors by room: $e');
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
      print('Error formatting exam date: $e');
      return examDate;
    }
  }

  /// Same as [_formatExamDateForApi], but keeps the session time ("HH:mm") when the
  /// Azerbaijani string carries one. Only for nezaretchi (Supervisor) requests —
  /// participants and monitors have no session time.
  String _formatExamDateWithSessionForApi(String examDate) {
    final converted = _formatExamDateForApi(examDate);
    if (converted == examDate) {
      return converted;
    }
    final lastToken = examDate.split(' ').last;
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(lastToken)) {
      return '$converted $lastToken';
    }
    return converted;
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
                'qeydiyyat': p.qeydiyyat,
              })
          .toList();

      print('Syncing ${participantsData.length} participants to server');
      print('Participants data: $participantsData');

      final response = await _dio.post(
        '/buraxilishes/syncburaxilish',
        data: participantsData,
      );

      print('Sync participants response status: ${response.statusCode}');
      print('Sync participants response data: ${response.data}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ResponseModel(
          success: true,
          message: response.data['message'] as String? ?? '',
        );
      } else {
        return ResponseModel(
          success: false,
          message: response.data['message'] ??
              'Sinxronizasiya zamanı xəta baş verdi',
        );
      }
    } on DioException catch (e) {
      print('Error syncing participants: $e');
      return ResponseModel(success: false, message: _syncErrorMessage(e));
    } catch (e) {
      print('General error syncing participants: $e');
      return ResponseModel(
        success: false,
        message: 'Naməlum xəta: $e',
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

      print('Syncing ${supervisorsData.length} supervisors to server');
      print('Supervisors data: $supervisorsData');

      final response = await _dio.post(
        '/supervisors/syncsupervisors',
        data: supervisorsData,
      );

      print('Sync supervisors response status: ${response.statusCode}');
      print('Sync supervisors response data: ${response.data}');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ResponseModel(
          success: true,
          message: response.data['message'] as String? ?? '',
        );
      } else {
        return ResponseModel(
          success: false,
          message: response.data['message'] ??
              'Sinxronizasiya zamanı xəta baş verdi',
        );
      }
    } on DioException catch (e) {
      print('Error syncing supervisors: $e');
      return ResponseModel(success: false, message: _syncErrorMessage(e));
    } catch (e) {
      print('General error syncing supervisors: $e');
      return ResponseModel(
        success: false,
        message: 'Naməlum xəta: $e',
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
      // NOTE: Imt_Tarix in DB is stored as raw string (e.g. Azerbaijani format).
      // The cancel endpoint uses string comparison (b.Imt_Tarix == examDate),
      // so we must NOT convert the date — pass the raw DB value as-is.
      print(
          'Canceling participant registration: isN=$isN, bina=$bina, examDate=$examDate');

      final response = await _dio.post(
        '/buraxilishes/cancelregistration',
        queryParameters: {
          'isN': isN,
          'bina': bina,
          'examDate': examDate,
        },
      );

      print('Cancel participant registration response: ${response.statusCode}');
      print('Response data: ${response.data}');

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
      print('Error canceling participant registration: $e');
      if (e.response != null) {
        print('Error response status: ${e.response!.statusCode}');
        print('Error response data: ${e.response!.data}');
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
      print('General error canceling participant registration: $e');
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
      final formattedDate = DateFormatter.dateToAzToDateWithSession(examDate);

      print(
          'Canceling supervisor registration: cardNumber=$cardNumber, buildingCode=$buildingCode, examDate=$formattedDate');

      final response = await _dio.post(
        '/supervisors/cancelregistration',
        queryParameters: {
          'cardNumber': cardNumber,
          'buildingCode': buildingCode,
          'examDate': formattedDate,
        },
      );

      print('Cancel supervisor registration response: ${response.statusCode}');
      print('Response data: ${response.data}');

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
      print('Error canceling supervisor registration: $e');
      if (e.response != null) {
        print('Error response status: ${e.response!.statusCode}');
        print('Error response data: ${e.response!.data}');
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
      print('General error canceling supervisor registration: $e');
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

      print(
          'Scanning monitor: workNumber=$workNumber, examDate=$examDate -> $formattedDate');

      final response = await _dio.get(
        '/monitors/checkmonitor',
        queryParameters: {
          'workNumber': workNumber,
          'examDate': formattedDate,
        },
      );

      print('Monitor scan response status: ${response.statusCode}');
      print('Monitor scan response data: ${response.data}');

      if (response.statusCode == 200) {
        return MonitorResponse.fromJson(response.data);
      } else {
        return MonitorResponse(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('Dio error scanning monitor: $e');
      if (e.response?.statusCode == 400) {
        return MonitorResponse(
          success: false,
          message: 'Axtarılan şəxs haqqında məlumat tapılmadı',
        );
      } else if (e.response != null) {
        print('Error response data: ${e.response!.data}');
        try {
          return MonitorResponse.fromJson(e.response!.data);
        } catch (parseError) {
          print('Error parsing error response: $parseError');
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
      print('General error scanning monitor: $error');
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

      print(
          'Canceling monitor registration: workNumber=$workNumber, buildingCode=$buildingCode, examDate=$formattedDate');

      final response = await _dio.post(
        '/monitors/cancelregistration',
        queryParameters: {
          'workNumber': workNumber,
          'buildingCode': buildingCode,
          'examDate': formattedDate,
        },
      );

      print('Cancel monitor registration response: ${response.statusCode}');
      print('Response data: ${response.data}');

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
      print('Error canceling monitor registration: $e');
      if (e.response != null) {
        print('Error response status: ${e.response!.statusCode}');
        print('Error response data: ${e.response!.data}');
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
      print('General error canceling monitor registration: $e');
      return ResponseModel(
        success: false,
        message: 'Xəta baş verdi',
      );
    }
  }

  /// Get violators for a building and exam date (offline download)
  Future<List<ViolatorInfo>> getViolatorsInBuilding({
    required String buildingCode,
    required String examDate,
  }) async {
    try {
      final response = await _dio.get(
        '/buraxilishes/getviolatorsinbuildingandexamdate',
        queryParameters: {'bina': buildingCode, 'examDate': examDate},
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => ViolatorInfo.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Error getting violators: $e');
      return [];
    }
  }

  /// Search İmtahan rəhbərləri by name/surname/patronymic for a given exam date
  Future<List<Monitor>> searchMonitorsByName({
    required String searchTerm,
    required String examDate,
  }) async {
    try {
      final formattedDate = DateFormatter.dateToAzToDate(examDate);
      print(
          'searchMonitorsByName - searchTerm: $searchTerm, examDate: $formattedDate');

      final response = await _dio.get(
        '/monitors/SearchByName',
        queryParameters: {
          'searchTerm': searchTerm,
          'examDate': formattedDate,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Monitor.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      print('Error searching monitors: $e');
      return [];
    } catch (e) {
      print('General error searching monitors: $e');
      return [];
    }
  }

  /// Notifies the server that the offline database was fully downloaded.
  /// Fire-and-forget — errors are swallowed so they never block the user.
  Future<void> reportDownloadComplete({
    required String buildingCode,
    required String examDate,
    required int participantCount,
    required int supervisorCount,
    required String appVersion,
  }) async {
    try {
      final deviceId = await DeviceIdentityService.instance.getDeviceId();
      await _dio.post(
        '/admin/downloadcomplete',
        data: {
          'buildingCode': buildingCode,
          'examDate': _formatExamDateForApi(examDate),
          'examDateRaw': examDate,
          'participantCount': participantCount,
          'supervisorCount': supervisorCount,
          'appVersion': appVersion,
          'deviceId': deviceId,
        },
      );
    } catch (e) {
      print('reportDownloadComplete error (ignored): $e');
    }
  }

  /// Returns the minimum required app version from server.
  /// Returns null on network error — caller should treat null as "no update needed".
  Future<String?> getMinimumAppVersion() async {
    try {
      final response = await _dio.get('/admin/appversion');
      if (response.statusCode == 200) {
        return response.data['minimumVersion'] as String?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('getMinimumAppVersion error (ignored): $e');
      return null;
    }
  }

  String _syncErrorMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) return 'Avtorizasiya vaxtı bitib. Yenidən daxil olun!';
    if (status == 429) return 'Həddən artıq çox sorğu (429). Bir neçə dəqiqə gözləyin';
    if (status == 400) return 'Məlumatlarda format xətası (400). Administratora məlumat verin';
    if (status == 500) return 'Server xətası (500). Administratora müraciət edin';
    if (status != null) return 'Server cavabı: $status';

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return 'Server ilə əlaqə qurulmadı (timeout). İnternet bağlantısını yoxlayın';
      case DioExceptionType.receiveTimeout:
        return 'Server vaxtında cavab vermədi (timeout). Yenidən cəhd edin';
      case DioExceptionType.connectionError:
        return 'İnternet bağlantısı yoxdur';
      default:
        return 'Şəbəkə xətası: ${e.message ?? e.type.name}';
    }
  }
}
