import 'package:dim_buraxilish_ft/models/participant_light_dto.dart';
import 'package:dim_buraxilish_ft/models/participants_page.dart';
import 'package:dim_buraxilish_ft/screens/admin/participants/admin_all_participants_view.dart';
import 'package:dim_buraxilish_ft/screens/admin/statistics/admin_person_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

List<ParticipantLightDto> _people(int count, {int from = 1}) => [
      for (var i = from; i < from + count; i++)
        ParticipantLightDto(
          id: i,
          cardNumber: 100000 + i,
          lastName: i == 2
              ? 'Hüseynzadə-Abdullayevа-Məmmədquliyev'
              : 'Soyad$i',
          firstName: 'Ad$i',
          fatherName: 'Ata$i',
          buildingCode: '1001',
          buildingName: 'Bina',
          hall: '$i',
          registeredAt: i.isEven ? DateTime(2026, 11, 3, 9, 30) : null,
        ),
    ];

List<AdminPersonRow> _rows(int count, {int from = 1}) =>
    AdminPersonRow.participants(
      _people(count, from: from),
      violators: {100003},
      showBuilding: true,
    );

Widget _view({
  List<AdminPersonRow>? rows,
  int total = 0,
  String query = '',
  bool loading = false,
  bool loadingMore = false,
  bool hasMore = false,
  String? error,
  String? moreError,
  bool hasExam = true,
  VoidCallback? onLoadMore,
  ValueChanged<String>? onQueryChanged,
  ValueChanged<AdminPersonRow>? onOpenPerson,
  VoidCallback? onRetry,
}) =>
    AdminAllParticipantsView(
      subtitle: '03.11.2026 · Sessiya 1',
      rows: rows,
      totalCount: total,
      query: query,
      loading: loading,
      loadingMore: loadingMore,
      hasMore: hasMore,
      error: error,
      moreError: moreError,
      hasExam: hasExam,
      onQueryChanged: onQueryChanged ?? (_) {},
      onLoadMore: onLoadMore ?? () {},
      onRefresh: () async {},
      onRetry: onRetry,
      onOpenPerson: onOpenPerson,
    );

void main() {
  test('ParticipantsPage.fromJson reads the paginated envelope', () {
    final page = ParticipantsPage.fromJson({
      'data': [
        {'cardNumber': 7, 'lastName': 'Əliyev', 'buildingCode': '12'},
      ],
      'totalCount': 120,
      'totalPages': 3,
      'hasNextPage': true,
    });
    expect(page.items.single.cardNumber, 7);
    expect(page.totalCount, 120);
    expect(page.totalPages, 3);
    expect(page.hasNextPage, isTrue);

    final bare = ParticipantsPage.fromJson({'data': []});
    expect(bare.items, isEmpty);
    expect(bare.hasNextPage, isFalse);
  });

  test('participant rows can carry the building', () {
    final row = _rows(1).single;
    expect(row.detail, 'Bina: 1001 · Zal: 1');
    final plain = AdminPersonRow.participants(_people(1)).single;
    expect(plain.detail, 'Zal: 1');
  });

  group('AdminAllParticipantsView layout', () {
    testAdminMatrix('rows, footer, states',
        (tester, size, scale, brightness) async {
      Future<void> pump(Widget w) => pumpAdmin(
            tester,
            w,
            size: size,
            textScale: scale,
            brightness: brightness,
          );

      await pump(_view(
        rows: _rows(6),
        total: 6,
        error: 'Yeniləmə alınmadı',
      ));
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);
      expect(find.text('Cəmi: 6 iştirakçı'), findsOneWidget);
      expect(find.text('Yeniləmə alınmadı'), findsOneWidget);

      await pump(_view(rows: _rows(6), total: 60, query: 'ad'));
      expect(find.text('60 nəticə · "ad"'), findsOneWidget);

      await pump(_view(rows: _rows(3), total: 60, hasMore: true));
      await expandViewport(tester, size.width);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await pump(_view(
        rows: _rows(3),
        total: 60,
        hasMore: true,
        moreError: 'Şəbəkə xətası',
      ));
      await expandViewport(tester, size.width);
      expect(find.text('Şəbəkə xətası'), findsOneWidget);
      expect(find.text('Yenidən cəhd et'), findsOneWidget);

      await pump(_view(loading: true));
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await pump(_view(error: 'Server xətası', onRetry: () {}));
      expect(find.text('Server xətası'), findsOneWidget);

      await pump(_view(rows: const []));
      expect(find.text('Bu imtahanda iştirakçı tapılmadı'), findsOneWidget);

      await pump(_view(rows: const [], query: 'zzz'));
      expect(find.text('Axtarışa uyğun nəticə tapılmadı'), findsOneWidget);

      await pump(_view(hasExam: false));
      expect(find.text('İmtahan seçilməyib'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AdminAllParticipantsView behaviour', () {
    testWidgets('tapping a row reports it', (tester) async {
      AdminPersonRow? opened;
      await pumpAdmin(
        tester,
        _view(rows: _rows(3), total: 3, onOpenPerson: (r) => opened = r),
      );
      await tester.tap(find.text('Soyad1 Ad1 Ata1'));
      expect((opened!.source as ParticipantLightDto).id, 1);
    });

    testWidgets('the footer requests the next page once when built',
        (tester) async {
      var requests = 0;
      await pumpAdmin(
        tester,
        _view(
          rows: _rows(3),
          total: 60,
          hasMore: true,
          onLoadMore: () => requests++,
        ),
      );
      await tester.pump();
      expect(requests, 1);
    });

    testWidgets('no request while a page is loading or after an error',
        (tester) async {
      var requests = 0;
      await pumpAdmin(
        tester,
        _view(
          rows: _rows(3),
          total: 60,
          hasMore: true,
          loadingMore: true,
          onLoadMore: () => requests++,
        ),
      );
      await tester.pump();
      expect(requests, 0);

      await pumpAdmin(
        tester,
        _view(
          rows: _rows(3),
          total: 60,
          hasMore: true,
          moreError: 'Xəta',
          onLoadMore: () => requests++,
        ),
      );
      await tester.pump();
      expect(requests, 0);

      // The retry button asks explicitly.
      await tester.tap(find.text('Yenidən cəhd et'));
      expect(requests, 1);
    });

    testWidgets('the search field reports the query after the debounce',
        (tester) async {
      final queries = <String>[];
      await pumpAdmin(
        tester,
        _view(rows: _rows(3), total: 3, onQueryChanged: queries.add),
      );
      await tester.enterText(find.byType(TextField), 'Əliyev');
      await tester.pump(const Duration(milliseconds: 100));
      expect(queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      expect(queries, ['Əliyev']);
    });
  });
}
