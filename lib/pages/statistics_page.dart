import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/statistics_type.dart';
import '../providers/participant_provider.dart';
import '../providers/supervisor_provider.dart';
import '../widgets/statistics_component.dart';
import 'registered_people_page.dart';
import '../design/app_colors.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
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
        title: const Text(
          'Statistika',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Табы
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: StatisticsPeopleType.values
                    .map((type) => _buildTabButton(type))
                    .toList(),
              ),
            ),
          ),

          // Контент
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(StatisticsPeopleType type) {
    final isActive = _currentType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentType = type;
          });
        },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryBlue.withOpacity(0.8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                type.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      isActive ? Colors.white : Colors.white.withOpacity(0.8),
                  fontSize: isActive ? 15 : 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              if (isActive)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
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
        Container(
          margin: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: _isRefreshing ? null : _refreshStatistics,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              elevation: 6,
              shadowColor: Colors.black.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              minimumSize: const Size(double.infinity, 60),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isRefreshing)
                  RotationTransition(
                    turns: _refreshController,
                    child: const Icon(Icons.refresh, size: 24),
                  )
                else
                  const Icon(Icons.refresh, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Yenilə',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.school,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 20),
          const Text(
            'İştirakçılar siyahısı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RegisteredPeoplePage(
                    participants: [], // Bu hissə sonra həqiqi data ilə doldurulacaq
                    isParticipants: true,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Siyahını gör'),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.supervisor_account,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 20),
          const Text(
            'Nəzarətçilər siyahısı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RegisteredPeoplePage(
                    supervisors: [], // Bu hissə sonra həqiqi data ilə doldurulacaq
                    isParticipants: false,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Siyahını gör'),
          ),
        ],
      ),
    );
  }
}
