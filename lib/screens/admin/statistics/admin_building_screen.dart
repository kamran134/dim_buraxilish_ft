import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/monitor_models.dart';
import '../../../models/participant_light_dto.dart';
import '../../../models/supervisor_detail_dto.dart';
import '../../../services/statistics_service.dart';
import 'admin_people_view.dart';
import 'admin_person_detail_screen.dart';
import 'admin_person_rows.dart';
import 'admin_statistics_rows.dart';

/// Loader of a building screen: fetches the people of one building per
/// segment (lazily, on first visit), polls the visible segment every 30 s and
/// reloads it after returning from a person's detail.
class AdminBuildingScreen extends StatefulWidget {
  final String buildingCode;
  final String? buildingName;
  final AdminStatsSegment initialSegment;

  const AdminBuildingScreen({
    super.key,
    required this.buildingCode,
    this.buildingName,
    this.initialSegment = AdminStatsSegment.participants,
  });

  @override
  State<AdminBuildingScreen> createState() => _AdminBuildingScreenState();
}

class _AdminBuildingScreenState extends State<AdminBuildingScreen> {
  static const Duration _pollInterval = Duration(seconds: 30);

  final StatisticsService _service = StatisticsService();
  Timer? _pollTimer;
  late AdminStatsSegment _segment;

  final Map<AdminStatsSegment, List<AdminPersonRow>> _rows = {};
  final Map<AdminStatsSegment, String?> _errors = {};
  final Set<AdminStatsSegment> _loading = {};

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _load(_segment));
    _load(_segment);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load(AdminStatsSegment segment) async {
    if (_loading.contains(segment)) return;
    final code = widget.buildingCode;
    if (code.isEmpty) {
      setState(() => _errors[segment] = 'Bina kodu boşdur');
      return;
    }

    setState(() {
      _loading.add(segment);
      if (!_rows.containsKey(segment)) _errors[segment] = null;
    });

    List<AdminPersonRow>? rows;
    String? error;
    try {
      switch (segment) {
        case AdminStatsSegment.participants:
          final (people, violators) = await (
            _service.getAllParticipantsInBuilding(code),
            _service.getViolatorCardNumbers(code),
          ).wait;
          if (people.success && people.data != null) {
            rows = AdminPersonRow.participants(
              people.data!,
              violators: violators,
            );
          } else {
            error = people.message;
          }
        case AdminStatsSegment.supervisors:
          final result = await _service.getAllSupervisorsInBuilding(code);
          if (result.success && result.data != null) {
            rows = AdminPersonRow.supervisors(result.data!);
          } else {
            error = result.message;
          }
        case AdminStatsSegment.monitors:
          final result = await _service.getMonitorsInBuilding(code);
          if (result.success && result.data != null) {
            rows = AdminPersonRow.monitors(result.data!);
          } else {
            error = result.message;
          }
      }
    } catch (e) {
      error = 'Xəta baş verdi: $e';
    }

    if (!mounted) return;
    setState(() {
      _loading.remove(segment);
      if (rows != null) {
        _rows[segment] = rows;
        _errors[segment] = null;
      } else {
        _errors[segment] = error;
      }
    });
  }

  void _selectSegment(AdminStatsSegment segment) {
    setState(() => _segment = segment);
    if (!_rows.containsKey(segment)) _load(segment);
  }

  Future<void> _openPerson(AdminPersonRow row) async {
    final source = row.source;
    final Widget screen;
    if (source is ParticipantLightDto && source.cardNumber != null) {
      screen = AdminPersonDetailScreen.participant(
        cardNumber: source.cardNumber!,
        buildingCode: widget.buildingCode,
      );
    } else if (source is SupervisorDetailDto && source.cardNumber != null) {
      screen = AdminPersonDetailScreen.supervisor(
        cardNumber: source.cardNumber!,
        buildingCode:
            source.buildingCode ?? int.tryParse(widget.buildingCode) ?? 0,
      );
    } else if (source is Monitor) {
      screen = AdminPersonDetailScreen.monitor(
        workNumber: source.workNumber,
        buildingCode: source.buildingCode,
      );
    } else {
      return;
    }

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    // The registration may have been cancelled there.
    if (mounted) _load(_segment);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.buildingName?.trim() ?? '';
    return AdminPeopleView(
      title: name.isEmpty ? 'Bina ${widget.buildingCode}' : name,
      subtitle: 'Kod: ${widget.buildingCode}',
      segment: _segment,
      onSegmentChanged: _selectSegment,
      rows: _rows[_segment],
      loading: _loading.contains(_segment),
      error: _errors[_segment],
      onRefresh: () => _load(_segment),
      onRetry: () => _load(_segment),
      onOpenPerson: _openPerson,
    );
  }
}
