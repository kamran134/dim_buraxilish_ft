import 'package:dim_buraxilish_ft/models/admin_models.dart';
import 'package:dim_buraxilish_ft/screens/admin/emergency/admin_emergency_view.dart';
import 'package:dim_buraxilish_ft/screens/admin/emergency/emergency_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

List<EmergencyBuilding> _buildings([int count = 30]) => [
      for (var i = 1; i <= count; i++)
        EmergencyBuilding(
          code: '${1000 + i}',
          name: i == 2
              ? 'Azərbaycan Dövlət Neft və Sənaye Universiteti, Azadlıq prospekti 20'
              : 'Bina $i',
        ),
    ];

List<EmergencyHistoryItem> _history() => [
      EmergencyHistoryItem(
        id: 1,
        title: 'Zalda dəyişiklik',
        body: 'Bütün imtahan rəhbərləri 3-cü mərtəbəyə keçsin. ' * 6,
        importance: EmergencyImportance.urgent,
        sentAt: DateTime(2026, 11, 3, 9, 30),
        isForAll: true,
        ackCount: 2,
        acks: [
          EmergencyAck(
            buildingCode: '1001',
            buildingName: 'Bakı Dövlət Universiteti',
            acknowledgedAt: DateTime(2026, 11, 3, 9, 32),
          ),
          EmergencyAck(
            buildingCode: '1002',
            buildingName: 'Texniki Universitet',
            acknowledgedAt: DateTime(2026, 11, 3, 9, 35),
          ),
        ],
      ),
      EmergencyHistoryItem(
        id: 2,
        title: 'Məlumat',
        body: 'Fasilə 15 dəqiqə',
        importance: EmergencyImportance.info,
        sentAt: DateTime(2026, 11, 2, 15, 0),
        isForAll: false,
        ackCount: 0,
      ),
    ];

Widget _view(
  EmergencyDraft draft, {
  EmergencyTab tab = EmergencyTab.send,
  ValueChanged<EmergencyTab>? onTabChanged,
  List<EmergencyBuilding>? buildings,
  String? buildingsError,
  bool hasExam = true,
  bool sending = false,
  Future<void> Function()? onSend,
  List<EmergencyHistoryItem>? history,
  String? historyError,
}) =>
    AdminEmergencyView(
      subtitle: '03.11.2026 · Sessiya 1',
      tab: tab,
      onTabChanged: onTabChanged ?? (_) {},
      draft: draft,
      buildings: buildings,
      buildingsError: buildingsError,
      hasExam: hasExam,
      onReloadBuildings: () {},
      sending: sending,
      onSend: onSend ?? () async {},
      history: history,
      historyError: historyError,
      onRefreshHistory: () async {},
    );

