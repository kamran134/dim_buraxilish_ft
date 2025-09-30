import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/statistics_type.dart';
import '../providers/participant_provider.dart';
import '../providers/supervisor_provider.dart';
import '../widgets/statistics_component.dart';
import '../design/app_colors.dart';
import '../models/participant_models.dart';
import '../models/supervisor_models.dart';

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
    return Consumer<ParticipantProvider>(
      builder: (context, participantProvider, child) {
        return FutureBuilder<List<Participant>>(
          future: participantProvider.getRegisteredParticipants(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Xəta baş verdi: ${snapshot.error}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final participants = snapshot.data ?? [];

            if (participants.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school,
                      size: 80,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Hələ ki, heç bir iştirakçı qeydiyyatdan keçməyib',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: participants.length,
              itemBuilder: (context, index) {
                return _ParticipantCard(participant: participants[index]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSupervisorsView() {
    return Consumer<SupervisorProvider>(
      builder: (context, supervisorProvider, child) {
        return FutureBuilder<List<Supervisor>>(
          future: supervisorProvider.getRegisteredSupervisors(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Xəta baş verdi: ${snapshot.error}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final supervisors = snapshot.data ?? [];

            if (supervisors.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.supervisor_account,
                      size: 80,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Hələ ki, heç bir nəzarətçi qeydiyyatdan keçməyib',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: supervisors.length,
              itemBuilder: (context, index) {
                return _SupervisorCard(supervisor: supervisors[index]);
              },
            );
          },
        );
      },
    );
  }

  // Helper function to format date
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }
}

// Participant Card Widget
class _ParticipantCard extends StatelessWidget {
  final Participant participant;

  const _ParticipantCard({Key? key, required this.participant})
      : super(key: key);

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'null') {
      return 'Məlum deyil';
    }
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug print for photo
    print('Participant ${participant.isN} photo: "${participant.photo}"');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: participant.photo != null &&
                        participant.photo!.isNotEmpty &&
                        participant.photo != 'null'
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Image.network(
                          participant.photo!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print(
                                'Photo load error for ${participant.isN}: $error');
                            return const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${participant.soy} ${participant.adi}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (participant.baba.isNotEmpty)
                      Text(
                        participant.baba,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Qeydiyyatlı',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.badge,
            'İş nömrəsi',
            participant.isN.toString(),
          ),
          _buildInfoRow(
            Icons.access_time,
            'Qeydiyyat vaxtı',
            _formatDate(participant.qeydiyyat),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Supervisor Card Widget
class _SupervisorCard extends StatelessWidget {
  final Supervisor supervisor;

  const _SupervisorCard({Key? key, required this.supervisor}) : super(key: key);

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'null') {
      return 'Məlum deyil';
    }
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug print for supervisor image
    print('Supervisor ${supervisor.cardNumber} image: "${supervisor.image}"');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.statisticsBlue.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: supervisor.image.isNotEmpty && supervisor.image != 'null'
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Image.network(
                          supervisor.image,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print(
                                'Image load error for supervisor ${supervisor.cardNumber}: $error');
                            return const Icon(
                              Icons.supervisor_account,
                              color: Colors.white,
                              size: 24,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.supervisor_account,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${supervisor.lastName} ${supervisor.firstName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (supervisor.fatherName.isNotEmpty)
                      Text(
                        supervisor.fatherName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Qeydiyyatlı',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.credit_card,
            'Kart nömrəsi',
            supervisor.cardNumber,
          ),
          _buildInfoRow(
            Icons.access_time,
            'Qeydiyyat vaxtı',
            _formatDate(supervisor.registerDate),
          ),
          _buildInfoRow(
            Icons.business,
            'Bina kodu',
            supervisor.buildingCode.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
