import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/auth_models.dart' show ResponseModel;
import '../../../models/response_models.dart' show DataResult;
import '../../../services/statistics_service.dart';
import 'admin_person_detail_view.dart';

typedef _DetailLoader = Future<DataResult<AdminPersonDetailData>> Function(
  StatisticsService service,
);

/// Loader of a person's detail (participant, supervisor or imtahan rəhbəri):
/// fetches the full record, and cancels the registration after a
/// confirmation.
class AdminPersonDetailScreen extends StatefulWidget {
  final AdminPersonKind kind;
  final _DetailLoader _load;

  AdminPersonDetailScreen._(this.kind, this._load, {super.key});

  /// Participant by work number (`cardNumber`) in a building; adds the
  /// protocol record when there is one.
  factory AdminPersonDetailScreen.participant({
    Key? key,
    required int cardNumber,
    required String buildingCode,
  }) =>
      AdminPersonDetailScreen._(
        AdminPersonKind.participant,
        (service) async {
          final person = await service.getParticipantDetail(
            cardNumber: cardNumber,
            buildingCode: buildingCode,
          );
          if (!person.success || person.data == null) {
            return DataResult.error(message: person.message);
          }
          // The protocol is a bonus: its failure must not hide the person.
          final protocol = await service.getParticipantProtocol(cardNumber);
          return DataResult.success(
            data: AdminPersonDetailData.participant(
              person.data!,
              protocol: protocol.data,
            ),
            message: person.message,
          );
        },
        key: key,
      );

  factory AdminPersonDetailScreen.supervisor({
    Key? key,
    required String cardNumber,
    required int buildingCode,
  }) =>
      AdminPersonDetailScreen._(
        AdminPersonKind.supervisor,
        (service) async {
          final result = await service.getSupervisorDetail(
            cardNumber: cardNumber,
            buildingCode: buildingCode,
          );
          if (!result.success || result.data == null) {
            return DataResult.error(message: result.message);
          }
          return DataResult.success(
            data: AdminPersonDetailData.supervisor(result.data!),
            message: result.message,
          );
        },
        key: key,
      );

  factory AdminPersonDetailScreen.monitor({
    Key? key,
    required int workNumber,
    required int buildingCode,
  }) =>
      AdminPersonDetailScreen._(
        AdminPersonKind.monitor,
        (service) async {
          final result = await service.getMonitorDetail(
            workNumber: workNumber,
            buildingCode: buildingCode,
          );
          if (!result.success || result.data == null) {
            return DataResult.error(message: result.message);
          }
          return DataResult.success(
            data: AdminPersonDetailData.monitor(result.data!),
            message: result.message,
          );
        },
        key: key,
      );

  @override
  State<AdminPersonDetailScreen> createState() =>
      _AdminPersonDetailScreenState();
}

class _AdminPersonDetailScreenState extends State<AdminPersonDetailScreen> {
  final StatisticsService _service = StatisticsService();

  AdminPersonDetailData? _data;
  bool _loading = false;
  bool _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget._load(_service);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (result.success && result.data != null) {
          _data = result.data;
        } else {
          _error = result.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Xəta baş verdi: $e';
      });
    }
  }

  Future<void> _confirmCancel() async {
    final id = _data?.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Qeydiyyatı ləğv et'),
        content: const Text('Qeydiyyatını silmək istədiyinizdən əminsinizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ləğv et'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final ResponseModel result;
    try {
      result = await _service.cancelRegistration(widget.kind, id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      _showMessage('Xəta baş verdi: $e');
      return;
    }
    if (!mounted) return;
    setState(() => _cancelling = false);
    _showMessage(result.message);
    if (result.success) await _load();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPersonDetailView(
      kind: widget.kind,
      data: _data,
      loading: _loading,
      error: _error,
      cancelling: _cancelling,
      onRefresh: _load,
      onRetry: _load,
      onCancelRegistration: _confirmCancel,
      onCallPhone: _callPhone,
    );
  }
}
