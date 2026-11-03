import 'package:dim_buraxilish_ft/models/monitor_models.dart';
import 'package:dim_buraxilish_ft/screens/admin/scan/admin_monitor_search_view.dart';
import 'package:dim_buraxilish_ft/screens/admin/scan/admin_scan_views.dart';
import 'package:dim_buraxilish_ft/screens/admin/scan/scan_activity_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

const Monitor _monitor = Monitor(
  workNumber: 501,
  firstName: 'Kamran',
  lastName: 'Kazımov',
  middleName: 'Elxan oğlu',
  idCardPin: '1ABC234',
  phone: '050 111 22 33, 055 444 55 66',
  buildingCode: 1001,
  buildingName: 'Azərbaycan Dövlət İqtisad Universitetinin əsas korpusu',
  roomId: 11,
  roomName: 'Otaq 11',
  examDate: '',
  registerDate: '2026-11-03T09:00:00',
  image: '',
  id: 5,
);

const Monitor _bareMonitor = Monitor(
  workNumber: 502,
  firstName: 'Leyla',
  lastName: 'Qasımova',
  middleName: '',
  idCardPin: '',
  buildingCode: 0,
  buildingName: '',
  roomId: 12,
  roomName: '',
  examDate: '',
  registerDate: 'null',
  image: '',
);

