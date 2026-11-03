import 'package:dim_buraxilish_ft/models/monitor_models.dart';
import 'package:dim_buraxilish_ft/models/participant_light_dto.dart';
import 'package:dim_buraxilish_ft/models/supervisor_detail_dto.dart';
import 'package:dim_buraxilish_ft/screens/admin/statistics/admin_people_view.dart';
import 'package:dim_buraxilish_ft/screens/admin/statistics/admin_person_rows.dart';
import 'package:dim_buraxilish_ft/screens/admin/statistics/admin_statistics_rows.dart';
import 'package:dim_buraxilish_ft/widgets/admin/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

final List<ParticipantLightDto> _participants = [
  ParticipantLightDto(
    id: 1,
    cardNumber: 100001,
    lastName: 'Məmmədov',
    firstName: 'Əli',
    fatherName: 'Rəşid oğlu',
    hall: '3',
    floor: '2',
    row: '4',
    seat: '12',
    registeredAt: DateTime(2026, 11, 3, 9, 30),
  ),
  ParticipantLightDto(
    id: 2,
    cardNumber: 100002,
    lastName: 'Hüseynzadə-Abdullayevа',
    firstName: 'Nərminə',
    fatherName: 'Elşad qızı',
    hall: '3',
  ),
  ParticipantLightDto(
    id: 3,
    cardNumber: 100003,
    lastName: 'Quliyev',
    firstName: 'Tural',
    registeredAt: DateTime(2026, 11, 3, 9, 45),
  ),
  ParticipantLightDto(id: 4, cardNumber: 100004),
];

final List<SupervisorDetailDto> _supervisors = [
  SupervisorDetailDto(
    id: 10,
    cardNumber: 'S-77',
    lastName: 'Əliyev',
    firstName: 'Vüqar',
    fatherName: 'Aydın oğlu',
    supervisorAction: 2,
    phone: '050 111 22 33, 055 444 55 66',
    registerDate: DateTime(2026, 11, 3, 8, 0),
  ),
  SupervisorDetailDto(
    id: 11,
    cardNumber: 'S-78',
    lastName: 'Həsənova',
    firstName: 'Gülnar',
    supervisorAction: 1,
  ),
];

final List<Monitor> _monitors = [
  const Monitor(
    workNumber: 501,
    firstName: 'Kamran',
    lastName: 'Kazımov',
    middleName: 'Elxan oğlu',
    idCardPin: '1ABC234',
    buildingCode: 1001,
    buildingName: 'Bina',
    roomId: 11,
    roomName: 'Otaq 11',
    examDate: '',
    registerDate: '2026-11-03T09:00:00',
    image: '',
    id: 5,
  ),
  const Monitor(
    workNumber: 502,
    firstName: 'Leyla',
    lastName: 'Qasımova',
    middleName: '',
    idCardPin: '',
    buildingCode: 1001,
    buildingName: 'Bina',
    roomId: 12,
    roomName: 'Çox uzun adlı otaq: Azərbaycan Dövlət İqtisad Universiteti',
    examDate: '',
    registerDate: '',
    image: '',
  ),
];

Widget _view({
  AdminStatsSegment segment = AdminStatsSegment.participants,
  List<AdminPersonRow>? rows,
  bool loading = false,
  String? error,
  ValueChanged<AdminStatsSegment>? onSegmentChanged = _ignore,
  VoidCallback? onRetry,
  ValueChanged<AdminPersonRow>? onOpenPerson,
}) {
  return AdminPeopleView(
    title: 'Azərbaycan Dövlət İqtisad Universitetinin Bakı şəhəri Həzi '
        'Aslanov küçəsindəki əsas tədris korpusu',
    subtitle: 'Kod: 1001',
    segment: segment,
    onSegmentChanged: onSegmentChanged,
    rows: rows,
    loading: loading,
    error: error,
    onRefresh: () async {},
    onRetry: onRetry,
    onOpenPerson: onOpenPerson,
  );
}

