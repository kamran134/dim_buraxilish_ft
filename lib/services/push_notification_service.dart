import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'device_identity_service.dart';
import 'emergency_message_service.dart';
import 'http_service.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // App is in background/terminated — system shows the notification automatically.
  // When user taps, onMessageOpenedApp fires and checkPending() runs.
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  static PushNotificationService get instance => _instance;
  PushNotificationService._internal();

  static const String _tokenUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/api/devicetokens';

  String? _buildingCode;
  String? _fcmToken;

  /// Last outcome of the registration pipeline, shown on the settings screen
  /// so a device that never shows up in the admin device list can be diagnosed
  /// without a debugger (release builds swallow debugPrint).
  final ValueNotifier<String> status = ValueNotifier('başlanmayıb');

  void _setStatus(String value) {
    status.value = value;
    debugPrint('[Push] $value');
  }

  /// Re-runs registration for the current building (tap on the status line).
  Future<void> retry() async {
    final code = _buildingCode;
    if (code == null) {
      _setStatus('bina yoxdur (login olun)');
      return;
    }
    await activate(buildingCode: code);
  }

  // ─── Init (call once in main) ──────────────────────────────────────────────

  void init() {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Token rotation — keep backend in sync automatically
    FirebaseMessaging.instance.onTokenRefresh.listen(_uploadToken);

    // User tapped notification while app was backgrounded:
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      EmergencyMessageService.instance.checkPending();
    });

    // User tapped notification while app was terminated:
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) EmergencyMessageService.instance.checkPending();
    });
  }

  // ─── Call after login / session restore ───────────────────────────────────

  Future<void> activate({
    required String buildingCode,
  }) async {
    _buildingCode = buildingCode;

    _setStatus('icazə yoxlanılır');
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _setStatus('icazə yoxdur (denied)');
      return;
    }

    try {
      // On iOS getToken() throws until APNs hands the app its device token,
      // which arrives asynchronously after the permission prompt.
      if (Platform.isIOS && !await _waitForApnsToken()) {
        // onTokenRefresh fires once APNs catches up and uploads the token then.
        _setStatus('APNs token yoxdur');
        return;
      }
      _fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      _setStatus('FCM token xətası: $e');
      return;
    }
    if (_fcmToken == null) {
      _setStatus('FCM token null');
      return;
    }

    await _uploadToken(_fcmToken!);
  }

  // ─── Call on logout ────────────────────────────────────────────────────────

  Future<void> deactivate() async {
    if (_fcmToken == null) return;
    final authToken = await HttpService().getToken();
    if (authToken == null) {
      _buildingCode = null;
      _fcmToken = null;
      return;
    }
    try {
      await http
          .delete(
            Uri.parse(_tokenUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({'fcmToken': _fcmToken}),
          )
          .timeout(const Duration(seconds: 5));
      debugPrint('[Push] Token removed.');
    } catch (e) {
      debugPrint('[Push] deactivate error: $e');
    } finally {
      _buildingCode = null;
      _fcmToken = null;
    }
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  Future<bool> _waitForApnsToken() async {
    for (var i = 0; i < 10; i++) {
      if (await FirebaseMessaging.instance.getAPNSToken() != null) return true;
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Future<void> _uploadToken(String fcmToken) async {
    if (_buildingCode == null) return;
    // Always fetch a fresh token instead of relying on a cached one — the JWT
    // captured at login can expire while the app stays logged in across an
    // exam period, and Firebase can rotate the FCM token long after that.
    // getToken() transparently refreshes an expired JWT via the refresh token.
    final authToken = await HttpService().getToken();
    if (authToken == null) {
      _setStatus('sessiya tokeni yoxdur');
      return;
    }
    try {
      final deviceId = await DeviceIdentityService.instance.getDeviceId();
      final deviceName = await DeviceIdentityService.instance.getDeviceName();
      final response = await http
          .post(
            Uri.parse(_tokenUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'buildingCode': _buildingCode,
              'fcmToken': fcmToken,
              'deviceId': deviceId,
              if (deviceName != null) 'deviceName': deviceName,
            }),
          )
          // Generous: the first request after an IIS app-pool recycle takes 5–9 s.
          .timeout(const Duration(seconds: 15));
      _setStatus(response.statusCode == 200
          ? 'qeydiyyatdan keçdi (bina $_buildingCode)'
          : 'server xətası ${response.statusCode}');
    } catch (e) {
      _setStatus('göndərmə xətası: $e');
    }
  }
}
