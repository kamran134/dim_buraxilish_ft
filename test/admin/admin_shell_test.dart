import 'package:dim_buraxilish_ft/providers/auth_provider.dart';
import 'package:dim_buraxilish_ft/providers/monitor_provider.dart';
import 'package:dim_buraxilish_ft/screens/admin/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'admin_test_harness.dart';

Widget _shell() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => MonitorProvider()),
    ],
    child: const AdminShell(),
  );
}

void main() {
  group('AdminShell navigation chrome', () {
    for (final entry in adminTestSizes.entries) {
      testWidgets('no overflow on ${entry.key}', (tester) async {
        await pumpAdmin(tester, _shell(), size: entry.value, textScale: 1.5);
        expect(tester.takeException(), isNull);
        expect(find.text('Əsas'), findsWidgets);
      });
    }

    testWidgets('phone: bottom bar, no rail', (tester) async {
      await pumpAdmin(tester, _shell(), size: const Size(360, 640));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      for (final label in ['Əsas', 'Statistika', 'Skan', 'Protokollar']) {
        expect(find.text(label), findsWidgets);
      }
    });

    testWidgets('landscape / tablet: rail, no bottom bar', (tester) async {
      await pumpAdmin(tester, _shell(), size: const Size(740, 360));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('menu button opens the drawer with all visible sections',
        (tester) async {
      await pumpAdmin(tester, _shell(), size: const Size(360, 640));
      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('İmtahan rəhbəri skanı'), findsWidgets);
      expect(find.text('Protokol hesabatları'), findsWidgets);
      expect(find.text('Ayarlar'), findsWidgets);
      expect(find.text('Admin Panel'), findsOneWidget);
    });
  });
}
