import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/notification_message.dart';
import '../services/database_service.dart';

class NotificationsProvider extends ChangeNotifier {
  static final NotificationsProvider _instance =
      NotificationsProvider._internal();
  static NotificationsProvider get instance => _instance;
  NotificationsProvider._internal();

  static const String _pendingUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/api/emergencyacks/pending';
  static const String _ackUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/api/emergencyacks/acknowledge';

  List<NotificationMessage> _messages = [];
  int _unreadCount = 0;
  bool _loading = false;

  List<NotificationMessage> get messages => _messages;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;

  String? _buildingCode;
  String? _token;

  void setCredentials(String buildingCode, String token) {
    _buildingCode = buildingCode;
    _token = token;
  }

  void clearCredentials() {
    _buildingCode = null;
    _token = null;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _messages = await DatabaseService.getNotifications();
      _unreadCount = _messages.where((m) => !m.isRead).length;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Called by EmergencyMessageService when a new message arrives.
  Future<void> onMessageReceived(NotificationMessage msg) async {
    await DatabaseService.saveNotification(msg);
    final existing = _messages.any((m) => m.messageId == msg.messageId);
    if (!existing) {
      _messages.insert(0, msg);
      _unreadCount++;
      notifyListeners();
    }
  }

  /// Load pending from server and save any new ones locally.
  Future<void> fetchPending() async {
    if (_buildingCode == null || _token == null) return;
    try {
      final response = await http.get(
        Uri.parse('$_pendingUrl?buildingCode=$_buildingCode'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded['success'] != true) return;
      final List msgs = decoded['data'] ?? [];
      for (final m in msgs) {
        final msg = NotificationMessage(
          id: 0,
          messageId: (m['id'] as num?)?.toInt() ?? 0,
          title: m['title']?.toString() ?? '',
          body: m['body']?.toString() ?? '',
          importance: (m['importance'] as num?)?.toInt() ?? 0,
          receivedAt: DateTime.now().toIso8601String(),
          isRead: false,
          buildingCode: _buildingCode!,
        );
        await onMessageReceived(msg);
      }
    } catch (e) {
      debugPrint('[Notifications] fetchPending error: $e');
    }
  }

  Future<void> markAllRead() async {
    final now = DateTime.now().toIso8601String();
    await DatabaseService.markAllNotificationsRead(now);
    _messages = _messages
        .map((m) => m.isRead ? m : m.copyWith(isRead: true, readAt: now))
        .toList();
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> acknowledge(int messageId) async {
    if (_buildingCode == null || _token == null) return;
    try {
      await http.post(
        Uri.parse(_ackUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'messageId': messageId,
          'buildingCode': _buildingCode,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[Notifications] acknowledge error: $e');
    }
  }

  Future<void> refreshUnreadCount() async {
    _unreadCount = await DatabaseService.getUnreadNotificationCount();
    notifyListeners();
  }
}
