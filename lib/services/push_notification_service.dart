import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'emergency_message_service.dart';

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
  String? _authToken;
  String? _fcmToken;

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
    required String authToken,
  }) async {
    _buildingCode = buildingCode;
    _authToken = authToken;

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] Permission denied.');
      return;
    }

    _fcmToken = await FirebaseMessaging.instance.getToken();
    if (_fcmToken == null) {
      debugPrint('[Push] Could not get FCM token.');
      return;
    }

    debugPrint('[Push] FCM token obtained.');
    await _uploadToken(_fcmToken!);
  }

  // ─── Call on logout ────────────────────────────────────────────────────────

  Future<void> deactivate() async {
    if (_fcmToken == null || _authToken == null) return;
    try {
      await http
          .delete(
            Uri.parse(_tokenUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
            body: jsonEncode({'fcmToken': _fcmToken}),
          )
          .timeout(const Duration(seconds: 5));
      debugPrint('[Push] Token removed.');
    } catch (e) {
      debugPrint('[Push] deactivate error: $e');
    } finally {
      _buildingCode = null;
      _authToken = null;
      _fcmToken = null;
    }
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  Future<void> _uploadToken(String fcmToken) async {
    if (_buildingCode == null || _authToken == null) return;
    try {
      await http
          .post(
            Uri.parse(_tokenUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
            body: jsonEncode({
              'buildingCode': _buildingCode,
              'fcmToken': fcmToken,
            }),
          )
          .timeout(const Duration(seconds: 5));
      debugPrint('[Push] Token uploaded.');
    } catch (e) {
      debugPrint('[Push] upload error: $e');
    }
  }
}
