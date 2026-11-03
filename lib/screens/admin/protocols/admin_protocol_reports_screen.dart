import 'package:flutter/material.dart';

import '../../../models/protocol_models.dart';
import '../../../services/http_service.dart';
import '../../../services/protocol_service.dart';
import 'admin_protocol_reports_view.dart';

/// Loader of Protokol hesabatları: fetches the protocol notes for the chosen
/// dates (today's exam date by default, as the web does) and hands them to
/// [AdminProtocolReportsView].
class AdminProtocolReportsScreen extends StatefulWidget {
  final bool inShell;
  final VoidCallback? onMenu;

  const AdminProtocolReportsScreen({
    super.key,
    this.inShell = false,
    this.onMenu,
  });

  @override
  State<AdminProtocolReportsScreen> createState() =>
      _AdminProtocolReportsScreenState();
}

class _AdminProtocolReportsScreenState
    extends State<AdminProtocolReportsScreen> {
  // The web asks for every record at once (page 1, 10000 per page).
  static const int _pageSize = 10000;

  final ProtocolService _service = ProtocolService(HttpService());

  late AdminProtocolFilters _filters;
  List<ProtocolNote>? _protocols;
  bool _loading = false;
  String? _error;

  // Bumped by every request; an older answer is dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filters = AdminProtocolFilters(
      examDate: DateTime(now.year, now.month, now.day),
    );
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (_filters.isEmpty) {
      setState(() {
        _protocols = null;
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    List<ProtocolNote>? protocols;
    String? error;
    try {
      final response = await _service.getProtocols(
        pageSize: _pageSize,
        examDate: AdminProtocolFilters.apiDate(_filters.examDate),
        startDate: AdminProtocolFilters.apiDate(_filters.startDate),
        endDate: AdminProtocolFilters.apiDate(_filters.endDate),
      );
      if (response.success && response.data != null) {
        protocols = response.data!.data;
      } else {
        error = response.message ?? 'Protokollar yüklənmədi';
      }
    } catch (_) {
      error = 'Protokollar yükləməkdə xəta baş verdi';
    }

    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      if (protocols != null) {
        _protocols = protocols;
      } else {
        _error = error;
      }
    });
  }

  void _apply(AdminProtocolFilters filters) {
    _filters = filters;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminProtocolReportsView(
      filters: _filters,
      protocols: _protocols,
      loading: _loading,
      error: _error,
      inShell: widget.inShell,
      onMenu: widget.onMenu,
      onApply: _apply,
      onRefresh: _load,
      onRetry: _load,
    );
  }
}
