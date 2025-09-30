import 'package:flutter/material.dart';
import '../models/participant_models.dart';
import '../models/supervisor_models.dart';
import '../design/app_colors.dart';

class RegisteredPeoplePage extends StatefulWidget {
  final List<Participant>? participants;
  final List<Supervisor>? supervisors;
  final bool isParticipants;
  final String? errorMessage;

  const RegisteredPeoplePage({
    Key? key,
    this.participants,
    this.supervisors,
    required this.isParticipants,
    this.errorMessage,
  }) : super(key: key);

  @override
  State<RegisteredPeoplePage> createState() => _RegisteredPeoplePageState();
}

class _RegisteredPeoplePageState extends State<RegisteredPeoplePage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Participant> _filteredParticipants = [];
  List<Supervisor> _filteredSupervisors = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.isParticipants) {
      _filteredParticipants = widget.participants ?? [];
    } else {
      _filteredSupervisors = widget.supervisors ?? [];
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.length > 2) {
        if (widget.isParticipants) {
          _filteredParticipants = widget.participants?.where((participant) {
                final fullName =
                    '${participant.soy} ${participant.adi} ${participant.baba}'
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^a-zA-ZəƏŞşÇçĞğÜüÖöIı ]'), '');
                final searchTerm = query
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-zA-ZəƏŞşÇçĞğÜüÖöIı ]'), '')
                    .trim();
                return fullName.contains(searchTerm);
              }).toList() ??
              [];
        } else {
          _filteredSupervisors = widget.supervisors?.where((supervisor) {
                final fullName =
                    '${supervisor.lastName} ${supervisor.firstName} ${supervisor.fatherName}'
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^a-zA-ZəƏŞşÇçĞğÜüÖöIı ]'), '');
                final searchTerm = query
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-zA-ZəƏŞşÇçĞğÜüÖöIı ]'), '')
                    .trim();
                return fullName.contains(searchTerm);
              }).toList() ??
              [];
        }
      } else {
        if (widget.isParticipants) {
          _filteredParticipants = widget.participants ?? [];
        } else {
          _filteredSupervisors = widget.supervisors ?? [];
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        title: Text(
          widget.isParticipants ? 'İştirakçılar' : 'Nəzarətçilər',
          style: const TextStyle(
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
          // Search bar
          Container(
            margin: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Axtarış',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.7),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white, width: 1),
                ),
              ),
            ),
          ),

          // Error message
          if (widget.errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red[300],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.errorMessage!,
                      style: TextStyle(
                        color: Colors.red[300],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // List
          Expanded(
            child: _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (widget.isParticipants) {
      if (_filteredParticipants.isEmpty) {
        return _buildEmptyState('İştirakçı tapılmadı');
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filteredParticipants.length,
        itemBuilder: (context, index) {
          return _ParticipantCard(participant: _filteredParticipants[index]);
        },
      );
    } else {
      if (_filteredSupervisors.isEmpty) {
        return _buildEmptyState('Nəzarətçi tapılmadı');
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filteredSupervisors.length,
        itemBuilder: (context, index) {
          return _SupervisorCard(supervisor: _filteredSupervisors[index]);
        },
      );
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isParticipants ? Icons.school : Icons.supervisor_account,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  final Participant participant;

  const _ParticipantCard({Key? key, required this.participant})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(
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
          if (participant.qeydiyyat != null &&
              participant.qeydiyyat!.isNotEmpty)
            _buildInfoRow(
              Icons.access_time,
              'Qeydiyyat vaxtı',
              participant.qeydiyyat!,
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

class _SupervisorCard extends StatelessWidget {
  final Supervisor supervisor;

  const _SupervisorCard({Key? key, required this.supervisor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(
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
          if (supervisor.registerDate.isNotEmpty)
            _buildInfoRow(
              Icons.access_time,
              'Qeydiyyat vaxtı',
              supervisor.registerDate,
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
