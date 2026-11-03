import 'package:dim_buraxilish_ft/screens/admin/admin_auto_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Probe extends StatefulWidget {
  final VoidCallback onRefresh;

  const _Probe({required this.onRefresh});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with AdminAutoRefresh {
  @override
  void initState() {
    super.initState();
    startAutoRefresh();
  }

  @override
  Future<void> onAutoRefresh() async => widget.onRefresh();

  @override
  Widget build(BuildContext context) => const Text('probe');
}

Widget _app(VoidCallback onRefresh, GlobalKey<NavigatorState> key) =>
    MaterialApp(
      navigatorKey: key,
      home: _Probe(onRefresh: onRefresh),
    );

void _lifecycle(WidgetTester tester, AppLifecycleState state) {
  tester.binding.handleAppLifecycleStateChanged(state);
}

void main() {
  testWidgets('refreshes every 30 seconds while visible', (tester) async {
    var count = 0;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(() => count++, nav));

    await tester.pump(const Duration(seconds: 29));
    expect(count, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(count, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(count, 2);
  });

  testWidgets('stops while another page covers it, then refreshes at once',
      (tester) async {
    var count = 0;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(() => count++, nav));

    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('covering page')),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 120));
    expect(count, 0);

    nav.currentState!.pop();
    await tester.pumpAndSettle();
    // Uncovered: one immediate refresh, then the 30 s rhythm again.
    expect(count, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(count, 2);
  });

  testWidgets('a dialog does not stop it', (tester) async {
    var count = 0;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(() => count++, nav));

    showDialog<void>(
      context: nav.currentContext!,
      builder: (_) => const AlertDialog(content: Text('dialog')),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(count, 1);
  });

  testWidgets('stops in the background and resumes with a refresh',
      (tester) async {
    var count = 0;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(() => count++, nav));

    _lifecycle(tester, AppLifecycleState.inactive);
    _lifecycle(tester, AppLifecycleState.hidden);
    _lifecycle(tester, AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 120));
    expect(count, 0);

    _lifecycle(tester, AppLifecycleState.hidden);
    _lifecycle(tester, AppLifecycleState.inactive);
    _lifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(count, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(count, 2);
  });

  testWidgets('no refresh after the screen is gone', (tester) async {
    var count = 0;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_app(() => count++, nav));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 120));
    expect(count, 0);
  });
}
