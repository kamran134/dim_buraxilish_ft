import 'package:dim_buraxilish_ft/models/monitor_models.dart';
import 'package:dim_buraxilish_ft/models/participant_light_dto.dart';
import 'package:dim_buraxilish_ft/models/participant_protocol_dto.dart';
import 'package:dim_buraxilish_ft/models/supervisor_detail_dto.dart';
import 'package:dim_buraxilish_ft/screens/admin/statistics/admin_person_detail_view.dart';
import 'package:dim_buraxilish_ft/services/statistics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

final AdminPersonDetailData _participant = AdminPersonDetailData.participant(
  ParticipantLightDto(
    id: 1,
    cardNumber: 100001,
    lastName: 'Hüseynzadə-Abdullayeva',
    firstName: 'Nərminə',
    fatherName: 'Elşad qızı',
    idCardSeries: 'AZE',
    idCardNumber: '12345678',
    birthDate: DateTime(2008, 5, 17),
    buildingName: 'Azərbaycan Dövlət İqtisad Universitetinin Bakı şəhəri '
        'Həzi Aslanov küçəsindəki əsas tədris korpusu',
    floor: '2',
    hall: '14',
    row: '3',
    seat: '9',
    registeredAt: DateTime(2026, 11, 3, 9, 30, 15),
  ),
  protocol: ParticipantProtocolDto(
    examName: 'Riyaziyyat',
    examDate: DateTime(2026, 6, 20),
    katName: 'Qayda pozuntusu',
    altKatName: 'Mobil telefon',
    qeyd: 'İmtahan zalında mobil telefon aşkar edildi',
    changeActivityDate: DateTime(2026, 6, 21, 11, 5),
    changeActivityInfo: 'Protokol yenilənib',
  ),
);

final AdminPersonDetailData _participantUnregistered =
    AdminPersonDetailData.participant(
  ParticipantLightDto(id: 2, cardNumber: 100002, lastName: 'Quliyev'),
);

final AdminPersonDetailData _supervisor = AdminPersonDetailData.supervisor(
  SupervisorDetailDto(
    id: 10,
    cardNumber: 'S-77',
    lastName: 'Əliyev',
    firstName: 'Vüqar',
    fatherName: 'Aydın oğlu',
    pinCode: '7XYZ123',
    supervisorAction: 2,
    buildingCode: 1001,
    buildingName: 'Bina 1',
    phone: '050 111 22 33, 055 444 55 66',
    registerDate: DateTime(2026, 11, 3, 8, 0),
  ),
);

final AdminPersonDetailData _monitor = AdminPersonDetailData.monitor(
  const Monitor(
    workNumber: 501,
    firstName: 'Kamran',
    lastName: 'Kazımov',
    middleName: 'Elxan oğlu',
    idCardPin: '1ABC234',
    phone: '070 123 45 67',
    buildingCode: 1001,
    buildingName: 'Bina 1',
    roomId: 11,
    roomName: 'Otaq 11',
    examDate: '',
    registerDate: '2026-11-03T09:00:00',
    image: '',
    id: 5,
  ),
);

Widget _view(
  AdminPersonKind kind, {
  AdminPersonDetailData? data,
  bool loading = false,
  String? error,
  bool cancelling = false,
  VoidCallback? onRetry,
  VoidCallback? onCancel,
  ValueChanged<String>? onCallPhone,
}) {
  return AdminPersonDetailView(
    kind: kind,
    data: data,
    loading: loading,
    error: error,
    cancelling: cancelling,
    onRefresh: () async {},
    onRetry: onRetry,
    onCancelRegistration: onCancel,
    onCallPhone: onCallPhone,
  );
}

