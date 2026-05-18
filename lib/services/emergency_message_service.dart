import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';
import '../widgets/emergency_message_dialog.dart';

class EmergencyMessageService {
  static final EmergencyMessageService _instance =
      EmergencyMessageService._internal();
  static EmergencyMessageService get instance => _instance;
  EmergencyMessageService._internal();

  static const String _hubUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/hubs/emergency';
  static const String _ackUrl =
      'https://eservices.dim.gov.az/buraxilishScan/api/api/emergencyacks/acknowledge';

  HubConnection? _connection;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _isConnected = false;
  String? _buildingCode;
  String? _token;

  bool get isConnected => _isConnected;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  Future<void> connect({
    required String buildingCode,
    required String token,
  }) async {
    if (_isConnected) return;

    _buildingCode = buildingCode;
    _token = token;

    debugPrint('[Emergency] Connecting to hub: $_hubUrl');
    debugPrint('[Emergency] Building code: $buildingCode');

    try {
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
        debugPrint('[Emergency] Reconnected. ID: $connectionId');
        _connection!.invoke('JoinBuilding', args: [buildingCode]).catchError(
          (e) {
            debugPrint('[Emergency] JoinBuilding error: $e');
            return null;
          },
        );
      });

      _connection!.on('ReceiveEmergencyMessage', _onMessage);

      final startFuture = _connection!.start();
      if (startFuture != null) {
        await startFuture.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            debugPrint('[Emergency] Connection timed out after 15s!');
            throw Exception('SignalR connection timeout');
          },
        );
      }
      _isConnected = true;
      debugPrint('[Emergency] Connected successfully!');

      await _connection!.invoke('JoinBuilding', args: [buildingCode]);
      debugPrint('[Emergency] Joined building group: building_$buildingCode');
    } catch (e, st) {
      _isConnected = false;
      debugPrint('[Emergency] Connection failed: $e');
      debugPrint('[Emergency] Stack: $st');
    }
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

    debugPrint('[Emergency] Showing dialog — title: $title, importance: $importance, messageId: $messageId');

    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('[Emergency] No navigator context, cannot show dialog');
      return;
    }

    showDialog(
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
