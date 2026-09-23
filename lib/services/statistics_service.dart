import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/exam_details_dto.dart';
import '../models/exam_statistics_dto.dart';
import '../models/participant_light_dto.dart';
import '../models/monitor_models.dart';
import '../models/supervisor_detail_dto.dart';
import '../models/monitor_room_statistics.dart';
import '../models/response_models.dart';
import '../services/database_service.dart';
import '../services/http_service.dart';

/// Status code + decoded JSON body of one statistics request.
class _ApiResponse {
  final int statusCode;
  final Map<String, dynamic>? body;

  const _ApiResponse(this.statusCode, this.body);
}

/// Сервис для работы с статистикой экзаменов.
///
/// Все запросы идут через dio из [HttpService] — тот же interceptor, что
/// ставит JWT, обновляет токен и добавляет `X-Exam-Slot` (см. API_slots.md),
/// поэтому сервер фильтрует статистику по выбранному слоту.
class StatisticsService {
  final HttpService _httpService = HttpService();

  /// `imtTarix` (legacyDate) активного слота — дата, которую экраны
  /// статистики передают как `examDate`. null, если слот не выбран.
  Future<String?> getActiveSlotExamDate() async {
    final details = await _httpService.getExamDetailsFromStorage();
    final slotKey = details?.slotKey;
    final examDate = details?.imtTarix;
    if (slotKey == null ||
        slotKey.isEmpty ||
        examDate == null ||
        examDate.isEmpty) {
      return null;
    }
    return examDate;
  }

