import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/statistics_type.dart';
import '../providers/participant_provider.dart';
import '../providers/supervisor_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/statistics_component.dart';
import '../widgets/statistics/statistics_widgets.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../services/statistics_service.dart';
import '../models/exam_statistics_dto.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  StatisticsPeopleType _currentType = StatisticsPeopleType.statistics;
  late AnimationController _refreshController;
  bool _isRefreshing = false;

  // Для админа - новые данные
  final StatisticsService _statisticsService = StatisticsService();
  List<ExamStatisticsDto> _adminStatistics = [];
  List<String> _examDates = [];
  String? _selectedExamDate;
  bool _isAdminLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Загружаем данные при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isAdmin || authProvider.isSuperAdmin) {
      _loadAdminData();
    } else {
      // Для мониторов - загружаем данные как обычно
      final participantProvider =
          Provider.of<ParticipantProvider>(context, listen: false);
      final supervisorProvider =
          Provider.of<SupervisorProvider>(context, listen: false);

      participantProvider.loadExamDetails();
      supervisorProvider.loadSupervisorDetails();
    }
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isAdminLoading = true;
    });

    try {
      // Загружаем даты экзаменов
      final datesResult = await _statisticsService.getAllExamDates();
      if (datesResult.success && datesResult.data != null) {
        _examDates = datesResult.data!;
        if (_examDates.isNotEmpty) {
          _selectedExamDate = _examDates.first;
          await _loadAdminStatistics(_selectedExamDate!);
        }
      }
    } catch (e) {
      print('Ошибка загрузки админ данных: $e');
    } finally {
      setState(() {
        _isAdminLoading = false;
      });
    }
  }

  Future<void> _loadAdminStatistics(String examDate) async {
    final result = await _statisticsService.getExamStatisticsByDate(examDate);
    if (result.success && result.data != null) {
      setState(() {
        _adminStatistics = result.data!;
      });
    }
  }

  Future<void> _refreshStatistics() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    _refreshController.repeat();

    try {
      _loadData();
      await Future.delayed(
          const Duration(milliseconds: 1000)); // Минимальное время анимации
    } finally {
      _refreshController.stop();
      _refreshController.reset();
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        title: Text(
          'Statistika',
          style: AppTextStyles.appBarTitle,
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Табы
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return StatisticsTabBar(
                currentType: _currentType,
                onTypeChanged: (type) {
                  setState(() {
                    _currentType = type;
                  });
                },
                isAdmin: authProvider.isAdmin || authProvider.isSuperAdmin,
              );
            },
          ),

          // Контент
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentType) {
      case StatisticsPeopleType.statistics:
        return _buildStatisticsView();
      case StatisticsPeopleType.participant:
        return _buildParticipantsView();
      case StatisticsPeopleType.supervisor:
        return _buildSupervisorsView();
    }
  }

  Widget _buildStatisticsView() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isAdmin || authProvider.isSuperAdmin) {
          return _buildAdminStatisticsView();
        } else {
          return _buildMonitorStatisticsView();
        }
      },
    );
  }

  Widget _buildAdminStatisticsView() {
    return Column(
      children: [
        Expanded(
          child: _isAdminLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : StatisticsComponent(
                  allMan: _getAdminMenCount(),
                  allWoman: _getAdminWomenCount(),
                  regMan: _getAdminRegisteredMenCount(),
                  regWoman: _getAdminRegisteredWomenCount(),
                  allSupervisors: _getAdminTotalSupervisors(),
                  registeredSupervisors: _getAdminRegisteredSupervisors(),
                ),
        ),

        // Кнопка обновления
        StatisticsRefreshButton(
          isRefreshing: _isRefreshing,
          onRefresh: _refreshStatistics,
          animationController: _refreshController,
        ),
      ],
    );
  }

  Widget _buildMonitorStatisticsView() {
    return Column(
      children: [
        Expanded(
          child: Consumer2<ParticipantProvider, SupervisorProvider>(
            builder: (context, participantProvider, supervisorProvider, child) {
              final participantStats = participantProvider.examDetails;
              final supervisorStats = supervisorProvider.supervisorDetails;

              if (participantProvider.isLoading ||
                  supervisorProvider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              }

              return StatisticsComponent(
                allMan: participantStats?.allManCount ?? 0,
                allWoman: participantStats?.allWomanCount ?? 0,
                regMan: participantStats?.regManCount ?? 0,
                regWoman: participantStats?.regWomanCount ?? 0,
                allSupervisors: supervisorStats?.allPersonCount ?? 0,
                registeredSupervisors: supervisorStats?.regPersonCount ?? 0,
              );
            },
          ),
        ),

        // Кнопка обновления
        StatisticsRefreshButton(
          isRefreshing: _isRefreshing,
          onRefresh: _refreshStatistics,
          animationController: _refreshController,
        ),
      ],
    );
  }

  Widget _buildParticipantsView() {
    return const StatisticsListView(isParticipants: true);
  }

  Widget _buildSupervisorsView() {
    return const StatisticsListView(isParticipants: false);
  }

  // Методы для получения админской статистики из ExamStatisticsDto
  int _getAdminTotalSupervisors() {
    return _adminStatistics.fold(
        0, (sum, stat) => sum + (stat.supervisorCount ?? 0));
  }

  int _getAdminRegisteredSupervisors() {
    return _adminStatistics.fold(
        0, (sum, stat) => sum + (stat.regSupervisorCount ?? 0));
  }

  int _getAdminTotalParticipants() {
    return _adminStatistics.fold(
        0, (sum, stat) => sum + stat.totalParticipants);
  }

  int _getAdminRegisteredParticipants() {
    return _adminStatistics.fold(
        0, (sum, stat) => sum + stat.registeredParticipants);
  }

  // Теперь у нас есть разбивка по полу участников
  int _getAdminMenCount() {
    return _adminStatistics.fold(
        0, (sum, stat) => sum + (stat.allManCount ?? 0));
  }

  int _getAdminWomenCount() {
    return _adminStatistics.fold(
        0, (sum, stat) => sum + (stat.allWomanCount ?? 0));
  }

  int _getAdminRegisteredMenCount() {
    return _adminStatistics.fold(
        0, (sum, stat) => sum + (stat.regManCount ?? 0));
  }

  int _getAdminRegisteredWomenCount() {
    return _adminStatistics.fold(
        0, (sum, stat) => sum + (stat.regWomanCount ?? 0));
  }
}
