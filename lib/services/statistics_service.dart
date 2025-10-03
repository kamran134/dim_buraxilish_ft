import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/exam_details_dto.dart';
import '../models/exam_statistics_dto.dart';
import '../models/response_models.dart';
import '../services/http_service.dart';

/// Сервис для работы с статистикой экзаменов
class StatisticsService {
  static const String _baseUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/api';
  final HttpService _httpService = HttpService();

  /// Получает все даты экзаменов
  Future<DataResult<List<String>>> getAllExamDates() async {
    try {
      final token = await _httpService.getToken();

      final response = await http.get(
        Uri.parse('$_baseUrl/buraxilishes/getallexamdate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          final List<String> examDates = data.map((e) => e.toString()).toList();

          return DataResult<List<String>>.success(
            data: examDates,
            message: jsonResponse['message'] ?? 'Tarixlər uğurla alındı',
          );
        } else {
          return DataResult<List<String>>.error(
            message: jsonResponse['message'] ?? 'Tarixlər alınmadı',
          );
        }
      } else {
        return DataResult<List<String>>.error(
          message: 'Server xətası: ${response.statusCode}',
        );
      }
    } catch (e) {
      return DataResult<List<String>>.error(
        message: 'Şəbəkə xətası: $e',
      );
    }
  }

  /// Получает все детали экзаменов для конкретной даты
  Future<DataResult<List<ExamDetailsDto>>> getAllExamDetailsInExamDate(
      String examDate) async {
    try {
      final token = await _httpService.getToken();

      final response = await http.get(
        Uri.parse(
            '$_baseUrl/buraxilishes/getallexamdetailsinexamdate?examDate=$examDate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          final List<ExamDetailsDto> examDetails = data
              .map((item) =>
                  ExamDetailsDto.fromJson(item as Map<String, dynamic>))
              .toList();

          return DataResult<List<ExamDetailsDto>>.success(
            data: examDetails,
            message: jsonResponse['message'] ?? 'Statistika uğurla alındı',
          );
        } else {
          return DataResult<List<ExamDetailsDto>>.error(
            message: jsonResponse['message'] ?? 'Statistika alınmadı',
          );
        }
      } else {
        return DataResult<List<ExamDetailsDto>>.error(
          message: 'Server xətası: ${response.statusCode}',
        );
      }
    } catch (e) {
      return DataResult<List<ExamDetailsDto>>.error(
        message: 'Şəbəkə xətası: $e',
      );
    }
  }

  /// Получает статистику для конкретного здания в определенную дату
  Future<DataResult<ExamDetailsDto>> getExamDetailsInExamDate(
      String bina, String examDate) async {
    try {
      final token = await _httpService.getToken();

      final response = await http.get(
        Uri.parse(
            '$_baseUrl/buraxilishes/getexamdetailsinexamdate?bina=$bina&examDate=$examDate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final Map<String, dynamic> data = jsonResponse['data'] ?? {};
          final ExamDetailsDto examDetails = ExamDetailsDto.fromJson(data);

          return DataResult<ExamDetailsDto>.success(
            data: examDetails,
            message:
                jsonResponse['message'] ?? 'Bina statistikası uğurla alındı',
          );
        } else {
          return DataResult<ExamDetailsDto>.error(
            message: jsonResponse['message'] ?? 'Bina statistikası alınmadı',
          );
        }
      } else {
        return DataResult<ExamDetailsDto>.error(
          message: 'Server xətası: ${response.statusCode}',
        );
      }
    } catch (e) {
      return DataResult<ExamDetailsDto>.error(
        message: 'Şəbəkə xətası: $e',
      );
    }
  }

  /// Получает комбинированную статистику экзаменов (участники + наблюдатели)
  Future<DataResult<List<ExamStatisticsDto>>> getExamStatisticsByDate(
      String examDate) async {
    try {
      final token = await _httpService.getToken();

      final response = await http.get(
        Uri.parse(
            '$_baseUrl/buraxilishes/getexamstatisticsbydate?examDate=$examDate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          final List<ExamStatisticsDto> examStatistics = data
              .map((item) =>
                  ExamStatisticsDto.fromJson(item as Map<String, dynamic>))
              .toList();

          return DataResult<List<ExamStatisticsDto>>.success(
            data: examStatistics,
            message:
                jsonResponse['message'] ?? 'Kombinə statistika uğurla alındı',
          );
        } else {
          return DataResult<List<ExamStatisticsDto>>.error(
            message: jsonResponse['message'] ?? 'Kombinə statistika alınmadı',
          );
        }
      } else {
        return DataResult<List<ExamStatisticsDto>>.error(
          message: 'Server xətası: ${response.statusCode}',
        );
      }
    } catch (e) {
      return DataResult<List<ExamStatisticsDto>>.error(
        message: 'Şəbəkə xətası: $e',
      );
    }
  }

  /// Получает реальную статистику Dashboard вместо моков
  Future<DataResult<DashboardStatistics>> getDashboardStatistics(
      String examDate) async {
    try {
      // Получаем все детали экзаменов
      final examDetailsResult = await getAllExamDetailsInExamDate(examDate);

      if (!examDetailsResult.success || examDetailsResult.data == null) {
        return DataResult<DashboardStatistics>.error(
          message: examDetailsResult.message,
        );
      }

      final examDetails = examDetailsResult.data!;
      final examSum = ExamStatisticsSum.fromExamDetailsList(examDetails);

      // Создаем статистику дашборда
      final dashboardStats = DashboardStatistics(
        totalParticipants: examSum.totalParticipants,
        totalRegistered: examSum.totalRegistered,
        totalUnregistered: examSum.totalUnregistered,
        totalBuildings: examDetails.length,
        registrationRate: examSum.registrationRate,
        examDetails: examDetails,
        examSum: examSum,
        examDate: examDate,
      );

      return DataResult<DashboardStatistics>.success(
        data: dashboardStats,
        message: 'Dashboard statistikası uğurla alındı',
      );
    } catch (e) {
      return DataResult<DashboardStatistics>.error(
        message: 'Dashboard statistikası alınmadı: $e',
      );
    }
  }
}

/// Модель для статистики Dashboard
class DashboardStatistics {
  final int totalParticipants;
  final int totalRegistered;
  final int totalUnregistered;
  final int totalBuildings;
  final double registrationRate;
  final List<ExamDetailsDto> examDetails;
  final ExamStatisticsSum examSum;
  final String examDate;

  DashboardStatistics({
    required this.totalParticipants,
    required this.totalRegistered,
    required this.totalUnregistered,
    required this.totalBuildings,
    required this.registrationRate,
    required this.examDetails,
    required this.examSum,
    required this.examDate,
  });
}
