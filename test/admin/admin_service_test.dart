import 'package:dim_buraxilish_ft/models/admin_models.dart';
import 'package:dim_buraxilish_ft/services/admin_service.dart';
import 'package:dim_buraxilish_ft/services/http_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the calls and answers from a canned handler.
class _FakeHttp extends HttpService {
  final Object? Function(String method, String path, Object? payload) handler;
  final List<String> calls = [];
  Object? lastPayload;

  _FakeHttp(this.handler);

  Response<dynamic> _respond(String method, String path, Object? payload) {
    calls.add('$method $path');
    lastPayload = payload;
    final result = handler(method, path, payload);
    if (result is DioException) throw result;
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: result,
    );
  }

  @override
  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) async =>
      _respond('GET', path, query);

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async =>
      _respond('POST', path, data);
}

DioException _httpError(int status, Object? body) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: body,
      ),
    );

void main() {
  test('getDeviceLogins parses logins and sends the date', () async {
    final http = _FakeHttp((_, __, ___) => {
          'count': 1,
          'logins': [
            {
              'buildingCode': '1001',
              'deviceId': 'a',
              'pendingParticipants': 2,
              'isRevoked': true,
            },
          ],
        });
    final result = await AdminService(httpService: http)
        .getDeviceLogins(date: DateTime(2026, 11, 3));
    expect(http.calls, ['GET /admin/devicelogins']);
    expect(http.lastPayload, {'date': '2026-11-03'});
    expect(result.data!.single.isRevoked, isTrue);
    expect(result.data!.single.pendingTotal, 2);

    await AdminService(httpService: http).getDeviceLogins();
    expect(http.lastPayload, isNull);
  });

  test('getDownloadStatus parses summary and buildings', () async {
    final http = _FakeHttp((_, __, ___) => {
          'summary': {'total': 2, 'downloaded': 1, 'notDownloaded': 1, 'noDevice': 0},
          'buildings': [
            {'buildingCode': '1', 'status': 'downloaded', 'participantCount': 5},
            {'buildingCode': '2', 'status': 'not_downloaded'},
          ],
        });
    final report = (await AdminService(httpService: http).getDownloadStatus()).data!;
    expect(report.summary.total, 2);
    expect(report.buildings.first.state, BuildingDownloadState.downloaded);
    expect(report.buildings.last.state, BuildingDownloadState.notDownloaded);
  });

  test('revokeDevices posts scope, building and device', () async {
    final http = _FakeHttp((_, __, ___) =>
        {'devices': 2, 'devicesWithPending': 1, 'refreshTokensRevoked': 3});
    final result = await AdminService(httpService: http).revokeDevices(
      RevokeScope.device,
      buildingCode: '1001',
      deviceId: 'dev',
    );
    expect(http.calls, ['POST /admin/devices/revoke']);
    expect(http.lastPayload, {
      'scope': 'device',
      'buildingCode': '1001',
      'deviceId': 'dev',
    });
    expect(result.data!.devices, 2);
    expect(result.data!.devicesWithPending, 1);
  });

  test('a server error carries its message; no response is a network error',
      () async {
    final withBody = _FakeHttp((_, __, ___) =>
        _httpError(400, {'success': false, 'message': 'scope: device'}));
    final bad = await AdminService(httpService: withBody)
        .revokeDevices(RevokeScope.all);
    expect(bad.success, isFalse);
    expect(bad.message, 'scope: device');

    final noBody = _FakeHttp((_, __, ___) => _httpError(500, null));
    final failed = await AdminService(httpService: noBody).getDeviceLogins();
    expect(failed.message, contains('500'));

    final offline = _FakeHttp((_, __, ___) =>
        DioException(requestOptions: RequestOptions(path: '/x')));
    final unreachable =
        await AdminService(httpService: offline).getDeviceLogins();
    expect(unreachable.message, startsWith('Şəbəkə xətası'));
  });

  test('getCurrentUser reads the wrapped profile', () async {
    final http = _FakeHttp((_, __, ___) => {
          'success': true,
          'data': {'userName': 'admin', 'role': 'admin', 'buildingCode': '0'},
        });
    final user = (await AdminService(httpService: http).getCurrentUser()).data!;
    expect(http.calls, ['GET /auth/me']);
    expect(user.userName, 'admin');
    expect(user.roleLabel, 'Administrator');

    final rejected = _FakeHttp(
        (_, __, ___) => {'success': false, 'message': 'Tapılmadı'});
    final result = await AdminService(httpService: rejected).getCurrentUser();
    expect(result.success, isFalse);
    expect(result.message, 'Tapılmadı');
  });

  test('sendEmergencyMessage posts the dto', () async {
    final http = _FakeHttp((_, __, ___) =>
        {'success': true, 'message': 'Təcili mesaj göndərildi.'});
    final result = await AdminService(httpService: http).sendEmergencyMessage(
      title: 'T',
      body: 'B',
      importance: EmergencyImportance.urgent,
      buildingCodes: ['1001'],
    );
    expect(http.calls, ['POST /emergencymessages/send']);
    expect(http.lastPayload, {
      'title': 'T',
      'body': 'B',
      'importance': 2,
      'buildingCodes': ['1001'],
    });
    expect(result.success, isTrue);
    expect(result.message, 'Təcili mesaj göndərildi.');

    final failing = _FakeHttp((_, __, ___) =>
        _httpError(403, {'message': 'İcazə yoxdur'}));
    final denied = await AdminService(httpService: failing).sendEmergencyMessage(
      title: 'T',
      body: 'B',
      importance: EmergencyImportance.info,
      buildingCodes: const [],
    );
    expect(denied.success, isFalse);
    expect(denied.message, 'İcazə yoxdur');
  });

  test('getEmergencyHistory parses messages with acks', () async {
    final http = _FakeHttp((_, __, ___) => {
          'success': true,
          'data': [
            {
              'id': 1,
              'title': 'T',
              'body': 'B',
              'importance': 2,
              'targetType': 'ALL',
              'ackCount': 1,
              'acks': [
                {'buildingCode': '1', 'buildingName': 'N'},
              ],
            },
          ],
        });
    final result =
        await AdminService(httpService: http).getEmergencyHistory(take: 20);
    expect(http.calls, ['GET /emergencymessages/history']);
    expect(http.lastPayload, {'take': 20});
    expect(result.data!.single.importance, EmergencyImportance.urgent);
    expect(result.data!.single.acks.single.buildingName, 'N');
  });
}
