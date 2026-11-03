import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/exam_statistics_dto.dart';
import '../../../models/monitor_room_statistics.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/statistics_event_bus.dart';
import '../../../services/statistics_service.dart';
import 'admin_building_screen.dart';
import 'admin_room_monitors_screen.dart';
import 'admin_statistics_rows.dart';
import 'admin_statistics_view.dart';

/// Loader of the Statistika tab: fetches the per-building and per-room
/// numbers of the active slot, polls every 30 s while the tab is [active],
/// reloads on a slot switch and hands everything to [AdminStatisticsView].
class AdminStatisticsScreen extends StatefulWidget {
  final AdminStatsSegment segment;
  final ValueChanged<AdminStatsSegment> onSegmentChanged;

  /// false while another tab of the shell is shown — pauses polling.
  final bool active;
  final bool inShell;
  final VoidCallback? onMenu;

  const AdminStatisticsScreen({
    super.key,
    required this.segment,
    required this.onSegmentChanged,
    this.active = true,
    this.inShell = true,
    this.onMenu,
  });

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  static const Duration _pollInterval = Duration(seconds: 30);

  final StatisticsService _service = StatisticsService();
  StreamSubscription<String>? _eventSubscription;
  Timer? _pollTimer;

  List<ExamStatisticsDto> _buildings = [];
  List<MonitorRoomStatistics> _rooms = [];
  bool _loading = false;
  bool _noActiveSlot = false;
  String? _buildingsError;
  String? _roomsError;

  // A load is already running; a request that arrives meanwhile is queued so
  // it re-reads the (possibly just switched) slot afterwards.
  bool _busy = false;
  bool _reloadQueued = false;
  String? _slotLabel;
  bool _slotLabelKnown = false;

  bool get _hasData => _buildings.isNotEmpty || _rooms.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _eventSubscription = StatisticsEventBus().onStatisticsUpdate.listen((_) {
      if (widget.active) _load(silent: _hasData);
    });
    _syncPolling();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A slot switch changes the label: drop the old numbers and reload.
    final label = Provider.of<AuthProvider>(context).activeExamHeaderLabel;
    if (_slotLabelKnown && label != _slotLabel) {
      _slotLabel = label;
      _buildings = [];
      _rooms = [];
      _load();
    }
    _slotLabel = label;
    _slotLabelKnown = true;
  }

  @override
  void didUpdateWidget(AdminStatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncPolling();
      if (widget.active) _load(silent: _hasData);
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _syncPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!widget.active) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _load(silent: true));
  }

  /// Loads buildings and rooms of the currently selected slot. A [silent]
  /// load (polling) keeps the current numbers on screen.
  Future<void> _load({bool silent = false}) async {
    if (_busy) {
      _reloadQueued = true;
      return;
    }
    _busy = true;
    try {
      final hasSlot = await _service.hasActiveSlot();
      if (!mounted) return;
      if (!hasSlot) {
        setState(() {
          _noActiveSlot = true;
          _buildings = [];
          _rooms = [];
          _buildingsError = null;
          _roomsError = null;
          _loading = false;
        });
        return;
      }

      setState(() {
        _noActiveSlot = false;
        if (!silent) {
          _loading = true;
          _buildingsError = null;
          _roomsError = null;
        }
      });

      final buildings = await _service.getExamStatisticsByDate();
      final rooms = await _service.getAllRoomStatistics();
      if (!mounted) return;

      setState(() {
        _loading = false;
        if (buildings.success && buildings.data != null) {
          _buildings = buildings.data!;
          _buildingsError = null;
        } else {
          _buildingsError = buildings.message;
        }
        if (rooms.success && rooms.data != null) {
          _rooms = rooms.data!;
          _roomsError = null;
        } else {
          _roomsError = rooms.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _buildingsError = 'Statistika yüklənmədi: $e';
      });
    } finally {
      _busy = false;
      if (_reloadQueued && mounted) {
        _reloadQueued = false;
        _load(silent: _hasData);
      }
    }
  }

  void _openBuilding(ExamStatisticsDto building, AdminStatsSegment segment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminBuildingScreen(
          buildingCode: building.buildingCode ?? '',
          buildingName: building.buildingName,
          initialSegment: segment,
        ),
      ),
    );
  }

  void _openRoom(MonitorRoomStatistics room) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminRoomMonitorsScreen(room: room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.segment == AdminStatsSegment.monitors;
    return AdminStatisticsView(
      segment: widget.segment,
      onSegmentChanged: widget.onSegmentChanged,
      buildings: _buildings,
      rooms: _rooms,
      loading: _loading,
      error: rooms ? _roomsError : _buildingsError,
      noActiveSlot: _noActiveSlot,
      inShell: widget.inShell,
      onMenu: widget.onMenu,
      onRefresh: () => _load(),
      onRetry: () => _load(),
      onOpenBuilding: _openBuilding,
      onOpenRoom: _openRoom,
    );
  }
}

/// Statistika as a pushed page (outside the shell): owns the selected
/// segment itself.
class AdminStatisticsPage extends StatefulWidget {
  final AdminStatsSegment segment;

  const AdminStatisticsPage({
    super.key,
    this.segment = AdminStatsSegment.participants,
  });

  @override
  State<AdminStatisticsPage> createState() => _AdminStatisticsPageState();
}

class _AdminStatisticsPageState extends State<AdminStatisticsPage> {
  late AdminStatsSegment _segment = widget.segment;

  @override
  Widget build(BuildContext context) {
    return AdminStatisticsScreen(
      segment: _segment,
      inShell: false,
      onSegmentChanged: (value) => setState(() => _segment = value),
    );
  }
}
