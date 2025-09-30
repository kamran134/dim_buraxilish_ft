import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/participant_models.dart';
import '../../models/supervisor_models.dart';
import '../../providers/participant_provider.dart';
import '../../providers/supervisor_provider.dart';
import 'participant_card.dart';
import 'supervisor_card.dart';

/// Компонент для отображения списков участников или супервизоров
class StatisticsListView extends StatelessWidget {
  final bool isParticipants; // true для участников, false для супервизоров

  const StatisticsListView({
    Key? key,
    required this.isParticipants,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isParticipants) {
      return _buildParticipantsView();
    } else {
      return _buildSupervisorsView();
    }
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
              return _buildErrorView(
                'Xəta baş verdi: ${snapshot.error}',
                Icons.error_outline,
              );
            }

            final participants = snapshot.data ?? [];

            if (participants.isEmpty) {
              return _buildEmptyView(
                'Hələ ki, heç bir iştirakçı qeydiyyatdan keçməyib',
                Icons.school,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: participants.length,
              itemBuilder: (context, index) {
                return ParticipantCard(participant: participants[index]);
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
              return _buildErrorView(
                'Xəta baş verdi: ${snapshot.error}',
                Icons.error_outline,
              );
            }

            final supervisors = snapshot.data ?? [];

            if (supervisors.isEmpty) {
              return _buildEmptyView(
                'Hələ ki, heç bir nəzarətçi qeydiyyatdan keçməyib',
                Icons.supervisor_account,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: supervisors.length,
              itemBuilder: (context, index) {
                return SupervisorCard(supervisor: supervisors[index]);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyView(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 20),
          Text(
            message,
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

  Widget _buildErrorView(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 20),
          Text(
            message,
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
}
