import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/monitor_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/admin/admin_phone_chips.dart';
import '../widgets/qr_scanner.dart';
import '../widgets/manual_input_dialog.dart';
import 'admin/scan/admin_scan_views.dart';
import 'admin/scan/scan_activity_guard.dart';
import 'login_screen.dart';
import 'monitor_search_screen.dart';

class MonitorScreen extends StatefulWidget {
  /// Shown as a tab of the admin shell: the initial state has a drawer
  /// button ([onMenu]) instead of "back" — there is nothing to go back to.
  final bool inShell;
  final VoidCallback? onMenu;

  /// false while another tab of the shell is selected: a running camera is
  /// stopped and does not restart by itself.
  final bool active;

  const MonitorScreen({
    super.key,
    this.inShell = false,
    this.onMenu,
    this.active = true,
  });

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  @override
  void initState() {
    super.initState();

    // Initialize provider and set auth error callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MonitorProvider>();

      // Set authentication error callback
      provider.setAuthenticationErrorCallback(() {
        _handleAuthenticationError();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitorProvider>(
      builder: (context, provider, child) {
        switch (provider.screenState) {
          case MonitorScreenState.initial:
            return _buildInitialView(provider);
          case MonitorScreenState.scanning:
            return _buildScanningView(provider);
          case MonitorScreenState.scanned:
            return _buildScannedView(provider);
          case MonitorScreenState.error:
            return _buildErrorView(provider);
        }
      },
    );
  }

  Widget _buildInitialView(MonitorProvider provider) {
    return AdminScanHomeView(
      inShell: widget.inShell,
      onMenu: widget.onMenu,
      loading: provider.isLoading,
      errorMessage: provider.errorMessage,
      onScan: () => provider.setScreenState(MonitorScreenState.scanning),
      onManualInput: () => ManualInputDialog.showMonitorDialog(
        context,
        (input) {
          Navigator.of(context).pop();
          provider.scanMonitor(input);
        },
      ),
      onSearch: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MonitorSearchScreen()),
        );
      },
    );
  }

  Widget _buildScanningView(MonitorProvider provider) {
    // The guard stops the camera (back to the start state) when the tab is
    // left, a page covers the screen or the app goes to the background.
    return ScanActivityGuard(
      active: widget.active,
      onDeactivate: () {
        if (provider.screenState == MonitorScreenState.scanning) {
          provider.setScreenState(MonitorScreenState.initial);
        }
      },
      child: Scaffold(
        body: QRScannerWidget(
          scannerType: 'monitor',
          onScan: (code) async {
            await provider.scanMonitor(code);
          },
          onClose: () {
            provider.setScreenState(MonitorScreenState.initial);
          },
        ),
      ),
    );
  }

  Widget _buildScannedView(MonitorProvider provider) {
    return AdminScanResultView(
      monitor: provider.currentMonitor!,
      successMessage: provider.successMessage,
      isRepeatEntry: provider.isRepeatEntry,
      loading: provider.isLoading,
      onBack: provider.resetToInitial,
      onNext: () {
        provider.resetToInitial();
        provider.setScreenState(MonitorScreenState.scanning);
      },
      onCancelRegistration: () => provider.cancelRegistration(),
      onCall: callAdminPhone,
    );
  }

  Widget _buildErrorView(MonitorProvider provider) {
    return AdminScanErrorView(
      message: provider.errorMessage,
      onBack: provider.resetToInitial,
      onRescan: () => provider.setScreenState(MonitorScreenState.scanning),
    );
  }

  void _handleAuthenticationError() async {
    if (!mounted) return;

    // Clear authentication data
    final authProvider = context.read<AuthProvider>();
    await authProvider.signOut();

    if (!mounted) return;

    // Navigate to login screen and replace all previous screens
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
      (route) => false,
    );
  }
}
