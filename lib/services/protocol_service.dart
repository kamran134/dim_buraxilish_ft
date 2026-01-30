/// Protocol API Service for the DIM Buraxilish application
/// Handles all protocol-related HTTP requests including CRUD operations
///
/// Author: GitHub Copilot
/// Date: 2025-10-13

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/protocol_models.dart';
import '../utils/date_formatter.dart';
import 'http_service.dart';

class ProtocolService {
  static const String baseUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/api';

  late final Dio _dio;
  final HttpService _httpService;

  ProtocolService(this._httpService) {
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
        final token = await _httpService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _httpService.removeToken();
        }
        handler.next(error);
      },
    ));
  }

  /// Get note types for dropdowns
  Future<NoteTypesResponse> getNoteTypes() async {
    try {
      if (kDebugMode) {
        debugPrint('[Protocol] Fetching note types');
      }

      final response = await _dio.get('/notetypes');

      if (kDebugMode) {
        debugPrint('[Protocol] Note types received: ${response.data}');
      }

      final noteTypesResponse = NoteTypesResponse.fromJson(response.data);

      if (kDebugMode) {
        debugPrint(
            '[Protocol] Parsed ${noteTypesResponse.data?.length ?? 0} note types');
      }

      return noteTypesResponse;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Protocol] Error fetching note types: $e');
        if (e is DioException) {
          debugPrint('[Protocol] Status: ${e.response?.statusCode}');
          debugPrint('[Protocol] Message: ${e.response?.data}');
        }
      }

      if (e is DioException) {
        return NoteTypesResponse(
          success: false,
          message: e.response?.data?['message'] ?? 'Qeyd növləri yüklənmədi',
        );
      }

      return const NoteTypesResponse(
        success: false,
        message: 'Şəbəkə xətası baş verdi',
      );
    }
  }

  /// Get protocol notes for monitors (filtered by exam date)
  Future<List<ProtocolNote>> getMyProtocolNotes({String? examDate}) async {
    try {
      if (kDebugMode) {
        debugPrint('[Protocol] Getting my protocol notes, examDate: $examDate');
      }

      String url = '/protocols/my-notes';

      // Add examDate filter if provided
      if (examDate != null && examDate.isNotEmpty) {
        // Convert to ISO format for API
        final isoDate = DateFormatter.azerbaijaniDateToISO(examDate);
        if (isoDate != null) {
          url += '?examDate=${Uri.encodeComponent(isoDate)}';
          if (kDebugMode) {
            debugPrint('[Protocol] Filtered URL: $url');
          }
        }
      }

      final response = await _dio.get(url);

      print('✅ My protocol notes response received:');
      print('   Status: ${response.statusCode}');
      print('   Success: ${response.data['success']}');

      if (response.data['success'] == true && response.data['data'] != null) {
        final notes = (response.data['data'] as List)
            .map((json) => ProtocolNote.fromJson(json))
            .toList();

        print('📊 Parsed protocol notes: ${notes.length}');
        return notes;
      }

      return [];
    } catch (e) {
      print('❌ Error fetching my protocol notes: $e');

      if (e is DioException) {
        print('   Status: ${e.response?.statusCode}');
        print('   Message: ${e.response?.data}');
      }

      return [];
    }
  }

  /// Create new protocol note (for monitors)
  Future<ProtocolResponse> createProtocolNote(
      CreateProtocolNoteRequest request) async {
    try {
      print('📝 ProtocolService.createProtocolNote()');
      print('   Request: ${request.toJson()}');

      final response =
          await _dio.post('/protocols/my-note', data: request.toJson());

      print('✅ Create protocol note response received:');
      print('   Status: ${response.statusCode}');
      print('   Data: ${response.data}');

      return ProtocolResponse.fromJson(response.data);
    } catch (e) {
      print('❌ Error creating protocol note: $e');

      if (e is DioException) {
        print('   Status: ${e.response?.statusCode}');
        print('   Message: ${e.response?.data}');

        return ProtocolResponse(
          success: false,
          message: e.response?.data?['message'] ?? 'Qeyd əlavə edilmədi',
        );
      }

      return const ProtocolResponse(
        success: false,
        message: 'Şəbəkə xətası baş verdi',
      );
    }
  }

  /// Update existing protocol note (for monitors)
  Future<ProtocolResponse> updateProtocolNote(
      UpdateProtocolNoteRequest request) async {
    try {
      print('📝 ProtocolService.updateProtocolNote()');
      print('   Request: ${request.toJson()}');

      final response =
          await _dio.put('/protocols/my-note', data: request.toJson());

      print('✅ Update protocol note response received:');
      print('   Status: ${response.statusCode}');
      print('   Data: ${response.data}');

      return ProtocolResponse.fromJson(response.data);
    } catch (e) {
      print('❌ Error updating protocol note: $e');

      if (e is DioException) {
        print('   Status: ${e.response?.statusCode}');
        print('   Message: ${e.response?.data}');

        return ProtocolResponse(
          success: false,
          message: e.response?.data?['message'] ?? 'Qeyd yenilənmədi',
        );
      }

      return const ProtocolResponse(
        success: false,
        message: 'Şəbəkə xətası baş verdi',
      );
    }
  }

  /// Get all protocols for admins with filtering
  Future<ProtocolsResponse> getProtocols({
    int page = 1,
    int pageSize = 100,
    int? bina,
    String? startDate,
    String? endDate,
    String? examDate,
  }) async {
    try {
      print('📝 ProtocolService.getProtocols()');
      print('   page: $page, pageSize: $pageSize');
      print('   bina: $bina, examDate: $examDate');
      print('   startDate: $startDate, endDate: $endDate');

      String url = '/protocols';
      List<String> queryParams = [];

      // Add pagination
      queryParams.add('page=$page');
      queryParams.add('pageSize=$pageSize');

      // Add filters
      if (bina != null) {
        queryParams.add('bina=$bina');
      }

      if (startDate != null && startDate.isNotEmpty) {
        // Convert to ISO format if needed
        String isoStartDate = startDate;
        if (!startDate.contains('T')) {
          isoStartDate = '${startDate}T00:00:00.000Z';
        }
        queryParams.add('startDate=${Uri.encodeComponent(isoStartDate)}');
      }

      if (endDate != null && endDate.isNotEmpty) {
        // Convert to ISO format if needed
        String isoEndDate = endDate;
        if (!endDate.contains('T')) {
          isoEndDate = '${endDate}T23:59:59.999Z';
        }
        queryParams.add('endDate=${Uri.encodeComponent(isoEndDate)}');
      }

      if (examDate != null && examDate.isNotEmpty) {
        // Convert to ISO format if needed
        String isoExamDate = examDate;
        if (!examDate.contains('T')) {
          isoExamDate = '${examDate}T00:00:00.000Z';
        }
        queryParams.add('examDate=${Uri.encodeComponent(isoExamDate)}');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      print('   Final URL: $url');

      final response = await _dio.get(url);

      print('✅ Get protocols response received:');
      print('   Status: ${response.statusCode}');
      print('   Success: ${response.data['success']}');

      return ProtocolsResponse.fromJson(response.data);
    } catch (e) {
      print('❌ Error fetching protocols: $e');

      if (e is DioException) {
        print('   Status: ${e.response?.statusCode}');
        print('   Message: ${e.response?.data}');

        return ProtocolsResponse(
          success: false,
          message: e.response?.data?['message'] ?? 'Protokollar yüklənmədi',
        );
      }

      return const ProtocolsResponse(
        success: false,
        message: 'Şəbəkə xətası baş verdi',
      );
    }
  }

  /// Get protocol by ID
  Future<ProtocolResponse> getProtocolById(int id) async {
    try {
      print('📝 ProtocolService.getProtocolById($id)');

      final response = await _dio.get('/protocols/$id');

      print('✅ Get protocol by ID response received:');
      print('   Status: ${response.statusCode}');
      print('   Data: ${response.data}');

      return ProtocolResponse.fromJson(response.data);
    } catch (e) {
      print('❌ Error fetching protocol by ID: $e');

      if (e is DioException) {
        print('   Status: ${e.response?.statusCode}');
        print('   Message: ${e.response?.data}');

        return ProtocolResponse(
          success: false,
          message: e.response?.data?['message'] ?? 'Protokol tapılmadı',
        );
      }

      return const ProtocolResponse(
        success: false,
        message: 'Şəbəkə xətası baş verdi',
      );
    }
  }
}
