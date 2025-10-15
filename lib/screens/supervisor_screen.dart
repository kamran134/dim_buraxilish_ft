import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/supervisor_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_database_provider.dart';
import '../widgets/qr_scanner.dart';
import '../widgets/manual_input_dialog.dart';
import '../widgets/common/common_widgets.dart';
import 'login_screen.dart';
import 'participant_screen.dart';
import 'statistics_screen.dart';
import 'protocol_notes_screen.dart';
import 'protocol_reports_screen.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class SupervisorScreen extends StatefulWidget {
  const SupervisorScreen({super.key});

  @override
  State<SupervisorScreen> createState() => _SupervisorScreenState();
}

class _SupervisorScreenState extends State<SupervisorScreen> {
  @override
  void initState() {
    super.initState();

    // Load supervisor details when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SupervisorProvider>();
      final offlineDbProvider = context.read<OfflineDatabaseProvider>();

      // Set reference to OfflineDatabaseProvider
      provider.setOfflineDatabaseProvider(offlineDbProvider);

      // Set authentication error callback
      provider.setAuthenticationErrorCallback(() {
        _handleAuthenticationError();
      });

      provider.loadSupervisorDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Consumer2<SupervisorProvider, OfflineDatabaseProvider>(
        builder: (context, provider, offlineProvider, child) {
          switch (provider.screenState) {
            case SupervisorScreenState.initial:
              return _buildInitialView(provider, offlineProvider, isDarkMode);
            case SupervisorScreenState.scanning:
              return _buildScanningView(provider);
            case SupervisorScreenState.scanned:
              return _buildScannedView(provider, isDarkMode);
            case SupervisorScreenState.error:
              return _buildErrorView(provider, isDarkMode);
          }
        },
      ),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildInitialView(SupervisorProvider provider,
      OfflineDatabaseProvider offlineProvider, bool isDarkMode) {
    return GradientBackground(
      gradientType: GradientType.supervisor,
      isDarkMode: isDarkMode,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            ScreenHeader(
              title: 'Nəzarətçilər',
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
                              Icons.supervisor_account,
                              size: 64,
                              color: AppColors.white,
                            ),
                            SizedBox(height: 20),
                            Text(
                              'Nəzarətçilər',
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'QR kod skaneri ilə nəzarətçi məlumatlarını oxuyun',
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
                                .setScreenState(SupervisorScreenState.scanning),
                            backgroundColor: AppColors.buttonRed,
                          ),
                          const SizedBox(height: 16),
                          ActionButton.manualInput(
                            onPressed: () =>
                                ManualInputDialog.showSupervisorDialog(
                              context,
                              (input) {
                                Navigator.of(context).pop();
                                provider.scanSupervisor(input);
                              },
                            ),
                            backgroundColor: AppColors.buttonBlue,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Offline Database Status
                    AnimatedWrapper(
                      child: _buildOfflineDbStatus(offlineProvider),
                    ),

                    // Online/Offline Toggle
                    if (provider.hasOfflineDatabase)
                      AnimatedWrapper(
                        child: OnlineToggle(
                          isOnlineMode: provider.isOnlineMode,
                          onToggle: () => provider.toggleOnlineMode(),
                        ),
                      ),

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

  Widget _buildScanningView(SupervisorProvider provider) {
    return QRScannerWidget(
      scannerType: 'supervisor',
      onScan: (code) {
        provider.scanSupervisor(code);
      },
      onClose: () {
        provider.setScreenState(SupervisorScreenState.initial);
      },
    );
  }

  Widget _buildScannedView(SupervisorProvider provider, bool isDarkMode) {
    final supervisor = provider.currentSupervisor!;
    final supervisorDetails = provider.supervisorDetails;

    return GradientBackground(
      gradientType: GradientType.supervisor,
      isDarkMode: isDarkMode,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            ScreenHeader(
              title: 'Nəzarətçi məlumatları',
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

                    // Supervisor Info Card
                    InfoCard(
                      fullName: supervisor.fullName,
                      subtitle: 'Vəsiqə nömrəsi: ${supervisor.cardNumber}',
                      photoWidget: PhotoWidget.supervisor(
                        photoData: supervisor.image,
                      ),
                      isRepeatEntry: provider.isRepeatEntry,
                      borderColor: provider.isRepeatEntry
                          ? AppColors.darkRed
                          : Colors.green,
                      actionButton: ActionButton.next(
                        onPressed: () {
                          provider.resetToInitial();
                          provider
                              .setScreenState(SupervisorScreenState.scanning);
                        },
                      ),
                      details: [
                        InfoDetail(
                            label: 'Bina kodu',
                            value: supervisor.buildingCode.toString()),
                        InfoDetail(
                            label: 'Bina adı', value: supervisor.buildingName),
                        if (supervisor.registerDate.isNotEmpty)
                          InfoDetail(
                              label: 'Qeydiyyat tarixi',
                              value: supervisor.registerDate),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Statistics Card
                    if (supervisorDetails != null)
                      StatisticsCard(
                        title: 'Statistikalar',
                        items: [
                          StatItem(
                            label: 'Qeydiyyatlı',
                            value: supervisorDetails.regPersonCount.toString(),
                            color: Colors.green,
                            icon: Icons.check_circle,
                          ),
                          StatItem(
                            label: 'Qeydiyyatsız',
                            value:
                                supervisorDetails.unregisteredCount.toString(),
                            color: AppColors.redButton,
                            icon: Icons.cancel,
                          ),
                        ],
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

  Widget _buildErrorView(SupervisorProvider provider, bool isDarkMode) {
    return GradientBackground(
      gradientType: GradientType.supervisor,
      isDarkMode: isDarkMode,
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
                              onPressed: () => provider.setScreenState(
                                  SupervisorScreenState.scanning),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
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

  Widget _buildOfflineDbStatus(OfflineDatabaseProvider offlineProvider) {
    if (offlineProvider.hasOfflineData) {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_done, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              'Oflayn baza mövcuddur (${offlineProvider.participantCount} iştirakçı, ${offlineProvider.supervisorCount} nəzarətçi)',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      // Не показываем ничего, когда нет офлайн базы
      return const SizedBox.shrink();
    }
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return CustomBottomNavigation(
      items: [
        BottomNavItem(
          icon: Icons.school,
          label: 'İştirakçılar',
          isSelected: false,
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ParticipantScreen(),
              ),
            );
          },
        ),
        BottomNavItem(
          icon: Icons.supervisor_account,
          label: 'Nəzarətçilər',
          isSelected: true, // Текущий экран
          onTap: () {},
        ),
        BottomNavItem(
          icon: Icons.analytics,
          label: 'Statistika',
          isSelected: false,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const StatisticsScreen(),
              ),
            );
          },
        ),
        BottomNavItem(
          icon: Icons.assignment,
          label: 'Protokollar',
          isSelected: false,
          onTap: () {
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            final userRole = authProvider.currentUserRole;

            // Мониторы идут к добавлению заметок, админы к просмотру отчетов
            if (userRole == 'monitor') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProtocolNotesScreen(),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProtocolReportsScreen(),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
