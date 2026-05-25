import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'http_service.dart';

/// Background sync service.
///
/// Starts a 30-second periodic timer after the first scan.
/// Stops automatically if no scan happens for 10 minutes.
/// Restarts on the next scan.
/// All sync activity is silent — no UI messages.
class SyncService extends ChangeNotifier {
  // ─── Singleton ────────────────────────────────────────────────────────────
  static final SyncService _instance = SyncService._internal();
  static SyncService get instance => _instance;
  SyncService._internal();

  // ─── Config ───────────────────────────────────────────────────────────────
  static const Duration _syncInterval = Duration(seconds: 30);
  static const Duration _idleTimeout = Duration(minutes: 10);

  // ─── State ────────────────────────────────────────────────────────────────
  Timer? _syncTimer;
  Timer? _idleTimer;
  bool _isSyncing = false;
  int _pendingParticipants = 0;
  int _pendingSupervisors = 0;
  bool? _lastSyncSuccess;
  int _lastSkippedCount = 0; // records not found on server during last sync

  final HttpService _httpService = HttpService();

  // ─── Getters ──────────────────────────────────────────────────────────────
  bool get isSyncing => _isSyncing;
  int get pendingParticipants => _pendingParticipants;
  int get pendingSupervisors => _pendingSupervisors;
  int get pendingTotal => _pendingParticipants + _pendingSupervisors;
  bool? get lastSyncSuccess => _lastSyncSuccess;
  bool get isTimerRunning => _syncTimer?.isActive ?? false;

  /// Number of records silently skipped by the server during the last sync
  /// because they were deleted from the server DB.
  int get lastSkippedCount => _lastSkippedCount;

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Call after every successful scan (non-repeat registration).
  /// Resets the idle countdown and ensures the periodic timer is running.
  void notifyScan() {
    _resetIdleTimer();
    if (!isTimerRunning) {
      _startSyncTimer();
    }
    // Update pending count without triggering an immediate sync
    _refreshPendingCount();
  }

  /// Force an immediate sync (e.g. manual sync button press).
  Future<void> syncNow() async {
    await _performSync();
  }

  /// Stop the sync timer (call on logout).
  void stopTimer() {
    _cancelTimers();
    _pendingParticipants = 0;
    _pendingSupervisors = 0;
    _lastSyncSuccess = null;
    _lastSkippedCount = 0;
    _isSyncing = false;
    notifyListeners();
    if (kDebugMode) debugPrint('[SyncService] Timers stopped (logout)');
  }

  /// Stop timer and clean up (call on logout).
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => _performSync());
    if (kDebugMode) debugPrint('[SyncService] Timer started (every 30s)');
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _onIdle);
  }

  void _onIdle() {
    _syncTimer?.cancel();
    _syncTimer = null;
    if (kDebugMode) debugPrint('[SyncService] Idle timeout — timer stopped');
  }

  void _cancelTimers() {
    _syncTimer?.cancel();
    _idleTimer?.cancel();
    _syncTimer = null;
    _idleTimer = null;
  }

  Future<void> _performSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    bool anySuccess = false;
    bool anyFailure = false;
    _lastSkippedCount = 0; // reset before each sync attempt

    try {
      // ── Participants ──────────────────────────────────────────────────────
      final unsyncedParticipants =
          await DatabaseService.getUnSyncedParticipants();

      if (unsyncedParticipants.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
              '[SyncService] Syncing ${unsyncedParticipants.length} participants...');
        }

        final result =
            await _httpService.syncParticipants(unsyncedParticipants);

        if (result.success) {
          // Delete only the specific IDs that were sent, not all online=0 records.
          // This prevents a race condition where a scan that arrived during the
          // in-flight HTTP request gets wrongly deleted from the queue.
          final ids = unsyncedParticipants.map((p) => p.isN).toList();
          await DatabaseService.clearSyncedParticipantsByIds(ids);
          anySuccess = true;
          _lastSkippedCount += _parseSkippedCount(result.message);
          if (kDebugMode) {
            debugPrint(
                '[SyncService] Participants synced: ${unsyncedParticipants.length}');
          }
        } else {
          anyFailure = true;
          if (kDebugMode) {
            debugPrint(
                '[SyncService] Participants sync failed: ${result.message}');
          }
        }
      }

      // ── Supervisors ───────────────────────────────────────────────────────
      final unsyncedSupervisors =
          await DatabaseService.getUnSyncedSupervisors();

      if (unsyncedSupervisors.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
              '[SyncService] Syncing ${unsyncedSupervisors.length} supervisors...');
        }

        final result = await _httpService.syncSupervisors(unsyncedSupervisors);

        if (result.success) {
          final cardNumbers =
              unsyncedSupervisors.map((s) => s.cardNumber).toList();
          await DatabaseService.clearSyncedSupervisorsByCardNumbers(
              cardNumbers);
          anySuccess = true;
          _lastSkippedCount += _parseSkippedCount(result.message);
          if (kDebugMode) {
            debugPrint(
                '[SyncService] Supervisors synced: ${unsyncedSupervisors.length}');
          }
        } else {
          anyFailure = true;
          if (kDebugMode) {
            debugPrint(
                '[SyncService] Supervisors sync failed: ${result.message}');
          }
        }
      }

      if (!anyFailure && !anySuccess) {
        // Nothing pending — consider it a success (nothing to do)
        _lastSyncSuccess = true;
      } else if (anySuccess && !anyFailure) {
        _lastSyncSuccess = true;
      } else {
        _lastSyncSuccess = false;
      }
    } catch (e) {
      anyFailure = true;
      _lastSyncSuccess = false;
      if (kDebugMode) debugPrint('[SyncService] Sync error: $e');
    } finally {
      _isSyncing = false;
      await _refreshPendingCount();
    }
  }

  Future<void> _refreshPendingCount() async {
    try {
      final p = await DatabaseService.getUnSyncedParticipants();
      final s = await DatabaseService.getUnSyncedSupervisors();
      _pendingParticipants = p.length;
      _pendingSupervisors = s.length;
    } catch (_) {
      _pendingParticipants = 0;
      _pendingSupervisors = 0;
    }
    notifyListeners();
  }

  /// Parses the PARTIAL_SYNC:{count} marker returned by the server
  /// when some records were not found in the DB (deleted between scan and sync).
  static int _parseSkippedCount(String message) {
    const prefix = 'PARTIAL_SYNC:';
    if (message.startsWith(prefix)) {
      return int.tryParse(message.substring(prefix.length)) ?? 0;
    }
    return 0;
  }
}
