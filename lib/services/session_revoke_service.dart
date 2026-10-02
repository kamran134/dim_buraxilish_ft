import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/session_revoked_screen.dart';
import 'heartbeat_service.dart';
import 'http_service.dart';
import 'sync_service.dart';

/// Why the session is being ended by the app.
enum RevokeReason {
  /// An administrator deactivated this device from the web panel.
  revokedByAdmin,

  /// The server rejected our session (401) without a revoke marker.
  sessionExpired,
}

/// Outcome of one attempt to push the offline queue to the server.
class DrainResult {
  final int pendingParticipants;
  final int pendingSupervisors;

  /// Human-readable reason the queue is not empty (null when it is).
  final String? error;

  /// The server answered 401: the data can only be sent after a fresh login.
  final bool needsRelogin;

  const DrainResult({
    required this.pendingParticipants,
    required this.pendingSupervisors,
    this.error,
    this.needsRelogin = false,
  });

  int get pending => pendingParticipants + pendingSupervisors;
  bool get isDrained => pending == 0;
}

/// The single place that ends a session on the server's say-so.
///
/// Flow: persist a "revoked" flag -> push the offline queue -> if it is empty,
/// sign out and go to the login screen; if not, show [SessionRevokedScreen]
/// and keep every unsent row. The flag survives an app restart (even offline),
/// so a revoked phone never silently falls back into the home screen.
///
/// Single-flight: while a flow is active (including while the blocking screen
/// is shown) further triggers are ignored.
class SessionRevokeService {
  static final SessionRevokeService instance = SessionRevokeService._();
  SessionRevokeService._();

  static const _flagKey = 'session_revoked';
  static const _messageKey = 'session_revoked_message';
  static const _reasonKey = 'session_revoked_reason';

  static const String revokedByAdminNotice =
      'Cihaz administrator tərəfindən deaktiv edilib. Yenidən daxil olun.';
  static const String sessionExpiredNotice =
      'Sessiyanın müddəti bitib. Yenidən daxil olun.';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final HttpService _httpService = HttpService();

  GlobalKey<NavigatorState>? _navigatorKey;

  bool _active = false;
  bool _blockingScreenShown = false;
  bool _finishing = false;
  RevokeReason _reason = RevokeReason.revokedByAdmin;
  String? _serverMessage;
  DrainResult? _lastDrain;

  /// Wire the app's navigator (call once from `main`).
  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  // ─── State for the blocking screen ────────────────────────────────────────

  /// True while a revoke flow is running or its blocking screen is shown.
  bool get isActive => _active;
  RevokeReason get reason => _reason;
  String? get serverMessage => _serverMessage;
  DrainResult? get lastDrain => _lastDrain;

  String get loginNotice => _reason == RevokeReason.revokedByAdmin
      ? revokedByAdminNotice
      : sessionExpiredNotice;

  // ─── Persisted flag ───────────────────────────────────────────────────────

