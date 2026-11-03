import 'package:dim_buraxilish_ft/models/admin_models.dart';
import 'package:dim_buraxilish_ft/screens/admin/account/admin_change_password_view.dart';
import 'package:dim_buraxilish_ft/screens/admin/account/admin_profile_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_harness.dart';

final DateTime _now = DateTime(2026, 11, 3, 12, 0);

const CurrentUser _admin = CurrentUser(
  userName: 'administrator.hesabi.cox.uzun.istifadeci.adi',
  role: 'superadmin',
  buildingCode: '0',
  buildingName: '',
);

Widget _profile({
  CurrentUser? user,
  String? error,
  AdminSessionInfo? session,
  VoidCallback? onChangePassword,
  Future<void> Function()? onRefresh,
}) =>
    AdminProfileView(
      user: user,
      error: error,
      session: session ??
          AdminSessionInfo(
            examLabel: '03.11.2026 · Sessiya 1',
            loginTime: DateTime(2026, 11, 3, 8, 30),
            tokenExpiration: DateTime(2026, 11, 5, 8, 30),
          ),
      clock: () => _now,
      onRefresh: onRefresh ?? () async {},
      onChangePassword: onChangePassword ?? () {},
    );

Widget _password({
  String userName = 'admin',
  bool submitting = false,
  String? error,
  Future<bool> Function(String, String)? onSubmit,
}) =>
    AdminChangePasswordView(
      userName: userName,
      submitting: submitting,
      error: error,
      onSubmit: onSubmit ?? (_, __) async => true,
    );

