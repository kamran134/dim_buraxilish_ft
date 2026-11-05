import 'package:dim_buraxilish_ft/providers/offline_database_provider.dart';
import 'package:dim_buraxilish_ft/widgets/offline_download_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Only the progress getters are real; everything else is never touched by the
/// widget.
class _FakeProvider extends ChangeNotifier implements OfflineDatabaseProvider {
  @override
  OfflineDownloadPhase? downloadPhase;
  @override
  OfflineDownloadTarget? downloadTarget;
  @override
  int? photosDone;
  @override
  int? photosTotal;
  @override
  bool photosRetrying = false;

  void update({
    OfflineDownloadTarget? target,
    OfflineDownloadPhase? phase,
    int? done,
    int? total,
    bool retrying = false,
  }) {
    downloadTarget = target ?? downloadTarget;
    downloadPhase = phase;
    photosDone = done;
    photosTotal = total;
    photosRetrying = retrying;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeProvider> _pump(WidgetTester tester,
    {OfflineDownloadTarget? target,
    OfflineDownloadPhase? phase,
    int? done,
    int? total,
    bool retrying = false}) async {
  final provider = _FakeProvider()
    ..downloadTarget = target
    ..downloadPhase = phase
    ..photosDone = done
    ..photosTotal = total
    ..photosRetrying = retrying;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<OfflineDatabaseProvider>.value(
          value: provider,
          child: const OfflineDownloadProgress(color: Colors.blue),
        ),
      ),
    ),
  );
  return provider;
}

LinearProgressIndicator _bar(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));

void main() {
  testWidgets('data phase: indeterminate bar and the data caption',
      (tester) async {
    await _pump(tester,
        target: OfflineDownloadTarget.participants,
        phase: OfflineDownloadPhase.data);

    expect(find.text('İştirakçıların məlumatları yüklənir'), findsOneWidget);
    expect(_bar(tester).value, isNull);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Tətbiqi bağlamayın'), findsOneWidget);
    expect(find.text('Bağlantı bərpa olunur...'), findsNothing);
  });

  testWidgets('caption names whose data is loading, in both phases',
      (tester) async {
    const titles = {
      OfflineDownloadTarget.participants: 'İştirakçıların məlumatları yüklənir',
      OfflineDownloadTarget.supervisors: 'Nəzarətçilərin məlumatları yüklənir',
      OfflineDownloadTarget.monitors: 'İmtahan rəhbərlərinin məlumatları yüklənir',
    };
    for (final phase in OfflineDownloadPhase.values) {
      for (final entry in titles.entries) {
        await _pump(tester,
            target: entry.key, phase: phase, done: 1, total: 2);
        expect(find.text(entry.value), findsOneWidget);
      }
    }
  });

  testWidgets('no target: generic caption', (tester) async {
    await _pump(tester, phase: OfflineDownloadPhase.photos, done: 1, total: 2);
    expect(find.text('Məlumatlar yüklənir'), findsOneWidget);
  });

  testWidgets('the word "Şəkillər" never appears', (tester) async {
    for (final target in [null, ...OfflineDownloadTarget.values]) {
      for (final phase in [null, ...OfflineDownloadPhase.values]) {
        await _pump(tester,
            target: target,
            phase: phase,
            done: 1,
            total: 2,
            retrying: true);
        expect(find.textContaining('Şəkillər'), findsNothing);
      }
    }
  });

  testWidgets('null phase is treated like the data phase', (tester) async {
    await _pump(tester);

    expect(find.text('Məlumatlar yüklənir'), findsOneWidget);
    expect(_bar(tester).value, isNull);
  });

  testWidgets('photos phase: determinate bar, counts and percent',
      (tester) async {
    await _pump(tester,
        target: OfflineDownloadTarget.participants,
        phase: OfflineDownloadPhase.photos,
        done: 312,
        total: 758);

    expect(find.text('İştirakçıların məlumatları yüklənir'), findsOneWidget);
    expect(find.text('312 / 758 · 41%'), findsOneWidget);
    expect(_bar(tester).value, closeTo(312 / 758, 1e-9));
  });

  testWidgets('photos phase: complete shows 100%', (tester) async {
    await _pump(tester,
        phase: OfflineDownloadPhase.photos, done: 758, total: 758);

    expect(find.text('758 / 758 · 100%'), findsOneWidget);
    expect(_bar(tester).value, 1.0);
  });

  testWidgets('zero total does not divide by zero', (tester) async {
    await _pump(tester,
        phase: OfflineDownloadPhase.photos, done: 0, total: 0);

    expect(tester.takeException(), isNull);
    expect(find.text('0 / 0 · 0%'), findsOneWidget);
    expect(_bar(tester).value, 0.0);
  });

  testWidgets('photos phase before any progress is reported', (tester) async {
    await _pump(tester, phase: OfflineDownloadPhase.photos);

    expect(tester.takeException(), isNull);
    expect(find.text('0 / 0 · 0%'), findsOneWidget);
  });

  testWidgets('done above total is clamped', (tester) async {
    await _pump(tester,
        phase: OfflineDownloadPhase.photos, done: 12, total: 10);

    expect(find.text('10 / 10 · 100%'), findsOneWidget);
    expect(_bar(tester).value, 1.0);
  });

  testWidgets('retry caption appears only while retrying', (tester) async {
    final provider = await _pump(tester,
        phase: OfflineDownloadPhase.photos, done: 5, total: 10);
    expect(find.text('Bağlantı bərpa olunur...'), findsNothing);

    provider.update(
        phase: OfflineDownloadPhase.photos, done: 5, total: 10, retrying: true);
    await tester.pump();
    expect(find.text('Bağlantı bərpa olunur...'), findsOneWidget);

    provider.update(phase: OfflineDownloadPhase.photos, done: 6, total: 10);
    await tester.pump();
    expect(find.text('Bağlantı bərpa olunur...'), findsNothing);
    expect(find.text('6 / 10 · 60%'), findsOneWidget);
  });

  testWidgets('follows the provider from the data to the photos phase',
      (tester) async {
    final provider = await _pump(tester,
        target: OfflineDownloadTarget.supervisors,
        phase: OfflineDownloadPhase.data);
    expect(find.text('Nəzarətçilərin məlumatları yüklənir'), findsOneWidget);
    expect(_bar(tester).value, isNull);

    provider.update(phase: OfflineDownloadPhase.photos, done: 1, total: 4);
    await tester.pump();
    expect(find.text('Nəzarətçilərin məlumatları yüklənir'), findsOneWidget);
    expect(find.text('1 / 4 · 25%'), findsOneWidget);
  });
}
