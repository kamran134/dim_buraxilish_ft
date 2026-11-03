import 'package:dim_buraxilish_ft/models/exam_details_dto.dart';
import 'package:dim_buraxilish_ft/models/exam_statistics_dto.dart';
import 'package:dim_buraxilish_ft/screens/admin/admin_home_view.dart';
import 'package:dim_buraxilish_ft/screens/admin/admin_sections.dart';
import 'package:dim_buraxilish_ft/services/statistics_service.dart';
import 'package:dim_buraxilish_ft/widgets/admin/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

ExamDetailsDto _building(
  int index, {
  required int all,
  required int registered,
  String? name,
}) {
  return ExamDetailsDto(
    buildingCode: '${1000 + index}',
    buildingName: name ?? 'Bina nömrə $index üzrə imtahan mərkəzi',
    allManCount: all ~/ 2,
    allWomanCount: all - all ~/ 2,
    regManCount: registered ~/ 2,
    regWomanCount: registered - registered ~/ 2,
  );
}

final List<ExamDetailsDto> _buildings = [
  _building(1, all: 200, registered: 190),
  _building(2, all: 100, registered: 20),
  _building(3, all: 300, registered: 150),
  _building(4, all: 0, registered: 0),
  _building(5, all: 120, registered: 118),
  _building(6, all: 80, registered: 41, name: ''),
  _building(
    7,
    all: 400,
    registered: 100,
    name: 'Azərbaycan Dövlət İqtisad Universitetinin Bakı şəhəri Həzi '
        'Aslanov küçəsindəki əsas tədris korpusu',
  ),
  _building(8, all: 50, registered: 49),
];

DashboardStatistics _stats() {
  final sum = ExamStatisticsSum.fromExamDetailsList(_buildings);
  return DashboardStatistics(
    totalParticipants: sum.totalParticipants,
    totalRegistered: sum.totalRegistered,
    totalUnregistered: sum.totalUnregistered,
    totalBuildings: _buildings.length,
    registrationRate: sum.registrationRate,
    examDetails: _buildings,
    examSum: sum,
  );
}

final List<ExamStatisticsDto> _examStats = [
  ExamStatisticsDto(
    buildingCode: '1001',
    supervisorCount: 40,
    regSupervisorCount: 30,
    monitorCount: 12,
    regMonitorCount: 9,
  ),
  ExamStatisticsDto(
    buildingCode: '1002',
    supervisorCount: 10,
    regSupervisorCount: 10,
    monitorCount: 12,
    regMonitorCount: 9,
  ),
];

Widget _view({
  DashboardStatistics? stats,
  List<ExamStatisticsDto> examStats = const [],
  bool loading = false,
  String? error,
  bool noActiveSlot = false,
  VoidCallback? onRetry,
  VoidCallback? onSelectExam,
  ValueChanged<ExamDetailsDto>? onOpenBuilding,
  ValueChanged<AdminSection>? onOpenSection,
}) {
  return Scaffold(
    drawer: const Drawer(),
    body: AdminHomeView(
      userName: 'admin.user',
      roleLabel: 'Super Administrator',
      examBar: const AdminExamBar(label: '24 sentyabr 2026 · 10:00'),
      stats: stats,
      examStats: examStats,
      loading: loading,
      error: error,
      noActiveSlot: noActiveSlot,
      onRefresh: () async {},
      onRetry: onRetry,
      onSelectExam: onSelectExam,
      onOpenBuilding: onOpenBuilding,
      onOpenSection: onOpenSection,
    ),
  );
}

