import 'package:flutter/material.dart';

import '../../../models/monitor_models.dart';
import '../../../models/monitor_room_statistics.dart';
import '../../../services/statistics_service.dart';
import 'admin_people_view.dart';
import 'admin_person_detail_screen.dart';
import 'admin_person_rows.dart';
import 'admin_statistics_rows.dart';

/// Imtahan rəhbərləri of one room. The people come from the API with an
/// offline fallback (see [StatisticsService.getRoomMonitors]).
class AdminRoomMonitorsScreen extends StatefulWidget {
  final MonitorRoomStatistics room;

  const AdminRoomMonitorsScreen({super.key, required this.room});

  @override
  State<AdminRoomMonitorsScreen> createState() =>
      _AdminRoomMonitorsScreenState();
}

class _AdminRoomMonitorsScreenState extends State<AdminRoomMonitorsScreen> {
  final StatisticsService _service = StatisticsService();

  List<AdminPersonRow>? _rows;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (_rows == null) _error = null;
    });
    try {
      final monitors = await _service.getRoomMonitors(widget.room.roomId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _rows = AdminPersonRow.monitors(monitors);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Xəta: $e';
      });
    }
  }

  Future<void> _openPerson(AdminPersonRow row) async {
    final source = row.source;
    if (source is! Monitor) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminPersonDetailScreen.monitor(
          workNumber: source.workNumber,
          buildingCode: source.buildingCode,
        ),
      ),
    );
    // The registration may have been cancelled there.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.room.roomName.trim();
    return AdminPeopleView(
      title: name.isEmpty ? 'Otaq ${widget.room.roomId}' : name,
      subtitle: 'İmtahan rəhbərləri',
      segment: AdminStatsSegment.monitors,
      rows: _rows,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      onRetry: _load,
      onOpenPerson: _openPerson,
    );
  }
}
