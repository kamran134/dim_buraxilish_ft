import 'package:dim_buraxilish_ft/models/exam_statistics_dto.dart';
import 'package:dim_buraxilish_ft/models/monitor_room_statistics.dart';
import 'package:dim_buraxilish_ft/screens/admin/statistics/admin_statistics_rows.dart';
import 'package:dim_buraxilish_ft/screens/admin/statistics/admin_statistics_view.dart';
import 'package:dim_buraxilish_ft/widgets/admin/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

ExamStatisticsDto _building(
  int index, {
  required int all,
  required int registered,
  String? name,
  int supervisors = 10,
  int registeredSupervisors = 8,
  int halls = 6,
}) {
  return ExamStatisticsDto(
    buildingCode: '${1000 + index}',
    buildingName: name ?? 'Bina nömrə $index üzrə imtahan mərkəzi',
    allManCount: all ~/ 2,
    allWomanCount: all - all ~/ 2,
    regManCount: registered ~/ 2,
    regWomanCount: registered - registered ~/ 2,
    supervisorCount: supervisors,
    regSupervisorCount: registeredSupervisors,
    hallCount: halls,
  );
}

final List<ExamStatisticsDto> _buildings = [
  _building(1, all: 200, registered: 190),
  _building(2, all: 100, registered: 20, registeredSupervisors: 3),
  _building(3, all: 300, registered: 150, registeredSupervisors: 6),
  _building(4, all: 0, registered: 0, supervisors: 0, registeredSupervisors: 0),
  _building(5, all: 120, registered: 118),
  _building(6, all: 80, registered: 41, name: ''),
  _building(
    7,
    all: 400,
    registered: 100,
    name: 'Azərbaycan Dövlət İqtisad Universitetinin Bakı şəhəri Həzi '
        'Aslanov küçəsindəki əsas tədris korpusu',
  ),
];

final List<MonitorRoomStatistics> _rooms = [
  MonitorRoomStatistics(
    roomId: 11,
    roomName: 'Otaq 11',
    examDate: '',
    allPersonCount: 10,
    regPersonCount: 9,
  ),
  MonitorRoomStatistics(
    roomId: 12,
    roomName: 'Çox uzun adlı otaq: Azərbaycan Dövlət İqtisad Universiteti',
    examDate: '',
    allPersonCount: 8,
    regPersonCount: 2,
  ),
  MonitorRoomStatistics(
    roomId: 13,
    roomName: '',
    examDate: '',
    allPersonCount: 0,
    regPersonCount: 0,
  ),
];

Widget _view({
  AdminStatsSegment segment = AdminStatsSegment.participants,
  List<ExamStatisticsDto>? buildings,
  List<MonitorRoomStatistics>? rooms,
  bool loading = false,
  String? error,
  bool noActiveSlot = false,
  ValueChanged<AdminStatsSegment>? onSegmentChanged,
  VoidCallback? onRetry,
  void Function(ExamStatisticsDto, AdminStatsSegment)? onOpenBuilding,
  ValueChanged<MonitorRoomStatistics>? onOpenRoom,
}) {
  return Scaffold(
    drawer: const Drawer(),
    body: AdminStatisticsView(
      segment: segment,
      onSegmentChanged: onSegmentChanged ?? (_) {},
      buildings: buildings ?? const [],
      rooms: rooms ?? const [],
      loading: loading,
      error: error,
      noActiveSlot: noActiveSlot,
      onRefresh: () async {},
      onRetry: onRetry,
      onOpenBuilding: onOpenBuilding,
      onOpenRoom: onOpenRoom,
    ),
  );
}

