import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';
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

  HubConnection? _connection;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _isConnected = false;
  String? _buildingCode;
  String? _token;

  // Guards against showing the same message twice (live + pending race)
  final Set<int> _activeDialogIds = {};
  bool _pendingCheckInProgress = false;

  bool get isConnected => _isConnected;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint('[Emergency] App paused — stopping SignalR connection.');
      _connection?.stop();
      _connection = null;
      _isConnected = false;
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('[Emergency] App resumed — reconnecting and checking pending.');
      if (_buildingCode != null && _token != null) {
        connect(buildingCode: _buildingCode!, token: _token!);
      }
      checkPending();
    }
  }

  void connect({
    required String buildingCode,
    required String token,
  }) {
    if (_isConnected) return;

    _buildingCode = buildingCode;
    _token = token;

    debugPrint('[Emergency] Connecting to hub: $_hubUrl');
    debugPrint('[Emergency] Building code: $buildingCode');

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
      _isConnected = false;
      debugPrint('[Emergency] Connection closed. Error: $error');
    });

    _connection!.onreconnecting(({error}) {
      debugPrint('[Emergency] Reconnecting... Error: $error');
    });

    _connection!.onreconnected(({connectionId}) {
      _isConnected = true;
      debugPrint('[Emergency] Reconnected. ID: $connectionId');
      _connection!.invoke('JoinBuilding', args: [buildingCode]).then((_) {
        debugPrint('[Emergency] JoinBuilding ok after reconnect');
        checkPending();
      }).catchError((e) {
        debugPrint('[Emergency] JoinBuilding error: $e');
        return null;
      });
    });

    _connection!.on('ReceiveEmergencyMessage', _onMessage);

    _connection!.start()?.then((_) {
      _isConnected = true;
      debugPrint('[Emergency] Connected successfully!');
      return _connection?.invoke('JoinBuilding', args: [buildingCode]);
    }).then((_) {
      debugPrint('[Emergency] Joined building group: building_$buildingCode');
    }).catchError((e) {
      debugPrint('[Emergency] Connection error: $e — retrying in 5s...');
      Future.delayed(const Duration(seconds: 5), () {
        if (!_isConnected && _buildingCode != null) {
          _connection = null;
          connect(buildingCode: buildingCode, token: token);
        }
      });
    });
  }

  void _onMessage(List<Object?>? args) {
    debugPrint('[Emergency] Message received! Args: $args');

    if (args == null || args.isEmpty) return;

    final raw = args[0];
    debugPrint('[Emergency] Raw arg type: ${raw.runtimeType}');

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
      debugPrint('[Emergency] Failed to parse message: $e');
      return;
    }

    final messageId = (data['messageId'] as num?)?.toInt() ?? 0;
    final title = data['title']?.toString() ?? '';
    final body = data['body']?.toString() ?? '';
    final importance = (data['importance'] as num?)?.toInt() ?? 0;

    debugPrint('[Emergency] Showing live dialog — title: $title, importance: $importance, messageId: $messageId');

    _showDialog(messageId: messageId, title: title, body: body, importance: importance);
  }

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
      if (msgs.isEmpty) {
        debugPrint('[Emergency] No pending messages.');
        return;
      }

      debugPrint('[Emergency] ${msgs.length} pending message(s) found.');

      for (final msg in msgs) {
        final id = (msg['id'] as num?)?.toInt() ?? 0;
        final title = msg['title']?.toString() ?? '';
        final body = msg['body']?.toString() ?? '';
        final importance = (msg['importance'] as num?)?.toInt() ?? 0;

        // Wait for each dialog to close before showing the next
        await _showDialog(
          messageId: id,
          title: title,
          body: body,
          importance: importance,
        );
      }
    } catch (e) {
      debugPrint('[Emergency] Pending check failed: $e');
    } finally {
      _pendingCheckInProgress = false;
    }
  }

  Future<void> _showDialog({
    required int messageId,
    required String title,
    required String body,
    required int importance,
  }) async {
    if (_activeDialogIds.contains(messageId)) {
      debugPrint('[Emergency] Dialog for messageId=$messageId already showing, skipping.');
      return;
    }

    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('[Emergency] No navigator context, cannot show dialog');
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
      debugPrint('[Emergency] Acknowledged messageId=$messageId for building=$_buildingCode');
    } catch (e) {
      debugPrint('[Emergency] Acknowledge failed: $e');
    }
  }

  Future<void> disconnect() async {
    if (_connection != null) {
      try {
        await _connection!.stop();
        debugPrint('[Emergency] Disconnected.');
      } catch (e) {
        debugPrint('[Emergency] Disconnect error: $e');
      }
      _connection = null;
    }
    _isConnected = false;
    _buildingCode = null;
    _token = null;
  }
}
