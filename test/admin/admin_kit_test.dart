import 'package:dim_buraxilish_ft/widgets/admin/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

const _longName =
    'Azərbaycan Dövlət İqtisad Universitetinin Bakı şəhəri Həzi Aslanov '
    'küçəsindəki əsas tədris korpusunun birinci mərtəbəsi';

void main() {
  group('AdminLayout', () {
    test('breakpoints', () {
      expect(AdminLayout.fromWidth(320).breakpoint, AdminBreakpoint.compact);
      expect(AdminLayout.fromWidth(599.9).breakpoint, AdminBreakpoint.compact);
      expect(AdminLayout.fromWidth(600).breakpoint, AdminBreakpoint.medium);
      expect(AdminLayout.fromWidth(1023).breakpoint, AdminBreakpoint.medium);
      expect(AdminLayout.fromWidth(1024).breakpoint, AdminBreakpoint.expanded);
    });

    test('columns, widths and gutters per breakpoint', () {
      final compact = AdminLayout.fromWidth(360);
      final medium = AdminLayout.fromWidth(800);
      final expanded = AdminLayout.fromWidth(1280);

      expect([compact.tileColumns, medium.tileColumns, expanded.tileColumns],
          [2, 3, 4]);
      expect([compact.cardColumns, medium.cardColumns, expanded.cardColumns],
          [1, 2, 3]);
      expect(compact.maxContentWidth, double.infinity);
      expect(medium.maxContentWidth, 840);
      expect(expanded.maxContentWidth, 1200);
      expect([
        compact.horizontalPadding,
        medium.horizontalPadding,
        expanded.horizontalPadding,
      ], [16, 24, 32]);
      expect(compact.useRail, isFalse);
      expect(medium.useRail, isTrue);
      expect(expanded.useRail, isTrue);
    });

    test('fitColumns drops columns when cells would be too narrow', () {
      expect(AdminLayout.fitColumns(4, 1200, 16), 4);
      expect(AdminLayout.fitColumns(3, 400, 16), 2);
      expect(AdminLayout.fitColumns(2, 200, 16), 1);
    });
  });

  group('kit showcase has no overflow', () {
    testAdminMatrix('AdminPage with every widget',
        (tester, size, scale, brightness) async {
      await pumpAdmin(
        tester,
        const _ShowcaseHost(),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);

      // Lazy list: build everything and check again.
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);
      expect(find.text('Məlumat tapılmadı'), findsOneWidget);
      expect(find.text('Yenidən cəhd et'), findsOneWidget);
    });
  });

  group('AdminPage', () {
    testWidgets('menu button in shell mode opens the drawer', (tester) async {
      await pumpAdmin(tester, _simplePage(inShell: true));
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text('DRAWER'), findsOneWidget);
    });

    testWidgets('back button when pushed', (tester) async {
      await pumpAdmin(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => _simplePage()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Test page'), findsNothing);
    });

    testWidgets('builder variant builds lazily', (tester) async {
      var built = 0;
      await pumpAdmin(
        tester,
        AdminPage.builder(
          title: 'List',
          itemCount: 1000,
          itemBuilder: (context, index) {
            built++;
            return AdminListTile(title: 'Item $index');
          },
        ),
        size: const Size(360, 640),
      );
      expect(built, lessThan(40));
      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('content is centred to maxContentWidth on wide screens',
        (tester) async {
      await pumpAdmin(
        tester,
        const AdminPage(title: 'Wide', body: SizedBox.expand(key: Key('b'))),
        size: const Size(1600, 900),
      );
      final width = tester.getSize(find.byKey(const Key('b'))).width;
      // 1200 max content width minus the 32 px gutters on both sides.
      expect(width, 1200 - 64);
    });
  });

  group('AdminSearchField', () {
    testWidgets('debounces typing by 400 ms and clears', (tester) async {
      final values = <String>[];
      await pumpAdmin(
        tester,
        Scaffold(body: AdminSearchField(onChanged: values.add)),
      );

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 300));
      expect(values, isEmpty);

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump(const Duration(milliseconds: 300));
      expect(values, isEmpty); // timer restarted
      await tester.pump(const Duration(milliseconds: 150));
      expect(values, ['abc']);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(values, ['abc', '']);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('submit fires immediately', (tester) async {
      final values = <String>[];
      await pumpAdmin(
        tester,
        Scaffold(body: AdminSearchField(onChanged: values.add)),
      );
      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(values, ['xyz']);
      await tester.pump(const Duration(seconds: 1));
      expect(values, ['xyz']); // pending debounce was cancelled
    });
  });

  group('AdminSegmented', () {
    testWidgets('reports taps', (tester) async {
      var selected = 0;
      await pumpAdmin(
        tester,
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AdminSegmented<int>(
              segments: const [
                AdminSegment(value: 0, label: 'A'),
                AdminSegment(value: 1, label: 'B'),
              ],
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      );
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(selected, 1);
    });
  });

  group('AdminSortMenu', () {
    testWidgets('selecting another option is ascending, same flips',
        (tester) async {
      final calls = <(String, bool)>[];
      await pumpAdmin(
        tester,
        Scaffold(
          body: AdminSortMenu<String>(
            options: const [
              AdminSortOption(value: 'code', label: 'Kod'),
              AdminSortOption(value: 'rate', label: 'Faiz'),
            ],
            selected: 'code',
            ascending: true,
            onChanged: (value, asc) => calls.add((value, asc)),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Faiz'));
      await tester.pumpAndSettle();
      expect(calls.last, ('rate', true));

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kod'));
      await tester.pumpAndSettle();
      expect(calls.last, ('code', false));
    });
  });

  group('states and small widgets', () {
    testWidgets('AdminErrorState retry callback', (tester) async {
      var retries = 0;
      await pumpAdmin(
        tester,
        Scaffold(
          body: AdminErrorState(message: 'Xəta', onRetry: () => retries++),
        ),
      );
      expect(find.text('Xəta'), findsOneWidget);
      await tester.tap(find.text('Yenidən cəhd et'));
      expect(retries, 1);
    });

    testWidgets('AdminExamBar shows label, hides absent actions',
        (tester) async {
      await pumpAdmin(
        tester,
        const Scaffold(body: AdminExamBar(label: null)),
      );
      expect(find.text('İmtahan seçilməyib'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
      expect(find.text('Dəyiş'), findsNothing);
    });

    testWidgets('AdminExamBar callbacks', (tester) async {
      var switched = 0;
      var changed = 0;
      await pumpAdmin(
        tester,
        Scaffold(
          body: AdminExamBar(
            label: '24 sentyabr',
            onSwitch: () => switched++,
            onChange: () => changed++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.tap(find.text('Dəyiş'));
      expect([switched, changed], [1, 1]);
    });

    testWidgets('AdminProgressRow percent and tap', (tester) async {
      var taps = 0;
      await pumpAdmin(
        tester,
        Scaffold(
          body: AdminProgressRow(
            label: 'Bina 1',
            done: 50,
            total: 200,
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('25.0%'), findsOneWidget);
      expect(find.text('50 / 200'), findsOneWidget);
      await tester.tap(find.text('Bina 1'));
      expect(taps, 1);
    });

    test('AdminProgressRow colours and zero total', () {
      expect(AdminProgressRow.colorForRate(99), isNot(
          AdminProgressRow.colorForRate(90)));
      expect(const AdminProgressRow(label: 'x', done: 0, total: 0).rate, 0);
    });

    testWidgets('AdminStatusBadge default labels', (tester) async {
      await pumpAdmin(
        tester,
        const Scaffold(
          body: Column(
            children: [
              AdminStatusBadge(status: AdminStatus.registered),
              AdminStatusBadge(status: AdminStatus.offline),
              AdminStatusBadge(status: AdminStatus.warning, label: 'Custom'),
            ],
          ),
        ),
      );
      expect(find.text('Qeydiyyatdan keçib'), findsOneWidget);
      expect(find.text('Oflayn'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('AdminKeyValueList renders dash for empty value',
        (tester) async {
      await pumpAdmin(
        tester,
        const Scaffold(
          body: AdminKeyValueList(items: [
            AdminKeyValue('Bina', '0123'),
            AdminKeyValue('Zal', ''),
          ]),
        ),
      );
      expect(find.text('Bina'), findsOneWidget);
      expect(find.text('0123'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('AdminGrid lays out rows of equal height', (tester) async {
      await pumpAdmin(
        tester,
        const Scaffold(
          body: AdminGrid(columns: 2, children: [
            SizedBox(key: Key('a'), height: 20),
            SizedBox(key: Key('b'), height: 60),
            SizedBox(key: Key('c'), height: 10),
          ]),
        ),
      );
      final a = tester.getRect(find.byKey(const Key('a')));
      final b = tester.getRect(find.byKey(const Key('b')));
      final c = tester.getRect(find.byKey(const Key('c')));
      expect(a.top, b.top);
      expect(c.top, greaterThan(b.top));
      expect(a.left, lessThan(b.left));
      expect(c.left, a.left);
    });
  });
}

Widget _simplePage({bool inShell = false}) => Scaffold(
      drawer: const Drawer(child: Text('DRAWER')),
      body: AdminPage(
        title: 'Test page',
        inShell: inShell,
        body: const SizedBox.shrink(),
      ),
    );

Widget _buildShowcase(BuildContext context) {
  return Scaffold(
    drawer: const Drawer(),
    body: AdminPage.list(
      title: 'Statistika',
      subtitle: 'Alt başlıq',
      inShell: true,
      onRefresh: () async {},
      actions: [
        AdminSortMenu<String>(
          options: const [
            AdminSortOption(value: 'code', label: 'Kod'),
            AdminSortOption(value: 'rate', label: 'Qeydiyyat faizi'),
          ],
          selected: 'code',
          ascending: true,
          onChanged: (_, __) {},
        ),
      ],
      headerBottom: AdminSearchField(onChanged: (_) {}),
      children: [
        AdminSegmented<int>(
          segments: const [
            AdminSegment(value: 0, label: 'İştirakçılar'),
            AdminSegment(value: 1, label: 'Nəzarətçilər'),
            AdminSegment(value: 2, label: 'İmtahan rəhbərləri'),
          ],
          selected: 2,
          onChanged: (_) {},
        ),
        AdminExamBar(
          label: '24 sentyabr 2026 · 10:00 · ikinci seans',
          onSwitch: () {},
          onChange: () {},
        ),
        AdminGrid.tiles(children: const [
          AdminStatTile(
            value: '1 234 567',
            label: 'Qeydiyyatdan keçməyən iştirakçılar',
            icon: Icons.school,
            percent: 99.5,
          ),
          AdminStatTile(
            value: '12',
            label: 'Ümumi imtahan rəhbəri',
            icon: Icons.badge,
          ),
        ]),
        const AdminGlassCard(child: Text('Glass')),
        AdminCard(
          title: _longName,
          trailing: const Icon(Icons.chevron_right),
          child: Column(
            children: [
              const AdminProgressRow(
                label: _longName,
                done: 1234,
                total: 5678,
              ),
              AdminListTile(
                asCard: false,
                leading: AdminListTile.codeLeading(context, '0123'),
                title: _longName,
                subtitle: _longName,
                trailing: const AdminStatusBadge(
                  status: AdminStatus.notRegistered,
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
        const AdminListTile(
          title: _longName,
          subtitle: 'Alt mətn',
          leading: Icon(Icons.person),
          trailing: AdminStatusBadge(status: AdminStatus.registered),
        ),
        const AdminCard(
          child: AdminPersonHeader(
            name: _longName,
            identifier: '1234567',
            status: AdminStatusBadge(status: AdminStatus.online),
          ),
        ),
        const AdminCard(
          child: AdminKeyValueList(items: [
            AdminKeyValue('Bina', _longName),
            AdminKeyValue('Zal', ''),
            AdminKeyValue('Telefon', '+994 50 123 45 67'),
          ]),
        ),
        const SizedBox(
          height: 240,
          child: AdminEmptyState(
            title: 'Məlumat tapılmadı',
            message: 'Axtarışı dəyişin',
          ),
        ),
        const SizedBox(height: 240, child: AdminLoading()),
        SizedBox(
          height: 300,
          child: AdminErrorState(message: _longName, onRetry: () {}),
        ),
        for (final status in AdminStatus.values)
          AdminStatusBadge(status: status),
      ],
    ),
  );
}

class _ShowcaseHost extends StatelessWidget {
  const _ShowcaseHost();

  @override
  Widget build(BuildContext context) => _buildShowcase(context);
}
