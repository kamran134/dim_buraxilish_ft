import 'package:dio/dio.dart';

import '../models/admin_models.dart';
import '../models/response_models.dart';
import 'http_service.dart';

/// A 2xx answer whose body says `success: false`.
class _ApiFailure implements Exception {
  final String message;

  const _ApiFailure(this.message);
}

/// Admin-only endpoints: device status and revoke (`admin/*`), emergency
/// messages (`emergencymessages/*`) and the profile (`auth/me`).
///
/// Goes through [HttpService]'s dio, so the JWT, token refresh and the
/// `X-Exam-Slot` header are handled by its interceptor.
class AdminService {
  final HttpService _http;

  AdminService({HttpService? httpService}) : _http = httpService ?? HttpService();

  /// Runs [call]; a 2xx body goes through [parse], anything else becomes an
  /// error result with the server message (or [fallback]).
  Future<DataResult<T>> _run<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic> body) parse,
    String fallback,
  ) async {
    try {
      final response = await call();
      return DataResult<T>.success(
        data: parse(_asMap(response.data)),
        message: _asMap(response.data)['message']?.toString() ?? '',
      );
    } on DioException catch (e) {
      final message = _asMap(e.response?.data)['message'];
      if (e.response == null) {
        return DataResult<T>.error(message: 'Şəbəkə xətası: ${e.message}');
      }
      return DataResult<T>.error(
        message: message is String && message.isNotEmpty
            ? message
            : '$fallback (${e.response?.statusCode})',
      );
    } on _ApiFailure catch (e) {
      return DataResult<T>.error(message: e.message);
    } catch (e) {
      return DataResult<T>.error(message: '$fallback: $e');
    }
  }

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  List<Map<String, dynamic>> _mapList(dynamic data) => [
        for (final item in (data as List<dynamic>? ?? const []))
          if (item is Map) Map<String, dynamic>.from(item),
      ];

  /// Success body of the wrapped endpoints (`{success, message, data}`).
  T _wrapped<T>(Map<String, dynamic> body, T Function(dynamic data) parse) {
    if (body['success'] == false) {
      throw _ApiFailure(body['message']?.toString() ?? 'Əməliyyat alınmadı');
    }
    return parse(body['data']);
  }

  String _apiDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// All registered devices; [date] narrows the shown download to that day.
  Future<DataResult<List<DeviceLogin>>> getDeviceLogins({DateTime? date}) =>
      _run(
        () => _http.get(
          '/admin/devicelogins',
          query: date == null
              ? null
              : {'date': _apiDate(date)},
        ),
        (body) => [
          for (final json in _mapList(body['logins'])) DeviceLogin.fromJson(json),
        ],
        'Cihazlar yüklənmədi',
      );

  /// Download state per building for the active slot.
  Future<DataResult<DownloadStatusReport>> getDownloadStatus() => _run(
        () => _http.get('/admin/downloadstatus'),
        (body) => DownloadStatusReport(
          summary: DownloadStatusSummary.fromJson(_asMap(body['summary'])),
          buildings: [
            for (final json in _mapList(body['buildings']))
              BuildingDownloadStatus.fromJson(json),
          ],
        ),
        'Bina statusları yüklənmədi',
      );

  /// Deactivates one device, all devices of a building or all devices.
  Future<DataResult<RevokeResult>> revokeDevices(
    RevokeScope scope, {
    String? buildingCode,
    String? deviceId,
  }) =>
      _run(
        () => _http.post('/admin/devices/revoke', data: {
          'scope': scope.name,
          'buildingCode': buildingCode,
          'deviceId': deviceId,
        }),
        RevokeResult.fromJson,
        'Deaktiv etmək mümkün olmadı',
      );

  Future<DataResult<CurrentUser>> getCurrentUser() => _run(
        () => _http.get('/auth/me'),
        (body) => _wrapped(
          body,
          (data) => CurrentUser.fromJson(_asMap(data)),
        ),
        'Profil yüklənmədi',
      );

  /// Sends an emergency message; empty [buildingCodes] = all buildings.
  Future<Result> sendEmergencyMessage({
    required String title,
    required String body,
    required EmergencyImportance importance,
    required List<String> buildingCodes,
  }) async {
    final result = await _run<String>(
      () => _http.post('/emergencymessages/send', data: {
        'title': title,
        'body': body,
        'importance': importance.value,
        'buildingCodes': buildingCodes,
      }),
      (response) => _wrapped(
        response,
        (_) => response['message']?.toString() ?? 'Mesaj göndərildi',
      ),
      'Mesaj göndərilmədi. Yenidən cəhd edin',
    );
    return result.success
        ? Result.success(message: result.data ?? result.message)
        : Result.error(message: result.message);
  }

  Future<DataResult<List<EmergencyHistoryItem>>> getEmergencyHistory({
    int take = 50,
  }) =>
      _run(
        () => _http.get('/emergencymessages/history', query: {'take': take}),
        (body) => _wrapped(
          body,
          (data) => [
            for (final json in _mapList(data)) EmergencyHistoryItem.fromJson(json),
          ],
        ),
        'Tarixçə yüklənmədi',
      );
}