void main() {
  group('AdminPersonDetailData', () {
    test('participant: fields, seat and protocol', () {
      expect(_participant.name, 'Hüseynzadə-Abdullayeva Nərminə Elşad qızı');
      expect(_participant.identifier, 'İş №: 100001');
      expect(_participant.isRegistered, isTrue);
      expect(_participant.id, 1);

      final fields = {for (final f in _participant.fields) f.label: f.value};
      expect(fields['Şəxsiyyət vəsiqəsi'], 'AZE 12345678');
      expect(fields['Doğum tarixi'], '17.05.2008');

      final seat = {for (final f in _participant.seat) f.label: f.value};
      expect(seat, {'Mərtəbə': '2', 'Zal': '14', 'Sıra': '3', 'Yer': '9'});

      final protocol = {for (final f in _participant.protocol) f.label: f.value};
      expect(protocol['Qayda pozulan imtahan'], 'Riyaziyyat');
      expect(protocol['Qayda pozulan imtahanın tarixi'], '20.06.2026');
      expect(protocol['Alt kateqoriya'], 'Mobil telefon');
    });

    test('participant without a protocol or registration', () {
      expect(_participantUnregistered.protocol, isEmpty);
      expect(_participantUnregistered.isRegistered, isFalse);
      // Empty values are not listed.
      expect(
        _participantUnregistered.seat.where((f) => f.value.isEmpty),
        isEmpty,
      );
    });

    test('an empty protocol record is dropped', () {
      final data = AdminPersonDetailData.participant(
        ParticipantLightDto(id: 3, cardNumber: 1),
        protocol: const ParticipantProtocolDto(),
      );
      expect(data.protocol, isEmpty);
    });

    test('supervisor: role, FİN and several phone numbers', () {
      expect(_supervisor.phones, ['050 111 22 33', '055 444 55 66']);
      final fields = {for (final f in _supervisor.fields) f.label: f.value};
      expect(fields['Vəzifəsi'], 'Əsas');
      expect(fields['FİN'], '7XYZ123');
    });

    test('monitor: registered by the register date, no photo', () {
      expect(_monitor.isRegistered, isTrue);
      expect(_monitor.photo, isNull);
      expect(_monitor.phones, ['070 123 45 67']);
    });

    test('phones split on commas, semicolons and Arabic commas', () {
      expect(
        AdminPersonDetailData.splitPhones('050 1, 055 2;070 3،077 4'),
        ['050 1', '055 2', '070 3', '077 4'],
      );
      expect(AdminPersonDetailData.splitPhones(null), isEmpty);
    });
  });

  group('AdminPersonDetailView layout', () {
    testAdminMatrix('every kind', (tester, size, scale, brightness) async {
      for (final entry in {
        AdminPersonKind.participant: _participant,
        AdminPersonKind.supervisor: _supervisor,
        AdminPersonKind.monitor: _monitor,
      }.entries) {
        await pumpAdmin(
          tester,
          _view(entry.key, data: entry.value, onCancel: () {}),
          size: size,
          textScale: scale,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        await expandViewport(tester, size.width);
        expect(tester.takeException(), isNull);
      }
    });

    testAdminMatrix('unregistered, loading, error, cancelling',
        (tester, size, scale, brightness) async {
      for (final view in [
        _view(
          AdminPersonKind.participant,
          data: _participantUnregistered,
          onCancel: () {},
        ),
        _view(AdminPersonKind.supervisor, loading: true),
        _view(AdminPersonKind.monitor, error: 'Server xətası', onRetry: () {}),
        _view(
          AdminPersonKind.participant,
          data: _participant,
          cancelling: true,
          onCancel: () {},
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

  group('AdminPersonDetailView content', () {
    testWidgets('participant shows data, seat and protocol', (tester) async {
      await pumpAdmin(
        tester,
        _view(
          AdminPersonKind.participant,
          data: _participant,
          onCancel: () {},
        ),
        size: const Size(412, 4000),
      );
      expect(find.text('İmtahan iştirakçısı'), findsOneWidget);
      expect(find.text('Hüseynzadə-Abdullayeva Nərminə Elşad qızı'),
          findsOneWidget);
      expect(find.text('Oturma yeri'), findsOneWidget);
      expect(find.text('Protokol məlumatları'), findsOneWidget);
      expect(find.text('Riyaziyyat'), findsOneWidget);
      expect(find.textContaining('Qeydiyyat: 03.11.2026 09:30:15'),
          findsOneWidget);
    });

    testWidgets('cancel button reports once, hidden when unregistered',
        (tester) async {
      var cancels = 0;
      await pumpAdmin(
        tester,
        _view(
          AdminPersonKind.supervisor,
          data: _supervisor,
          onCancel: () => cancels++,
        ),
        size: const Size(412, 4000),
      );
      await tester.tap(find.text('Qeydiyyatını ləğv et'));
      expect(cancels, 1);

      await pumpAdmin(
        tester,
        _view(
          AdminPersonKind.participant,
          data: _participantUnregistered,
          onCancel: () => cancels++,
        ),
        size: const Size(412, 4000),
      );
      expect(find.text('Qeydiyyatını ləğv et'), findsNothing);
      expect(find.text('Qeydiyyatdan keçməyib'), findsOneWidget);
    });

    testWidgets('cancelling disables the button', (tester) async {
      var cancels = 0;
      await pumpAdmin(
        tester,
        _view(
          AdminPersonKind.participant,
          data: _participant,
          cancelling: true,
          onCancel: () => cancels++,
        ),
        size: const Size(412, 4000),
      );
      await tester.tap(find.text('Gözləyin...'));
      expect(cancels, 0);
    });

    testWidgets('phone chips call back', (tester) async {
      final called = <String>[];
      await pumpAdmin(
        tester,
        _view(
          AdminPersonKind.supervisor,
          data: _supervisor,
          onCallPhone: called.add,
        ),
        size: const Size(412, 4000),
      );
      await tester.tap(find.text('055 444 55 66'));
      expect(called, ['055 444 55 66']);
    });

    testWidgets('error state offers a retry', (tester) async {
      var retries = 0;
      await pumpAdmin(
        tester,
        _view(
          AdminPersonKind.monitor,
          error: 'Server xətası',
          onRetry: () => retries++,
        ),
      );
      await tester.tap(find.text('Yenidən cəhd et'));
      expect(retries, 1);
    });

    testWidgets('no word "monitor" appears in the UI', (tester) async {
      await pumpAdmin(
        tester,
        _view(AdminPersonKind.monitor, data: _monitor, onCancel: () {}),
        size: const Size(412, 4000),
      );
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
      expect(texts.where((t) => t.toLowerCase().contains('monitor')), isEmpty);
      expect(find.text('İmtahan rəhbəri'), findsOneWidget);
    });
  });
}
