import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/exam_details_dto.dart';
import '../../models/exam_statistics_dto.dart';
import '../../providers/auth_provider.dart';
import '../../services/statistics_event_bus.dart';
import '../../services/statistics_service.dart';
import '../../utils/role_helper.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../building_details_screen.dart';
import '../exam_select_screen.dart';
import 'admin_home_view.dart';
import 'admin_sections.dart';

/// Loader of the Əsas tab: fetches the dashboard statistics for the active
/// slot, polls every 30 s while the tab is [active], reloads on a slot
/// switch and hands everything to [AdminHomeView].
class AdminHomeScreen extends StatefulWidget {
  /// false while another tab of the shell is shown — pauses polling.
  final bool active;
  final bool inShell;
  final VoidCallback? onMenu;

  /// Opens a drawer section; the shell switches tabs, the default pushes.
  final ValueChanged<AdminSection>? onOpenSection;

  const AdminHomeScreen({
    super.key,
    this.active = true,
    this.inShell = true,
    this.onMenu,
    this.onOpenSection,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const Duration _pollInterval = Duration(seconds: 30);

  final StatisticsService _service = StatisticsService();
  StreamSubscription<String>? _eventSubscription;
  Timer? _pollTimer;

  DashboardStatistics? _stats;
  List<ExamStatisticsDto> _examStats = [];
  bool _loading = false;
  bool _noActiveSlot = false;
  String? _error;

  // A load is already running; a request that arrives meanwhile is queued so
  // it re-reads the (possibly just switched) slot afterwards.
  bool _busy = false;
  bool _reloadQueued = false;
  String? _slotLabel;
  bool _slotLabelKnown = false;

  @override
  void initState() {
    super.initState();
    _eventSubscription = StatisticsEventBus().onStatisticsUpdate.listen((_) {
      _load(silent: _stats != null);
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
      _stats = null;
      _examStats = [];
      _load();
    }
    _slotLabel = label;
    _slotLabelKnown = true;
  }

  @override
  void didUpdateWidget(AdminHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncPolling();
      if (widget.active) _load(silent: _stats != null);
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

  /// Loads the dashboard for the currently selected slot. The slot is
  /// re-read from storage each time, so a slot switch is picked up. A
  /// [silent] load (polling) keeps the current numbers on screen and does
  /// not replace them with an error.
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
          _error = null;
          _stats = null;
          _examStats = [];
          _loading = false;
        });
        return;
      }

      setState(() {
        _noActiveSlot = false;
        if (!silent) {
          _loading = true;
          _error = null;
        }
      });

      final dashboard = await _service.getDashboardStatistics();
      final combined = await _service.getExamStatisticsByDate();
      if (!mounted) return;

      setState(() {
        _loading = false;
        if (dashboard.success && dashboard.data != null) {
          _stats = dashboard.data;
          _error = null;
          if (combined.success && combined.data != null) {
            _examStats = combined.data!;
          }
        } else {
          _error = dashboard.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Statistika yüklənmədi: $e';
      });
    } finally {
      _busy = false;
      if (_reloadQueued && mounted) {
        _reloadQueued = false;
        _load(silent: _stats != null);
      }
    }
  }

  void _openSection(AdminSection section) {
    final handler = widget.onOpenSection;
    if (handler != null) {
      handler(section);
    } else {
      pushAdminSection(Navigator.of(context), section);
    }
  }

  void _openBuilding(ExamDetailsDto building) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuildingDetailsScreen(building: building),
      ),
    );
  }

  void _selectExam() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExamSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AdminHomeView(
      userName:
          RoleHelper.getUserNameFromToken(auth.accessToken?.token) ??
              'İstifadəçi',
      roleLabel: RoleHelper.getRoleDescription(auth.currentUserRole),
      examBar: AdminExamBar.connected(onSwitched: () => _load()),
      stats: _stats,
      examStats: _examStats,
      loading: _loading,
      error: _error,
      noActiveSlot: _noActiveSlot,
      inShell: widget.inShell,
      onMenu: widget.onMenu,
      onRefresh: () => _load(),
      onRetry: () => _load(),
      onSelectExam: _selectExam,
      onOpenBuilding: _openBuilding,
      onOpenSection: _openSection,
    );
  }
}
