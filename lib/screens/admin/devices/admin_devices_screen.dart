import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/admin_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/admin_service.dart';
import '../admin_auto_refresh.dart';
import 'admin_devices_view.dart';

/// Loader of Cihazların statusu: devices (`admin/devicelogins`) and the
/// download state per building (`admin/downloadstatus`), refreshed every 30 s
/// while the screen is visible, and the revoke calls.
class AdminDevicesScreen extends StatefulWidget {
  const AdminDevicesScreen({super.key});

  @override
  State<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends State<AdminDevicesScreen>
    with AdminAutoRefresh {
  final AdminService _service = AdminService();

  List<DeviceLogin>? _logins;
  DownloadStatusReport? _report;
  String? _error;
  String? _reportError;
  DateTime? _date;
  bool _revoking = false;

  // Bumped by every load; answers of older generations are dropped.
  int _generation = 0;
  String? _slotLabel;
  bool _slotLabelKnown = false;

  @override
  void initState() {
    super.initState();
    _load();
    startAutoRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A slot switch: the building statuses belong to another exam.
    final label = Provider.of<AuthProvider>(context).activeExamHeaderLabel;
    if (_slotLabelKnown && label != _slotLabel) {
      _slotLabel = label;
      _report = null;
      _reportError = null;
      _load();
    }
    _slotLabel = label;
    _slotLabelKnown = true;
  }

  @override
  Future<void> onAutoRefresh() => _load();

  Future<void> _load() async {
    final generation = ++_generation;
    final hasExam = context.read<AuthProvider>().hasActiveExam;

    // Both requests start at once.
    final devicesFuture = _service.getDeviceLogins(date: _date);
    final statusFuture = hasExam ? _service.getDownloadStatus() : null;
    final devices = await devicesFuture;
    final status = await statusFuture;
    if (!mounted || generation != _generation) return;

    setState(() {
      final logins = devices.data;
      if (devices.success && logins != null) {
        _logins = logins;
        _error = null;
      } else {
        // A failed refresh keeps the rows that are on screen.
        _error = devices.message;
      }
      if (status != null) {
        final report = status.data;
        if (status.success && report != null) {
          _report = report;
          _reportError = null;
        } else {
          _reportError = status.message;
        }
      }
    });
  }

  void _onDateChanged(DateTime? date) {
    _date = date;
    setState(() => _logins = null);
    _load();
  }

  Future<void> _revoke(
    RevokeScope scope, {
    String? buildingCode,
    String? deviceId,
  }) async {
    setState(() => _revoking = true);
    final result = await _service.revokeDevices(
      scope,
      buildingCode: buildingCode,
      deviceId: deviceId,
    );
    if (!mounted) return;
    setState(() => _revoking = false);

    final data = result.data;
    if (result.success && data != null) {
      final note = data.devicesWithPending > 0
          ? ' (${data.devicesWithPending} cihazda göndərilməmiş qeyd var)'
          : '';
      _showMessage('${data.devices} cihaz deaktiv edildi$note');
      await _load();
    } else {
      _showMessage(result.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AdminDevicesView(
      subtitle: auth.activeExamHeaderLabel,
      logins: _logins,
      error: _error,
      report: _report,
      reportError: _reportError,
      hasExam: auth.hasActiveExam,
      date: _date,
      revoking: _revoking,
      onRefresh: _load,
      onRetry: _load,
      onDateChanged: _onDateChanged,
      onRevoke: _revoke,
    );
  }
}