void main() {
  group('AdminHomeSummary', () {
    test('totals, rates and the five lowest buildings', () {
      final summary = AdminHomeSummary.from(_stats(), _examStats);

      expect(summary.totalParticipants, 1250);
      expect(summary.registeredParticipants, 668);
      expect(summary.unregisteredParticipants, 582);
      expect(summary.participantRate, closeTo(53.44, 0.01));

      // Supervisors are summed over buildings.
      expect(summary.totalSupervisors, 50);
      expect(summary.registeredSupervisors, 40);
      expect(summary.supervisorRate, 80);
      // Imtahan rəhbərləri are global: taken from the first row only.
      expect(summary.totalMonitors, 12);
      expect(summary.registeredMonitors, 9);
      expect(summary.monitorRate, 75);

      final codes = summary.lowestBuildings.map((b) => b.buildingCode);
      // Building 1004 has no participants and is skipped; worst first.
      expect(codes, ['1002', '1007', '1003', '1006', '1001']);
    });

    test('empty statistics do not divide by zero', () {
      final empty = DashboardStatistics(
        totalParticipants: 0,
        totalRegistered: 0,
        totalUnregistered: 0,
        totalBuildings: 0,
        registrationRate: 0,
        examDetails: const [],
        examSum: ExamStatisticsSum.fromExamDetailsList(const []),
      );
      final summary = AdminHomeSummary.from(empty, const []);
      expect(summary.supervisorRate, 0);
      expect(summary.monitorRate, 0);
      expect(summary.lowestBuildings, isEmpty);
    });
  });

  group('AdminHomeView layout', () {
    testAdminMatrix('with data', (tester, size, scale, brightness) async {
      await pumpAdmin(
        tester,
        _view(stats: _stats(), examStats: _examStats),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);

      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);

      expect(find.text('Admin panel'), findsOneWidget);
      expect(find.text('Ümumi iştirakçı'), findsOneWidget);
      expect(find.text('Ən aşağı qeydiyyat'), findsOneWidget);
      expect(find.text('İmtahan rəhbəri skanı'), findsOneWidget);
      expect(find.text('Ayarlar'), findsOneWidget);
    });

    testAdminMatrix('loading, error and no slot',
        (tester, size, scale, brightness) async {
      for (final view in [
        _view(loading: true),
        _view(error: 'Server xətası', onRetry: () {}),
        _view(noActiveSlot: true, onSelectExam: () {}),
        _view(
          stats: _stats(),
          examStats: _examStats,
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

  group('AdminHomeView content', () {
    testWidgets('stat values and building rows', (tester) async {
      await pumpAdmin(
        tester,
        _view(stats: _stats(), examStats: _examStats),
        size: const Size(412, 4000),
      );
      expect(tester.takeException(), isNull);

      expect(find.text('1250'), findsOneWidget);
      expect(find.text('668'), findsOneWidget);
      expect(find.text('582'), findsOneWidget);
      expect(find.text('53.4%'), findsOneWidget);
      expect(find.text('Ümumi nəzarətçi'), findsOneWidget);
      expect(find.text('Ümumi imtahan rəhbəri'), findsOneWidget);
      expect(find.text('admin.user · Super Administrator'), findsOneWidget);
      expect(find.text('24 sentyabr 2026 · 10:00'), findsOneWidget);

      // Five lowest buildings, no more.
      expect(find.byType(AdminProgressRow), findsNWidgets(5));
      expect(find.textContaining('Bina 1007'), findsOneWidget);
      expect(find.textContaining('Bina 1004'), findsNothing);
      // A building without a name still gets a label.
      expect(find.text('Bina 1006'), findsOneWidget);
    });

    testWidgets('no word "monitor" appears in the UI', (tester) async {
      await pumpAdmin(
        tester,
        _view(stats: _stats(), examStats: _examStats),
        size: const Size(412, 4000),
      );
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
      expect(texts.where((t) => t.toLowerCase().contains('monitor')), isEmpty);
    });

    testWidgets('quick links hide Əsas and call back', (tester) async {
      AdminSection? opened;
      await pumpAdmin(
        tester,
        _view(
          stats: _stats(),
          examStats: _examStats,
          onOpenSection: (section) => opened = section,
        ),
        size: const Size(412, 4000),
      );
      // "Əsas" is the page title only, not a tile.
      expect(find.byType(AdminMenuTile), findsNWidgets(adminSections.length - 1));

      await tester.tap(find.text('Statistika: İştirakçılar'));
      expect(opened?.id, 'statistics_participants');
    });

    testWidgets('tapping a building row reports the building', (tester) async {
      ExamDetailsDto? opened;
      await pumpAdmin(
        tester,
        _view(
          stats: _stats(),
          examStats: _examStats,
          onOpenBuilding: (b) => opened = b,
        ),
        size: const Size(412, 4000),
      );
      await tester.tap(find.textContaining('Bina 1002'));
      expect(opened?.buildingCode, '1002');
    });

    testWidgets('error state offers a retry', (tester) async {
      var retries = 0;
      await pumpAdmin(
        tester,
        _view(error: 'Server xətası', onRetry: () => retries++),
        size: const Size(412, 4000),
      );
      expect(find.text('Server xətası'), findsOneWidget);
      await tester.tap(find.text('Yenidən cəhd et'));
      expect(retries, 1);
    });

    testWidgets('no active slot offers exam selection', (tester) async {
      var selected = 0;
      await pumpAdmin(
        tester,
        _view(noActiveSlot: true, onSelectExam: () => selected++),
        size: const Size(412, 4000),
      );
      expect(find.text('Ümumi iştirakçı'), findsNothing);
      await tester.tap(find.text('İmtahan seçin'));
      expect(selected, 1);
    });

    testWidgets('loading shows a spinner and no numbers', (tester) async {
      await pumpAdmin(
        tester,
        _view(loading: true),
        size: const Size(412, 4000),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Ümumi iştirakçı'), findsNothing);
    });
  });

  group('adminSections', () {
    test('every tab is reachable and ids are unique', () {
      final tabs = adminSections.map((s) => s.tab).whereType<AdminTab>();
      expect(tabs.toSet(), AdminTab.values.toSet());
      // Only Statistika has several entries, one per segment.
      final stats = adminSections.where((s) => s.statsSegment != null);
      expect(stats.length, 3);
      expect(tabs.length, AdminTab.values.length + 2);
      final ids = adminSections.map((s) => s.id);
      expect(ids.toSet().length, ids.length);
    });

    test('every non-home section can be opened', () {
      for (final section in adminSections.where((s) => !s.isHome)) {
        expect(section.pageBuilder, isNotNull, reason: section.id);
      }
    });
  });
}
