import '../models/participant_models.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_database_provider.dart';
import 'database_service.dart';
import 'http_service.dart';
import 'sync_service.dart';

/// Unified outcome of a session switch's download step, covering both the
/// admin path (all monitors) and the regular participant+supervisor path —
/// so every screen that lets a user pick a session renders the same states
/// instead of re-implementing the download orchestration.
enum SessionSwitchResult { success, partialSuccess, emptyData, networkError }

class SessionSwitchOutcome {
  final SessionSwitchResult result;
  final int participantCount;
  final int supervisorCount;
  final bool missingParticipants;

  /// Human-readable detail. Always set on [SessionSwitchResult.networkError]
  /// (surfaced from [OfflineDatabaseProvider.errorMessage] — never swallowed)
  /// and on [SessionSwitchResult.partialSuccess].
  final String? message;

  const SessionSwitchOutcome({
    required this.result,
    this.participantCount = 0,
    this.supervisorCount = 0,
    this.missingParticipants = false,
    this.message,
  });
}

/// Single place that knows how to switch the app's active exam session:
/// flush the unsynced queue, wipe the offline tables, persist the new
/// session, update [AuthProvider], and re-download the offline database for
/// the current user's role (admin: all monitors; monitor/nəzarətçi:
/// participants + supervisors).
///
/// Used by ExamSelectScreen, RealDashboardScreen and HomeScreen so this flow
/// only exists once. Does NOT touch [DatabaseService]/[SyncService]
/// internals or scanning — it only calls their existing public methods, the
/// same way ExamSelectScreen already did before this was extracted.
class ExamSessionSwitcher {
  const ExamSessionSwitcher._();

  /// Steps a–c: flush the unsynced queue (best-effort), clear the
  /// master/offline tables (the registration queue survives — see
  /// [DatabaseService.clearAllDatabase]'s doc comment), then persist the
  /// newly picked session and update [authProvider] so every provider that
  /// reads it sees the change immediately.
  ///
  /// Call this once per switch. To retry only the download after a failed
  /// [downloadForRole], call [downloadForRole] again directly — re-running
  /// this step is unnecessary (though harmless: sync/clear are idempotent).
  static Future<void> persistSelection({
    required AuthProvider authProvider,
    required HttpService httpService,
    required int examId,
    required String examName,
    required int sessionId,
    required String sessionLabel,
    required String legacyImtTarix,
    required List<ExamSessionSummary> sessions,
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
      imtTarix: legacyImtTarix,
      examId: examId,
      examName: examName,
      sessionId: sessionId,
      sessionLabel: sessionLabel,
      sessions: sessions,
    );
    await httpService.storeExamDetails(newDetails);
    authProvider.setActiveExam(
      imtTarix: legacyImtTarix,
      examName: examName,
      sessionLabel: sessionLabel,
    );
  }

  /// Step d: download the offline database for the current role — same
  /// branch by role that used to run right after login / on
  /// ExamSelectScreen. Errors are never swallowed: on failure, the real
  /// message from [OfflineDatabaseProvider.errorMessage] is returned so the
  /// caller can show it (the admin path previously ignored this entirely —
  /// that was the bug).
  ///
  /// Safe to call again on its own to retry just the download.
  static Future<SessionSwitchOutcome> downloadForRole({
    required AuthProvider authProvider,
    required OfflineDatabaseProvider offlineProvider,
  }) async {
    if (authProvider.canAccessDashboard) {
      await offlineProvider.downloadAdminOfflineDatabase();
      final error = offlineProvider.errorMessage;
      if (error != null) {
        return SessionSwitchOutcome(
          result: SessionSwitchResult.networkError,
          message: error,
        );
      }
      return const SessionSwitchOutcome(result: SessionSwitchResult.success);
    }

    final result = await offlineProvider.downloadOfflineDatabase();
    switch (result) {
      case OfflineDownloadResult.success:
        offlineProvider.reportDownloadComplete();
        return SessionSwitchOutcome(
          result: SessionSwitchResult.success,
          participantCount: offlineProvider.participantCount,
          supervisorCount: offlineProvider.supervisorCount,
        );
      case OfflineDownloadResult.partialSuccess:
        final missingParticipants = offlineProvider.participantCount == 0;
        return SessionSwitchOutcome(
          result: SessionSwitchResult.partialSuccess,
          participantCount: offlineProvider.participantCount,
          supervisorCount: offlineProvider.supervisorCount,
          missingParticipants: missingParticipants,
          message: missingParticipants
              ? 'İştirakçılar yüklənmədi.'
              : 'Nəzarətçilər yüklənmədi.',
        );
      case OfflineDownloadResult.emptyData:
        return const SessionSwitchOutcome(result: SessionSwitchResult.emptyData);
      case OfflineDownloadResult.networkError:
        return SessionSwitchOutcome(
          result: SessionSwitchResult.networkError,
          message: offlineProvider.errorMessage,
        );
    }
  }

  /// Convenience wrapper combining [persistSelection] + [downloadForRole]
  /// for callers that don't need to retry the download separately (e.g. the
  /// bottom-sheet switcher — it always starts a fresh attempt from the
  /// beginning).
  static Future<SessionSwitchOutcome> switchSession({
    required AuthProvider authProvider,
    required OfflineDatabaseProvider offlineProvider,
    required HttpService httpService,
    required int examId,
    required String examName,
    required int sessionId,
    required String sessionLabel,
    required String legacyImtTarix,
    required List<ExamSessionSummary> sessions,
  }) async {
    await persistSelection(
      authProvider: authProvider,
      httpService: httpService,
      examId: examId,
      examName: examName,
      sessionId: sessionId,
      sessionLabel: sessionLabel,
      legacyImtTarix: legacyImtTarix,
      sessions: sessions,
    );
    return downloadForRole(
      authProvider: authProvider,
      offlineProvider: offlineProvider,
    );
  }
}
