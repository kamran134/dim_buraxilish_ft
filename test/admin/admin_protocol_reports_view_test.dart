import 'package:dim_buraxilish_ft/models/protocol_models.dart';
import 'package:dim_buraxilish_ft/screens/admin/protocols/admin_protocol_reports_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

ProtocolNote _note(
  int id,
  int building,
  String type,
  String text, {
  String created = '2026-11-03T09:30:00',
  String? updated,
}) =>
    ProtocolNote(
      id: id,
      buildingCode: building,
      noteTypeId: 1,
      noteTypeName: type,
      note: text,
      createdAt: created,
      updatedAt: updated ?? created,
      examDate: '2026-11-03T00:00:00',
    );

final List<ProtocolNote> _notes = [
  _note(1, 1002, 'Texniki problem', 'Elektrik kəsildi, ' * 20),
  _note(2, 1001, 'Pozuntu', 'İştirakçı telefonla tutuldu',
      updated: '2026-11-03T10:15:00'),
  _note(3, 1002, 'Pozuntu', 'Qeyd'),
  _note(4, 1001, 'Ümumi qeyd', 'Hər şey qaydasındadır'),
];

final AdminProtocolFilters _today =
    AdminProtocolFilters(examDate: DateTime(2026, 11, 3));

Widget _view({
  AdminProtocolFilters? filters,
  List<ProtocolNote>? protocols,
  bool loading = false,
  String? error,
  ValueChanged<AdminProtocolFilters>? onApply,
  VoidCallback? onRetry,
}) =>
    AdminProtocolReportsView(
      filters: filters ?? _today,
      protocols: protocols,
      loading: loading,
      error: error,
      onApply: onApply ?? (_) {},
      onRefresh: () async {},
      onRetry: onRetry,
      inShell: false,
    );

void main() {
  group('AdminProtocolEntry.build', () {
    test('no grouping keeps the server order', () {
      final entries = AdminProtocolEntry.build(_notes);
      expect(entries.map((e) => e.note!.id), [1, 2, 3, 4]);
    });

    test('by building: sorted numerically, each group with its count', () {
      final entries = AdminProtocolEntry.build(
        _notes,
        grouping: AdminProtocolGrouping.building,
      );
      expect(entries.map((e) => e.isGroup ? e.groupLabel : '${e.note!.id}'), [
        'Bina 1001', '2', '4',
        'Bina 1002', '1', '3',
      ]);
      expect(entries.first.groupCount, 2);
    });

    test('by type: groups sorted by name', () {
      final entries = AdminProtocolEntry.build(
        _notes,
        grouping: AdminProtocolGrouping.type,
      );
      expect(
        entries.where((e) => e.isGroup).map((e) => e.groupLabel),
        ['Pozuntu', 'Texniki problem', 'Ümumi qeyd'],
      );
    });

    test('search covers building, type and note, case-insensitively', () {
      List<int> ids(String q) => AdminProtocolEntry.build(_notes, query: q)
          .map((e) => e.note!.id)
          .toList();
      expect(ids('1001'), [2, 4]);
      expect(ids('POZUNTU'), [2, 3]);
      expect(ids('telefonla'), [2]);
      expect(ids('yoxdur'), isEmpty);
    });

    test('filters round-trip to the API date format', () {
      expect(AdminProtocolFilters.apiDate(DateTime(2026, 1, 5)), '2026-01-05');
      expect(AdminProtocolFilters.apiDate(null), isNull);
      expect(AdminProtocolFilters.empty.isEmpty, isTrue);
      expect(_today.isEmpty, isFalse);
    });
  });

  group('AdminProtocolReportsView layout', () {
    testAdminMatrix('results, empty, loading, error and filters',
        (tester, size, scale, brightness) async {
      Future<void> pump(Widget w) => pumpAdmin(
            tester,
            w,
            size: size,
            textScale: scale,
            brightness: brightness,
          );

      await pump(_view(protocols: _notes));
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);
      expect(find.text('4 protokol'), findsOneWidget);
      expect(find.text('Bina 1001'), findsWidgets);

      await tester.tap(find.text('Bina üzrə'));
      await tester.pump();
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);

      await pump(_view());
      expect(find.text('Tarix seçib axtarın'), findsOneWidget);

      await pump(_view(protocols: const []));
      expect(find.text('Protokol tapılmadı'), findsOneWidget);

      await pump(_view(loading: true));
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await pump(_view(error: 'Protokollar yüklənmədi', onRetry: () {}));
      expect(find.text('Yenidən cəhd et'), findsOneWidget);

      // Open the filters.
      await pump(_view(protocols: _notes));
      await tester.tap(find.byTooltip('Filtrləri göstər'));
      await tester.pump();
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);
      expect(find.text('İmtahan tarixi'), findsOneWidget);
      expect(find.text('Axtar'), findsOneWidget);
    });
  });

  group('AdminProtocolReportsView behaviour', () {
    testWidgets('search without any date asks for one', (tester) async {
      var applied = 0;
      await pumpAdmin(
        tester,
        _view(
          filters: AdminProtocolFilters.empty,
          onApply: (_) => applied++,
        ),
      );
      await tester.tap(find.byTooltip('Filtrləri göstər'));
      await tester.pump();
      await tester.tap(find.text('Axtar'));
      await tester.pump();
      expect(applied, 0);
      expect(
        find.text('Zəhmət olmasa axtarış üçün tarix seçin'),
        findsOneWidget,
      );
    });

    testWidgets('search applies the filters; clear applies empty ones',
        (tester) async {
      final applied = <AdminProtocolFilters>[];
      await pumpAdmin(tester, _view(onApply: applied.add));
      await tester.tap(find.byTooltip('Filtrləri göstər'));
      await tester.pump();
      await tester.tap(find.text('Axtar'));
      await tester.pump();
      expect(applied.single, _today);

      await tester.tap(find.text('Təmizlə'));
      await tester.pump();
      expect(applied.last.isEmpty, isTrue);
    });

    testWidgets('tapping a record opens the full text', (tester) async {
      await pumpAdmin(tester, _view(protocols: _notes));
      await tester.tap(find.text('İştirakçı telefonla tutuldu'));
      await tester.pumpAndSettle();
      expect(find.text('Yaradılma tarixi'), findsOneWidget);
      // Edited record: the last-edit row is listed.
      expect(find.text('Son redaktə'), findsOneWidget);
      await tester.tap(find.text('Bağla'));
      await tester.pumpAndSettle();
      expect(find.text('Yaradılma tarixi'), findsNothing);
    });

    testWidgets('search field narrows the list', (tester) async {
      await pumpAdmin(tester, _view(protocols: _notes));
      await tester.enterText(find.byType(TextField), 'telefonla');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('1 protokol'), findsOneWidget);
    });
  });
}
