import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/participant_models.dart';
import '../models/supervisor_models.dart';
import '../providers/participant_provider.dart';
import '../providers/supervisor_provider.dart';
import '../design/app_colors.dart';

/// Экран для просмотра зарегистрированных людей из локальной базы данных
class DatabasePeopleScreen extends StatefulWidget {
  const DatabasePeopleScreen({super.key});

  @override
  State<DatabasePeopleScreen> createState() => _DatabasePeopleScreenState();
}

class _DatabasePeopleScreenState extends State<DatabasePeopleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Participant> _registeredParticipants = [];
  List<Supervisor> _registeredSupervisors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRegisteredPeople();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRegisteredPeople() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final participantProvider = context.read<ParticipantProvider>();
      final supervisorProvider = context.read<SupervisorProvider>();

      final participants =
          await participantProvider.getRegisteredParticipants();
      final supervisors = await supervisorProvider.getRegisteredSupervisors();

      setState(() {
        _registeredParticipants = participants;
        _registeredSupervisors = supervisors;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading registered people: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadRegisteredPeople();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Qeydiyyatdan keçənlər',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          tabs: [
            Tab(
              text: 'İştirakçılar (${_registeredParticipants.length})',
            ),
            Tab(
              text: 'Nəzarətçilər (${_registeredSupervisors.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryBlue,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildParticipantsList(),
                _buildSupervisorsList(),
              ],
            ),
    );
  }

  Widget _buildParticipantsList() {
    if (_registeredParticipants.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Qeydiyyatdan keçən iştirakçı yoxdur',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.primaryBlue,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _registeredParticipants.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final participant = _registeredParticipants[index];
          return _buildParticipantCard(participant);
        },
      ),
    );
  }

  Widget _buildSupervisorsList() {
    if (_registeredSupervisors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.supervisor_account_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Qeydiyyatdan keçən nəzarətçi yoxdur',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.primaryBlue,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _registeredSupervisors.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final supervisor = _registeredSupervisors[index];
          return _buildSupervisorCard(supervisor);
        },
      ),
    );
  }

  Widget _buildParticipantCard(Participant participant) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${participant.adi} ${participant.soy}'.trim(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'İş nömrəsi: ${participant.isN}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (participant.baba.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Ata adı: ${participant.baba}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
          if (participant.qeydiyyat != null &&
              participant.qeydiyyat!.isNotEmpty &&
              participant.qeydiyyat != 'null') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.registeredGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.registeredGreen.withOpacity(0.3)),
              ),
              child: Text(
                'Qeydiyyat: ${participant.qeydiyyat}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.registeredGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupervisorCard(Supervisor supervisor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.supervisor_account,
                  color: AppColors.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${supervisor.firstName} ${supervisor.lastName}'.trim(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kart nömrəsi: ${supervisor.cardNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (supervisor.fatherName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Ata adı: ${supervisor.fatherName}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
          if (supervisor.registerDate.isNotEmpty &&
              supervisor.registerDate != 'null') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.registeredGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.registeredGreen.withOpacity(0.3)),
              ),
              child: Text(
                'Qeydiyyat: ${supervisor.registerDate}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.registeredGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
