import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/exam_details_dto.dart';
import '../models/exam_statistics_dto.dart';
import '../models/monitor_room_statistics.dart';
import '../services/statistics_service.dart';
import '../services/statistics_event_bus.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../utils/role_helper.dart';
import '../widgets/admin_drawer.dart';
import 'building_details_screen.dart';
import 'buildings_statistics_screen.dart';
import 'rooms_statistics_screen.dart';
import 'room_monitors_screen.dart';
import 'dart:async';

class RealDashboardScreen extends StatefulWidget {
  const RealDashboardScreen({Key? key}) : super(key: key);

  @override
  State<RealDashboardScreen> createState() => _RealDashboardScreenState();
}

class _RealDashboardScreenState extends State<RealDashboardScreen>
    with TickerProviderStateMixin {
  // Подписка на события обновления статистики
  StreamSubscription<String>? _statisticsUpdateSubscription;

  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Реальные данные
  final StatisticsService _statisticsService = StatisticsService();
  DashboardStatistics? _dashboardStats;
  List<ExamStatisticsDto> _examStatistics = [];
  List<MonitorRoomStatistics> _roomStatistics = [];
  List<String> _examDates = [];
  String? _selectedExamDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Подписываемся на события обновления статистики
    _statisticsUpdateSubscription =
        StatisticsEventBus().onStatisticsUpdate.listen((source) {
      refreshStatistics();
    });

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
    // Отписываемся от событий
    _statisticsUpdateSubscription?.cancel();
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

  /// Публичный метод для обновления статистики (вызывается извне)
  Future<void> refreshStatistics() async {
    final examDateToRefresh = _selectedExamDate ?? _dashboardStats?.examDate;
    if (examDateToRefresh != null) {
      await _loadDashboardStatistics(examDateToRefresh);
    }
  }

  Future<void> _loadDashboardStatistics(String examDate) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Загружаем обычную статистику Dashboard
      final dashboardResult =
          await _statisticsService.getDashboardStatistics(examDate);

      // Загружаем объединенную статистику (участники + наблюдатели)
      final combinedResult =
          await _statisticsService.getExamStatisticsByDate(examDate);

      // Загружаем статистику комнат
      final roomStatsResult =
          await _statisticsService.getAllRoomStatistics(examDate);

      if (dashboardResult.success && dashboardResult.data != null) {
        setState(() {
          _dashboardStats = dashboardResult.data!;
          if (combinedResult.success && combinedResult.data != null) {
            _examStatistics = combinedResult.data!;
          }
          if (roomStatsResult.success && roomStatsResult.data != null) {
            _roomStatistics = roomStatsResult.data!;
          } else {
            _roomStatistics = []; // Очищаем если загрузка неудачна
          }
        });
      } else {
        setState(() {
          _errorMessage = dashboardResult.message;
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
                          _buildRoomStatistics(),
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
                'Ümumi statistika',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatisticRow(
              'İmtahan rəhbəri sayı (ümumi)',
              _getTotalMonitors(),
              const Color(0xFF059669)), // green-600 for monitors
          _buildStatisticRow('Qeydiyyatdan keçənlər', _getRegisteredMonitors(),
              AppColors.successGreen),
          _buildStatisticRow('Qeydiyyatdan keçməyənlər',
              _getUnregisteredMonitors(), AppColors.errorRed),
          const SizedBox(height: 16),
          _buildProgressBar('Qeydiyyat faizi', _getMonitorRegistrationRate()),
          const Divider(height: 32),
          _buildStatisticRow('Nəzarətçi sayı (ümumi)', _getTotalSupervisors(),
              AppColors.primaryBlue),
          _buildStatisticRow('Qeydiyyatdan keçənlər',
              _getRegisteredSupervisors(), AppColors.successGreen),
          _buildStatisticRow('Qeydiyyatdan keçməyənlər',
              _getUnregisteredSupervisors(), AppColors.errorRed),
          const SizedBox(height: 16),
          _buildProgressBar(
              'Qeydiyyat faizi', _getSupervisorRegistrationRate()),
          const Divider(height: 32),
          _buildStatisticRow('İştirakçı sayı (ümumi)',
              examSum.totalParticipants, AppColors.primaryBlue),
          _buildStatisticRow('Qeydiyyatdan keçənlər', examSum.totalRegistered,
              AppColors.successGreen),
          _buildStatisticRow('Qeydiyyatdan keçməyənlər',
              examSum.totalUnregistered, AppColors.errorRed),
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

  Widget _buildRoomStatistics() {
    if (_roomStatistics.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalRooms = _roomStatistics.length;
    final problematicRooms = _roomStatistics
        .where((room) => room.registrationPercentage < 85.0)
        .toList();
    final excellentRooms = _roomStatistics
        .where((room) => room.registrationPercentage >= 95.0)
        .toList();

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
                Icons.meeting_room,
                color: AppColors.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Otaqlar üzrə statistika',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Краткая сводка
          Row(
            children: [
              Expanded(
                child: _buildRoomSummaryCard(
                  'Ümumi',
                  totalRooms.toString(),
                  AppColors.primaryBlue,
                  Icons.meeting_room,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRoomSummaryCard(
                  'Problemli',
                  problematicRooms.length.toString(),
                  AppColors.errorRed,
                  Icons.warning_amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRoomSummaryCard(
                  'Əla',
                  excellentRooms.length.toString(),
                  AppColors.successGreen,
                  Icons.check_circle,
                ),
              ),
            ],
          ),

          // Проблемные комнаты (если есть)
          if (problematicRooms.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.warning, color: AppColors.errorRed, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Diqqət tələb edən otaqlar',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.errorRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...problematicRooms.take(3).map((room) => _buildRoomStatItem(room)),
          ],

          // Кнопка "Подробная статистика"
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoomsStatisticsScreen(
                      initialExamDate: _selectedExamDate,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.analytics),
              label: Text('Ətraflı statistika ($totalRooms otaq)'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingStatistics() {
    if (_dashboardStats?.examDetails == null ||
        _dashboardStats!.examDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalBuildings = _dashboardStats!.examDetails.length;
    final problematicCount = _getProblematicBuildingsCount();
    final excellentCount = _getExcellentBuildingsCount();
    final problematicBuildings = _getProblematicBuildings();

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
                'Binalar üzrə statistika',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Краткая сводка
          Row(
            children: [
              Expanded(
                child: _buildBuildingSummaryCard(
                  'Ümumi',
                  totalBuildings.toString(),
                  AppColors.primaryBlue,
                  Icons.apartment,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBuildingSummaryCard(
                  'Problemli',
                  problematicCount.toString(),
                  AppColors.errorRed,
                  Icons.warning_amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBuildingSummaryCard(
                  'Əla',
                  excellentCount.toString(),
                  AppColors.successGreen,
                  Icons.check_circle,
                ),
              ),
            ],
          ),

          // Проблемные здания (если есть)
          if (problematicBuildings.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.warning, color: AppColors.errorRed, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Diqqət tələb edən binalar',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.errorRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...problematicBuildings
                .take(3)
                .map((building) => _buildBuildingStatItem(building)),
          ],

          // Кнопка "Подробная статистика"
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BuildingsStatisticsScreen(
                      initialExamDate: _selectedExamDate,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.analytics),
              label: Text('Ətraflı statistika ($totalBuildings bina)'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSummaryCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomStatItem(MonitorRoomStatistics room) {
    final registrationRate = room.registrationPercentage;
    final isProblematic = registrationRate < 85.0;

    return InkWell(
      onTap: () => _navigateToRoomDetails(room),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                  room.roomId.toString(),
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
                    room.roomName,
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${room.allPersonCount} imtahan rəhbəri',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textGrey),
                  ),
                  // Индикатор процента регистрации
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isProblematic
                          ? AppColors.errorRed.withOpacity(0.1)
                          : AppColors.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${registrationRate.toStringAsFixed(1)}% qeydiyyat',
                      style: AppTextStyles.caption.copyWith(
                        color: isProblematic
                            ? AppColors.errorRed
                            : AppColors.successGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${room.regPersonCount}/${room.allPersonCount}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingSummaryCard(
      String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingStatItem(ExamDetailsDto building) {
    // Найдем соответствующую объединенную статистику для этого здания
    final combinedStats = _examStatistics.firstWhere(
      (stat) => stat.kodBina == building.kodBina,
      orElse: () => ExamStatisticsDto(
        kodBina: building.kodBina,
        supervisorCount: 0,
        regSupervisorCount: 0,
        hallCount: 0,
      ),
    );

    return InkWell(
      onTap: () => _navigateToBuildingDetails(building),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${building.totalParticipants} iştirakçı',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textGrey),
                  ),
                  // Индикатор Yetərsay
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: combinedStats.yetarsayIsGood
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: combinedStats.yetarsayIsGood
                            ? Colors.green
                            : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      combinedStats.yetarsayStatus,
                      style: AppTextStyles.caption.copyWith(
                        color: combinedStats.yetarsayIsGood
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
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
                // Показываем объединенную статистику в формате "780 | 20"
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${building.totalRegistered}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: AppColors.textGrey.withOpacity(0.5),
                    ),
                    Text(
                      '${combinedStats.regSupervisorCount ?? 0}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
                  'İştirakçılar\nüzrə',
                  Icons.school,
                  AppColors.participantGradient,
                  () => _navigateToParticipants(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Binalar\nüzrə',
                  Icons.apartment,
                  AppColors.blueGradient,
                  () => _navigateToBuildings(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'Yenilə\n ',
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

  // Методы для получения статистики наблюдателей
  int _getTotalSupervisors() {
    return _examStatistics.fold(
        0, (sum, stat) => sum + (stat.supervisorCount ?? 0));
  }

  int _getRegisteredSupervisors() {
    return _examStatistics.fold(
        0, (sum, stat) => sum + (stat.regSupervisorCount ?? 0));
  }

  int _getUnregisteredSupervisors() {
    return _getTotalSupervisors() - _getRegisteredSupervisors();
  }

  double _getSupervisorRegistrationRate() {
    final total = _getTotalSupervisors();
    if (total == 0) return 0.0;
    final registered = _getRegisteredSupervisors();
    return (registered / total) * 100;
  }

  // Методы для получения статистики мониторов - только с первого элемента (глобальные данные)
  int _getTotalMonitors() {
    if (_examStatistics.isEmpty) return 0;
    final count = _examStatistics[0].monitorCount ?? 0;
    return count;
  }

  int _getRegisteredMonitors() {
    if (_examStatistics.isEmpty) return 0;
    final count = _examStatistics[0].regMonitorCount ?? 0;
    return count;
  }

  int _getUnregisteredMonitors() {
    return _getTotalMonitors() - _getRegisteredMonitors();
  }

  double _getMonitorRegistrationRate() {
    final total = _getTotalMonitors();
    if (total == 0) return 0.0;
    final registered = _getRegisteredMonitors();
    return (registered / total) * 100;
  }

  // Методы для анализа зданий
  int _getProblematicBuildingsCount() {
    if (_examStatistics.isEmpty || _dashboardStats?.examDetails == null)
      return 0;

    int count = 0;
    for (final building in _dashboardStats!.examDetails) {
      final combinedStats = _examStatistics.firstWhere(
        (stat) => stat.kodBina == building.kodBina,
        orElse: () => ExamStatisticsDto(
            kodBina: building.kodBina,
            supervisorCount: 0,
            regSupervisorCount: 0,
            hallCount: 0),
      );

      // Здание проблематичное если:
      // 1. Низкий процент регистрации участников (<85%)
      // 2. Проблемы с Yetərsay (недостаток супервайзеров)
      if (building.registrationRate < 85.0 || !combinedStats.yetarsayIsGood) {
        count++;
      }
    }
    return count;
  }

  int _getExcellentBuildingsCount() {
    if (_examStatistics.isEmpty || _dashboardStats?.examDetails == null)
      return 0;

    int count = 0;
    for (final building in _dashboardStats!.examDetails) {
      final combinedStats = _examStatistics.firstWhere(
        (stat) => stat.kodBina == building.kodBina,
        orElse: () => ExamStatisticsDto(
            kodBina: building.kodBina,
            supervisorCount: 0,
            regSupervisorCount: 0,
            hallCount: 0),
      );

      // Здание отличное если:
      // 1. Высокий процент регистрации участников (>=95%)
      // 2. Нет проблем с Yetərsay
      if (building.registrationRate >= 95.0 && combinedStats.yetarsayIsGood) {
        count++;
      }
    }
    return count;
  }

  List<ExamDetailsDto> _getProblematicBuildings() {
    if (_examStatistics.isEmpty || _dashboardStats?.examDetails == null)
      return [];

    final problematicBuildings = <ExamDetailsDto>[];
    for (final building in _dashboardStats!.examDetails) {
      final combinedStats = _examStatistics.firstWhere(
        (stat) => stat.kodBina == building.kodBina,
        orElse: () => ExamStatisticsDto(
            kodBina: building.kodBina,
            supervisorCount: 0,
            regSupervisorCount: 0,
            hallCount: 0),
      );

      if (building.registrationRate < 85.0 || !combinedStats.yetarsayIsGood) {
        problematicBuildings.add(building);
      }
    }

    // Сортируем по убыванию проблематичности (сначала самые плохие)
    problematicBuildings
        .sort((a, b) => a.registrationRate.compareTo(b.registrationRate));

    return problematicBuildings;
  }

  void _navigateToParticipants() {
    // Навигация к участникам
  }

  void _navigateToBuildings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuildingsStatisticsScreen(
          initialExamDate: _selectedExamDate,
        ),
      ),
    );
  }

  void _navigateToRoomDetails(MonitorRoomStatistics room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomMonitorsScreen(
          roomStats: room,
        ),
      ),
    );
  }

  void _navigateToBuildingDetails(ExamDetailsDto building) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuildingDetailsScreen(
          building: building,
          examDate: _selectedExamDate!,
        ),
      ),
    );
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
