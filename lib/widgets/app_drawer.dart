import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/supervisor_screen.dart';
import '../screens/participant_screen.dart';
import '../screens/unsent_data_screen.dart';
import '../screens/settings_screen.dart';
import '../design/app_colors.dart';
import '../constants/app_version.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.newBlueLight,
              AppColors.newBlueDark,
              AppColors.primaryBlue,
            ],
          ),
        ),
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Logo with enhanced styling - изображение заполняет весь контейнер
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(20), // Увеличили radius
                        boxShadow: [
                          // Основная тень
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                            spreadRadius: 1,
                          ),
                          // Внутренняя подсветка
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                            spreadRadius: 0,
                          ),
                        ],
                        // Градиентная граница
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            20), // Обрезаем изображение по radius
                        child: Image.asset(
                          'assets/images/logos/DIMLogo.png',
                          fit: BoxFit.cover, // Заполняет весь контейнер
                          width: 70,
                          height: 70,
                        ),
                      ),
                      // child: const Icon(
                      //   Icons.school,
                      //   size: 35,
                      //   color: Colors.white,
                      // ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Dövlət İmtahan Mərkəzi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Buraxılış Sistemi',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Menu Items Section
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.home,
                        title: 'Əsas',
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.school,
                        title: 'İmtahan iştirakçıları',
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToParticipantScreen(context);
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.supervisor_account,
                        title: 'Nəzarətçilər',
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToSupervisorScreen(context);
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.signal_cellular_off,
                        title: 'Göndərilməmiş məlumatlar',
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToUnsentDataScreen(context);
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.analytics,
                        title: 'Statistika',
                        onTap: () {
                          Navigator.pop(context);
                          _showComingSoonDialog(context, 'Statistika');
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.storage,
                        title: 'Oflayn baza',
                        onTap: () {
                          Navigator.pop(context);
                          _showComingSoonDialog(context, 'Oflayn baza');
                        },
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.settings,
                        title: 'Ayarlar',
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToSettingsScreen(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Section
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Logout Button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.exit_to_app,
                        color: Colors.white,
                        size: 20,
                      ),
                      title: const Text(
                        'Sistemdən çıxış',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      onTap: () => _showLogoutDialog(context),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),

                  // Footer Info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Versiya: ${AppVersion.version}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Dövlət İmtahan Mərkəzi Ⓒ 2025',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        hoverColor: Colors.white.withOpacity(0.1),
        splashColor: Colors.white.withOpacity(0.2),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Sistemdən çıxış',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            'Sistemdən çıxmaq istədiyinizə əminsiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Ləğv et',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close drawer

                final navigator = Navigator.of(context);
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                await authProvider.signOut();

                if (context.mounted) {
                  navigator.pushReplacement(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const LoginScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 500),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Çıxış'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToParticipantScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ParticipantScreen(),
      ),
    );
  }

  void _navigateToSupervisorScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SupervisorScreen(),
      ),
    );
  }

  void _navigateToUnsentDataScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const UnsentDataScreen(),
      ),
    );
  }

  void _navigateToSettingsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String screenName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          screenName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text('Bu bölmə tezliklə hazır olacaq...'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
