import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/participant_models.dart';
import '../providers/participant_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_database_provider.dart';
import '../widgets/qr_scanner.dart';
import '../widgets/manual_input_dialog.dart';
import '../widgets/common/common_widgets.dart';
import 'login_screen.dart';
import 'supervisor_screen.dart';
import 'statistics_screen.dart';
import 'protocol_notes_screen.dart';
import 'protocol_reports_screen.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class ParticipantScreen extends StatefulWidget {
  const ParticipantScreen({super.key});

  @override
  State<ParticipantScreen> createState() => _ParticipantScreenState();
}

class _ParticipantScreenState extends State<ParticipantScreen> {
  @override
  void initState() {
    super.initState();

    // Load exam details when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ParticipantProvider>();
      final offlineDbProvider = context.read<OfflineDatabaseProvider>();

      // Set reference to OfflineDatabaseProvider
      provider.setOfflineDatabaseProvider(offlineDbProvider);

      // Set authentication error callback
      provider.setAuthenticationErrorCallback(() {
        _handleAuthenticationError();
      });

      provider.loadExamDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Consumer2<ParticipantProvider, OfflineDatabaseProvider>(
        builder: (context, provider, offlineProvider, child) {
          switch (provider.screenState) {
            case ParticipantScreenState.initial:
              return _buildInitialView(provider, offlineProvider, isDarkMode);
            case ParticipantScreenState.scanning:
              return _buildScanningView(provider);
            case ParticipantScreenState.scanned:
              return _buildScannedView(provider, isDarkMode);
            case ParticipantScreenState.error:
              return _buildErrorView(provider, isDarkMode);
          }
        },
      ),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildInitialView(ParticipantProvider provider,
      OfflineDatabaseProvider offlineProvider, bool isDarkMode) {
    return GradientBackground(
      gradientType: GradientType.participant,
      isDarkMode: isDarkMode,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            ScreenHeader(
              title: 'İmtahan iştirakçıları',
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
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.school,
                              size: 64,
                              color: Colors.white,
                            ),
                            SizedBox(height: 20),
                            Text(
                              'İmtahan iştirakçıları',
                              style: AppTextStyles.h2.copyWith(
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'QR kod skaneri ilə iştirakçı məlumatlarını oxuyun',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
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
                            onPressed: () => provider.setScreenState(
                                ParticipantScreenState.scanning),
                          ),
                          const SizedBox(height: 16),
                          ActionButton.manualInput(
                            onPressed: () =>
                                ManualInputDialog.showParticipantDialog(
                              context,
                              (input) {
                                Navigator.of(context).pop();
                                provider.enterParticipantManually(input);
                              },
                            ),
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

  Widget _buildScanningView(ParticipantProvider provider) {
    return QRScannerWidget(
      scannerType: 'participant',
      onScan: (code) {
        provider.scanParticipant(code);
      },
      onClose: () {
        provider.setScreenState(ParticipantScreenState.initial);
      },
    );
  }

  Widget _buildScannedView(ParticipantProvider provider, bool isDarkMode) {
    final participant = provider.currentParticipant!;
    final examDetails = provider.examDetails;

    return GradientBackground(
      gradientType: GradientType.participant,
      isDarkMode: isDarkMode,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            ScreenHeader(
              title: 'İştirakçı məlumatları',
              onBackPressed: () => provider.reset(),
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

                    // Participant Info Card
                    InfoCard(
                      fullName: participant.fullName,
                      subtitle: 'İş nömrəsi: ${participant.isN}',
                      photoWidget: PhotoWidget.participant(
                        photoData: participant.photo,
                      ),
                      isRepeatEntry: provider.isRepeatEntry,
                      borderColor: provider.isRepeatEntry
                          ? AppColors.darkRed
                          : Colors.green,
                      actionButton: ActionButton.next(
                        onPressed: () {
                          provider.nextParticipant();
                        },
                      ),
                      details: [
                        InfoDetail(
                            label: 'Mərtəbə', value: participant.mertebe),
                        InfoDetail(label: 'Zal', value: participant.zal),
                        InfoDetail(label: 'Sıra', value: participant.sira),
                        InfoDetail(label: 'Yer', value: participant.yer),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Statistics Card
                    if (examDetails != null)
                      StatisticsCard(
                        title: 'Statistikalar',
                        items: [
                          StatItem(
                            label: 'Qeydiyyatlı',
                            value: examDetails.totalRegisteredCount.toString(),
                            color: Colors.green,
                            icon: Icons.check_circle,
                          ),
                          StatItem(
                            label: 'Qeydiyyatsız',
                            value: examDetails.notRegisteredCount.toString(),
                            color: AppColors.errorRed,
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

  Widget _buildErrorView(ParticipantProvider provider, bool isDarkMode) {
    return GradientBackground(
      gradientType: GradientType.participant,
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
                    color: Colors.white.withOpacity(0.95),
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
                        color: AppColors.errorRed,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Xəta baş verdi',
                        style: TextStyle(
                          fontSize: 24,
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
                              onPressed: () => provider.reset(),
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
                                  ParticipantScreenState.scanning),
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
          isSelected: true, // Текущий экран
          onTap: () {},
        ),
        BottomNavItem(
          icon: Icons.supervisor_account,
          label: 'Nəzarətçilər',
          isSelected: false,
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const SupervisorScreen(),
              ),
            );
          },
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
