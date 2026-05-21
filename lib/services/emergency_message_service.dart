import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';
import '../models/notification_message.dart';
import '../providers/notifications_provider.dart';
import '../widgets/emergency_message_dialog.dart';

class EmergencyMessageService with WidgetsBindingObserver {
  static final EmergencyMessageService _instance =
      EmergencyMessageService._internal();
  static EmergencyMessageService get instance => _instance;
  EmergencyMessageService._internal();

  static const String _hubUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/hubs/emergency';
  static const String _ackUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/api/emergencyacks/acknowledge';
  static const String _pendingUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/api/emergencyacks/pending';

  GlobalKey<NavigatorState>? _navigatorKey;

  // Credentials — survive connect/disconnect cycles
  String? _buildingCode;
  String? _token;

  // Connection
  HubConnection? _connection;
  bool _connecting = false;
  Timer? _healthTimer;

  // Dialog dedup
  final Set<int> _activeDialogIds = {};
  bool _pendingCheckInProgress = false;

  /// True only when SignalR reports Connected — no manual flag that can lie.
  bool get _isConnected =>
      _connection?.state == HubConnectionState.Connected;

  // ─── Init ──────────────────────────────────────────────────────────────────

  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    WidgetsBinding.instance.addObserver(this);
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  void connect({required String buildingCode, required String token}) {
    _buildingCode = buildingCode;
    _token = token;
    NotificationsProvider.instance.setCredentials(buildingCode, token);
    _startConnection();
    _startHealthTimer();
  }