void main() {
  group('CurrentUser', () {
    test('fromJson and role captions', () {
      final user = CurrentUser.fromJson({
        'userName': 'admin',
        'role': 'monitor',
        'buildingCode': '1001',
        'buildingName': 'Bina',
      });
      expect(user.roleLabel, 'Ümumi imtahan rəhbəri');
      expect(user.buildingCode, '1001');
      expect(
        const CurrentUser(userName: 'a', role: 'admin').roleLabel,
        'Administrator',
      );
      expect(
        const CurrentUser(userName: 'a', role: 'superadmin').roleLabel,
        'Super Administrator',
      );
      expect(
        const CurrentUser(userName: 'a', role: '').roleLabel,
        'Naməlum rol',
      );
    });

    test('formatSessionDuration', () {
      expect(formatSessionDuration(const Duration(minutes: 12)), '12 dəqiqə');
      expect(
        formatSessionDuration(const Duration(hours: 3, minutes: 35)),
        '3 saat 35 dəqiqə',
      );
    });
  });

  group('AdminProfileView', () {
    testAdminMatrix('renders without overflow', (
      tester,
      size,
      scale,
      brightness,
    ) async {
      await pumpAdmin(
        tester,
        _profile(user: _admin),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Super Administrator'), findsWidgets);
      expect(find.text('Sessiya müddəti'), findsOneWidget);
    });

    testWidgets('shows session facts and hides the empty building',
        (tester) async {
      await pumpAdmin(tester, _profile(user: _admin));
      await expandViewport(tester, 412);
      expect(find.text('03.11.2026 08:30'), findsOneWidget);
      expect(find.text('3 saat 30 dəqiqə'), findsOneWidget);
      expect(find.text('05.11.2026 08:30'), findsOneWidget);
      expect(find.text('Bina kodu'), findsNothing);
    });

    testWidgets('building rows appear when the server sends them',
        (tester) async {
      await pumpAdmin(
        tester,
        _profile(
          user: const CurrentUser(
            userName: 'b1001',
            role: 'monitor',
            buildingCode: '1001',
            buildingName: 'Bakı Dövlət Universiteti',
          ),
        ),
      );
      await expandViewport(tester, 412);
      expect(find.text('Bina kodu'), findsOneWidget);
      expect(find.text('Bakı Dövlət Universiteti'), findsOneWidget);
    });

    testWidgets('stale data keeps the profile and shows the error',
        (tester) async {
      await pumpAdmin(
        tester,
        _profile(user: _admin, error: 'Şəbəkə xətası'),
      );
      await expandViewport(tester, 412);
      expect(find.text('Şəbəkə xətası'), findsOneWidget);
      expect(find.text('Hesab'), findsOneWidget);
    });

    testWidgets('loading and error without data', (tester) async {
      await pumpAdmin(tester, _profile());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      var refreshed = 0;
      await pumpAdmin(
        tester,
        _profile(error: 'Profil yüklənmədi', onRefresh: () async => refreshed++),
      );
      await tester.tap(find.text('Yenidən cəhd et'));
      expect(refreshed, 1);
    });

    testWidgets('change-password button', (tester) async {
      var tapped = false;
      await pumpAdmin(
        tester,
        _profile(user: _admin, onChangePassword: () => tapped = true),
      );
      await expandViewport(tester, 412);
      await tester.tap(find.text('Şifrəni dəyiş'));
      expect(tapped, isTrue);
    });
  });

  group('AdminChangePasswordView', () {
    testAdminMatrix('renders without overflow', (
      tester,
      size,
      scale,
      brightness,
    ) async {
      await pumpAdmin(
        tester,
        _password(userName: 'administrator.hesabi.cox.uzun.istifadeci.adi'),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      await expandViewport(tester, size.width);
      expect(tester.takeException(), isNull);
      expect(find.text('Cari parol'), findsOneWidget);
      expect(find.text('Yeni parol'), findsOneWidget);
      expect(find.text('Parol təkrarı'), findsOneWidget);
    });

    testWidgets('validates before submitting', (tester) async {
      var submits = 0;
      await pumpAdmin(
        tester,
        _password(onSubmit: (_, __) async {
          submits++;
          return true;
        }),
      );
      await expandViewport(tester, 412);

      await tester.tap(find.widgetWithText(TextButton, 'Şifrəni dəyiş'));
      await tester.pump();
      expect(find.text('Cari parol tələb olunur'), findsOneWidget);
      expect(find.text('Yeni parol tələb olunur'), findsOneWidget);
      expect(find.text('Parol təkrarı tələb olunur'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'old');
      await tester.enterText(find.byType(TextFormField).at(1), 'ab');
      await tester.enterText(find.byType(TextFormField).at(2), 'ab');
      await tester.tap(find.widgetWithText(TextButton, 'Şifrəni dəyiş'));
      await tester.pump();
      expect(find.text('Parol ən azı 3 simvol olmalıdır'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), 'abc');
      await tester.enterText(find.byType(TextFormField).at(2), 'abd');
      await tester.tap(find.widgetWithText(TextButton, 'Şifrəni dəyiş'));
      await tester.pump();
      expect(find.text('Parollar uyğun gəlmir'), findsOneWidget);
      expect(submits, 0);
    });

    testWidgets('submits the passwords and clears the form on success',
        (tester) async {
      final calls = <(String, String)>[];
      await pumpAdmin(
        tester,
        _password(onSubmit: (current, next) async {
          calls.add((current, next));
          return true;
        }),
      );
      await expandViewport(tester, 412);

      await tester.enterText(find.byType(TextFormField).at(0), 'old');
      await tester.enterText(find.byType(TextFormField).at(1), 'new123');
      await tester.enterText(find.byType(TextFormField).at(2), 'new123');
      await tester.tap(find.widgetWithText(TextButton, 'Şifrəni dəyiş'));
      await tester.pumpAndSettle();

      expect(calls, [('old', 'new123')]);
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .map((f) => f.controller!.text);
      expect(fields, everyElement(isEmpty));
    });

    testWidgets('a rejected change keeps the input and shows the error',
        (tester) async {
      await pumpAdmin(
        tester,
        _password(
          error: 'Cari parol yanlışdır',
          onSubmit: (_, __) async => false,
        ),
      );
      await expandViewport(tester, 412);
      await tester.enterText(find.byType(TextFormField).at(0), 'old');
      await tester.enterText(find.byType(TextFormField).at(1), 'new123');
      await tester.enterText(find.byType(TextFormField).at(2), 'new123');
      await tester.tap(find.widgetWithText(TextButton, 'Şifrəni dəyiş'));
      await tester.pumpAndSettle();

      expect(find.text('Cari parol yanlışdır'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'old',
      );
    });

    testWidgets('visibility toggles reveal the password', (tester) async {
      await pumpAdmin(tester, _password());
      await expandViewport(tester, 412);
      bool obscured(int i) => tester
          .widget<EditableText>(find.descendant(
            of: find.byType(TextFormField).at(i),
            matching: find.byType(EditableText),
          ))
          .obscureText;
      expect(obscured(0), isTrue);
      await tester.tap(find.byTooltip('Göstər').first);
      await tester.pump();
      expect(obscured(0), isFalse);
      expect(obscured(1), isTrue);
    });

    testWidgets('submitting disables a second send', (tester) async {
      var submits = 0;
      await pumpAdmin(
        tester,
        _password(submitting: true, onSubmit: (_, __) async {
          submits++;
          return true;
        }),
      );
      await expandViewport(tester, 412);
      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Şifrəni dəyiş').last,
          matching: find.byType(TextButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(submits, 0);
    });
  });
}
