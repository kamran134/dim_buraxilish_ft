import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/role_models.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../utils/role_helper.dart';
import '../widgets/app_drawer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Mock data - в реальном приложении будет получаться с API
  final DashboardStats _mockStats = DashboardStats(
    totalParticipants: 1250,
    totalSupervisors: 85,
    totalBuildings: 12,
    activeExams: 3,
    examStatistics: [
      ExamStatistic(
        examDate: '2024-01-15',
        participantCount: 420,
        supervisorCount: 28,
        completedCount: 395,
        completionRate: 94.0,
      ),
      ExamStatistic(
        examDate: '2024-01-22',
        participantCount: 385,
        supervisorCount: 25,
        completedCount: 372,
        completionRate: 96.6,
      ),
      ExamStatistic(
        examDate: '2024-01-29',
        participantCount: 445,
        supervisorCount: 32,
        completedCount: 398,
        completionRate: 89.4,
      ),
    ],
    buildingStatistics: [
      BuildingStatistic(
        buildingId: 1,
        buildingName: 'Bina 1',
        participantCount: 125,
        supervisorCount: 8,
        completedCount: 118,
        completionRate: 94.4,
      ),
      BuildingStatistic(
        buildingId: 2,
        buildingName: 'Bina 2',
        participantCount: 98,
        supervisorCount: 6,
        completedCount: 95,
        completionRate: 96.9,
      ),
    ],
  );

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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: const AppDrawer(),
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
                        _buildStatsCards(),
                        const SizedBox(height: 24),
                        _buildExamStatistics(),
                        const SizedBox(height: 24),
                        _buildBuildingStatistics(),
                        const SizedBox(height: 24),
                        _buildQuickActions(),
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
                    'Dashboard',
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

  Widget _buildStatsCards() {
    final stats = [
      _StatCardData(
        title: 'İştirakçılar',
        value: '${_mockStats.totalParticipants}',
        icon: Icons.school,
        gradient: AppColors.participantGradient,
      ),
      _StatCardData(
        title: 'Nəzarətçilər',
        value: '${_mockStats.totalSupervisors}',
        icon: Icons.supervisor_account,
        gradient: AppColors.supervisorGradient,
      ),
      _StatCardData(
        title: 'Binalar',
        value: '${_mockStats.totalBuildings}',
        icon: Icons.apartment,
        gradient: AppColors.blueGradient,
      ),
      _StatCardData(
        title: 'Aktiv İmtahanlar',
        value: '${_mockStats.activeExams}',
        icon: Icons.assessment,
        gradient: AppColors.greenGradient,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        return _buildStatCard(stats[index], index);
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
                'İmtahan Statistikaları',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._mockStats.examStatistics.map((exam) => _buildExamStatItem(exam)),
        ],
      ),
    );
  }

  Widget _buildExamStatItem(ExamStatistic exam) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.examDate,
                  style:
                      AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${exam.participantCount} iştirakçı',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${exam.completionRate.toStringAsFixed(1)}%',
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getCompletionRateColor(exam.completionRate),
                  ),
                ),
                Text(
                  'tamamlandı',
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: AppColors.lightGrey,
            ),
            child: FractionallySizedBox(
              widthFactor: exam.completionRate / 100,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _getCompletionRateColor(exam.completionRate),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingStatistics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._mockStats.buildingStatistics
              .map((building) => _buildBuildingStatItem(building)),
        ],
      ),
    );
  }

  Widget _buildBuildingStatItem(BuildingStatistic building) {
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
                '${building.buildingId}',
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
                  building.buildingName,
                  style:
                      AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${building.participantCount} iştirakçı • ${building.supervisorCount} nəzarətçi',
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
                '${building.completionRate.toStringAsFixed(1)}%',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getCompletionRateColor(building.completionRate),
                ),
              ),
              Text(
                '${building.completedCount}/${building.participantCount}',
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
        color: Colors.white,
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
                  'Nəzarətçiləri\nGör',
                  Icons.supervisor_account,
                  AppColors.supervisorGradient,
                  () => _navigateToSupervisors(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Statistika\nGör',
                  Icons.analytics,
                  AppColors.greenGradient,
                  () => _navigateToStatistics(),
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
    Navigator.pushNamed(context, '/participants');
  }

  void _navigateToSupervisors() {
    Navigator.pushNamed(context, '/supervisors');
  }

  void _navigateToStatistics() {
    Navigator.pushNamed(context, '/statistics');
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
