import 'package:flutter/material.dart';
import '../../models/participant_models.dart';
import '../../models/supervisor_models.dart';
import '../../services/database_service.dart';
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

  // All entries (offline DB or fallback registered-only)
  List<Participant>? _cachedParticipants;
  Set<int> _registeredParticipantIds = {};

  List<Supervisor>? _cachedSupervisors;
  Set<String> _registeredSupervisorIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didUpdateWidget(StatisticsListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Safety net: if isParticipants changes without a key-forced state recreation,
    // reset cache and reload so the new list type is always shown correctly.
    if (oldWidget.isParticipants != widget.isParticipants) {
      setState(() {
        _cachedParticipants = null;
        _cachedSupervisors = null;
        _registeredParticipantIds = {};
        _registeredSupervisorIds = {};
      });
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (widget.isParticipants) {
        final allParticipants = await DatabaseService.getAllParticipants();
        final registeredList =
            await DatabaseService.getRegisteredParticipants();
        final registeredIds = registeredList.map((p) => p.isN).toSet();

        if (mounted) {
          setState(() {
            if (allParticipants.isEmpty) {
              // Offline DB not downloaded — fall back to registered-only (old behavior)
              _cachedParticipants = registeredList;
            } else {
              _cachedParticipants = allParticipants;
            }
            _registeredParticipantIds = registeredIds;
          });
        }
      } else {
        final allSupervisors = await DatabaseService.getAllSupervisors();
        final registeredList = await DatabaseService.getRegisteredSupervisors();
        final registeredIds = registeredList.map((s) => s.cardNumber).toSet();

        if (mounted) {
          setState(() {
            if (allSupervisors.isEmpty) {
              // Offline DB not downloaded — fall back to registered-only (old behavior)
              _cachedSupervisors = registeredList;
            } else {
              _cachedSupervisors = allSupervisors;
            }
            _registeredSupervisorIds = registeredIds;
          });
        }
      }
    } catch (e) {
      // On any error, show empty list so the spinner doesn't stay forever
      if (mounted) {
        setState(() {
          if (widget.isParticipants) {
            _cachedParticipants = [];
          } else {
            _cachedSupervisors = [];
          }
        });
      }
    }
  }

  List<Participant> _filteredParticipants() {
    var all = _cachedParticipants ?? [];
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      all = all.where((p) {
        return p.adi.toLowerCase().contains(q) ||
            p.soy.toLowerCase().contains(q) ||
            p.baba.toLowerCase().contains(q) ||
            p.isN.toString().contains(q);
      }).toList();
    }
    // Registered first, then unregistered
    return [
      ...all.where((p) => _registeredParticipantIds.contains(p.isN)),
      ...all.where((p) => !_registeredParticipantIds.contains(p.isN)),
    ];
  }

  List<Supervisor> _filteredSupervisors() {
    var all = _cachedSupervisors ?? [];
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      all = all.where((s) {
        return s.firstName.toLowerCase().contains(q) ||
            s.lastName.toLowerCase().contains(q) ||
            s.fatherName.toLowerCase().contains(q) ||
            s.cardNumber.toLowerCase().contains(q);
      }).toList();
    }
    // Registered first, then unregistered
    return [
      ...all.where((s) => _registeredSupervisorIds.contains(s.cardNumber)),
      ...all.where((s) => !_registeredSupervisorIds.contains(s.cardNumber)),
    ];
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
          hintText: 'Axtar...',
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

    if (_cachedParticipants!.isEmpty) {
      return _buildEmptyView(
        'Hələ ki, heç bir iştirakçı qeydiyyatdan keçməyib',
        Icons.school,
      );
    }

    final participants = _filteredParticipants();

    if (participants.isEmpty) {
      return _buildEmptyView('Nəticə tapılmadı', Icons.search_off);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final p = participants[index];
        return ParticipantCard(
          participant: p,
          isRegistered: _registeredParticipantIds.contains(p.isN),
        );
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

    if (_cachedSupervisors!.isEmpty) {
      return _buildEmptyView(
        'Hələ ki, heç bir nəzarətçi qeydiyyatdan keçməyib',
        Icons.supervisor_account,
      );
    }

    final supervisors = _filteredSupervisors();

    if (supervisors.isEmpty) {
      return _buildEmptyView('Nəticə tapılmadı', Icons.search_off);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: supervisors.length,
      itemBuilder: (context, index) {
        final s = supervisors[index];
        return SupervisorCard(
          supervisor: s,
          isRegistered: _registeredSupervisorIds.contains(s.cardNumber),
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
}