  Future<bool> isFlagSet() async {
    try {
      return await _secureStorage.read(key: _flagKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistFlag() async {
    try {
      await _secureStorage.write(key: _flagKey, value: 'true');
      await _secureStorage.write(
          key: _reasonKey,
          value: _reason == RevokeReason.revokedByAdmin ? 'admin' : 'expired');
      if (_serverMessage != null) {
        await _secureStorage.write(key: _messageKey, value: _serverMessage);
      } else {
        await _secureStorage.delete(key: _messageKey);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SessionRevoke] persist flag error: $e');
    }
  }

  /// Clears the persisted flag and resets the in-memory state. Called when the
  /// flow completes and on every successful login.
  Future<void> reset() async {
    try {
      await _secureStorage.delete(key: _flagKey);
      await _secureStorage.delete(key: _reasonKey);
      await _secureStorage.delete(key: _messageKey);
    } catch (e) {
      if (kDebugMode) debugPrint('[SessionRevoke] clear flag error: $e');
    }
    // Last, so triggers arriving while the flag is being cleared stay ignored.
    _active = false;
    _blockingScreenShown = false;
    _finishing = false;
    _lastDrain = null;
  }

  /// If a previous run left the flag set (app killed mid-flow, or the blocking
  /// screen was showing), re-enter the flow. Returns true when it did.
  Future<bool> resumeIfFlagged() async {
    if (!await isFlagSet()) return false;
    String? reason;
    String? message;
    try {
      reason = await _secureStorage.read(key: _reasonKey);
      message = await _secureStorage.read(key: _messageKey);
    } catch (_) {}
    await trigger(
      reason: reason == 'expired'
          ? RevokeReason.sessionExpired
          : RevokeReason.revokedByAdmin,
      serverMessage: message,
    );
    return true;
  }

  // ─── Flow ─────────────────────────────────────────────────────────────────

  /// Starts the revoke flow. Safe to fire-and-forget; the returned future
  /// completes once the app has navigated to the login or blocking screen.
  Future<void> trigger({
    required RevokeReason reason,
    String? serverMessage,
  }) async {
    if (_active) return;
    _active = true;
    _finishing = false;
    _reason = reason;
    _serverMessage = serverMessage;
    _lastDrain = null;
    if (kDebugMode) debugPrint('[SessionRevoke] triggered: $reason');

    await _persistFlag();
    HeartbeatService.instance.stop();

    final result = await drain();
    if (result.isDrained) {
      await _finish();
    } else {
      _showBlockingScreen();
    }
  }

  /// Pushes the offline queue to the server and recounts it. Never deletes
  /// anything itself — rows leave the queue only through the normal sync path
  /// after the server confirmed them.
  Future<DrainResult> drain() async {
    // Respect the global sync lock: let an in-flight sync finish first so the
    // same rows are never POSTed twice and the recount below is accurate.
    for (var i = 0; i < 60 && SyncService.isSyncLocked; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final sync = SyncService.instance;
    // Refreshes the counters and, if anything is queued, runs a sync now (and
    // keeps the periodic timer going so a returning connection drains it too).
    await sync.kickstartIfPending();
    await sync.refreshPending();

    final participants = sync.pendingParticipants;
    final supervisors = sync.pendingSupervisors;

    String? error;
    var needsRelogin = false;
    if (participants + supervisors > 0) {
      // Find out why it did not go through: no/expired token (401) vs offline.
      final probe = await _httpService.getSessionStatus();
      needsRelogin = probe.isUnauthorized;
      if (needsRelogin) {
        error = 'Məlumatları göndərmək üçün yenidən daxil olmaq lazımdır.';
      } else if (probe.isUnreachable) {
        error = 'İnternet bağlantısı yoxdur.';
      } else {
        error = sync.lastSyncError ?? 'Sinxronizasiya uğursuz oldu.';
      }
    }

    final result = DrainResult(
      pendingParticipants: participants,
      pendingSupervisors: supervisors,
      error: error,
      needsRelogin: needsRelogin,
    );
    _lastDrain = result;
    return result;
  }

  /// "Yenidən göndər": re-run the drain; leaves the flow if the queue is empty.
  Future<DrainResult> retry() async {
    final result = await drain();
    if (result.isDrained) await _finish();
    return result;
  }

  /// Called by the blocking screen when the background sync timer emptied the
  /// queue on its own (connection came back).
  Future<void> finishIfDrained() async {
    if (!_active || _finishing) return;
    final sync = SyncService.instance;
    if (sync.isSyncing) return;
    await sync.refreshPending();
    if (sync.pendingTotal == 0) await _finish();
  }

  /// "Yenidən daxil ol" on the blocking screen: sign out but keep the queue on
  /// the phone — [SyncService.kickstartIfPending] sends it after the next login.
  Future<void> reloginKeepingQueue() => _finish();

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final notice = loginNotice;

    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) {
      // No UI to navigate yet — the persisted flag brings us back here on the
      // next start.
      _finishing = false;
      return;
    }
    // clearData only wipes the offline lookup tables and auth storage:
    // DatabaseService.clearAllDatabase() keeps the unsent registrations.
    await Provider.of<AuthProvider>(context, listen: false)
        .signOut(clearData: true);
    await reset();

    _navigatorKey?.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => LoginScreen(noticeMessage: notice)),
      (route) => false,
    );
  }

  void _showBlockingScreen() {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null || _blockingScreenShown) return;
    _blockingScreenShown = true;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SessionRevokedScreen()),
      (route) => false,
    );
  }
}
