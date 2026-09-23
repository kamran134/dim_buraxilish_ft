import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../models/participant_models.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_database_provider.dart';
import '../services/http_service.dart';
import 'session_switch_progress_dialog.dart';

/// Opens the "switch slot" bottom sheet for the currently selected slot
/// (built from the stored [ExamDetails.slots] — no extra network call), lets
/// the user pick a different slot, confirms, then runs the shared
/// [SessionSwitchProgressDialog] flow.
///
/// Used by both RealDashboardScreen (admin) and HomeScreen/MainScreen
/// (monitor) so the picker and the switch flow only exist once. [onSwitched]
/// is called after a switch actually completes (success, or "davam et" on
/// partial/empty data) so the caller can refresh whatever it shows
/// (statistics, exam details, ...).
Future<void> showSessionSwitcherSheet({
  required BuildContext context,
  VoidCallback? onSwitched,
}) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final httpService = HttpService();
  final details = await httpService.getExamDetailsFromStorage();
  if (!context.mounted) return;
  if (details == null || details.slots.isEmpty) {
    return;
  }

  final selected = await showModalBottomSheet<SlotSummary>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SlotListSheet(
      slots: details.slots,
      currentSlotKey: details.slotKey,
    ),
  );

  if (selected == null || !context.mounted) return;
  if (selected.key == details.slotKey) return; // already active

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Təsdiq'),
      content: Text(
          '${selected.label} seçilsin? Offline baza yenidən yüklənəcək.'),
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
      slot: selected,
      slots: details.slots,
    ),
  );

  if (result == true) {
    onSwitched?.call();
  }
}

class _SlotListSheet extends StatelessWidget {
  final List<SlotSummary> slots;
  final String? currentSlotKey;

  const _SlotListSheet({
    required this.slots,
    required this.currentSlotKey,
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
            'Slot seçin',
            style: AppTextStyles.h4.copyWith(
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ...slots.map((slot) {
            final isCurrent = slot.key == currentSlotKey;
            return ListTile(
              leading: Icon(
                isCurrent ? Icons.check_circle : Icons.schedule,
                color: isCurrent
                    ? AppColors.success
                    : (isDark ? Colors.white70 : AppColors.textSecondary),
              ),
              title: Text(
                slot.label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              onTap: () => Navigator.of(context).pop(slot),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
