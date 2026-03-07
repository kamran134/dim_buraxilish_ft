import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/offline_database_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../widgets/exam_date_dropdown.dart';
import '../widgets/common/common_widgets.dart';
import 'main_screen.dart';
import 'real_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedExamDate;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isDownloadingOffline = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // Загружаем даты экзаменов после постройки виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExamDates();
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadExamDates() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.loadExamDates();
  }

  Future<void> _refreshData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError(); // Очищаем предыдущие ошибки
    await authProvider.loadExamDates();
  }

  Future<void> _handleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final offlineProvider =
        Provider.of<OfflineDatabaseProvider>(context, listen: false);

    if (authProvider.isLockedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Hesab bloklanıb. ${authProvider.lockoutSecondsLeft} saniyə gözləyin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate() || _selectedExamDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zəhmət olmasa bütün xanaları doldurun'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await authProvider.signInWithJWT(
      _usernameController.text.trim(),
      _passwordController.text,
      _selectedExamDate!,
    );

    if (!mounted) return;

    if (!success) {
      setState(() => _isLoading = false);
      // Error will be shown via Consumer
      return;
    }

    // Login succeeded — now download offline database
    setState(() {
      _isLoading = false;
      _isDownloadingOffline = true;
    });

    await offlineProvider.downloadOfflineDatabase();

    if (!mounted) return;

    setState(() => _isDownloadingOffline = false);

    if (offlineProvider.errorMessage != null) {
      // Download failed — sign out and show error so user retries
      await authProvider.signOut(clearData: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(offlineProvider.errorMessage!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    // All good — navigate
    final targetScreen = authProvider.canAccessDashboard
        ? const RealDashboardScreen()
        : const MainScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildDownloadOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0046a3),
                Color(0xFF0c7bc5),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Məlumatlar yüklənir',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Zəhmət olmasa gözləyin...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: GradientBackground(
            gradientType: GradientType.default_,
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo and Title
                            _buildHeader(),

                            const SizedBox(height: 40),

                            // Login Form
                            _buildLoginForm(),

                            const SizedBox(height: 30),

                            // Login Button
                            _buildLoginButton(),

                            const SizedBox(height: 20),

                            // Error and Lockout Display
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                if (authProvider.isLockedOut) {
                                  return Container(
                                    margin: const EdgeInsets.only(top: 20),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.red.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      'Hesab bloklanıb. ${authProvider.lockoutSecondsLeft} saniyə sonra yenidən cəhd edin.',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                if (authProvider.error != null) {
                                  return MessageDisplay(
                                    message: authProvider.error!,
                                    type: MessageType.error,
                                    margin: const EdgeInsets.only(top: 20),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isDownloadingOffline) _buildDownloadOverlay(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                AppColors.splashLightGrey,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.school,
            size: 50,
            color: AppColors.deepBlue,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'DİM Buraxılış Sistemi',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Sistemə giriş',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Username Field
            CustomTextField(
              controller: _usernameController,
              hintText: 'İstifadəçi adı',
              prefixIcon: Icons.person_outline,
              forceLight: true, // Принудительно светлая тема
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'İstifadəçi adı tələb olunur';
                }
                if (value.length > 50) {
                  return 'İstifadəçi adı 50 simvoldan çox ola bilməz';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Password Field
            CustomTextField(
              controller: _passwordController,
              hintText: 'Şifrə',
              prefixIcon: Icons.lock_outline,
              obscureText: _obscurePassword,
              forceLight: true, // Принудительно светлая тема
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey[600],
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Şifrə tələb olunur';
                }
                if (value.length > 100) {
                  return 'Şiəfrə 100 simvoldan çox ola bilməz';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Exam Date Dropdown
            ExamDateDropdown(
              selectedDate: _selectedExamDate,
              onChanged: (value) {
                setState(() {
                  _selectedExamDate = value;
                });
              },
              forceLight: true, // Принудительно светлая тема
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Opacity(
          opacity: authProvider.isLockedOut ? 0.5 : 1.0,
          child: CustomButton(
            text: authProvider.isLockedOut
                ? 'Gözləyin (${authProvider.lockoutSecondsLeft}s)'
                : 'Sistemə daxil ol',
            isLoading: _isLoading,
            onPressed: _handleLogin,
            backgroundColor: Colors.white,
            textColor: AppColors.deepBlue,
            icon: Icons.login,
          ),
        );
      },
    );
  }
}
