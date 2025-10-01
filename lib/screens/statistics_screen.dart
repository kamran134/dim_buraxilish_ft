import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/statistics_type.dart';
import '../providers/participant_provider.dart';
import '../providers/supervisor_provider.dart';
import '../widgets/statistics_component.dart';
import '../widgets/statistics/statistics_widgets.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

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
    final participantProvider =
        Provider.of<ParticipantProvider>(context, listen: false);
    final supervisorProvider =
        Provider.of<SupervisorProvider>(context, listen: false);

    participantProvider.loadExamDetails();
    supervisorProvider.loadSupervisorDetails();
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
          StatisticsTabBar(
            currentType: _currentType,
            onTypeChanged: (type) {
              setState(() {
                _currentType = type;
              });
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
}
