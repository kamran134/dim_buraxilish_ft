import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../models/participant_models.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_database_provider.dart';
import '../services/http_service.dart';
import 'session_switch_progress_dialog.dart';

/// Opens the "switch session" bottom sheet for the currently selected exam
/// (built from the stored [ExamDetails.sessions] — no extra network call),
/// lets the user pick a different session, confirms, then runs the shared
/// [SessionSwitchProgressDialog] flow.
///
/// Used by both RealDashboardScreen (admin) and HomeScreen/MainScreen
/// (monitor/nəzarətçi) so the picker and the switch flow only exist once.
/// [onSwitched] is called after a switch actually completes (success, or
/// "davam et" on partial/empty data) so the caller can refresh whatever it
/// shows (statistics, exam details, ...).
Future<void> showSessionSwitcherSheet({
  required BuildContext context,
  VoidCallback? onSwitched,
}) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final httpService = HttpService();
  final details = await httpService.getExamDetailsFromStorage();
  if (!context.mounted) return;
  if (details == null || details.sessions.isEmpty || details.examId == null) {
    return;
  }

  final selected = await showModalBottomSheet<ExamSessionSummary>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SessionListSheet(
      sessions: details.sessions,
      currentSessionId: details.sessionId,
    ),
  );

  if (selected == null || !context.mounted) return;
  if (selected.id == details.sessionId) return; // already active

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Təsdiq'),
      content: Text(
          '${details.examName} · ${selected.label} seçilsin? Offline baza yenidən yüklənəcək.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Ləğv et'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Seç'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final offlineProvider =
      Provider.of<OfflineDatabaseProvider>(context, listen: false);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SessionSwitchProgressDialog(
      authProvider: authProvider,
      offlineProvider: offlineProvider,
      httpService: httpService,
      examId: details.examId!,
      examName: details.examName ?? '',
      session: selected,
      sessions: details.sessions,
    ),
  );

  if (result == true) {
    onSwitched?.call();
  }
}

class _SessionListSheet extends StatelessWidget {
  final List<ExamSessionSummary> sessions;
  final int? currentSessionId;

  const _SessionListSheet({
    required this.sessions,
    required this.currentSessionId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            'Növbə seçin',
            style: AppTextStyles.h4.copyWith(
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...sessions.map((session) {
            final disabled = session.legacyImtTarix == null;
            final isCurrent = session.id == currentSessionId;
            return ListTile(
              enabled: !disabled,
              leading: Icon(
                isCurrent ? Icons.check_circle : Icons.schedule,
                color: isCurrent
                    ? AppColors.success
                    : (isDark ? Colors.white70 : AppColors.textSecondary),
              ),
              title: Text(
                session.label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: disabled
                      ? (isDark ? Colors.white38 : Colors.black38)
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              subtitle: disabled
                  ? const Text('Köhnə sistemlə əlaqələndirilməyib')
                  : null,
              onTap:
                  disabled ? null : () => Navigator.of(context).pop(session),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
