import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../utils/app_version.dart';
import 'device_identity_service.dart';
import 'http_service.dart';
import 'session_revoke_service.dart';
import 'sync_service.dart';

/// Reports this device's state to the server so the admin panel can show how
/// many records each phone still has unsent, and learns whether the admin has
/// deactivated the device.
///
/// Runs while the user is authenticated: sent immediately on [start], then every
/// [_interval] while the app is in the foreground, and once on every resume.
/// All errors are swallowed — the heartbeat must never disturb the user.
class HeartbeatService with WidgetsBindingObserver {
  static final HeartbeatService instance = HeartbeatService._();
  HeartbeatService._();

  static const Duration _interval = Duration(minutes: 2);

  final HttpService _httpService = HttpService();

  Timer? _timer;
  bool _running = false;
  bool _sending = false;

  /// Starts (or keeps running) the heartbeat. No-op while a revoke flow runs.
  void start() {
    if (_running || SessionRevokeService.instance.isActive) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    unawaited(_send());
  }

  /// Stops the heartbeat (sign-out, revoke flow).
  void stop() {
    if (!_running) return;
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      unawaited(_send());
    } else if (state == AppLifecycleState.paused) {
      // Foreground only: no periodic traffic while the app is in the background.
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _send());
  }

  Future<void> _send() async {
    if (!_running || _sending) return;
    _sending = true;
    try {
      final sync = SyncService.instance;
      // The in-memory counters can be stale (0 until something refreshed them).
      await sync.refreshPending();

      final examDetails = await _httpService.getExamDetailsFromStorage();
      final slotKey = examDetails?.slotKey;
      final lastSyncAt = sync.lastSyncAt;

      final result = await _httpService.sendHeartbeat({
        'deviceId': await DeviceIdentityService.instance.getDeviceId(),
        'deviceName': await DeviceIdentityService.instance.getDeviceName(),
        'appVersion': await getAppVersion(),
        'slotKey': (slotKey == null || slotKey.isEmpty) ? null : slotKey,
        'pendingParticipants': sync.pendingParticipants,
        'pendingSupervisors': sync.pendingSupervisors,
        'lastSyncAt': lastSyncAt == null ? null : _isoWithOffset(lastSyncAt),
      });

      if (result.isRevoked && _running) {
        unawaited(SessionRevokeService.instance.trigger(
          reason: RevokeReason.revokedByAdmin,
          serverMessage: result.message,
        ));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Heartbeat] error (ignored): $e');
    } finally {
      _sending = false;
    }
  }

  /// ISO-8601 with the local UTC offset, e.g. `2026-10-02T12:34:56+04:00`.
  static String _isoWithOffset(DateTime time) {
    final local = time.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final base = local.toIso8601String().split('.').first;
    return '$base$sign$hours:$minutes';
  }
}
