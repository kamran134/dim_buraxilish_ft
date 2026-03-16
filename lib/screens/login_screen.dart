import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _pinControllers = List.generate(4, (_) => TextEditingController());
  final _pinFocusNodes = List.generate(4, (_) => FocusNode());
  final _adminUsernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isAdmin = false;

  String get _resolvedUsername {
    if (_isAdmin) {
      return _adminUsernameController.text.trim();
    }
    final digits = _pinControllers.map((c) => c.text).join();
    return 'bina$digits';
  }

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

    final pinFilled = _isAdmin
        ? _adminUsernameController.text.trim().isNotEmpty
        : _pinControllers.every((c) => c.text.isNotEmpty);
    if (!_formKey.currentState!.validate() ||
        _selectedExamDate == null ||
        !pinFilled) {
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
      _resolvedUsername,
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

    if (authProvider.canAccessDashboard) {
      // Admin: download monitors list (non-blocking — errors don't prevent login)
      await offlineProvider.downloadAdminOfflineDatabase();
    } else {
      // Monitor: download participants + supervisors (blocking — must succeed)
      await offlineProvider.downloadOfflineDatabase();

      if (!mounted) return;
      setState(() => _isDownloadingOffline = false);

      if (offlineProvider.errorMessage != null) {
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
    }

    if (!mounted) return;
    setState(() => _isDownloadingOffline = false);

    // Navigate
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            authProvider.canAccessDashboard
                ? const RealDashboardScreen()
                : const MainScreen(),
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
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    _adminUsernameController.dispose();
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
            // Role toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildRoleChip('İmtahan rəhbəri', false),
                  _buildRoleChip('Admin', true),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Username input — PIN boxes or text field
            if (!_isAdmin)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.apartment_outlined,
                          color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Bina kodu',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: SizedBox(
                          width: 56,
                          height: 60,
                          child: TextField(
                            controller: _pinControllers[i],
                            focusNode: _pinFocusNodes[i],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.deepBlue, width: 2),
                              ),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty && i < 3) {
                                _pinFocusNodes[i + 1].requestFocus();
                              } else if (value.isEmpty && i > 0) {
                                _pinFocusNodes[i - 1].requestFocus();
                              }
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              )
            else
              CustomTextField(
                controller: _adminUsernameController,
                hintText: 'İstifadəçi adı',
                prefixIcon: Icons.person_outline,
                forceLight: true,
                validator: (value) {
                  if (_isAdmin && (value == null || value.isEmpty)) {
                    return 'İstifadəçi adı tələb olunur';
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

  Widget _buildRoleChip(String label, bool isAdminChip) {
    final selected = _isAdmin == isAdminChip;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isAdmin = isAdminChip;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.deepBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAdminChip
                    ? Icons.admin_panel_settings_outlined
                    : Icons.apartment_outlined,
                size: 16,
                color: selected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