void _ignore(AdminStatsSegment _) {}

List<AdminPersonRow> _rowsFor(AdminStatsSegment segment) => switch (segment) {
      AdminStatsSegment.participants => AdminPersonRow.participants(
          _participants,
          violators: {100003},
        ),
      AdminStatsSegment.supervisors => AdminPersonRow.supervisors(_supervisors),
      AdminStatsSegment.monitors => AdminPersonRow.monitors(_monitors),
    };

void main() {
  group('AdminPersonRow', () {
    test('participants: name, place, registration and violator flag', () {
      final rows = AdminPersonRow.participants(
        _participants,
        violators: {100003},
      );
      expect(rows[0].name, 'Məmmədov Əli Rəşid oğlu');
      expect(rows[0].identifier, 'İş №: 100001');
      expect(rows[0].detail, 'Zal: 3 · Mərtəbə: 2 · Sıra: 4 · Yer: 12');
      expect(rows[0].registered, isTrue);
      expect(rows[1].registered, isFalse);
      expect(rows[2].violator, isTrue);
      expect(rows[0].violator, isFalse);
      // A record without any name still renders.
      expect(rows[3].name, '—');
    });

    test('supervisors: role and phone', () {
      final rows = AdminPersonRow.supervisors(_supervisors);
      expect(rows[0].detail, 'Əsas · 050 111 22 33, 055 444 55 66');
      expect(rows[1].detail, 'Ehtiyyat');
    });

    test('monitors: registration comes from the register date', () {
      final rows = AdminPersonRow.monitors(_monitors);
      expect(rows[0].registered, isTrue);
      expect(rows[1].registered, isFalse);
      expect(rows[0].name, 'Kazımov Kamran Elxan oğlu');
    });

    test('filter by registration and search text', () {
      final rows = AdminPersonRow.participants(
        _participants,
        violators: {100003},
      );
      List<int> ids(List<AdminPersonRow> r) =>
          r.map((e) => (e.source as ParticipantLightDto).id!).toList();

      expect(ids(AdminPersonRow.filter(rows)), [1, 2, 3, 4]);
      expect(
        ids(AdminPersonRow.filter(rows, filter: AdminRegFilter.registered)),
        [1, 3],
      );
      expect(
        ids(AdminPersonRow.filter(rows, filter: AdminRegFilter.notRegistered)),
        [2, 4],
      );
      expect(
        ids(AdminPersonRow.filter(rows, filter: AdminRegFilter.violators)),
        [3],
      );
      expect(ids(AdminPersonRow.filter(rows, query: '100002')), [2]);
      expect(ids(AdminPersonRow.filter(rows, query: 'QULIYEV')), [3]);
      expect(
        AdminPersonRow.filter(
          rows,
          filter: AdminRegFilter.registered,
          query: '100002',
        ),
        isEmpty,
      );
    });
  });

  group('AdminPeopleView layout', () {
    testAdminMatrix('every segment with rows',
        (tester, size, scale, brightness) async {
      for (final segment in AdminStatsSegment.values) {
        await pumpAdmin(
          tester,
          _view(segment: segment, rows: _rowsFor(segment)),
          size: size,
          textScale: scale,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        await expandViewport(tester, size.width);
        expect(tester.takeException(), isNull);
        expect(find.text('Kod: 1001'), findsOneWidget);
      }
    });

    testAdminMatrix('loading, error, empty and a room (no segments)',
        (tester, size, scale, brightness) async {
      for (final view in [
        _view(loading: true),
        _view(error: 'Server xətası', onRetry: () {}),
        _view(rows: const []),
        _view(
          segment: AdminStatsSegment.monitors,
          onSegmentChanged: null,
          rows: _rowsFor(AdminStatsSegment.monitors),
          error: 'Yeniləmə alınmadı',
        ),
      ]) {
        await pumpAdmin(
          tester,
          view,
          size: size,
          textScale: scale,
          brightness: brightness,
        );
        await expandViewport(tester, size.width);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('AdminPeopleView content', () {
    testWidgets('summary counts and one tile per person', (tester) async {
      await pumpAdmin(
        tester,
        _view(rows: _rowsFor(AdminStatsSegment.participants)),
        size: const Size(412, 4000),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AdminListTile), findsNWidgets(4));
      expect(find.text('Məmmədov Əli Rəşid oğlu'), findsOneWidget);
      expect(find.text('Pozuntu'), findsWidgets);
      // total 4, registered 2, not registered 2.
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Ümumi'), findsOneWidget);
    });

    testWidgets('registration filter narrows the list', (tester) async {
      await pumpAdmin(
        tester,
        _view(rows: _rowsFor(AdminStatsSegment.participants)),
        size: const Size(412, 4000),
      );
      await tester.tap(find.text('Keçməyən').last);
      await tester.pump();
      expect(find.byType(AdminListTile), findsNWidgets(2));

      await tester.tap(find.text('Keçən').last);
      await tester.pump();
      expect(find.byType(AdminListTile), findsNWidgets(2));
      expect(find.text('Quliyev Tural'), findsOneWidget);
    });

    testWidgets('only participants get the violators filter', (tester) async {
      await pumpAdmin(
        tester,
        _view(rows: _rowsFor(AdminStatsSegment.participants)),
        size: const Size(412, 4000),
      );
      expect(find.text('Pozuntu'), findsWidgets);
      await tester.tap(find.text('Pozuntu').first);
      await tester.pump();
      expect(find.byType(AdminListTile), findsOneWidget);

      await pumpAdmin(
        tester,
        _view(
          segment: AdminStatsSegment.supervisors,
          rows: _rowsFor(AdminStatsSegment.supervisors),
        ),
        size: const Size(412, 4000),
      );
      expect(find.text('Pozuntu'), findsNothing);
    });

    testWidgets('search and the empty hint', (tester) async {
      await pumpAdmin(
        tester,
        _view(rows: _rowsFor(AdminStatsSegment.participants)),
        size: const Size(412, 4000),
      );
      await tester.enterText(find.byType(TextField), '100002');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AdminListTile), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'tapılmaz');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AdminListTile), findsNothing);
      expect(find.text('Heç nə tapılmadı'), findsOneWidget);
    });

    testWidgets('empty building shows the segment-specific message',
        (tester) async {
      await pumpAdmin(
        tester,
        _view(segment: AdminStatsSegment.supervisors, rows: const []),
      );
      expect(find.text('Bu binada nəzarətçi tapılmadı'), findsOneWidget);
    });

    testWidgets('tapping a person reports the row', (tester) async {
      AdminPersonRow? opened;
      await pumpAdmin(
        tester,
        _view(
          rows: _rowsFor(AdminStatsSegment.participants),
          onOpenPerson: (row) => opened = row,
        ),
        size: const Size(412, 4000),
      );
      await tester.tap(find.text('Məmmədov Əli Rəşid oğlu'));
      expect((opened?.source as ParticipantLightDto?)?.id, 1);
    });

    testWidgets('segment switch is reported; a room has no switch',
        (tester) async {
      AdminStatsSegment? selected;
      await pumpAdmin(
        tester,
        _view(
          rows: const [],
          onSegmentChanged: (value) => selected = value,
        ),
      );
      await tester.tap(find.text('İmtahan rəhbərləri'));
      expect(selected, AdminStatsSegment.monitors);

      await pumpAdmin(
        tester,
        _view(
          segment: AdminStatsSegment.monitors,
          onSegmentChanged: null,
          rows: const [],
        ),
      );
      expect(find.text('İmtahan rəhbərləri'), findsNothing);
    });

    testWidgets('error state offers a retry', (tester) async {
      var retries = 0;
      await pumpAdmin(
        tester,
        _view(error: 'Server xətası', onRetry: () => retries++),
      );
      await tester.tap(find.text('Yenidən cəhd et'));
      expect(retries, 1);
    });
  });
}
