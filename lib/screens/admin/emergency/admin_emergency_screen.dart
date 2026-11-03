import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/admin_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/admin_service.dart';
import '../../../services/statistics_service.dart';
import 'admin_emergency_view.dart';
import 'emergency_draft.dart';

/// Loader of Təcili elan: the buildings of the active exam for the picker,
/// the send call (`emergencymessages/send`) and the history
/// (`emergencymessages/history`, loaded when its tab is first opened).
class AdminEmergencyScreen extends StatefulWidget {
  const AdminEmergencyScreen({super.key});

  @override
  State<AdminEmergencyScreen> createState() => _AdminEmergencyScreenState();
}

class _AdminEmergencyScreenState extends State<AdminEmergencyScreen> {
  final AdminService _service = AdminService();
  final StatisticsService _statistics = StatisticsService();
  final EmergencyDraft _draft = EmergencyDraft();

  EmergencyTab _tab = EmergencyTab.send;
  List<EmergencyBuilding>? _buildings;
  String? _buildingsError;
  List<EmergencyHistoryItem>? _history;
  String? _historyError;
  bool _sending = false;

  String? _slotLabel;
  bool _slotLabelKnown = false;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A slot switch: the picker lists the buildings of another exam.
    final label = Provider.of<AuthProvider>(context).activeExamHeaderLabel;
    if (_slotLabelKnown && label != _slotLabel) {
      _slotLabel = label;
      _buildings = null;
      _draft.clearSelection();
      _loadBuildings();
    }
    _slotLabel = label;
    _slotLabelKnown = true;
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _loadBuildings() async {
    if (!context.read<AuthProvider>().hasActiveExam) return;
    setState(() => _buildingsError = null);
    final result = await _statistics.getAllExamDetailsInExamDate();
    if (!mounted) return;
    setState(() {
      final data = result.data;
      if (result.success && data != null) {
        _buildings = [
          for (final b in data)
            if ((b.buildingCode ?? '').isNotEmpty)
              EmergencyBuilding(
                code: b.buildingCode!,
                name: b.buildingName ?? '',
              ),
        ];
      } else {
        _buildingsError = 'Bina siyahısı yüklənmədi.';
      }
    });
  }

  Future<void> _loadHistory() async {
    final result = await _service.getEmergencyHistory();
    if (!mounted) return;
    setState(() {
      final data = result.data;
      if (result.success && data != null) {
        _history = data;
        _historyError = null;
      } else {
        // A failed refresh keeps the messages that are on screen.
        _historyError = 'Tarixçə yüklənmədi.';
      }
    });
  }

  void _onTabChanged(EmergencyTab tab) {
    setState(() => _tab = tab);
    if (tab == EmergencyTab.history && _history == null) _loadHistory();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final result = await _service.sendEmergencyMessage(
      title: _draft.title.text.trim(),
      body: _draft.body.text.trim(),
      importance: _draft.importance,
      buildingCodes: _draft.buildingCodes,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.success) {
        _draft.reset();
        // The new message belongs in the history: reload it on next open.
        _history = null;
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AdminEmergencyView(
      subtitle: auth.activeExamHeaderLabel,
      tab: _tab,
      onTabChanged: _onTabChanged,
      draft: _draft,
      buildings: _buildings,
      buildingsError: _buildingsError,
      hasExam: auth.hasActiveExam,
      onReloadBuildings: _loadBuildings,
      sending: _sending,
      onSend: _send,
      history: _history,
      historyError: _historyError,
      onRefreshHistory: _loadHistory,
    );
  }
}
