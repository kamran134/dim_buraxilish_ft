import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/monitor_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/qr_scanner.dart';
import '../widgets/manual_input_dialog.dart';
import '../widgets/common/common_widgets.dart';
import 'login_screen.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Consumer<MonitorProvider>(
        builder: (context, provider, child) {
          switch (provider.screenState) {
            case MonitorScreenState.initial:
              return _buildInitialView(provider, isDarkMode);
            case MonitorScreenState.scanning:
              return _buildScanningView(provider);
            case MonitorScreenState.scanned:
              return _buildScannedView(provider, isDarkMode);
            case MonitorScreenState.error:
              return _buildErrorView(provider, isDarkMode);
          }
        },
      ),
    );
  }

  Widget _buildInitialView(MonitorProvider provider, bool isDarkMode) {
    // Green gradient for monitors
    const greenGradient = [
      Color(0xFF059669), // emerald-600
      Color(0xFF047857), // emerald-700
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF065F46), // darker green for dark mode
                  const Color(0xFF064E3B),
                ]
              : greenGradient,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            ScreenHeader(
              title: 'İmtahan rəhbərləri',
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Welcome Section
                    AnimatedWrapper(
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: AppColors.whiteTransparent15,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.blackText.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              size: 64,
                              color: AppColors.white,
                            ),
                            SizedBox(height: 20),
                            Text(
                              'İmtahan rəhbərləri',
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'QR kod skaneri ilə imtahan rəhbəri məlumatlarını oxuyun',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: AppColors.lightGrey200,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Action Buttons
                    AnimatedWrapper(
                      child: Column(
                        children: [
                          ActionButton.scan(
                            onPressed: () => provider
                                .setScreenState(MonitorScreenState.scanning),
                            backgroundColor:
                                const Color(0xFF10B981), // green-500
                          ),
                          const SizedBox(height: 16),
                          ActionButton.manualInput(
                            onPressed: () =>
                                ManualInputDialog.showMonitorDialog(
                              context,
                              (input) {
                                Navigator.of(context).pop();
                                provider.scanMonitor(input);
                              },
                            ),
                            backgroundColor:
                                const Color(0xFF059669), // green-600
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Loading indicator
                    if (provider.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),

                    // Error Display (only show if not loading and there's an error)
                    if (!provider.isLoading && provider.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: MessageDisplay(
                          message: provider.errorMessage!,
                          type: MessageType.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningView(MonitorProvider provider) {
    return QRScannerWidget(
      scannerType: 'monitor',
      onScan: (code) async {
        await provider.scanMonitor(code);
      },
      onClose: () {
        provider.setScreenState(MonitorScreenState.initial);
      },
    );
  }

  Widget _buildScannedView(MonitorProvider provider, bool isDarkMode) {
    final monitor = provider.currentMonitor!;

    // Green gradient for monitors
    const greenGradient = [
      Color(0xFF059669), // emerald-600
      Color(0xFF047857), // emerald-700
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF065F46), // darker green for dark mode
                  const Color(0xFF064E3B),
                ]
              : greenGradient,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            ScreenHeader(
              title: 'İmtahan rəhbəri məlumatları',
              onBackPressed: () => provider.resetToInitial(),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Success message
                    if (provider.successMessage != null)
                      MessageDisplay(
                        message: provider.successMessage!,
                        type: MessageType.success,
                      ),

                    // Monitor Info Card
                    InfoCard(
                      fullName: '${monitor.firstName} ${monitor.lastName}',
                      subtitle: monitor.middleName.isNotEmpty
                          ? 'Ata adı: ${monitor.middleName}'
                          : 'Əməkdaşlıq №: ${monitor.workNumber}',
                      photoWidget: PhotoWidget.supervisor(
                        photoData: monitor.image,
                      ),
                      isRepeatEntry: provider.isRepeatEntry,
                      borderColor: provider.isRepeatEntry
                          ? AppColors.darkRed
                          : const Color(0xFF10B981), // green-500
                      actionButton: null,
                      details: [
                        InfoDetail(
                            label: 'Əməkdaşlıq №',
                            value: monitor.workNumber.toString()),
                        if (monitor.idCardPin.isNotEmpty)
                          InfoDetail(label: 'FİN', value: monitor.idCardPin),
                        if (monitor.buildingCode > 0)
                          InfoDetail(
                              label: 'Bina kodu',
                              value: monitor.buildingCode.toString()),
                        if (monitor.buildingName.isNotEmpty)
                          InfoDetail(
                              label: 'Bina adı', value: monitor.buildingName),
                        if (monitor.roomId > 0)
                          InfoDetail(
                              label: 'Otaq №',
                              value: monitor.roomId.toString()),
                        if (monitor.roomName.isNotEmpty)
                          InfoDetail(
                              label: 'Otaq adı', value: monitor.roomName),
                        if (monitor.registerDate.isNotEmpty &&
                            monitor.registerDate != 'null')
                          InfoDetail(
                              label: 'Qeydiyyat tarixi',
                              value: monitor.registerDate),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Action buttons row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          // Cancel Registration Button (small, red, left side)
                          SizedBox(
                            width: 100,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: provider.isLoading
                                  ? null
                                  : () async {
                                      // Show confirmation dialog
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => Theme(
                                          data: Theme.of(context).copyWith(
                                            dialogTheme: DialogThemeData(
                                              backgroundColor: isDarkMode
                                                  ? Colors.grey[850]
                                                  : Colors.white,
                                              titleTextStyle: TextStyle(
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              contentTextStyle: TextStyle(
                                                color: isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black87,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          child: AlertDialog(
                                            title: const Text('Təsdiq'),
                                            content: const Text(
                                              'Qeydiyyatını silmək istədiyinizdən əminsinizmi?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(false),
                                                child: Text(
                                                  'Xeyr',
                                                  style: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(true),
                                                child: const Text(
                                                  'Bəli',
                                                  style: TextStyle(
                                                      color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );

                                      if (confirm == true) {
                                        await provider.cancelRegistration();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Ləğv et',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Next Button (main, large, right side)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                provider.resetToInitial();
                                provider.setScreenState(
                                    MonitorScreenState.scanning);
                              },
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Növbəti'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF10B981), // green-500
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(MonitorProvider provider, bool isDarkMode) {
    // Green gradient for monitors
    const greenGradient = [
      Color(0xFF059669), // emerald-600
      Color(0xFF047857), // emerald-700
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF065F46), // darker green for dark mode
                  const Color(0xFF064E3B),
                ]
              : greenGradient,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: AppColors.whiteTransparent95,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 80,
                        color: AppColors.redButton,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Xəta baş verdi',
                        style: TextStyle(
                          fontSize: 24, // h2 equivalent
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        provider.errorMessage ?? 'Naməlum xəta',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => provider.resetToInitial(),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Geri qayıt'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => provider
                                  .setScreenState(MonitorScreenState.scanning),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF10B981), // green-500
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Yenidən skanla'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