void main() {
  group('AdminScanHomeView', () {
    testAdminMatrix('buttons and error', (tester, size, scale, brightness) async {
      var scans = 0;
      await pumpAdmin(
        tester,
        AdminScanHomeView(
          inShell: true,
          onMenu: () {},
          errorMessage: 'Uzun xəta mətni: ' * 6,
          onScan: () => scans++,
          onManualInput: () {},
          onSearch: () {},
        ),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Skan et'), findsOneWidget);
      expect(find.text('Əllə daxil et'), findsOneWidget);
      expect(find.text('Ad ilə axtar'), findsOneWidget);
      expect(find.byTooltip('Menyu'), findsOneWidget);
      await tester.ensureVisible(find.text('Skan et'));
      await tester.tap(find.text('Skan et'));
      expect(scans, 1);
    });

    testWidgets('loading hides the error', (tester) async {
      await pumpAdmin(
        tester,
        AdminScanHomeView(
          loading: true,
          errorMessage: 'Xəta',
          onScan: () {},
          onManualInput: () {},
          onSearch: () {},
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Xəta'), findsNothing);
    });
  });

  group('AdminScanResultView', () {
    testAdminMatrix('full and bare monitor',
        (tester, size, scale, brightness) async {
      for (final monitor in [_monitor, _bareMonitor]) {
        await pumpAdmin(
          tester,
          AdminScanResultView(
            monitor: monitor,
            successMessage: 'İmtahan rəhbəri məlumatları uğurla oxundu',
            isRepeatEntry: monitor == _bareMonitor,
            onBack: () {},
            onNext: () {},
            onCancelRegistration: () {},
            onCall: (_) {},
          ),
          size: size,
          textScale: scale,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Növbəti'), findsOneWidget);
        expect(find.text('Ləğv et'), findsOneWidget);
      }
      await pumpAdmin(
        tester,
        AdminScanResultView(
          monitor: _monitor,
          onBack: () {},
          onNext: () {},
          onCancelRegistration: () {},
          onCall: (_) {},
        ),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      expect(find.text('Kazımov Kamran Elxan oğlu'), findsNothing);
      expect(find.text('Kamran Kazımov Elxan oğlu'), findsOneWidget);
      expect(find.text('050 111 22 33'), findsOneWidget);
      expect(find.text('Qeydiyyatdan keçdi'), findsOneWidget);
    });

    testWidgets('cancel asks for confirmation first', (tester) async {
      var cancelled = 0;
      await pumpAdmin(
        tester,
        AdminScanResultView(
          monitor: _monitor,
          onBack: () {},
          onNext: () {},
          onCancelRegistration: () => cancelled++,
          onCall: (_) {},
        ),
      );
      await tester.tap(find.text('Ləğv et'));
      await tester.pumpAndSettle();
      expect(find.text('Təsdiq'), findsOneWidget);
      expect(cancelled, 0);

      await tester.tap(find.text('Xeyr'));
      await tester.pumpAndSettle();
      expect(cancelled, 0);

      await tester.tap(find.text('Ləğv et'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bəli'));
      await tester.pumpAndSettle();
      expect(cancelled, 1);
    });

    testWidgets('phone chip hands the number to onCall', (tester) async {
      String? called;
      await pumpAdmin(
        tester,
        AdminScanResultView(
          monitor: _monitor,
          onBack: () {},
          onNext: () {},
          onCancelRegistration: () {},
          onCall: (phone) => called = phone,
        ),
      );
      await tester.tap(find.text('055 444 55 66'));
      expect(called, '055 444 55 66');
    });
  });

  group('AdminScanErrorView', () {
    testAdminMatrix('message and actions',
        (tester, size, scale, brightness) async {
      var rescans = 0;
      await pumpAdmin(
        tester,
        AdminScanErrorView(
          message: 'İmtahan rəhbəri tapılmadı: ' * 5,
          onBack: () {},
          onRescan: () => rescans++,
        ),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Xəta baş verdi'), findsOneWidget);
      await tester.ensureVisible(find.text('Yenidən skanla'));
      await tester.tap(find.text('Yenidən skanla'));
      expect(rescans, 1);
      expect(find.text('Geri qayıt'), findsOneWidget);
    });
  });

  group('AdminMonitorSearchView', () {
    Widget view({
      String query = '',
      List<Monitor> results = const [],
      bool loading = false,
      String? message,
      ValueChanged<String>? onCopy,
    }) =>
        AdminMonitorSearchView(
          query: query,
          results: results,
          loading: loading,
          message: message,
          onQueryChanged: (_) {},
          onCopyWorkNumber: onCopy ?? (_) {},
          onCall: (_) {},
        );

    testAdminMatrix('hint, empty, loading and results',
        (tester, size, scale, brightness) async {
      Future<void> pump(Widget w) => pumpAdmin(
            tester,
            w,
            size: size,
            textScale: scale,
            brightness: brightness,
          );

      await pump(view());
      expect(find.text('Axtarmaq üçün ən az 2 simvol daxil edin'),
          findsOneWidget);

      await pump(view(query: 'ka', loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pump(view(query: 'ka', message: '"ka" axtarışı üzrə nəticə '
          'tapılmadı'));
      expect(find.textContaining('nəticə tapılmadı'), findsOneWidget);

      await pump(view(query: 'ka', results: [_monitor, _bareMonitor]));
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);
      expect(find.text('Kazımov Kamran Elxan oğlu'), findsOneWidget);
      expect(find.text('İş № 501'), findsOneWidget);
      expect(find.text('İş № 502'), findsOneWidget);
    });

    testWidgets('copy button reports the work number', (tester) async {
      String? copied;
      await pumpAdmin(
        tester,
        view(query: 'ka', results: [_monitor], onCopy: (v) => copied = v),
      );
      await tester.tap(find.text('Kopyala'));
      expect(copied, '501');
    });
  });

  group('ScanActivityGuard', () {
    Widget host({
      required bool active,
      required VoidCallback onDeactivate,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: ScanActivityGuard(
              active: active,
              onDeactivate: onDeactivate,
              child: const Text('camera'),
            ),
          ),
        );

    testWidgets('stays quiet while active', (tester) async {
      var stops = 0;
      await tester.pumpWidget(host(active: true, onDeactivate: () => stops++));
      await tester.pump();
      expect(stops, 0);
    });

    testWidgets('stops once when the tab is left', (tester) async {
      var stops = 0;
      await tester.pumpWidget(host(active: true, onDeactivate: () => stops++));
      await tester.pumpWidget(host(active: false, onDeactivate: () => stops++));
      await tester.pump();
      await tester.pumpWidget(host(active: false, onDeactivate: () => stops++));
      await tester.pump();
      expect(stops, 1);
    });

    testWidgets('stops when the app goes to the background', (tester) async {
      var stops = 0;
      await tester.pumpWidget(host(active: true, onDeactivate: () => stops++));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(stops, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('ignores the inactive state (permission prompt)',
        (tester) async {
      var stops = 0;
      await tester.pumpWidget(host(active: true, onDeactivate: () => stops++));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(stops, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('stops when a page covers it but not for a dialog',
        (tester) async {
      var stops = 0;
      await tester.pumpWidget(host(active: true, onDeactivate: () => stops++));
      final context = tester.element(find.text('camera'));

      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('manual input')),
      );
      await tester.pumpAndSettle();
      expect(stops, 0);
      Navigator.of(context).pop();
      await tester.pumpAndSettle();

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('other page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(stops, 1);
    });
  });
}
