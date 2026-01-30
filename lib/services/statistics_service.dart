import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/exam_details_dto.dart';
import '../models/exam_statistics_dto.dart';
import '../models/participant_light_dto.dart';
import '../models/supervisor_detail_dto.dart';
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

  /// Получает список участников по зданию и дате экзамена
  Future<DataResult<List<ParticipantLightDto>>> getAllParticipantsInBuilding(
      String bina, String examDate) async {
    try {
      final token = await _httpService.getToken();

      if (kDebugMode) {
        debugPrint(
            '[Statistics] getAllParticipantsInBuilding: bina=$bina, examDate=$examDate');
      }

      final url =
          '$_baseUrl/buraxilishes/getallparticipantlightinbuildingandexamdate?bina=$bina&examDate=$examDate';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        debugPrint('[Statistics] Response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          final List<ParticipantLightDto> participants = data
              .map((item) =>
                  ParticipantLightDto.fromJson(item as Map<String, dynamic>))
              .toList();

          return DataResult<List<ParticipantLightDto>>.success(
            data: participants,
            message: jsonResponse['message'] ?? 'İştirakçılar uğurla alındı',
          );
        } else {
          return DataResult<List<ParticipantLightDto>>.error(
            message: jsonResponse['message'] ?? 'İştirakçılar alınmadı',
          );
        }
      } else {
        return DataResult<List<ParticipantLightDto>>.error(
          message: 'Server xətası: ${response.statusCode}',
        );
      }
    } catch (e) {
      return DataResult<List<ParticipantLightDto>>.error(
        message: 'Şəbəkə xətası: $e',
      );
    }
  }

  /// Получает список наблюдателей по зданию и дате экзамена
  Future<DataResult<List<SupervisorDetailDto>>> getAllSupervisorsInBuilding(
      String buildingCode, String examDate) async {
    try {
      final token = await _httpService.getToken();

      if (kDebugMode) {
        debugPrint(
            '[Statistics] getAllSupervisorsInBuilding: buildingCode=$buildingCode, examDate=$examDate');
      }

      // Преобразуем buildingCode в число (Angular ожидает number)
      final buildingCodeNum = int.tryParse(buildingCode) ?? 0;

      // Преобразуем дату в формат MM/DD/yyyy как делает Angular
      final formattedExamDate = _convertToMMDDYYYY(examDate);

      if (kDebugMode) {
        debugPrint(
            '[Statistics] buildingCodeNum=$buildingCodeNum, formattedDate=$formattedExamDate');
      }

      final url =
          '$_baseUrl/supervisors/GetAllSupervisorDetailDtoInExamDateAndBuilding?buildingCode=$buildingCodeNum&examDate=$formattedExamDate';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        debugPrint('[Statistics] Response status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          final List<SupervisorDetailDto> supervisors = data
              .map((item) =>
                  SupervisorDetailDto.fromJson(item as Map<String, dynamic>))
              .toList();

          return DataResult<List<SupervisorDetailDto>>.success(
            data: supervisors,
            message: jsonResponse['message'] ?? 'Nəzarətçilər uğurla alındı',
          );
        } else {
          return DataResult<List<SupervisorDetailDto>>.error(
            message: jsonResponse['message'] ?? 'Nəzarətçilər alınmadı',
          );
        }
      } else {
        return DataResult<List<SupervisorDetailDto>>.error(
          message: 'Server xətası: ${response.statusCode}',
        );
      }
    } catch (e) {
      return DataResult<List<SupervisorDetailDto>>.error(
        message: 'Şəbəkə xətası: $e',
      );
    }
  }

  /// Преобразует дату из азербайджанского формата в MM/DD/yyyy
  /// Копирует логику из Angular HelperService.convertToDate()
  String _convertToMMDDYYYY(String examDate) {
    // Если дата уже в правильном формате, возвращаем как есть
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(examDate)) {
      return examDate;
    }

    // Разбираем азербайджанскую дату: "5 oktyabr 2025-ci il"
    final parts = examDate.split(' ');
    if (parts.length < 3) {
      return examDate; // Если формат не подходит, возвращаем как есть
    }

    final day = parts[0].padLeft(2, '0'); // Добавляем ведущий ноль если нужно
    final monthName = parts[1].toLowerCase();
    final year = parts[2].replaceAll(RegExp(r'[^\d]'), ''); // Убираем "-ci il"

    // Преобразуем названия месяцев в номера (копируем логику Angular)
    String month;
    switch (monthName) {
      case 'yanvar':
        month = '01';
        break;
      case 'fevral':
        month = '02';
        break;
      case 'mart':
        month = '03';
        break;
      case 'aprel':
        month = '04';
        break;
      case 'may':
        month = '05';
        break;
      case 'iyun':
        month = '06';
        break;
      case 'iyul':
        month = '07';
        break;
      case 'avqust':
        month = '08';
        break;
      case 'sentyabr':
        month = '09';
        break;
      case 'oktyabr':
        month = '10';
        break;
      case 'noyabr':
        month = '11';
        break;
      case 'dekabr':
        month = '12';
        break;
      default:
        return examDate; // Если месяц неизвестен, возвращаем как есть
    }

    // Возвращаем в формате MM/DD/yyyy
    return '$month/$day/$year';
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