  Future<void> disconnect() async {
    _buildingCode = null;
    _token = null;
    NotificationsProvider.instance.clearCredentials();
    _healthTimer?.cancel();
    _healthTimer = null;
    await _stopConnection();
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint('[Emergency] Paused — stopping.');
      _healthTimer?.cancel();
      _stopConnection();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[Emergency] Resumed — reconnecting.');
      if (_buildingCode != null && _token != null) {
        _startConnection();
        _startHealthTimer();
      }
      checkPending();
    }
  }

  // ─── Connection internals ──────────────────────────────────────────────────

  void _startConnection() {
    if (_connecting || _isConnected) return;
    if (_buildingCode == null || _token == null) return;
    _connecting = true;

    final buildingCode = _buildingCode!;
    final token = _token!;

    debugPrint('[Emergency] Connecting — building $buildingCode');

    _connection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
            transport: HttpTransportType.LongPolling,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.onclose(({error}) {
      debugPrint('[Emergency] Connection closed. error=$error');
    });

    _connection!.onreconnecting(({error}) {
      debugPrint('[Emergency] Reconnecting... error=$error');
    });

    _connection!.onreconnected(({connectionId}) {
      debugPrint('[Emergency] Reconnected id=$connectionId');
      checkPending();
    });

    _connection!.on('ReceiveEmergencyMessage', _onMessage);

    final startFuture = _connection!.start();
    if (startFuture == null) {
      // start() returned null — connection established synchronously
      _connecting = false;
      debugPrint('[Emergency] Connected (sync)!');
      checkPending();
    } else {
      startFuture.then((_) {
        _connecting = false;
        debugPrint('[Emergency] Connected!');
        checkPending();
      }).catchError((e) {
        _connecting = false;
        debugPrint('[Emergency] start() error: $e — retry in 5s');
        Future.delayed(const Duration(seconds: 5), () {
          if (!_isConnected && !_connecting && _buildingCode != null) {
            _connection = null;
            _startConnection();
          }
        });
      });
    }
  }

  Future<void> _stopConnection() async {
    _connecting = false;
    final conn = _connection;
    _connection = null;
    try {
      await conn?.stop();
    } catch (_) {}
  }

  void _startHealthTimer() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_buildingCode == null) return;
      if (!_isConnected && !_connecting) {
        debugPrint('[Emergency] Health: not connected — restarting.');
        _connection = null;
        _startConnection();
      }
    });
  }

  // ─── Message handling ──────────────────────────────────────────────────────

  void _onMessage(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final raw = args[0];
    Map<String, dynamic> data;
    try {
      if (raw is Map<String, dynamic>) {
        data = raw;
      } else if (raw is Map) {
        data = Map<String, dynamic>.from(raw);
      } else {
        debugPrint('[Emergency] Unexpected arg type: ${raw.runtimeType}');
        return;
      }
    } catch (e) {
      debugPrint('[Emergency] Parse error: $e');
      return;
    }

    final messageId = (data['messageId'] as num?)?.toInt() ?? 0;
    final title = data['title']?.toString() ?? '';
    final body = data['body']?.toString() ?? '';
    final importance = (data['importance'] as num?)?.toInt() ?? 0;
    final targetType = data['targetType']?.toString() ?? 'ALL';
    final rawCodes = data['buildingCodes'];

    if (targetType == 'SPECIFIC' && rawCodes != null) {
      final List codes = rawCodes is List ? rawCodes : [];
      if (_buildingCode == null || !codes.any((c) => c.toString() == _buildingCode)) {
        debugPrint('[Emergency] Message id=$messageId not for this building — skipped.');
        return;
      }
    }

    debugPrint('[Emergency] Live message id=$messageId title=$title');
    NotificationsProvider.instance.onMessageReceived(NotificationMessage(
      id: 0,
      messageId: messageId,
      title: title,
      body: body,
      importance: importance,
      receivedAt: DateTime.now().toIso8601String(),
      isRead: false,
      buildingCode: _buildingCode ?? '',
    ));
    _showDialog(messageId: messageId, title: title, body: body, importance: importance);
  }

  // ─── Pending check ─────────────────────────────────────────────────────────

  Future<void> checkPending() async {
    if (_buildingCode == null || _token == null) return;
    if (_pendingCheckInProgress) return;
    _pendingCheckInProgress = true;
    try {
      final response = await http.get(
        Uri.parse('$_pendingUrl?buildingCode=$_buildingCode'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded['success'] != true) return;
      final List msgs = decoded['data'] ?? [];
      if (msgs.isEmpty) return;

      debugPrint('[Emergency] ${msgs.length} pending message(s).');
      for (final msg in msgs) {
        final messageId = (msg['id'] as num?)?.toInt() ?? 0;
        final title = msg['title']?.toString() ?? '';
        final body = msg['body']?.toString() ?? '';
        final importance = (msg['importance'] as num?)?.toInt() ?? 0;
        await NotificationsProvider.instance.onMessageReceived(NotificationMessage(
          id: 0,
          messageId: messageId,
          title: title,
          body: body,
          importance: importance,
          receivedAt: DateTime.now().toIso8601String(),
          isRead: false,
          buildingCode: _buildingCode ?? '',
        ));
        await _showDialog(
          messageId: messageId,
          title: title,
          body: body,
          importance: importance,
        );
      }
    } catch (e) {
      debugPrint('[Emergency] checkPending error: $e');
    } finally {
      _pendingCheckInProgress = false;
    }
  }

  // ─── Dialog ────────────────────────────────────────────────────────────────

  Future<void> _showDialog({
    required int messageId,
    required String title,
    required String body,
    required int importance,
  }) async {
    if (_activeDialogIds.contains(messageId)) return;
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('[Emergency] No navigator context.');
      return;
    }
    _activeDialogIds.add(messageId);
    try {
      await showDialog(
        context: context,
        barrierDismissible: importance < 2,
        barrierColor: Colors.black87,
        builder: (_) => EmergencyMessageDialog(
          title: title,
          body: body,
          importance: importance,
          onAcknowledge: () => _acknowledge(messageId),
        ),
      );
    } finally {
      _activeDialogIds.remove(messageId);
    }
  }

  // ─── Acknowledge ───────────────────────────────────────────────────────────

  Future<void> _acknowledge(int messageId) async {
    if (messageId <= 0 || _buildingCode == null || _token == null) return;
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
      );
      debugPrint('[Emergency] Acknowledged messageId=$messageId');
    } catch (e) {
      debugPrint('[Emergency] Acknowledge error: $e');
    }
  }
}
