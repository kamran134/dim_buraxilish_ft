import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/participant_models.dart';
import '../../models/supervisor_models.dart';
import '../../providers/participant_provider.dart';
import '../../providers/supervisor_provider.dart';
import 'participant_card.dart';
import 'supervisor_card.dart';

/// Компонент для отображения списков участников или супервизоров
class StatisticsListView extends StatefulWidget {
  final bool isParticipants; // true для участников, false для супервизоров

  const StatisticsListView({
    Key? key,
    required this.isParticipants,
  }) : super(key: key);

  @override
  State<StatisticsListView> createState() => _StatisticsListViewState();
}

class _StatisticsListViewState extends State<StatisticsListView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Participant>? _cachedParticipants;
  List<Supervisor>? _cachedSupervisors;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (widget.isParticipants) {
      final provider = Provider.of<ParticipantProvider>(context, listen: false);
      final result = await provider.getRegisteredParticipants();
      if (mounted) setState(() => _cachedParticipants = result);
    } else {
      final provider = Provider.of<SupervisorProvider>(context, listen: false);
      final result = await provider.getRegisteredSupervisors();
      if (mounted) setState(() => _cachedSupervisors = result);
    }
  }

  List<Participant> _filteredParticipants() {
    final all = _cachedParticipants ?? [];
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((p) {
      return p.adi.toLowerCase().contains(q) ||
          p.soy.toLowerCase().contains(q) ||
          p.baba.toLowerCase().contains(q) ||
          p.isN.toString().contains(q);
    }).toList();
  }

  List<Supervisor> _filteredSupervisors() {
    final all = _cachedSupervisors ?? [];
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((s) {
      return s.firstName.toLowerCase().contains(q) ||
          s.lastName.toLowerCase().contains(q) ||
          s.fatherName.toLowerCase().contains(q) ||
          s.cardNumber.toLowerCase().contains(q) ||
          s.buildingName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchField(),
        Expanded(
          child: widget.isParticipants
              ? _buildParticipantsView()
              : _buildSupervisorsView(),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: widget.isParticipants ? 'Axtar...' : 'Axtar...',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white12,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantsView() {
    if (_cachedParticipants == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    final participants = _filteredParticipants();

    if (_cachedParticipants!.isEmpty) {
      return _buildEmptyView(
        'Hələ ki, heç bir iştirakçı qeydiyyatdan keçməyib',
        Icons.school,
      );
    }

    if (participants.isEmpty) {
      return _buildEmptyView('Nəticə tapılmadı', Icons.search_off);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        return ParticipantCard(participant: participants[index]);
      },
    );
  }

  Widget _buildSupervisorsView() {
    if (_cachedSupervisors == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    final supervisors = _filteredSupervisors();

    if (_cachedSupervisors!.isEmpty) {
      return _buildEmptyView(
        'Hələ ki, heç bir nəzarətçi qeydiyyatdan keçməyib',
        Icons.supervisor_account,
      );
    }

    if (supervisors.isEmpty) {
      return _buildEmptyView('Nəticə tapılmadı', Icons.search_off);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: supervisors.length,
      itemBuilder: (context, index) {
        return SupervisorCard(supervisor: supervisors[index]);
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
}
