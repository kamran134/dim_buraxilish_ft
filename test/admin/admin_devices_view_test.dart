import 'package:dim_buraxilish_ft/models/admin_models.dart';
import 'package:dim_buraxilish_ft/screens/admin/devices/admin_devices_logic.dart';
import 'package:dim_buraxilish_ft/screens/admin/devices/admin_devices_view.dart';
import 'package:dim_buraxilish_ft/widgets/admin/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

final DateTime _now = DateTime(2026, 11, 3, 12, 0);

List<DeviceLogin> _logins() => [
      // Online, unsent records.
      DeviceLogin(
        buildingCode: '1001',
        buildingName: 'Bakı Dövlət Universiteti, Akademik Zahid Xəlilov küç. 23',
        deviceId: 'dev-1',
        deviceName: 'Samsung Galaxy A54',
        examDateRaw: '03.11.2026',
        downloadedAt: DateTime(2026, 11, 3, 8, 15),
        participantCount: 420,
        supervisorCount: 31,
        appVersion: '9.3.1',
        lastSeenAt: DateTime(2026, 11, 3, 11, 58),
        pendingParticipants: 3,
        pendingSupervisors: 1,
      ),
      // Second device of the same building, silent for an hour.
      DeviceLogin(
        buildingCode: '1001',
        buildingName: 'Bakı Dövlət Universiteti, Akademik Zahid Xəlilov küç. 23',
        deviceId: 'dev-2',
        deviceName: 'Xiaomi Redmi',
        examDateRaw: '03.11.2026',
        downloadedAt: DateTime(2026, 11, 3, 7, 40),
        participantCount: 420,
        supervisorCount: 31,
        appVersion: '9.3.1',
        lastSeenAt: DateTime(2026, 11, 3, 11, 0),
        pendingParticipants: 0,
        pendingSupervisors: 0,
      ),
      // Old app: no heartbeat data and no device name.
      const DeviceLogin(
        buildingCode: '1002',
        buildingName: 'Azərbaycan Texniki Universiteti',
        deviceId: 'dev-3',
      ),
      // Revoked.
      DeviceLogin(
        buildingCode: '1003',
        buildingName: 'Sumqayıt Dövlət Universiteti',
        deviceId: 'dev-4',
        deviceName: 'iPhone 13',
        isRevoked: true,
        revokedAt: DateTime(2026, 11, 3, 10, 5),
        lastSeenAt: DateTime(2026, 11, 3, 10, 0),
        appVersion: '9.2.0',
      ),
    ];

DownloadStatusReport _report() => DownloadStatusReport(
      summary: const DownloadStatusSummary(
        total: 3,
        downloaded: 1,
        notDownloaded: 1,
        noDevice: 1,
      ),
      buildings: [
        BuildingDownloadStatus(
          buildingCode: '1001',
          buildingName: 'Bakı Dövlət Universiteti',
          downloadedAt: DateTime(2026, 11, 3, 8, 15),
          participantCount: 420,
          supervisorCount: 31,
          state: BuildingDownloadState.downloaded,
        ),
        const BuildingDownloadStatus(
          buildingCode: '1002',
          buildingName: 'Azərbaycan Texniki Universiteti',
          state: BuildingDownloadState.notDownloaded,
        ),
        const BuildingDownloadStatus(
          buildingCode: '1004',
          buildingName: 'Gəncə Dövlət Universiteti',
          state: BuildingDownloadState.noDevice,
        ),
      ],
    );

Widget _view({
  List<DeviceLogin>? logins,
  String? error,
  DownloadStatusReport? report,
  String? reportError,
  bool hasExam = true,
  DateTime? date,
  bool revoking = false,
  VoidCallback? onRetry,
  ValueChanged<DateTime?>? onDateChanged,
  RevokeCallback? onRevoke,
}) =>
    AdminDevicesView(
      subtitle: '03.11.2026 · Sessiya 1',
      logins: logins,
      error: error,
      report: report,
      reportError: reportError,
      hasExam: hasExam,
      date: date,
      revoking: revoking,
      clock: () => _now,
      onRefresh: () async {},
      onRetry: onRetry,
      onDateChanged: onDateChanged ?? (_) {},
      onRevoke: onRevoke ?? (scope, {buildingCode, deviceId}) async {},
    );