void main() {
  group('AdminStatsRow', () {
    test('participants rows carry counts, a fallback title and the source', () {
      final rows = AdminStatsRow.participants(_buildings);
      expect(rows.length, _buildings.length);
      expect(rows.first.code, '1001');
      expect(rows.first.done, 190);
      expect(rows.first.total, 200);
      // Building 6 has no name.
      expect(rows[5].title, 'Bina 1006');
      expect(rows.first.source, same(_buildings.first));
    });

    test('supervisors rows flag a shortage against the hall count', () {
      final rows = AdminStatsRow.supervisors(_buildings);
      expect(rows[0].shortage, isFalse); // 8 of 6 halls
      expect(rows[1].shortage, isTrue); // 3 of 6 halls
      expect(rows[0].note, 'Zal sayı: 6');
    });

    test('rooms rows fall back to the room number', () {
      final rows = AdminStatsRow.rooms(_rooms);
      expect(rows[2].title, 'Otaq 13');
      expect(rows[2].rate, 0);
    });

    test('search matches code and title, case-insensitively', () {
      final rows = AdminStatsRow.participants(_buildings);
      expect(
        AdminStatsRow.filterAndSort(rows, query: '1003').map((r) => r.code),
        ['1003'],
      );
      expect(
        AdminStatsRow.filterAndSort(rows, query: 'iqtisad').map((r) => r.code),
        ['1007'],
      );
      expect(AdminStatsRow.filterAndSort(rows, query: 'yoxdur'), isEmpty);
    });

    test('sorting by code is numeric, by rate ascending / descending', () {
      final registered = {100: 1, 9: 9, 20: 5};
      final rows = AdminStatsRow.rooms([
        for (final entry in registered.entries)
          MonitorRoomStatistics(
            roomId: entry.key,
            roomName: 'Otaq ${entry.key}',
            examDate: '',
            allPersonCount: 10,
            regPersonCount: entry.value,
          ),
      ]);
      expect(
        AdminStatsRow.filterAndSort(rows).map((r) => r.code),
        ['9', '20', '100'],
      );
      expect(
        AdminStatsRow.filterAndSort(rows, sort: AdminStatsSort.rate)
            .map((r) => r.code),
        ['100', '20', '9'],
      );
      expect(
        AdminStatsRow.filterAndSort(
          rows,
          sort: AdminStatsSort.rate,
          ascending: false,
        ).map((r) => r.code),
        ['9', '20', '100'],
      );
    });
  });

  group('AdminStatisticsView layout', () {
    testAdminMatrix('every segment with data',
        (tester, size, scale, brightness) async {
      for (final segment in AdminStatsSegment.values) {
        await pumpAdmin(
          tester,
          _view(segment: segment, buildings: _buildings, rooms: _rooms),
          size: size,
          textScale: scale,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        await expandViewport(tester, size.width);
        expect(tester.takeException(), isNull);
        expect(find.text('Statistika'), findsOneWidget);
        expect(find.text('İştirakçılar'), findsOneWidget);
      }
    });

    testAdminMatrix('loading, error, empty and no slot',
        (tester, size, scale, brightness) async {
      for (final view in [
        _view(loading: true),
        _view(error: 'Server xətası', onRetry: () {}),
        _view(),
        _view(noActiveSlot: true),
        _view(
          segment: AdminStatsSegment.monitors,
          buildings: _buildings,
          rooms: _rooms,
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

  group('AdminStatisticsView content', () {
    testWidgets('participants: summary and one row per building',
        (tester) async {
      await pumpAdmin(
        tester,
        _view(buildings: _buildings),
        size: const Size(412, 4000),
      );
      expect(tester.takeException(), isNull);

      // 200+100+300+0+120+80+400 participants, 190+20+150+0+118+41+100 reg.
      expect(find.text('1200'), findsOneWidget);
      expect(find.text('619'), findsOneWidget);
      expect(find.text('581'), findsOneWidget);
      expect(find.text('Ümumi iştirakçı'), findsOneWidget);
      expect(find.byType(AdminProgressRow), findsNWidgets(_buildings.length));
      expect(find.text('Bina 1006'), findsOneWidget);
    });

    testWidgets('supervisors: halls and shortage badges', (tester) async {
      await pumpAdmin(
        tester,
        _view(segment: AdminStatsSegment.supervisors, buildings: _buildings),
        size: const Size(412, 4000),
      );
      expect(find.text('Ümumi nəzarətçi'), findsOneWidget);
      expect(find.text('Zal sayı: 6'), findsWidgets);
      expect(find.text('Yetərsay yoxdur'), findsNWidgets(2));
      expect(find.text('Yetərsay var'), findsWidgets);
    });

    testWidgets('monitors: rooms, no building words', (tester) async {
      await pumpAdmin(
        tester,
        _view(segment: AdminStatsSegment.monitors, rooms: _rooms),
        size: const Size(412, 4000),
      );
      expect(find.text('Ümumi imtahan rəhbəri'), findsOneWidget);
      expect(find.text('Otaq 11'), findsOneWidget);
      expect(find.text('Otaq 13'), findsOneWidget);
      expect(find.byType(AdminProgressRow), findsNWidgets(_rooms.length));
    });

    testWidgets('tapping a building reports it with the segment',
        (tester) async {
      ExamStatisticsDto? opened;
      AdminStatsSegment? openedSegment;
      await pumpAdmin(
        tester,
        _view(
          segment: AdminStatsSegment.supervisors,
          buildings: _buildings,
          onOpenBuilding: (building, segment) {
            opened = building;
            openedSegment = segment;
          },
        ),
        size: const Size(412, 4000),
      );
      await tester.tap(find.text('Bina 1006'));
      expect(opened?.buildingCode, '1006');
      expect(openedSegment, AdminStatsSegment.supervisors);
    });

    testWidgets('tapping a room reports it', (tester) async {
      MonitorRoomStatistics? opened;
      await pumpAdmin(
        tester,
        _view(
          segment: AdminStatsSegment.monitors,
          rooms: _rooms,
          onOpenRoom: (room) => opened = room,
        ),
        size: const Size(412, 4000),
      );
      await tester.tap(find.text('Otaq 11'));
      expect(opened?.roomId, 11);
    });

    testWidgets('segment switch is reported', (tester) async {
      AdminStatsSegment? selected;
      await pumpAdmin(
        tester,
        _view(
          buildings: _buildings,
          onSegmentChanged: (value) => selected = value,
        ),
      );
      await tester.tap(find.text('Nəzarətçilər'));
      expect(selected, AdminStatsSegment.supervisors);
    });

    testWidgets('search narrows the list and shows an empty hint',
        (tester) async {
      await pumpAdmin(
        tester,
        _view(buildings: _buildings),
        size: const Size(412, 4000),
      );
      await tester.enterText(find.byType(TextField), '1003');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AdminProgressRow), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'yoxdur');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AdminProgressRow), findsNothing);
      expect(find.text('Heç nə tapılmadı'), findsOneWidget);
    });

    testWidgets('error state offers a retry', (tester) async {
      var retries = 0;
      await pumpAdmin(
        tester,
        _view(error: 'Server xətası', onRetry: () => retries++),
      );
      expect(find.text('Server xətası'), findsOneWidget);
      await tester.tap(find.text('Yenidən cəhd et'));
      expect(retries, 1);
    });

    testWidgets('no word "monitor" appears in the UI', (tester) async {
      for (final segment in AdminStatsSegment.values) {
        await pumpAdmin(
          tester,
          _view(segment: segment, buildings: _buildings, rooms: _rooms),
          size: const Size(412, 4000),
        );
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
        expect(
          texts.where((t) => t.toLowerCase().contains('monitor')),
          isEmpty,
        );
      }
    });
  });
}
