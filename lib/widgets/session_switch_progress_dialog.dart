import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../models/participant_models.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_database_provider.dart';
import '../services/slot_switcher.dart';
import '../services/http_service.dart';

enum _DialogPhase { syncing, downloading, success, partial, empty, error }

/// Non-dismissible dialog that drives [SlotSwitcher] end to end and shows
/// its progress/result, with an explicit retry on failure — used by every
/// screen that lets the user switch slots outside of ExamSelectScreen
/// (which has its own full-screen overlay for the same states). Errors are
/// always shown, never swallowed.
///
/// Pops with `true` once the switch actually completed (success, or the user
/// chose to continue despite partial/empty data), `false`/`null` otherwise.
class SessionSwitchProgressDialog extends StatefulWidget {
  final AuthProvider authProvider;
  final OfflineDatabaseProvider offlineProvider;
  final HttpService httpService;
  final SlotSummary slot;
  final List<SlotSummary> slots;

  const SessionSwitchProgressDialog({
    super.key,
    required this.authProvider,
    required this.offlineProvider,
    required this.httpService,
    required this.slot,
    required this.slots,
  });

  @override
  State<SessionSwitchProgressDialog> createState() =>
      _SessionSwitchProgressDialogState();
}

class _SessionSwitchProgressDialogState
    extends State<SessionSwitchProgressDialog> {
  _DialogPhase _phase = _DialogPhase.syncing;
  String? _detail;
  bool _missingParticipants = false;
  int _participants = 0;
  int _supervisors = 0;
  bool _persisted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!_persisted) {
      if (mounted) setState(() => _phase = _DialogPhase.syncing);
      await SlotSwitcher.persistSelection(
        authProvider: widget.authProvider,
        httpService: widget.httpService,
        slotKey: widget.slot.key,
        slotLabel: widget.slot.label,
        legacyDate: widget.slot.legacyDate,
        slots: widget.slots,
      );
      _persisted = true;
    }
    if (!mounted) return;

    setState(() => _phase = _DialogPhase.downloading);
    final outcome = await SlotSwitcher.downloadForRole(
      authProvider: widget.authProvider,
      offlineProvider: widget.offlineProvider,
    );
    if (!mounted) return;

    switch (outcome.result) {
      case SlotSwitchResult.success:
        setState(() {
          _phase = _DialogPhase.success;
          _participants = outcome.participantCount;
          _supervisors = outcome.supervisorCount;
        });
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop(true);
      case SlotSwitchResult.partialSuccess:
        setState(() {
          _phase = _DialogPhase.partial;
          _detail = outcome.message;
          _missingParticipants = outcome.missingParticipants;
        });
      case SlotSwitchResult.emptyData:
        setState(() {
          _phase = _DialogPhase.empty;
          _detail =
              'Server bu bina üçün məlumat qaytarmadı. Tarixin düzgünlüyünü və internet bağlantısını yoxlayın.';
        });
      case SlotSwitchResult.networkError:
        setState(() {
          _phase = _DialogPhase.error;
          _detail = outcome.message ??
              'Məlumatlar yüklənmədi. Bağlantını yoxlayıb yenidən cəhd edin.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase == _DialogPhase.syncing ||
        _phase == _DialogPhase.downloading;
    return PopScope(
      canPop: !busy,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_phase) {
      case _DialogPhase.syncing:
        return _spinner('Göndərilməmiş məlumat göndərilir...');
      case _DialogPhase.downloading:
        return _spinner('Məlumatlar yüklənir...');
      case _DialogPhase.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 48),
            const SizedBox(height: 12),
            Text('Növbə dəyişdirildi', style: AppTextStyles.h4),
            if (_participants > 0 || _supervisors > 0) ...[
              const SizedBox(height: 6),
              Text('$_participants iştirakçı · $_supervisors nəzarətçi',
                  style: AppTextStyles.bodyMedium),
            ],
          ],
        );
      case _DialogPhase.partial:
        return _resultWithRetry(
          icon: Icons.warning_amber_rounded,
          title: 'Natamam yükləndi',
          message: _detail ?? '',
          continueLabel: _missingParticipants
              ? 'Bu imtahanda iştirakçı yoxdur'
              : 'Bu imtahanda nəzarətçi yoxdur',
        );
      case _DialogPhase.empty:
        return _resultWithRetry(
          icon: Icons.warning_amber_rounded,
          title: 'Məlumat tapılmadı',
          message: _detail ?? '',
        );
      case _DialogPhase.error:
        return _resultWithRetry(
          icon: Icons.wifi_off_rounded,
          title: 'Yükləmə uğursuz oldu',
          message: _detail ?? '',
        );
    }
  }

  Widget _spinner(String text) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
        ],
      );

  Widget _resultWithRetry({
    required IconData icon,
    required String title,
    required String message,
    String? continueLabel,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.error, size: 48),
        const SizedBox(height: 12),
        Text(title, style: AppTextStyles.h4, textAlign: TextAlign.center),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
        ],
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Bağla'),
            ),
            ElevatedButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yenidən cəhd et'),
            ),
          ],
        ),
        if (continueLabel != null) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(continueLabel),
          ),
        ],
      ],
    );
  }
}