void main() {
  group('models and logic', () {
    test('DeviceLogin.fromJson reads the API shape', () {
      final login = DeviceLogin.fromJson({
        'buildingCode': '1001',
        'deviceId': 'a',
        'lastSeenAt': '2026-11-03T11:58:00',
        'pendingParticipants': 2,
        'isRevoked': false,
      });
      expect(login.pendingTotal, 2);
      expect(login.hasPending, isTrue);
      expect(login.isRecentlySeen(_now), isTrue);
      expect(login.deviceName, isNull);

      final old = DeviceLogin.fromJson({'buildingCode': '5'});
      expect(old.pendingTotal, isNull);
      expect(old.isRecentlySeen(_now), isFalse);
    });

    test('online window is 10 minutes', () {
      final edge = DeviceLogin(
        buildingCode: '1',
        lastSeenAt: _now.subtract(const Duration(minutes: 10)),
      );
      final past = DeviceLogin(
        buildingCode: '1',
        lastSeenAt: _now.subtract(const Duration(minutes: 11)),
      );
      expect(edge.isRecentlySeen(_now), isTrue);
      expect(past.isRecentlySeen(_now), isFalse);
    });

    test('BuildingDownloadStatus.fromJson maps the status strings', () {
      BuildingDownloadState state(String status) =>
          BuildingDownloadStatus.fromJson(
            {'buildingCode': '1', 'status': status},
          ).state;
      expect(state('downloaded'), BuildingDownloadState.downloaded);
      expect(state('not_downloaded'), BuildingDownloadState.notDownloaded);
      expect(state('no_device'), BuildingDownloadState.noDevice);
    });

    test('filterDevices searches code, name, device and date', () {
      List<String?> ids(String q, [DeviceFilter f = DeviceFilter.all]) => [
            for (final d in filterDevices(
              _logins(),
              query: q,
              filter: f,
              now: _now,
            ))
              d.deviceId,
          ];
      expect(ids('1002'), ['dev-3']);
      expect(ids('samsung'), ['dev-1']);
      expect(ids('sumqayıt'), ['dev-4']);
      expect(ids('03.11.2026'), ['dev-1', 'dev-2']);
      expect(ids('', DeviceFilter.online), ['dev-1']);
      expect(ids('', DeviceFilter.offline), ['dev-2', 'dev-3']);
      expect(ids('', DeviceFilter.revoked), ['dev-4']);
      expect(ids('', DeviceFilter.pending), ['dev-1']);
    });

    test('sortDevices orders by code numerically and by date', () {
      final byCode = sortDevices(
        _logins(),
        DeviceSort.buildingCode,
        ascending: true,
      ).map((d) => d.buildingCode).toList();
      expect(byCode, ['1001', '1001', '1002', '1003']);

      final newestFirst = sortDevices(
        _logins(),
        DeviceSort.downloadedAt,
        ascending: false,
      ).map((d) => d.deviceId).toList();
      expect(newestFirst.first, 'dev-1');
      expect(newestFirst[1], 'dev-2');

      final byPending = sortDevices(
        _logins(),
        DeviceSort.pending,
        ascending: false,
      );
      expect(byPending.first.deviceId, 'dev-1');
    });

    test('DeviceCounts', () {
      final counts = DeviceCounts.of(_logins(), _now);
      expect(counts.total, 4);
      expect(counts.online, 1);
      expect(counts.revoked, 1);
      expect(counts.withPending, 1);
    });

    test('revoke confirmation warns about pending and unknown devices', () {
      final text = revokeConfirmationText(
        question: 'Bütün cihazlar deaktiv edilsin?',
        devices: _logins(),
        now: _now,
      );
      expect(text, startsWith('Bütün cihazlar deaktiv edilsin?'));
      expect(text, contains('giriş səhifəsinə yönləndiriləcək'));
      expect(text, contains('1 cihazda göndərilməmiş 4 qeyd var'));
      // dev-2 is silent, dev-3 never reported; dev-4 is already revoked.
      expect(text, contains('2 cihazın vəziyyəti naməlumdur'));

      final clean = revokeConfirmationText(
        question: 'q',
        devices: [_logins().first],
        now: _now,
      );
      expect(clean, isNot(contains('naməlumdur')));
    });

    test('filterBuildings by state and query', () {
      final all = _report().buildings;
      expect(
        filterBuildings(all, query: '', filter: BuildingFilter.noDevice)
            .map((b) => b.buildingCode),
        ['1004'],
      );
      expect(
        filterBuildings(all, query: 'texniki', filter: BuildingFilter.all)
            .map((b) => b.buildingCode),
        ['1002'],
      );
    });
  });

  group('AdminDevicesView', () {
    testAdminMatrix('devices list renders without overflow', (
      tester,
      size,
      scale,
      brightness,
    ) async {
      await pumpAdmin(
        tester,
        _view(logins: _logins(), report: _report()),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);
      expect(find.text('Cihazların statusu'), findsOneWidget);
      expect(find.text('Cəmi'), findsOneWidget);
      expect(find.text('Samsung Galaxy A54'), findsOneWidget);
      expect(find.text('iPhone 13'), findsOneWidget);
    });

    testAdminMatrix('buildings segment renders without overflow', (
      tester,
      size,
      scale,
      brightness,
    ) async {
      await pumpAdmin(
        tester,
        _view(logins: _logins(), report: _report()),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      await tester.tap(find.text('Binalar (baza yükləməsi)'));
      await tester.pump();
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);
      expect(find.text('Cəmi bina'), findsOneWidget);
      expect(find.text('Cihaz yoxdur'), findsWidgets);
    });

    testWidgets('shows the status badges of each device', (tester) async {
      await pumpAdmin(tester, _view(logins: _logins()));
      await expandViewport(tester, 412);
      expect(find.text('Deaktiv'), findsWidgets);
      expect(find.text('Oflayn'), findsWidgets);
      expect(find.text('4 göndərilməmiş'), findsOneWidget);
      expect(find.text('Binada 2 cihaz'), findsNWidgets(2));
      expect(find.text('naməlum'), findsWidgets);
    });

    testWidgets('status chip filters the list', (tester) async {
      await pumpAdmin(tester, _view(logins: _logins()));
      await expandViewport(tester, 412);
      await tester.tap(find.descendant(
        of: find.byType(AdminFilterChips<DeviceFilter>),
        matching: find.text('Deaktiv'),
      ));
      await tester.pump();
      expect(find.text('iPhone 13'), findsOneWidget);
      expect(find.text('Samsung Galaxy A54'), findsNothing);
    });

    testWidgets('search narrows the list', (tester) async {
      await pumpAdmin(tester, _view(logins: _logins()));
      await expandViewport(tester, 412);
      await tester.enterText(find.byType(TextField), 'xiaomi');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Xiaomi Redmi'), findsOneWidget);
      expect(find.text('Samsung Galaxy A54'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Heç bir giriş tapılmadı'), findsOneWidget);
    });

    testWidgets('revoking one device asks for confirmation first',
        (tester) async {
      final calls = <String>[];
      await pumpAdmin(
        tester,
        _view(
          logins: _logins(),
          onRevoke: (scope, {buildingCode, deviceId}) async =>
              calls.add('${scope.name}/$buildingCode/$deviceId'),
        ),
      );
      await expandViewport(tester, 412);

      await tester.tap(find.text('Cihazı deaktiv et').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('"Samsung Galaxy A54" cihazı'), findsOneWidget);
      expect(find.textContaining('göndərilməmiş 4 qeyd'), findsOneWidget);
      expect(calls, isEmpty);

      await tester.tap(find.text('Ləğv et'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);

      await tester.tap(find.text('Cihazı deaktiv et').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deaktiv et'));
      await tester.pumpAndSettle();
      expect(calls, ['device/1001/dev-1']);
    });

    testWidgets('building revoke counts the devices of the building',
        (tester) async {
      final calls = <String>[];
      await pumpAdmin(
        tester,
        _view(
          logins: _logins(),
          onRevoke: (scope, {buildingCode, deviceId}) async =>
              calls.add('${scope.name}/$buildingCode/$deviceId'),
        ),
      );
      await expandViewport(tester, 412);
      await tester.tap(find.text('Binanın bütün cihazlarını deaktiv et').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('üzrə bütün cihazlar (2)'), findsOneWidget);
      await tester.tap(find.text('Deaktiv et'));
      await tester.pumpAndSettle();
      expect(calls, ['building/1001/null']);
    });

    testWidgets('revoke-all lives in the menu and confirms', (tester) async {
      final calls = <String>[];
      await pumpAdmin(
        tester,
        _view(
          logins: _logins(),
          onRevoke: (scope, {buildingCode, deviceId}) async =>
              calls.add(scope.name),
        ),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bütün cihazları deaktiv et'));
      await tester.pumpAndSettle();
      expect(find.textContaining('BÜTÜN binaların cihazları (4)'), findsOneWidget);
      await tester.tap(find.text('Deaktiv et'));
      await tester.pumpAndSettle();
      expect(calls, ['all']);
    });

    testWidgets('revoked device and busy state disable the buttons',
        (tester) async {
      await pumpAdmin(tester, _view(logins: _logins(), revoking: true));
      await expandViewport(tester, 412);
      final buttons = tester
          .widgetList<TextButton>(find.byType(TextButton))
          .where((b) => b.onPressed == null);
      expect(buttons, isNotEmpty);
    });

    testWidgets('date filter: clear button reports null', (tester) async {
      final dates = <DateTime?>[];
      await pumpAdmin(
        tester,
        _view(
          logins: _logins(),
          date: DateTime(2026, 11, 2),
          onDateChanged: dates.add,
        ),
      );
      expect(find.textContaining('02.11.2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Tarix filterini sil'));
      expect(dates, [null]);
    });

    testWidgets('loading, error and empty states', (tester) async {
      await pumpAdmin(tester, _view());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      var retried = false;
      await pumpAdmin(
        tester,
        _view(error: 'Şəbəkə xətası', onRetry: () => retried = true),
      );
      expect(find.text('Şəbəkə xətası'), findsOneWidget);
      await tester.tap(find.text('Yenidən cəhd et'));
      expect(retried, isTrue);

      await pumpAdmin(tester, _view(logins: const []));
      expect(find.text('Heç bir giriş tapılmadı'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the rows and shows the error',
        (tester) async {
      await pumpAdmin(
        tester,
        _view(logins: _logins(), error: 'Cihazlar yüklənmədi'),
      );
      await expandViewport(tester, 412);
      expect(find.text('Cihazlar yüklənmədi'), findsOneWidget);
      expect(find.text('Samsung Galaxy A54'), findsOneWidget);
    });

    testWidgets('buildings segment without an exam', (tester) async {
      await pumpAdmin(tester, _view(logins: _logins(), hasExam: false));
      await tester.tap(find.text('Binalar (baza yükləməsi)'));
      await tester.pump();
      expect(find.text('İmtahan seçilməyib'), findsOneWidget);
    });

    testWidgets('buildings segment: filter by state', (tester) async {
      await pumpAdmin(tester, _view(logins: _logins(), report: _report()));
      await tester.tap(find.text('Binalar (baza yükləməsi)'));
      await tester.pump();
      await expandViewport(tester, 412);
      expect(find.text('Gəncə Dövlət Universiteti'), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byType(AdminFilterChips<BuildingFilter>),
        matching: find.text('Yüklənməyib'),
      ));
      await tester.pump();
      expect(find.text('Gəncə Dövlət Universiteti'), findsNothing);
      expect(find.text('Azərbaycan Texniki Universiteti'), findsOneWidget);
    });
  });
}
