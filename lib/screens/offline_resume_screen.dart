import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_database_provider.dart';
import '../services/slot_switcher.dart';
import '../widgets/common/common_widgets.dart';
import '../widgets/offline_download_progress.dart';
import 'main_screen.dart';

enum _ResumePhase { downloading, success, partialData, emptyData, networkError }

/// Finishes an offline download that was interrupted (app closed, phone
/// locked, connection lost) before opening the app. The local database is
/// wiped on every logout, so the app is never entered with incomplete data:
/// SplashScreen sends non-admin users here until the download is complete.
///
/// There is no way back from here except retrying or logging out.
class OfflineResumeScreen extends StatefulWidget {
  const OfflineResumeScreen({super.key});

  @override
  State<OfflineResumeScreen> createState() => _OfflineResumeScreenState();
}

class _OfflineResumeScreenState extends State<OfflineResumeScreen> {
  _ResumePhase _phase = _ResumePhase.downloading;
  int _participants = 0;
  int _supervisors = 0;
  String _message = '';
  String _continueLabel = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _download());
  }

  Future<void> _download() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final offlineProvider =
        Provider.of<OfflineDatabaseProvider>(context, listen: false);

    setState(() => _phase = _ResumePhase.downloading);
    final outcome = await SlotSwitcher.downloadForRole(
      authProvider: authProvider,
      offlineProvider: offlineProvider,
    );
    if (!mounted) return;

    switch (outcome.result) {
      case SlotSwitchResult.success:
        setState(() {
          _phase = _ResumePhase.success;
          _participants = outcome.participantCount;
          _supervisors = outcome.supervisorCount;
        });
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        _openMainScreen();
      case SlotSwitchResult.partialSuccess:
        setState(() {
          _phase = _ResumePhase.partialData;
          _message = outcome.message ?? '';
          _continueLabel = outcome.continueLabel ?? 'Davam et';
        });
      case SlotSwitchResult.emptyData:
        setState(() {
          _phase = _ResumePhase.emptyData;
          _message =
              'Server bu bina üçün məlumat qaytarmadı.\nTarixin düzgünlüyünü və internet bağlantısını yoxlayın.';
        });
      case SlotSwitchResult.networkError:
        setState(() {
          _phase = _ResumePhase.networkError;
          _message = outcome.message ??
              'Məlumatlar yüklənmədi.\nBağlantını yoxlayıb yenidən cəhd edin.';
        });
    }
  }

  void _openMainScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.lightBlue, AppColors.darkBlue],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(
                        vertical: 40, horizontal: 32),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: _buildContent(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_phase) {
      case _ResumePhase.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _title('Yükləmə davam etdirilir'),
            const SizedBox(height: 24),
            const OfflineDownloadProgress(color: Colors.white),
          ],
        );
      case _ResumePhase.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 64),
            const SizedBox(height: 24),
            _title('Baza yükləndi!'),
            const SizedBox(height: 8),
            _body('$_participants iştirakçı · $_supervisors nəzarətçi'),
          ],
        );
      case _ResumePhase.partialData:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 56),
            const SizedBox(height: 20),
            _title('Natamam yükləndi'),
            const SizedBox(height: 8),
            _body(
                '$_message\nZəhmət olmasa bir daha cəhd edin\nvə ya qərargahdan məlumatları dəqiqləşdirin.'),
            const SizedBox(height: 28),
            _retryButton(),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _openMainScreen,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(_continueLabel),
            ),
          ],
        );
      case _ResumePhase.emptyData:
        return _errorContent(
          icon: Icons.warning_amber_rounded,
          title: 'Məlumat tapılmadı',
        );
      case _ResumePhase.networkError:
        return _errorContent(
          icon: Icons.wifi_off_rounded,
          title: 'Yükləmə uğursuz oldu',
        );
    }
  }

  Widget _errorContent({required IconData icon, required String title}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 56),
        const SizedBox(height: 20),
        _title(title),
        const SizedBox(height: 8),
        _body(_message),
        const SizedBox(height: 28),
        _retryButton(),
        const SizedBox(height: 12),
        const LogoutButton(
          type: LogoutButtonType.settings,
          title: 'Çıxış',
          textColor: Colors.white,
          iconColor: Colors.white,
          backgroundColor: Colors.white,
        ),
      ],
    );
  }

  Widget _retryButton() {
    return ElevatedButton.icon(
      onPressed: _download,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('Yenidən cəhd et'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  Widget _title(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.none,
      ),
    );
  }

  Widget _body(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 13,
        decoration: TextDecoration.none,
      ),
    );
  }
}
