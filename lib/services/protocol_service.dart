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
      final response = await _dio.get('/notetypes');

      final noteTypesResponse = NoteTypesResponse.fromJson(response.data);

      return noteTypesResponse;
    } catch (e) {
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
      String url = '/protocols/my-notes';

      // Add examDate filter if provided
      if (examDate != null && examDate.isNotEmpty) {
        // Convert to ISO format for API
        final isoDate = DateFormatter.azerbaijaniDateToISO(examDate);
        if (isoDate != null) {
          url += '?examDate=${Uri.encodeComponent(isoDate)}';
        }
      }

      final response = await _dio.get(url);

      if (response.data['success'] == true && response.data['data'] != null) {
        final notes = (response.data['data'] as List)
            .map((json) => ProtocolNote.fromJson(json))
            .toList();

        return notes;
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Create new protocol note (for monitors)
  Future<ProtocolResponse> createProtocolNote(
      CreateProtocolNoteRequest request) async {
    try {
      final response =
          await _dio.post('/protocols/my-note', data: request.toJson());

      return ProtocolResponse.fromJson(response.data);
    } catch (e) {
      if (e is DioException) {
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
      final response =
          await _dio.put('/protocols/my-note', data: request.toJson());

      return ProtocolResponse.fromJson(response.data);
    } catch (e) {
      if (e is DioException) {
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

      final response = await _dio.get(url);

      return ProtocolsResponse.fromJson(response.data);
    } catch (e) {
      if (e is DioException) {
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
      final response = await _dio.get('/protocols/$id');

      return ProtocolResponse.fromJson(response.data);
    } catch (e) {
      if (e is DioException) {
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