void main() {
  group('EmergencyDraft', () {
    test('canSend needs both texts and, for a selection, a building', () {
      final draft = EmergencyDraft();
      addTearDown(draft.dispose);
      expect(draft.canSend, isFalse);

      draft.title.text = ' Başlıq ';
      draft.body.text = '   ';
      expect(draft.canSend, isFalse);

      draft.body.text = 'Mətn';
      expect(draft.canSend, isTrue);
      expect(draft.buildingCodes, isEmpty);

      draft.setSendToAll(false);
      expect(draft.canSend, isFalse);
      draft.toggle('1002');
      draft.toggle('1001');
      expect(draft.canSend, isTrue);
      expect(draft.buildingCodes, ['1001', '1002']);

      draft.toggle('1002');
      expect(draft.selected, {'1001'});
    });

    test('toggleAll selects, then deselects, the given codes', () {
      final draft = EmergencyDraft();
      addTearDown(draft.dispose);
      draft.setSendToAll(false);
      draft.toggle('9');

      draft.toggleAll(['1', '2', '3']);
      expect(draft.selected, {'1', '2', '3', '9'});
      draft.toggleAll(['1', '2', '3']);
      expect(draft.selected, {'9'});
      draft.toggleAll(const []);
      expect(draft.selected, {'9'});
    });

    test('switching back to "all" drops the selection; reset clears all', () {
      final draft = EmergencyDraft();
      addTearDown(draft.dispose);
      draft.title.text = 't';
      draft.body.text = 'b';
      draft.setImportance(EmergencyImportance.urgent);
      draft.setSendToAll(false);
      draft.toggle('1');

      draft.setSendToAll(true);
      expect(draft.selected, isEmpty);

      draft.setSendToAll(false);
      draft.toggle('1');
      draft.reset();
      expect(draft.title.text, isEmpty);
      expect(draft.body.text, isEmpty);
      expect(draft.importance, EmergencyImportance.info);
      expect(draft.sendToAll, isTrue);
      expect(draft.selected, isEmpty);
    });
  });

  group('models', () {
    test('EmergencyHistoryItem.fromJson', () {
      final item = EmergencyHistoryItem.fromJson({
        'id': 5,
        'title': 'T',
        'body': 'B',
        'importance': 1,
        'sentAt': '2026-11-03T09:30:00',
        'targetType': 'SPECIFIC',
        'ackCount': 1,
        'acks': [
          {
            'buildingCode': '1001',
            'buildingName': 'Bina',
            'acknowledgedAt': '2026-11-03T09:32:00',
          },
        ],
      });
      expect(item.importance, EmergencyImportance.warning);
      expect(item.isForAll, isFalse);
      expect(item.acks.single.buildingName, 'Bina');
      expect(item.sentAt, DateTime(2026, 11, 3, 9, 30));

      final bare = EmergencyHistoryItem.fromJson({'id': 1, 'importance': 9});
      expect(bare.importance, EmergencyImportance.info);
      expect(bare.isForAll, isTrue);
    });

    test('filterEmergencyBuildings matches code and name', () {
      expect(filterEmergencyBuildings(_buildings(), '1005'), hasLength(1));
      expect(filterEmergencyBuildings(_buildings(), 'neft'), hasLength(1));
      expect(filterEmergencyBuildings(_buildings(), ''), hasLength(30));
    });
  });

  group('AdminEmergencyView', () {
    testAdminMatrix('send tab with the building picker', (
      tester,
      size,
      scale,
      brightness,
    ) async {
      final draft = EmergencyDraft();
      addTearDown(draft.dispose);
      draft.setSendToAll(false);
      draft.toggle('1002');
      await pumpAdmin(
        tester,
        _view(draft, buildings: _buildings()),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);
      expect(find.text('Təcili elan'), findsOneWidget);
      expect(find.text('Seçilmiş: 1'), findsOneWidget);
      expect(find.text('Göndər'), findsWidgets);
    });

    testAdminMatrix('history tab', (tester, size, scale, brightness) async {
      final draft = EmergencyDraft();
      addTearDown(draft.dispose);
      await pumpAdmin(
        tester,
        _view(draft, tab: EmergencyTab.history, history: _history()),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);
      expect(find.text('Zalda dəyişiklik'), findsOneWidget);
      expect(find.text('Təsdiqləyən binalar: 2'), findsOneWidget);
    });

    testWidgets('send button follows the draft and confirms first',
        (tester) async {
      final draft = EmergencyDraft();
      addTearDown(draft.dispose);
      var sent = 0;
      await pumpAdmin(
        tester,
        _view(draft, onSend: () async => sent++),
      );
      await expandViewport(tester, 412);

      TextButton sendButton() => tester.widget<TextButton>(find.ancestor(
            of: find.text('Göndər').last,
            matching: find.byType(TextButton),
          ));
      expect(sendButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField).at(0), 'Başlıq');
      await tester.enterText(find.byType(TextField).at(1), 'Mesajın mətni');
      await tester.pump();
      expect(sendButton().onPressed, isNotNull);

      await tester.tap(find.text('Təcili'));
      await tester.pump();
      expect(draft.importance, EmergencyImportance.urgent);

      await tester.tap(find.text('Göndər').last);
      await tester.pumpAndSettle();
      expect(find.text('Mesajı göndər'), findsOneWidget);
      expect(find.textContaining('Alıcılar: Bütün binalar'), findsOneWidget);
      expect(find.textContaining('Əhəmiyyət: Təcili'), findsOneWidget);
      expect(sent, 0);

      await tester.tap(find.text('Ləğv et'));
      await tester.pumpAndSettle();
      expect(sent, 0);

      await tester.tap(find.text('Göndər').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Göndər').last);
      await tester.pumpAndSettle();
      expect(sent, 1);
    });

    testWidgets('building picker: search and select all', (tester) async {
      final draft = EmergencyDraft();
      addTearDown(draft.dispose);
      await pumpAdmin(tester, _view(draft, buildings: _buildings()));
      await expandViewport(tester, 412);

      expect(find.text('Bütün binalara göndər'), findsOneWidget);
      expect(find.text('Hamısını seç'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(draft.sendToAll, isFalse);
      expect(find.text('Hamısını seç'), findsOneWidget);

      // Select everything the search shows.
      await tester.enterText(find.byType(TextField).last, 'Bina 1');
      await tester.pump();
      await tester.tap(find.text('Hamısını seç'));
      await tester.pump();
      // "Bina 1", "Bina 10".."Bina 19" -> 11 buildings.
      expect(draft.selected, hasLength(11));
      expect(find.text('Seçimi ləğv et'), findsOneWidget);

      await tester.tap(find.text('Seçimi ləğv et'));
      await tester.pump();
      expect(draft.selected, isEmpty);

      await tester.tap(find.text('Bina 1').last);
      await tester.pump();
      expect(draft.selected, {'1001'});
      await tester.tap(find.text('Təmizlə'));
      await tester.pump();
      expect(draft.selected, isEmpty);
    });

    testWidgets('picker states: no exam, loading, error', (tester) async {
      final draft = EmergencyDraft();
      addTearDown(draft.dispose);
      draft.setSendToAll(false);

      await pumpAdmin(tester, _view(draft, hasExam: false));
      await expandViewport(tester, 412);
      expect(find.text('Bina siyahısı üçün imtahan seçin'), findsOneWidget);

      await pumpAdmin(tester, _view(draft));
      await expandViewport(tester, 412);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pumpAdmin(
        tester,
        _view(draft, buildingsError: 'Bina siyahısı yüklənmədi.'),
      );
      await expandViewport(tester, 412);
      expect(find.text('Bina siyahısı yüklənmədi.'), findsOneWidget);
      expect(find.text('Yenidən cəhd et'), findsOneWidget);
    });

    testWidgets('tabs report the switch', (tester) async {
      final draft = EmergencyDraft();
      addTearDown(draft.dispose);
      final tabs = <EmergencyTab>[];
      await pumpAdmin(tester, _view(draft, onTabChanged: tabs.add));
      await tester.tap(find.text('Tarixçə'));
      expect(tabs, [EmergencyTab.history]);
    });

    testWidgets('history: expand a message to see who acknowledged it',
        (tester) async {
      final draft = EmergencyDraft();
      addTearDown(draft.dispose);
      await pumpAdmin(
        tester,
        _view(draft, tab: EmergencyTab.history, history: _history()),
      );
      await expandViewport(tester, 412);
      expect(find.textContaining('Texniki Universitet'), findsNothing);

      await tester.tap(find.text('Zalda dəyişiklik'));
      await tester.pump();
      expect(find.textContaining('1001 · Bakı Dövlət Universiteti'),
          findsOneWidget);
      expect(find.textContaining('1002 · Texniki Universitet'), findsOneWidget);

      await tester.tap(find.text('Məlumat'));
      await tester.pump();
      expect(find.text('Hələ təsdiq yoxdur'), findsOneWidget);
    });

    testWidgets('history: loading, error, empty', (tester) async {
      final draft = EmergencyDraft();
      addTearDown(draft.dispose);

      await pumpAdmin(tester, _view(draft, tab: EmergencyTab.history));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pumpAdmin(
        tester,
        _view(draft, tab: EmergencyTab.history, historyError: 'Tarixçə yüklənmədi.'),
      );
      expect(find.text('Tarixçə yüklənmədi.'), findsOneWidget);

      await pumpAdmin(
        tester,
        _view(draft, tab: EmergencyTab.history, history: const []),
      );
      expect(find.text('Hələ mesaj göndərilməyib'), findsOneWidget);
    });
  });
}
