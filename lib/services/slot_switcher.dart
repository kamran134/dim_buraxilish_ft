import '../models/participant_models.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_database_provider.dart';
import 'database_service.dart';
import 'http_service.dart';
import 'sync_service.dart';

/// Unified outcome of a slot switch's download step, covering both the
/// admin path (all monitors) and the regular participant+supervisor path —
/// so every screen that lets a user pick a slot renders the same states
/// instead of re-implementing the download orchestration.
enum SlotSwitchResult { success, partialSuccess, emptyData, networkError }

class SlotSwitchOutcome {
  final SlotSwitchResult result;
  final int participantCount;
  final int supervisorCount;
  final bool missingParticipants;

  /// Human-readable detail. Always set on [SlotSwitchResult.networkError]
  /// (surfaced from [OfflineDatabaseProvider.errorMessage] — never swallowed,
  /// including the explicit "invalid slot" 400 case) and on
  /// [SlotSwitchResult.partialSuccess].
  final String? message;

  const SlotSwitchOutcome({
    required this.result,
    this.participantCount = 0,
    this.supervisorCount = 0,
    this.missingParticipants = false,
    this.message,
  });
}

/// Single place that knows how to switch the app's active slot: flush the
/// unsynced queue, wipe the offline tables, persist the new slot, update
/// [AuthProvider], and re-download the offline database for the current
/// user's role (admin: all monitors; monitor: participants + supervisors).
///
/// A slot (date + start time) may cover several exams in the same building —
/// scanning at the door happens per building+slot, never per exam (see
/// API_slots.md). `IS_N` is unique within a slot, so the sqflite v8 schema
/// (one exam session's worth of rows at a time) still applies unmodified —
/// nothing here touches [DatabaseService]/[SyncService] internals or
/// scanning, it only calls their existing public methods, same as the
/// exam+session version this replaces (formerly `ExamSessionSwitcher`).
///
/// Used by ExamSelectScreen, RealDashboardScreen and HomeScreen so this flow
/// only exists once.
class SlotSwitcher {
  const SlotSwitcher._();

  /// Steps a–c: flush the unsynced queue (best-effort), clear the
  /// master/offline tables (the registration queue survives — see
  /// [DatabaseService.clearAllDatabase]'s doc comment), then persist the
  /// newly picked slot and update [authProvider] so every provider that
  /// reads it sees the change immediately.
  ///
  /// Call this once per switch. To retry only the download after a failed
  /// [downloadForRole], call [downloadForRole] again directly — re-running
  /// this step is unnecessary (though harmless: sync/clear are idempotent).
  static Future<void> persistSelection({
    required AuthProvider authProvider,
    required HttpService httpService,
    required String slotKey,
    required String slotLabel,
    required String legacyDate,
    required List<SlotSummary> slots,
    void Function(int remainingUnsynced)? onUnsyncedRemaining,
  }) async {
    final unsyncedParticipants = await DatabaseService.getUnSyncedParticipants();
    final unsyncedSupervisors = await DatabaseService.getUnSyncedSupervisors();
    if (unsyncedParticipants.isNotEmpty || unsyncedSupervisors.isNotEmpty) {
      await SyncService.instance.syncNow();

      if (onUnsyncedRemaining != null) {
        final remainingP = await DatabaseService.getUnSyncedParticipants();
        final remainingS = await DatabaseService.getUnSyncedSupervisors();
        final remaining = remainingP.length + remainingS.length;
        if (remaining > 0) onUnsyncedRemaining(remaining);
      }
    }

    await DatabaseService.clearAllDatabase();

    final existing = await httpService.getExamDetailsFromStorage();
    final newDetails = ExamDetails(
      kodBina: existing?.kodBina,
      adBina: existing?.adBina,
      imtTarix: legacyDate,
      slotKey: slotKey,
      slotLabel: slotLabel,
      slots: slots,
    );
    await httpService.storeExamDetails(newDetails);
    authProvider.setActiveExam(
      imtTarix: legacyDate,
      slotLabel: slotLabel,
    );
  }

  /// Step d: download the offline database for the current role — same
  /// branch by role that used to run right after login / on
  /// ExamSelectScreen. Errors are never swallowed: on failure, the real
  /// message from [OfflineDatabaseProvider.errorMessage] is returned so the
  /// caller can show it (this includes the explicit "invalid slot" 400 case
  /// — see [OfflineDatabaseProvider.downloadOfflineDatabase]).
  ///
  /// Safe to call again on its own to retry just the download.
  static Future<SlotSwitchOutcome> downloadForRole({
    required AuthProvider authProvider,
    required OfflineDatabaseProvider offlineProvider,
  }) async {
    if (authProvider.canAccessDashboard) {
      await offlineProvider.downloadAdminOfflineDatabase();
      final error = offlineProvider.errorMessage;
      if (error != null) {
        return SlotSwitchOutcome(
          result: SlotSwitchResult.networkError,
          message: error,
        );
      }
      return const SlotSwitchOutcome(result: SlotSwitchResult.success);
    }

    final result = await offlineProvider.downloadOfflineDatabase();
    switch (result) {
      case OfflineDownloadResult.success:
        offlineProvider.reportDownloadComplete();
        return SlotSwitchOutcome(
          result: SlotSwitchResult.success,
          participantCount: offlineProvider.participantCount,
          supervisorCount: offlineProvider.supervisorCount,
        );
      case OfflineDownloadResult.partialSuccess:
        final missingParticipants = offlineProvider.participantCount == 0;
        return SlotSwitchOutcome(
          result: SlotSwitchResult.partialSuccess,
          participantCount: offlineProvider.participantCount,
          supervisorCount: offlineProvider.supervisorCount,
          missingParticipants: missingParticipants,
          message: missingParticipants
              ? 'İştirakçılar yüklənmədi.'
              : 'Nəzarətçilər yüklənmədi.',
        );
      case OfflineDownloadResult.emptyData:
        return const SlotSwitchOutcome(result: SlotSwitchResult.emptyData);
      case OfflineDownloadResult.networkError:
        return SlotSwitchOutcome(
          result: SlotSwitchResult.networkError,
          message: offlineProvider.errorMessage,
        );
    }
  }

  /// Convenience wrapper combining [persistSelection] + [downloadForRole]
  /// for callers that don't need to retry the download separately (e.g. the
  /// bottom-sheet switcher — it always starts a fresh attempt from the
  /// beginning).
  static Future<SlotSwitchOutcome> switchSlot({
    required AuthProvider authProvider,
    required OfflineDatabaseProvider offlineProvider,
    required HttpService httpService,
    required String slotKey,
    required String slotLabel,
    required String legacyDate,
    required List<SlotSummary> slots,
  }) async {
    await persistSelection(
      authProvider: authProvider,
      httpService: httpService,
      slotKey: slotKey,
      slotLabel: slotLabel,
      legacyDate: legacyDate,
      slots: slots,
    );
    return downloadForRole(
      authProvider: authProvider,
      offlineProvider: offlineProvider,
    );
  }
}