  /// GET через общий dio. Ответ с кодом ошибки (dio бросает DioException)
  /// превращается в [_ApiResponse] с этим кодом; сетевые ошибки без ответа
  /// пробрасываются дальше — их ловят вызывающие методы.
  Future<_ApiResponse> _get(String path, Map<String, dynamic> query) async {
    try {
      final response = await _httpService.get(path, query: query);
      return _ApiResponse(response.statusCode ?? 0, _asMap(response.data));
    } on DioException catch (e) {
      final response = e.response;
      if (response == null) rethrow;
      return _ApiResponse(response.statusCode ?? 0, _asMap(response.data));
    }
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = json.decode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  /// Сообщение для ответа не-200: текст сервера (например, 400 на неверный
  /// `X-Exam-Slot`), иначе код.
  String _serverError(_ApiResponse response) {
    final message = response.body?['message'];
    if (message is String && message.isNotEmpty) return message;
    return 'Server xətası: ${response.statusCode}';
  }

  /// Получает все даты экзаменов (легаси-список; экраны статистики его больше
  /// не используют — дата берётся из выбранного слота).
  Future<DataResult<List<String>>> getAllExamDates() async {
    try {
      final response = await _get('/buraxilishes/getallexamdate', {});

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = response.body ?? {};

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
          message: _serverError(response),
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
      final response = await _get(
        '/buraxilishes/getallexamdetailsinexamdate',
        {'examDate': examDate},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = response.body ?? {};

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
          message: _serverError(response),
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
      final response = await _get(
        '/buraxilishes/getexamdetailsinexamdate',
        {'bina': bina, 'examDate': examDate},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = response.body ?? {};

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
          message: _serverError(response),
        );
      }
    } catch (e) {
      return DataResult<ExamDetailsDto>.error(
        message: 'Şəbəkə xətası: $e',
      );
    }
  }

  /// Получает комбинированную статистику экзаменов (участники + наблюдатели)
  /// ОБХОДНОЙ ПУТЬ: вызываем два отдельных эндпоинта и объединяем данные
  Future<DataResult<List<ExamStatisticsDto>>> getExamStatisticsByDate(
      String examDate) async {
    try {
      final formattedExamDate = _convertToMMDDYYYY(examDate);

      // 1. Получаем данные участников (используем ФОРМАТИРОВАННУЮ дату!)
      final participantsResponse = await _get(
        '/buraxilishes/getallexamdetailsinexamdate',
        {'examDate': formattedExamDate},
      );

      // 2. Получаем данные супервайзеров
      final supervisorsResponse = await _get(
        '/supervisors/GetAllExamDetailsInExamDate',
        {'examDate': formattedExamDate},
      );

      // 3. Получаем данные мониторов
      final monitorsResponse = await _get(
        '/monitors/GetAllExamDetailsInExamDate',
        {'examDate': formattedExamDate},
      );

      if (participantsResponse.statusCode == 200) {
        final participantsJson = participantsResponse.body ?? {};
        final List<dynamic> participantsData = participantsJson['data'] ?? [];

        // Создаем Map для быстрого поиска
        Map<String, dynamic> participantsByBuilding = {};
        Map<String, dynamic> supervisorsByBuilding = {};

        // Индексируем участников по kod_Bina
        for (var participant in participantsData) {
          final buildingCode = participant['kod_Bina']?.toString() ?? '';
          if (buildingCode.isNotEmpty) {
            participantsByBuilding[buildingCode] = participant;
          }
        }

        if (supervisorsResponse.statusCode == 200) {
          final supervisorsJson = supervisorsResponse.body ?? {};
          final List<dynamic> supervisorsData = supervisorsJson['data'] ?? [];

          // Индексируем супервайзеров по buildingCode
          for (var supervisor in supervisorsData) {
            final buildingCode = supervisor['buildingCode']?.toString() ?? '';
            if (buildingCode.isNotEmpty) {
              supervisorsByBuilding[buildingCode] = supervisor;
            }
          }
        }

        // Обрабатываем данные мониторов
        // ВАЖНО: Мониторы группируются по комнатам (roomId), а не по зданиям (buildingCode)
        // Поэтому суммируем общее количество мониторов со всех комнат
        int totalMonitorCount = 0;
        int totalRegMonitorCount = 0;

        if (monitorsResponse.statusCode == 200) {
          final monitorsJson = monitorsResponse.body ?? {};
          final List<dynamic> monitorsData = monitorsJson['data'] ?? [];

          // Суммируем всех мониторов со всех комнат
          for (var monitor in monitorsData) {
            final allPersonCount = monitor['allPersonCount'] as int? ?? 0;
            final regPersonCount = monitor['regPersonCount'] as int? ?? 0;

            totalMonitorCount += allPersonCount;
            totalRegMonitorCount += regPersonCount;
          }
        }

        // Получаем все уникальные buildingCode из участников и супервайзеров
        final allBuildingCodes = <String>{
          ...participantsByBuilding.keys,
          ...supervisorsByBuilding.keys,
        };

        // Объединяем данные для всех зданий
        final List<ExamStatisticsDto> examStatistics = [];

        for (var buildingCode in allBuildingCodes) {
          final participant = participantsByBuilding[buildingCode];
          final supervisor = supervisorsByBuilding[buildingCode];

          examStatistics.add(ExamStatisticsDto(
            // Данные участников (если есть)
            kodBina: participant?['kod_Bina']?.toString() ?? buildingCode,
            adBina: participant?['ad_Bina'] ??
                supervisor?['buildingName'] ??
                'Bina $buildingCode',
            erize: participant?['erize'],
            imtBegin: participant?['imt_Begin'],
            imtTarix: participant?['imt_Tarix'],
            allManCount: participant?['allManCount'] ?? 0,
            regManCount: participant?['regManCount'] ?? 0,
            allWomanCount: participant?['allWomanCount'] ?? 0,
            regWomanCount: participant?['regWomanCount'] ?? 0,
            // Данные супервайзеров (если есть)
            supervisorCount: supervisor?['allPersonCount'] ?? 0,
            regSupervisorCount: supervisor?['regPersonCount'] ?? 0,
            hallCount: supervisor?['hallCount'] ?? 0,
            // Данные мониторов - НЕ добавляем в каждое здание, это глобальная статистика
            monitorCount: 0,
            regMonitorCount: 0,
          ));
        }

        // Добавляем данные мониторов в результат для использования в дашборде
        if (examStatistics.isNotEmpty && totalMonitorCount > 0) {
          // Добавляем данные мониторов только к первому зданию для экономии памяти
          examStatistics[0] = ExamStatisticsDto(
            kodBina: examStatistics[0].kodBina,
            adBina: examStatistics[0].adBina,
            erize: examStatistics[0].erize,
            imtBegin: examStatistics[0].imtBegin,
            imtTarix: examStatistics[0].imtTarix,
            allManCount: examStatistics[0].allManCount,
            regManCount: examStatistics[0].regManCount,
            allWomanCount: examStatistics[0].allWomanCount,
            regWomanCount: examStatistics[0].regWomanCount,
            supervisorCount: examStatistics[0].supervisorCount,
            regSupervisorCount: examStatistics[0].regSupervisorCount,
            hallCount: examStatistics[0].hallCount,
            // Добавляем глобальные данные мониторов только к первому элементу
            monitorCount: totalMonitorCount,
            regMonitorCount: totalRegMonitorCount,
          );
        }

        return DataResult<List<ExamStatisticsDto>>.success(
          data: examStatistics,
          message: 'Kombinə statistika uğurla alındı',
        );
      } else {
        return DataResult<List<ExamStatisticsDto>>.error(
          message: _serverError(participantsResponse),
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
      final response = await _get(
        '/buraxilishes/getallparticipantlightinbuildingandexamdate',
        {'bina': bina, 'examDate': examDate},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = response.body ?? {};

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
          message: _serverError(response),
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
      // Преобразуем buildingCode в число (Angular ожидает number)
      final buildingCodeNum = int.tryParse(buildingCode) ?? 0;

      // Преобразуем дату в формат MM/DD/yyyy [HH:mm] как делает Angular
      final formattedExamDate = _convertToMMDDYYYYWithSession(examDate);

      final response = await _get(
        '/supervisors/GetAllSupervisorDetailDtoInExamDateAndBuilding',
        {
          'buildingCode': buildingCodeNum.toString(),
          'examDate': formattedExamDate,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = response.body ?? {};

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
          message: _serverError(response),
        );
      }
    } catch (e) {
      return DataResult<List<SupervisorDetailDto>>.error(
        message: 'Şəbəkə xətası: $e',
      );
    }
  }

  /// Получает статистику по всем комнатам для конкретной даты экзамена
  Future<DataResult<List<MonitorRoomStatistics>>> getAllRoomStatistics(
      String examDate) async {
    final localRegisteredMonitors =
        await DatabaseService.getRegisteredMonitors(examDate: examDate);

    try {
      // Преобразуем дату в формат MM/DD/yyyy как делает Angular
      final formattedExamDate = _convertToMMDDYYYY(examDate);

      final response = await _get(
        '/monitors/GetAllExamDetailsInExamDate',
        {'examDate': formattedExamDate},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = response.body ?? {};

        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'] ?? [];
          final List<MonitorRoomStatistics> apiRoomStats = data
              .map((item) =>
                  MonitorRoomStatistics.fromJson(item as Map<String, dynamic>))
              .toList();

          final mergedRoomStats = _mergeRoomStatisticsWithLocal(
            apiRoomStats,
            localRegisteredMonitors,
          );

          return DataResult<List<MonitorRoomStatistics>>.success(
            data: mergedRoomStats,
            message:
                jsonResponse['message'] ?? 'Otaq statistikaları uğurla alındı',
          );
        } else {
          if (localRegisteredMonitors.isNotEmpty) {
            return DataResult<List<MonitorRoomStatistics>>.success(
              data: _buildRoomStatisticsFromLocal(localRegisteredMonitors),
              message: 'Lokal statistikalar göstərilir',
            );
          }

          return DataResult<List<MonitorRoomStatistics>>.error(
            message: jsonResponse['message'] ?? 'Otaq statistikaları alınmadı',
          );
        }
      } else {
        // 400 = rejected `X-Exam-Slot` — never paper over it with local
        // data (API_slots.md: no silent fallback when the header is present).
        if (response.statusCode != 400 && localRegisteredMonitors.isNotEmpty) {
          return DataResult<List<MonitorRoomStatistics>>.success(
            data: _buildRoomStatisticsFromLocal(localRegisteredMonitors),
            message: 'Lokal statistikalar göstərilir',
          );
        }

        return DataResult<List<MonitorRoomStatistics>>.error(
          message: _serverError(response),
        );
      }
    } catch (e) {
      if (localRegisteredMonitors.isNotEmpty) {
        return DataResult<List<MonitorRoomStatistics>>.success(
          data: _buildRoomStatisticsFromLocal(localRegisteredMonitors),
          message: 'Lokal statistikalar göstərilir',
        );
      }

      return DataResult<List<MonitorRoomStatistics>>.error(
        message: 'Şəbəkə xətası: $e',
      );
    }
  }

  List<MonitorRoomStatistics> _mergeRoomStatisticsWithLocal(
    List<MonitorRoomStatistics> apiStats,
    List<Monitor> localRegisteredMonitors,
  ) {
    if (localRegisteredMonitors.isEmpty) {
      return apiStats;
    }

    final Map<int, int> localRegisteredCountByRoom = {};
    final Map<int, String> localRoomNames = {};
    final Map<int, String> localExamDates = {};

    for (final monitor in localRegisteredMonitors) {
      localRegisteredCountByRoom[monitor.roomId] =
          (localRegisteredCountByRoom[monitor.roomId] ?? 0) + 1;
      localRoomNames[monitor.roomId] = monitor.roomName;
      localExamDates[monitor.roomId] = monitor.examDate;
    }

    final Map<int, MonitorRoomStatistics> mergedByRoom = {
      for (final room in apiStats) room.roomId: room,
    };

    for (final entry in localRegisteredCountByRoom.entries) {
      final roomId = entry.key;
      final localRegisteredCount = entry.value;

      final existing = mergedByRoom[roomId];
      if (existing != null) {
        mergedByRoom[roomId] = MonitorRoomStatistics(
          roomId: existing.roomId,
          roomName: existing.roomName,
          examDate: existing.examDate,
          allPersonCount: existing.allPersonCount,
          regPersonCount: localRegisteredCount > existing.regPersonCount
              ? localRegisteredCount
              : existing.regPersonCount,
        );
      } else {
        mergedByRoom[roomId] = MonitorRoomStatistics(
          roomId: roomId,
          roomName: localRoomNames[roomId] ?? 'Otaq $roomId',
          examDate: localExamDates[roomId] ?? '',
          allPersonCount: localRegisteredCount,
          regPersonCount: localRegisteredCount,
        );
      }
    }

    final mergedList = mergedByRoom.values.toList();
    mergedList.sort((a, b) => a.roomName.compareTo(b.roomName));
    return mergedList;
  }

  List<MonitorRoomStatistics> _buildRoomStatisticsFromLocal(
      List<Monitor> localRegisteredMonitors) {
    final Map<int, List<Monitor>> byRoom = {};

    for (final monitor in localRegisteredMonitors) {
      byRoom.putIfAbsent(monitor.roomId, () => []);
      byRoom[monitor.roomId]!.add(monitor);
    }

    final localStats = byRoom.entries.map((entry) {
      final monitors = entry.value;
      final first = monitors.first;
      final count = monitors.length;

      return MonitorRoomStatistics(
        roomId: entry.key,
        roomName: first.roomName,
        examDate: first.examDate,
        allPersonCount: count,
        regPersonCount: count,
      );
    }).toList();

    localStats.sort((a, b) => a.roomName.compareTo(b.roomName));
    return localStats;
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

  /// То же, что _convertToMMDDYYYY, но сохраняет время сеанса ("HH:mm"), если оно есть.
  /// Только для запросов по nəzarətçilər (Supervisor) — у участников и мониторов
  /// времени сеанса нет.
  String _convertToMMDDYYYYWithSession(String examDate) {
    final converted = _convertToMMDDYYYY(examDate);
    if (converted == examDate) {
      return converted;
    }
    final lastToken = examDate.split(' ').last;
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(lastToken)) {
      return '$converted $lastToken';
    }
    return converted;
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
