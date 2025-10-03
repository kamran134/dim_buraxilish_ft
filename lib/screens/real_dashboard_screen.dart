import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/exam_details_dto.dart';
import '../services/statistics_service.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../utils/role_helper.dart';
import '../widgets/admin_drawer.dart';

class RealDashboardScreen extends StatefulWidget {
  const RealDashboardScreen({Key? key}) : super(key: key);

  @override
  State<RealDashboardScreen> createState() => _RealDashboardScreenState();
}

class _RealDashboardScreenState extends State<RealDashboardScreen>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Реальные данные
  final StatisticsService _statisticsService = StatisticsService();
  DashboardStatistics? _dashboardStats;
  List<String> _examDates = [];
  String? _selectedExamDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Загружаем данные
    _loadExamDates();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadExamDates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _statisticsService.getAllExamDates();
      if (result.success && result.data != null) {
        setState(() {
          _examDates = result.data!;
          if (_examDates.isNotEmpty) {
            _selectedExamDate = _examDates.first;
            _loadDashboardStatistics(_selectedExamDate!);
          }
        });
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Xəta baş verdi: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardStatistics(String examDate) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _statisticsService.getDashboardStatistics(examDate);
      if (result.success && result.data != null) {
        setState(() {
          _dashboardStats = result.data!;
        });
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Statistika yüklənmədi: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AdminDrawer(),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) _buildErrorMessage(),
                        if (_isLoading) _buildLoadingIndicator(),
                        if (_dashboardStats != null) ...[
                          _buildExamDateSelector(),
                          const SizedBox(height: 24),
                          _buildStatsCards(),
                          const SizedBox(height: 24),
                          _buildExamStatistics(),
                          const SizedBox(height: 24),
                          _buildBuildingStatistics(),
                          const SizedBox(height: 24),
                          _buildQuickActions(),
                        ],
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBlue, AppColors.lightBlue],
          ),
        ),
        child: FlexibleSpaceBar(
          titlePadding: const EdgeInsets.only(left: 72, bottom: 16),
          title: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin panel',
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    RoleHelper.getRoleDescription(authProvider.currentUserRole),
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.errorRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTextStyles.body1.copyWith(color: AppColors.errorRed),
            ),
          ),
          IconButton(
            onPressed: () => _loadExamDates(),
            icon: Icon(Icons.refresh, color: AppColors.errorRed),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Məlumatlar yüklənir...',
              style: AppTextStyles.body1.copyWith(color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamDateSelector() {
    if (_examDates.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Text(
            'İmtahan tarixi:',
            style:
                AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedExamDate,
              isExpanded: true,
              underline: Container(),
              items: _examDates.map((date) {
                return DropdownMenuItem<String>(
                  value: date,
                  child: Text(date),
                );
              }).toList(),
              onChanged: (newDate) {
                if (newDate != null && newDate != _selectedExamDate) {
                  setState(() {
                    _selectedExamDate = newDate;
                  });
                  _loadDashboardStatistics(newDate);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_dashboardStats == null) return const SizedBox.shrink();

    final stats = _dashboardStats!;
    final statsData = [
      _StatCardData(
        title: 'Ümumi iştirakçı',
        value: '${stats.totalParticipants}',
        icon: Icons.school,
        gradient: AppColors.participantGradient,
      ),
      _StatCardData(
        title: 'Qeydiyyatdan keçən',
        value: '${stats.totalRegistered}',
        icon: Icons.check_circle,
        gradient: AppColors.greenGradient,
      ),
      _StatCardData(
        title: 'Qeydiyyatdan keçməyən',
        value: '${stats.totalUnregistered}',
        icon: Icons.cancel,
        gradient: [AppColors.errorRed, AppColors.errorRed.withOpacity(0.7)],
      ),
      _StatCardData(
        title: 'Binalar',
        value: '${stats.totalBuildings}',
        icon: Icons.apartment,
        gradient: AppColors.blueGradient,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: statsData.length,
      itemBuilder: (context, index) {
        return _buildStatCard(statsData[index], index);
      },
    );
  }

  Widget _buildStatCard(_StatCardData data, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: data.gradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: data.gradient.first.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      data.icon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.value,
                        style: AppTextStyles.h1.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        data.title,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExamStatistics() {
    if (_dashboardStats?.examSum == null) return const SizedBox.shrink();

    final examSum = _dashboardStats!.examSum;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics,
                color: AppColors.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Ümumi Statistika',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatisticRow('Ümumi iştirakçı', examSum.totalParticipants,
              AppColors.primaryBlue),
          _buildStatisticRow(
              'Kişi', examSum.allManCount, AppColors.statisticsBlue),
          _buildStatisticRow(
              'Qadın', examSum.allWomanCount, AppColors.lightBlue),
          const Divider(height: 32),
          _buildStatisticRow('Qeydiyyatdan keçən', examSum.totalRegistered,
              AppColors.successGreen),
          _buildStatisticRow(
              'Kişi (qeydiyyat)', examSum.regManCount, AppColors.successGreen),
          _buildStatisticRow('Qadın (qeydiyyat)', examSum.regWomanCount,
              AppColors.successGreen),
          const Divider(height: 32),
          _buildStatisticRow('Qeydiyyatdan keçməyən', examSum.totalUnregistered,
              AppColors.errorRed),
          const SizedBox(height: 16),
          _buildProgressBar('Qeydiyyat faizi', examSum.registrationRate),
        ],
      ),
    );
  }

  Widget _buildStatisticRow(String title, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTextStyles.body1,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value.toString(),
              style: AppTextStyles.bodyLarge.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String title, double percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: AppTextStyles.bodyLarge.copyWith(
                color: _getCompletionRateColor(percentage),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: AppColors.lightGrey,
          valueColor: AlwaysStoppedAnimation<Color>(
              _getCompletionRateColor(percentage)),
        ),
      ],
    );
  }

  Widget _buildBuildingStatistics() {
    if (_dashboardStats?.examDetails == null ||
        _dashboardStats!.examDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.apartment,
                color: AppColors.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Bina Statistikaları',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._dashboardStats!.examDetails
              .take(5)
              .map((building) => _buildBuildingStatItem(building)),
          if (_dashboardStats!.examDetails.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // Показать все здания
                  },
                  child: Text(
                      'Hamısını gör (${_dashboardStats!.examDetails.length})'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBuildingStatItem(ExamDetailsDto building) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                building.kodBina ?? '?',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  building.adBina ?? 'Bilinməyən bina',
                  style:
                      AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${building.totalParticipants} iştirakçı',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${building.registrationRate.toStringAsFixed(1)}%',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getCompletionRateColor(building.registrationRate),
                ),
              ),
              Text(
                '${building.totalRegistered}/${building.totalParticipants}',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flash_on,
                color: AppColors.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Sürətli Əməliyyatlar',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  'İştirakçıları\nGör',
                  Icons.school,
                  AppColors.participantGradient,
                  () => _navigateToParticipants(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Binalar\nGör',
                  Icons.apartment,
                  AppColors.blueGradient,
                  () => _navigateToBuildings(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Yenilə',
                  Icons.refresh,
                  AppColors.greenGradient,
                  () => _loadDashboardStatistics(_selectedExamDate ?? ''),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    List<Color> gradient,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCompletionRateColor(double rate) {
    if (rate >= 95) return AppColors.successGreen;
    if (rate >= 85) return AppColors.statisticsBlue;
    return AppColors.errorRed;
  }

  void _navigateToParticipants() {
    // Навигация к участникам
  }

  void _navigateToBuildings() {
    // Навигация к зданиям
  }
}

class _StatCardData {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });
}
