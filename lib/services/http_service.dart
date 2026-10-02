import 'dart:async';
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
import '../models/session_models.dart';
import 'database_service.dart';
import 'session_revoke_service.dart';

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
  static Future<_RefreshResult>? _refreshInFlight;

  /// Marker set in `RequestOptions.extra` by the calls the session-revoke flow
  /// itself makes (session probe, heartbeat), so a revoked-session 401 on them
  /// never re-triggers the flow.
  static const String _skipRevokeTriggerKey = 'skipRevokeTrigger';

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
        // one has been picked — see API_slots.md. Full-switch (9.2, contract
        // §1): this header (or `X-Exam-Session-Id`, resolved server-side) is
        // now the ONLY way the server learns the exam context — there is no
        // `examDate` query/body fallback left on any endpoint.
        final examDetails = await getExamDetailsFromStorage();
        final slotKey = examDetails?.slotKey;
        if (slotKey != null && slotKey.isNotEmpty) {
          options.headers['X-Exam-Slot'] = slotKey;
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          if (_isSessionRevoked(error.response)) {
            // The admin deactivated this device. Keep the token: the revoked
            // token is still accepted by the sync endpoints, which the revoke
            // flow needs to drain the offline queue before logging out.
            if (error.requestOptions.extra[_skipRevokeTriggerKey] != true) {
              unawaited(SessionRevokeService.instance.trigger(
                reason: RevokeReason.revokedByAdmin,
                serverMessage: _messageFromBody(error.response?.data),
              ));
            }
          } else {
            await removeToken();
          }
        }
        handler.next(error);
      },
    ));
  }

  /// Plain authenticated GET through this service's dio, so callers outside
  /// HttpService (StatisticsService) get the same interceptor: JWT, token
  /// refresh and the `X-Exam-Slot` header. Don't create a second Dio for that.
  /// Non-2xx responses throw [DioException] (dio default) — the caller reads
  /// `e.response` for the status code and server message.
  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return _dio.get(path, queryParameters: query);
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
        if (refreshed.token != null) return refreshed.token!.token;

        // Drop the stored token only when the server actually rejected the
        // refresh. On a network error (phone offline) keep the expired token so
        // a later call can refresh once connectivity is back.
        if (refreshed.rejected) await removeToken();
        return null;
      }
      return null;
    } catch (error) {
      if (kDebugMode) print('Error getting token: $error');
      return null;
    }
  }

  Future<_RefreshResult> _refreshAccessToken(String? refreshToken) {
    if (refreshToken == null || refreshToken.isEmpty) {
      return Future.value(const _RefreshResult.rejected());
    }
    return _refreshInFlight ??=
        _performRefresh(refreshToken).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<_RefreshResult> _performRefresh(String refreshToken) async {
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
        return _RefreshResult.success(newToken);
      }
      // The server answered but did not issue a token.
      return const _RefreshResult.rejected();
    } on DioException catch (error) {
      if (kDebugMode) print('Token refresh failed: $error');
      final status = error.response?.statusCode;
      if (status == 401 || status == 400) {
        return const _RefreshResult.rejected();
      }
      // Network error, timeout, 5xx — not a verdict on the refresh token.
      return const _RefreshResult.unavailable();
    } catch (error) {
      if (kDebugMode) print('Token refresh failed: $error');
      return const _RefreshResult.unavailable();
    }
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
  // the exam is picked afterwards on a dedicated screen (see getSlots()).
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

  Future<Response> getTParolByBina(int buildingCode) async {
    return await _dio.get('/tparols/getbybina?buildingCode=$buildingCode');
  }

  /// Full-switch (9.2, contract §1.4): `examDate` dropped — the server reads
  /// the exam scope from `X-Exam-Slot` (or falls back to all buildings for
  /// the emergency-message building selector when no exam is selected).
  Future<Response> getAllBuildingInExamDate() async {
    return await _dio.get('/tparols/getallbuildinginexamdate');
  }

  // Participant scanning methods

  // Scan participant online (from React Native: checkjobnoatbinaandexamdate)
  Future<ParticipantResponse> scanParticipant({
    required String jobNo,
    required String building,
  }) async {
    try {
      final response = await _dio.get(
        '/buraxilishes/checkjobnoatbinaandexamdate',
        queryParameters: {
          'cardNumber': jobNo,
          'buildingCode': building,
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
      if (kDebugMode) print('Error scanning participant: $e');
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
    required int buildingCode,
    bool persist = true,
  }) async {
    try {
      final response = await _dio.get(
        '/buraxilishes/getexamdetailsinexamdate',
        queryParameters: {'buildingCode': buildingCode},
      );

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
      if (kDebugMode) print('Error getting exam details: $e');
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
      return await DatabaseService.getParticipantByWorkNumber(workNumber);
    } catch (e) {
      if (kDebugMode) print('Error getting participant from offline DB: $e');
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
      if (kDebugMode) print('Error getting registered participants: $e');
      return [];
    }
  }

  /// Save participants to offline database
  Future<void> saveParticipantsOffline(List<Participant> participants) async {
    try {
      await DatabaseService.saveParticipants(participants);
    } catch (e) {
      if (kDebugMode) print('Error saving participants offline: $e');
    }
  }

  /// Check if offline database has data
  Future<bool> hasOfflineData() async {
    try {
      return await DatabaseService.hasOfflineData();
    } catch (e) {
      if (kDebugMode) print('Error checking offline data: $e');
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
  }) async {
    try {
      final response = await _dio.get(
        '/supervisors/checksupervisor',
        queryParameters: {
          'cardNumber': cardNumber,
          'buildingCode': buildingCode,
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
      if (e.response?.statusCode == 400) {
        return SupervisorResponse(
          success: false,
          message: 'Axtarılan şəxs haqqında məlumat tapılmadı',
        );
      } else if (e.response != null) {
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
      if (kDebugMode) print('General error scanning supervisor: $error');
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
      if (kDebugMode) print('Error getting supervisor from offline DB: $error');
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
      if (kDebugMode) print('Error getting registered supervisors: $e');
      return [];
    }
  }

  /// Save supervisors to offline database
  Future<void> saveSupervisorsOffline(List<Supervisor> supervisors) async {
    try {
      await DatabaseService.saveSupervisors(supervisors);
    } catch (e) {
      if (kDebugMode) print('Error saving supervisors offline: $e');
    }
  }

  /// Get supervisor details/statistics from API.
  /// [persist] controls whether the result is written to secure storage.
  Future<SupervisorDetails?> getSupervisorDetails({
    required int buildingCode,
    bool persist = true,
  }) async {
    try {
      final response = await _dio.get(
        '/supervisors/GetExamDetailsInExamDate',
        queryParameters: {'buildingCode': buildingCode},
      );

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
      if (kDebugMode) print('Error getting supervisor details: $e');
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

  /// Get all participants by building (for offline download)
  Future<List<Participant>> getParticipantsByBuilding({
    required String buildingCode,
  }) async {
    try {
      final response = await _dio.get(
        '/buraxilishes/GetAllParticipantInBuildingAndExamDate',
        queryParameters: {'buildingCode': buildingCode},
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Participant.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) print('Error getting participants by building: $e');
      return [];
    }
  }

  /// Get all participants by building, WITHOUT photos (for offline download).
  /// Same response fields as [getParticipantsByBuilding], just lighter —
  /// photos are downloaded separately in bulk via [downloadParticipantPhotos]
  /// and merged into SQLite afterwards.
  ///
  /// Unlike [getParticipantsByBuilding], errors are NOT swallowed here — they
  /// propagate to the caller (OfflineDatabaseProvider already wraps this call
  /// in its own try/catch that logs and flags the network error).
  Future<List<Participant>> getParticipantsLightByBuilding({
    required String buildingCode,
  }) async {
    final response = await _dio.get(
      '/buraxilishes/getallparticipantlightinbuildingandexamdate',
      queryParameters: {'buildingCode': buildingCode},
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
  ///   cardNumber : int64
  ///   len  : int32  (> 0)
  ///   data : len bytes
  /// ```
  /// Returns the number of photos actually received. If the stream ends
  /// early (server-side race), that's not an error — whatever was read is
  /// returned. An EOF in the middle of a record is a [FormatException].
  Future<int> downloadParticipantPhotos({
    required String buildingCode,
    required Future<void> Function(List<MapEntry<int, Uint8List>> batch)
        onBatch,
    void Function(int done, int total)? onProgress,
  }) async {
    final response = await _dio.get(
      '/buraxilishes/getparticipantphotosstream',
      queryParameters: {'buildingCode': buildingCode},
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

  /// Get all supervisors by building (for offline download)
  Future<List<Supervisor>> getSupervisorsByBuilding({
    required String buildingCode,
  }) async {
    try {
      final response = await _dio.get(
        '/supervisors/GetAllSupervisorDetailDtoInExamDateAndBuilding',
        queryParameters: {'buildingCode': buildingCode},
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
      if (kDebugMode) print('Error getting supervisors by building: $e');
      return [];
    } catch (e) {
      if (kDebugMode) print('Error getting supervisors by building: $e');
      return [];
    }
  }

  /// Get all monitors for a building (used for admin offline download)
  Future<List<Monitor>> getMonitorsByBuilding({
    required String buildingCode,
  }) async {
    try {
      final response = await _dio.get(
        '/monitors/GetByBuildingCodeAndExamDate',
        queryParameters: {'buildingCode': buildingCode},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Monitor.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      if (kDebugMode) print('Error getting monitors by building: $e');
      return [];
    }
  }

  /// Get ALL monitors with images for the active slot (admin — no building
  /// code needed).
  Future<List<Monitor>> getAllMonitors() async {
    try {
      final response =
          await _dio.get('/monitors/GetAllMonitorDetailDtoInExamDate');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Monitor.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      // A 400 means the `X-Exam-Slot` header was rejected — propagate so
      // OfflineDatabaseProvider can show an explicit error instead of the
      // generic "no data" message.
      if (e.response?.statusCode == 400) rethrow;
      if (kDebugMode) print('Error getting all monitors: $e');
      return [];
    } catch (e) {
      if (kDebugMode) print('Error getting all monitors: $e');
      return [];
    }
  }

  /// Get monitors for a specific room (admin — no building code needed)
  Future<List<Monitor>> getMonitorsByRoomId({
    required int roomId,
  }) async {
    try {
      final response = await _dio.get(
        '/monitors/GetByRoomIdAndExamDate',
        queryParameters: {'roomId': roomId},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Monitor.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Error getting monitors by room: $e');
      return [];
    }
  }

  // =========== SYNC METHODS ===========

  /// Sync registered participants to server.
  ///
  /// Contract §1.3: `[{id?, cardNumber?, buildingCode?, slotKey?,
  /// registeredAt}]`. Rows that already know their server `Participants.Id`
  /// (every scan since 9.2) sync by `id`; a row with no `id` (a v8
  /// offline-queue row migrated to v9 — see DatabaseService's v9 migration)
  /// falls back to `cardNumber`+`buildingCode`+`slotKey`. No exam-scope
  /// header is required for this call.
  Future<ResponseModel> syncParticipants(List<Participant> participants) async {
    try {
      final participantsData = participants.map((p) {
        final row = <String, dynamic>{'registeredAt': p.registeredAt};
        if (p.id != null) {
          row['id'] = p.id;
        } else {
          row['cardNumber'] = p.cardNumber;
          row['buildingCode'] = p.buildingCode;
          row['slotKey'] = p.slotKey;
        }
        return row;
      }).toList();

      final response = await _dio.post(
        '/buraxilishes/syncburaxilish',
        data: participantsData,
      );

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
      if (kDebugMode) print('Error syncing participants: $e');
      return ResponseModel(success: false, message: _syncErrorMessage(e));
    } catch (e) {
      if (kDebugMode) print('General error syncing participants: $e');
      return ResponseModel(
        success: false,
        message: 'Naməlum xəta: $e',
      );
    }
  }

  /// Sync registered supervisors to server.
  ///
  /// Contract §1.3: `[{id?, cardNumber?, buildingCode?, slotKey?,
  /// registerDate}]` — same id-first, slotKey-fallback branch as
  /// [syncParticipants].
  Future<ResponseModel> syncSupervisors(List<Supervisor> supervisors) async {
    try {
      final supervisorsData = supervisors.map((s) {
        final row = <String, dynamic>{'registerDate': s.registerDate};
        if (s.id != null) {
          row['id'] = s.id;
        } else {
          row['cardNumber'] = s.cardNumber;
          row['buildingCode'] = s.buildingCode;
          row['slotKey'] = s.slotKey;
        }
        return row;
      }).toList();

      final response = await _dio.post(
        '/supervisors/syncsupervisors',
        data: supervisorsData,
      );

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
      if (kDebugMode) print('Error syncing supervisors: $e');
      return ResponseModel(success: false, message: _syncErrorMessage(e));
    } catch (e) {
      if (kDebugMode) print('General error syncing supervisors: $e');
      return ResponseModel(
        success: false,
        message: 'Naməlum xəta: $e',
      );
    }
  }

  /// Cancel participant registration by server row id (contract §1.3).
  Future<ResponseModel> cancelParticipantRegistration({
    required int id,
  }) async {
    try {
      final response = await _dio.post(
        '/buraxilishes/cancelregistration',
        queryParameters: {'id': id},
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
      if (kDebugMode) print('General error canceling participant registration: $e');
      return ResponseModel(
        success: false,
        message: 'Xəta baş verdi',
      );
    }
  }

  /// Cancel supervisor registration by server row id (contract §1.3).
  Future<ResponseModel> cancelSupervisorRegistration({
    required int id,
  }) async {
    try {
      final response = await _dio.post(
        '/supervisors/cancelregistration',
        queryParameters: {'id': id},
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
      if (kDebugMode) print('General error canceling supervisor registration: $e');
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
  }) async {
    try {
      final response = await _dio.get(
        '/monitors/checkmonitor',
        queryParameters: {'workNumber': workNumber},
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
      if (e.response?.statusCode == 400) {
        return MonitorResponse(
          success: false,
          message: 'Axtarılan şəxs haqqında məlumat tapılmadı',
        );
      } else if (e.response != null) {
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
      if (kDebugMode) print('General error scanning monitor: $error');
      return MonitorResponse(
        success: false,
        message: 'Gözlənilməz xəta baş verdi',
      );
    }
  }

  /// Cancel monitor registration by server row id (contract §1.3).
  Future<ResponseModel> cancelMonitorRegistration({
    required int id,
  }) async {
    try {
      final response = await _dio.post(
        '/monitors/cancelregistration',
        queryParameters: {'id': id},
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
      if (kDebugMode) print('General error canceling monitor registration: $e');
      return ResponseModel(
        success: false,
        message: 'Xəta baş verdi',
      );
    }
  }

  /// Get violators for a building (offline download)
  Future<List<ViolatorInfo>> getViolatorsInBuilding({
    required String buildingCode,
  }) async {
    try {
      final response = await _dio.get(
        '/buraxilishes/getviolatorsinbuildingandexamdate',
        queryParameters: {'buildingCode': buildingCode},
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

  /// Search İmtahan rəhbərləri by name/surname/patronymic (active slot)
  Future<List<Monitor>> searchMonitorsByName({
    required String searchTerm,
  }) async {
    try {
      final response = await _dio.get(
        '/monitors/SearchByName',
        queryParameters: {'searchTerm': searchTerm},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => Monitor.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) print('Error searching monitors: $e');
      return [];
    } catch (e) {
      if (kDebugMode) print('General error searching monitors: $e');
      return [];
    }
  }

  /// Notifies the server that the offline database was fully downloaded.
  /// Fire-and-forget — errors are swallowed so they never block the user.
  /// Contract §1.3: body is `{buildingCode, slotKey, ...}` — the server
  /// resolves `DbDownloadLog.ExamDate`/`ExamDateRaw` from the slot itself.
  Future<void> reportDownloadComplete({
    required String buildingCode,
    required String slotKey,
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
          'slotKey': slotKey,
          'participantCount': participantCount,
          'supervisorCount': supervisorCount,
          'appVersion': appVersion,
          'deviceId': deviceId,
        },
      );
    } catch (e) {
      if (kDebugMode) print('reportDownloadComplete error (ignored): $e');
    }
  }

  // =========== SESSION / HEARTBEAT ===========

  /// `GET /auth/session` — asks the server whether this device's session was
  /// revoked. Works with a revoked token. Never throws: anything inconclusive
  /// (offline, timeout, 5xx, 404 from an older backend) is reported as
  /// [SessionCheckOutcome.unreachable].
  Future<SessionCheckResult> getSessionStatus({
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _sessionCall(
      () => _dio.get('/auth/session', options: _revokeFlowOptions),
      timeout,
    );
  }

  /// `POST /devicetokens/heartbeat` — reports the device state (pending queue
  /// sizes etc.) and learns whether the session was revoked. Works with a
  /// revoked token. Never throws.
  Future<SessionCheckResult> sendHeartbeat(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _sessionCall(
      () => _dio.post('/devicetokens/heartbeat',
          data: payload, options: _revokeFlowOptions),
      timeout,
    );
  }

  Options get _revokeFlowOptions =>
      Options(extra: {_skipRevokeTriggerKey: true});

  Future<SessionCheckResult> _sessionCall(
    Future<Response<dynamic>> Function() request,
    Duration timeout,
  ) async {
    try {
      final response = await request().timeout(timeout);
      if (response.statusCode == 200) {
        final body = response.data;
        final Map map = body is Map
            ? (body['data'] is Map ? body['data'] as Map : body)
            : const {};
        return SessionCheckResult(
          map['revoked'] == true
              ? SessionCheckOutcome.revoked
              : SessionCheckOutcome.active,
          message: map['message'] as String?,
        );
      }
      return const SessionCheckResult(SessionCheckOutcome.unreachable);
    } on DioException catch (e) {
      final response = e.response;
      if (response?.statusCode == 401) {
        return SessionCheckResult(
          _isSessionRevoked(response)
              ? SessionCheckOutcome.revoked
              : SessionCheckOutcome.unauthorized,
          message: _messageFromBody(response?.data),
        );
      }
      return const SessionCheckResult(SessionCheckOutcome.unreachable);
    } catch (_) {
      // TimeoutException and anything else: treat as offline.
      return const SessionCheckResult(SessionCheckOutcome.unreachable);
    }
  }

  static bool _isSessionRevoked(Response<dynamic>? response) =>
      response?.headers.value('x-session-revoked') == '1';

  static String? _messageFromBody(dynamic body) {
    if (body is Map && body['message'] is String) {
      final message = body['message'] as String;
      return message.isEmpty ? null : message;
    }
    return null;
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

/// Result of one refresh attempt. [rejected] is true only when the server
/// answered and refused (or there was no refresh token at all) — a network
/// failure is neither a success nor a rejection.
class _RefreshResult {
  final AccessTokenModel? token;
  final bool rejected;

  const _RefreshResult.success(AccessTokenModel this.token) : rejected = false;
  const _RefreshResult.rejected()
      : token = null,
        rejected = true;
  const _RefreshResult.unavailable()
      : token = null,
        rejected = false;
}
