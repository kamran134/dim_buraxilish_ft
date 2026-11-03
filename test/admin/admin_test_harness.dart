import 'package:dim_buraxilish_ft/design/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screen sizes every admin screen must survive (SPEC §2.2).
const Map<String, Size> adminTestSizes = {
  '320x568': Size(320, 568),
  '360x640': Size(360, 640),
  '412x915': Size(412, 915),
  '740x360 landscape': Size(740, 360),
  '800x1280 tablet': Size(800, 1280),
  '1280x800 tablet': Size(1280, 800),
};

const List<double> adminTestTextScales = [1.0, 1.5];

/// Pumps [child] in a MaterialApp at [size] logical pixels with the given
/// text scale and theme brightness. Reset of the view is registered on the
/// tester.
Future<void> pumpAdmin(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(412, 915),
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
      home: child,
    ),
  );
  await tester.pump();
}

/// Makes the viewport very tall so a lazy list builds all of its items.
Future<void> expandViewport(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 6000);
  await tester.pump();
}

/// Runs [body] for every size × text scale × theme combination.
void testAdminMatrix(
  String description,
  Future<void> Function(
    WidgetTester tester,
    Size size,
    double textScale,
    Brightness brightness,
  ) body,
) {
  for (final entry in adminTestSizes.entries) {
    for (final scale in adminTestTextScales) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '$description [${entry.key}, x$scale, ${brightness.name}]',
          (tester) => body(tester, entry.value, scale, brightness),
        );
      }
    }
  }
}
