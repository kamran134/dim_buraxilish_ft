import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../models/monitor_models.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/common/message_display.dart';

const String _scanTitle = 'İmtahan rəhbərləri';

/// Start screen of the imtahan rəhbəri scanner: QR scan, manual input and
/// search by name. Pure view — [MonitorScreen] feeds it from the provider.
class AdminScanHomeView extends StatelessWidget {
  final bool inShell;
  final VoidCallback? onMenu;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onScan;
  final VoidCallback onManualInput;
  final VoidCallback onSearch;

  const AdminScanHomeView({
    super.key,
    this.inShell = false,
    this.onMenu,
    this.loading = false,
    this.errorMessage,
    required this.onScan,
    required this.onManualInput,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: _scanTitle,
      inShell: inShell,
      onMenu: onMenu,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - AppSpacing.lg * 2,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminGlassCard(
                    padding: AppSpacing.paddingLG,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          size: 64,
                          color: Colors.white,
                        ),
                        AppSpacing.verticalGapMD,
                        Text(
                          _scanTitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h3.copyWith(color: Colors.white),
                        ),
                        AppSpacing.verticalGapSM,
                        Text(
                          'QR kod skaneri ilə imtahan rəhbəri məlumatlarını '
                          'oxuyun',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.verticalGapLG,
                  AdminActionButton(
                    label: 'Skan et',
                    icon: Icons.qr_code_scanner,
                    onPressed: onScan,
                  ),
                  AppSpacing.verticalGapMD,
                  AdminActionButton(
                    label: 'Əllə daxil et',
                    icon: Icons.keyboard,
                    style: AdminActionStyle.glass,
                    onPressed: onManualInput,
                  ),
                  AppSpacing.verticalGapMD,
                  AdminActionButton(
                    label: 'Ad ilə axtar',
                    icon: Icons.person_search,
                    style: AdminActionStyle.glass,
                    onPressed: onSearch,
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.lg),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  if (!loading && errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: MessageDisplay(
                        message: errorMessage!,
                        type: MessageType.error,
                        margin: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Result of a scan: the imtahan rəhbəri's card with the cancel-registration
/// and "next scan" actions pinned below.
class AdminScanResultView extends StatelessWidget {
  final Monitor monitor;
  final String? successMessage;
  final bool isRepeatEntry;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onCancelRegistration;
  final ValueChanged<String> onCall;

  const AdminScanResultView({
    super.key,
    required this.monitor,
    this.successMessage,
    this.isRepeatEntry = false,
    this.loading = false,
    required this.onBack,
    required this.onNext,
    required this.onCancelRegistration,
    required this.onCall,
  });

  /// Asks for confirmation, then calls [onConfirmed].
  static Future<void> confirmCancel(
    BuildContext context,
    VoidCallback onConfirmed,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Təsdiq'),
        content: const Text('Qeydiyyatını silmək istədiyinizdən əminsinizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Xeyr'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Bəli',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final phones = splitAdminPhones(monitor.phone);
    final hasRegisterDate =
        monitor.registerDate.isNotEmpty && monitor.registerDate != 'null';
    final name =
        '${monitor.firstName} ${monitor.lastName} ${monitor.middleName}'.trim();

    return AdminPage(
      title: 'İmtahan rəhbəri məlumatları',
      onBack: onBack,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (successMessage != null)
                    MessageDisplay(
                      message: successMessage!,
                      type: MessageType.success,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    ),
                  AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AdminPersonHeader(
                          photoData: monitor.image,
                          placeholderIcon: Icons.supervisor_account,
                          name: name.isEmpty ? '—' : name,
                          identifier: 'İş nömrəsi: ${monitor.workNumber}',
                          status: AdminStatusBadge(
                            status: isRepeatEntry
                                ? AdminStatus.warning
                                : AdminStatus.registered,
                            label: isRepeatEntry
                                ? 'Təkrar giriş'
                                : 'Qeydiyyatdan keçdi',
                          ),
                        ),
                        AppSpacing.verticalGapSM,
                        AdminKeyValueList(
                          items: [
                            if (monitor.roomName.isNotEmpty)
                              AdminKeyValue('Otaq', monitor.roomName),
                            if (monitor.idCardPin.isNotEmpty)
                              AdminKeyValue('FİN', monitor.idCardPin),
                            if (monitor.buildingCode > 0)
                              AdminKeyValue(
                                'Bina kodu',
                                monitor.buildingCode.toString(),
                              ),
                            if (monitor.buildingName.isNotEmpty)
                              AdminKeyValue('Bina adı', monitor.buildingName),
                            if (hasRegisterDate)
                              AdminKeyValue(
                                'Qeydiyyat tarixi',
                                DateFormatter.formatISOToAz(
                                  monitor.registerDate,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (phones.isNotEmpty) ...[
                    AppSpacing.verticalGapMD,
                    AdminCard(
                      title: 'Telefon nömrəsi',
                      child: AdminPhoneChips(phones: phones, onCall: onCall),
                    ),
                  ],
                  AppSpacing.verticalGapMD,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AdminActionButton(
                    label: 'Ləğv et',
                    style: AdminActionStyle.danger,
                    onPressed: loading
                        ? null
                        : () => confirmCancel(context, onCancelRegistration),
                  ),
                ),
                AppSpacing.horizontalGapMD,
                Expanded(
                  flex: 3,
                  child: AdminActionButton(
                    label: 'Növbəti',
                    icon: Icons.qr_code_scanner,
                    onPressed: onNext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state of the scanner: what went wrong, "back" and "scan again".
class AdminScanErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback onBack;
  final VoidCallback onRescan;

  const AdminScanErrorView({
    super.key,
    this.message,
    required this.onBack,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: _scanTitle,
      onBack: onBack,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - AppSpacing.lg * 2,
            ),
            child: Center(
              child: AdminCard(
                padding: AppSpacing.paddingLG,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: AppColors.error,
                      semanticLabel: 'Xəta',
                    ),
                    AppSpacing.verticalGapMD,
                    Text(
                      'Xəta baş verdi',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h3.copyWith(
                        color: AdminStyle.textPrimary(context),
                      ),
                    ),
                    AppSpacing.verticalGapSM,
                    Text(
                      message ?? 'Naməlum xəta',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AdminStyle.textSecondary(context),
                      ),
                    ),
                    AppSpacing.verticalGapLG,
                    AdminActionButton(
                      label: 'Yenidən skanla',
                      icon: Icons.qr_code_scanner,
                      style: AdminActionStyle.filled,
                      onPressed: onRescan,
                    ),
                    AppSpacing.verticalGapSM,
                    AdminActionButton(
                      label: 'Geri qayıt',
                      style: AdminActionStyle.outlined,
                      onPressed: onBack,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
