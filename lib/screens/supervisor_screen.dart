import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/supervisor_models.dart';
import '../providers/supervisor_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_database_provider.dart';
import '../widgets/qr_scanner.dart';
import '../widgets/manual_input_dialog.dart';
import 'login_screen.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class SupervisorScreen extends StatefulWidget {
  const SupervisorScreen({super.key});

  @override
  State<SupervisorScreen> createState() => _SupervisorScreenState();
}

class _SupervisorScreenState extends State<SupervisorScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

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

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
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
    );
  }

  Widget _buildInitialView(SupervisorProvider provider,
      OfflineDatabaseProvider offlineProvider, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  AppColors.darkGradient1,
                  AppColors.darkGradient2,
                  AppColors.darkGradient3,
                ]
              : [
                  AppColors.primaryBlue,
                  const Color(0xFFf5576c),
                  const Color(0xFF764ba2),
                ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: AppColors.white,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Nəzarətçilər',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Welcome Section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
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
                    ),

                    const SizedBox(height: 40),

                    // Action Buttons
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          _buildActionButton(
                            onPressed: () => provider
                                .setScreenState(SupervisorScreenState.scanning),
                            icon: Icons.qr_code_scanner,
                            title: 'Skan et',
                            backgroundColor: AppColors.buttonRed,
                          ),
                          const SizedBox(height: 16),
                          _buildActionButton(
                            onPressed: () =>
                                ManualInputDialog.showSupervisorDialog(
                              context,
                              (input) {
                                Navigator.of(context).pop();
                                provider.scanSupervisor(input);
                              },
                            ),
                            icon: Icons.keyboard,
                            title: 'Əllə daxil et',
                            backgroundColor: AppColors.buttonBlue,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Offline Database Status
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildOfflineDbStatus(offlineProvider),
                    ),

                    // Online/Offline Toggle
                    if (provider.hasOfflineDatabase)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildOnlineToggle(provider),
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
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.redButton.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  provider.errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  AppColors.darkGradient1,
                  AppColors.darkGradient2,
                  AppColors.darkGradient3,
                ]
              : [
                  AppColors.lightBlue,
                  AppColors.darkBlue,
                  AppColors.primaryBlue,
                ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => provider.resetToInitial(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Nəzarətçi məlumatları',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Success message
                    if (provider.successMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                provider.successMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Supervisor Info Card
                    Container(
                      padding: const EdgeInsets.all(24),
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
                          // Repeat entry message - shown above photo if it's a repeat entry
                          if (provider.isRepeatEntry)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                'TƏKRAR GİRİŞ',
                                style: TextStyle(
                                  fontSize: 20, // h4 equivalent
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkRed,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // Photo placeholder
                          Container(
                            width: double.infinity,
                            height: 280,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: provider.isRepeatEntry
                                    ? AppColors.darkRed
                                    : Colors.green,
                                width: 3,
                              ),
                            ),
                            child: supervisor.image.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child:
                                        _buildSupervisorPhoto(supervisor.image),
                                  )
                                : const Icon(
                                    Icons.supervisor_account,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                          ),

                          const SizedBox(height: 20),

                          // Name
                          Text(
                            supervisor.fullName,
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.blackText,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          // Card number under name
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Vəsiqə nömrəsi: ${supervisor.cardNumber}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Next Button - moved here for quick access
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Container(), // spacer
                              ),
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    provider.resetToInitial();
                                    provider.setScreenState(
                                        SupervisorScreenState.scanning);
                                  },
                                  icon: const Icon(Icons.qr_code_scanner,
                                      size: 18),
                                  label: const Text(
                                    'Növbəti',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: AppColors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(), // spacer
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Details in two columns
                          _buildDetailsGrid(supervisor),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Statistics Card
                    if (supervisorDetails != null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.whiteTransparent15,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Statistikalar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18, // h5 equivalent
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    'Qeydiyyatlı',
                                    supervisorDetails.regPersonCount.toString(),
                                    Colors.green,
                                    Icons.check_circle,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 60,
                                  color: AppColors.white30,
                                ),
                                Expanded(
                                  child: _buildStatItem(
                                    'Qeydiyyatsız',
                                    supervisorDetails.unregisteredCount
                                        .toString(),
                                    AppColors.redButton,
                                    Icons.cancel,
                                  ),
                                ),
                              ],
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

  Widget _buildErrorView(SupervisorProvider provider, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  AppColors.darkGradient1,
                  AppColors.darkGradient2,
                  AppColors.darkGradient3,
                ]
              : [
                  AppColors.darkBlue,
                  AppColors.primaryBlue,
                  AppColors.lightBlue,
                ],
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

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String title,
    required Color backgroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildOnlineToggle(SupervisorProvider provider) {
    return GestureDetector(
      onTap: () => provider.toggleOnlineMode(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              provider.isOnlineMode ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.isOnlineMode ? 'Online rejim' : 'Oflayn rejim',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    provider.isOnlineMode
                        ? 'İnternet bağlantısı aktivdir'
                        : 'Lokal bazadan istifadə edilir',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12, // bodySmall equivalent
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: provider.isOnlineMode,
              onChanged: (_) => provider.toggleOnlineMode(),
              activeColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsGrid(Supervisor supervisor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // First row: Building Code and Building Name
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                    'Bina kodu', supervisor.buildingCode.toString()),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDetailItem('Bina adı', supervisor.buildingName),
              ),
            ],
          ),
          if (supervisor.registerDate.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Second row: Register Date (if available)
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                      'Qeydiyyat tarixi', supervisor.registerDate),
                ),
                Expanded(child: Container()), // Empty space
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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

  Widget _buildSupervisorPhoto(String photoData) {
    try {
      // Try to decode as base64 if it looks like base64 data
      if (photoData.startsWith('data:image') || photoData.length > 100) {
        // Remove data URL prefix if present
        String base64String = photoData;
        if (photoData.startsWith('data:image')) {
          base64String = photoData.split(',').last;
        }

        // Decode base64 to bytes
        final Uint8List bytes = base64Decode(base64String);

        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading supervisor photo: $error');
            return const Icon(
              Icons.supervisor_account,
              size: 60,
              color: Colors.grey,
            );
          },
        );
      } else {
        // If not base64, show placeholder
        return const Icon(
          Icons.supervisor_account,
          size: 60,
          color: Colors.grey,
        );
      }
    } catch (e) {
      print('Error decoding supervisor photo: $e');
      return const Icon(
        Icons.supervisor_account,
        size: 60,
        color: Colors.grey,
      );
    }
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
}
