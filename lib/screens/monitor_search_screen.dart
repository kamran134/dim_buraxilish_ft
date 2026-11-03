import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../design/app_colors.dart';
import '../models/monitor_models.dart';
import '../providers/auth_provider.dart';
import '../services/http_service.dart';
import '../widgets/admin/admin_phone_chips.dart';
import 'admin/scan/admin_monitor_search_view.dart';

class MonitorSearchScreen extends StatefulWidget {
  const MonitorSearchScreen({super.key});

  @override
  State<MonitorSearchScreen> createState() => _MonitorSearchScreenState();
}

class _MonitorSearchScreenState extends State<MonitorSearchScreen> {
  final HttpService _httpService = HttpService();

  String _query = '';
  List<Monitor> _results = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Term of the request in flight; a slower answer to an older term is dropped.
  String? _pendingTerm;

  // Called by the search field after its 400 ms debounce.
  void _onSearchChanged(String value) {
    final term = value.trim();
    if (term.length < AdminMonitorSearchView.minQueryLength) {
      setState(() {
        _query = term;
        _pendingTerm = null;
        _isLoading = false;
        _results = [];
        _errorMessage = null;
      });
      return;
    }
    _search(term);
  }

  Future<void> _search(String term) async {
    final hasExam = context.read<AuthProvider>().hasActiveExam;
    if (!hasExam) {
      setState(() {
        _query = term;
        _errorMessage = 'İmtahan seçilməyib';
      });
      return;
    }

    setState(() {
      _query = term;
      _pendingTerm = term;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _httpService.searchMonitorsByName(
        searchTerm: term,
      );
      if (!mounted || _pendingTerm != term) return;
      setState(() {
        _results = results;
        _isLoading = false;
        if (results.isEmpty) {
          _errorMessage = '"$term" axtarışı üzrə nəticə tapılmadı';
        }
      });
    } catch (e) {
      if (!mounted || _pendingTerm != term) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Xəta baş verdi';
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('İş nömrəsi kopyalandı'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminMonitorSearchView(
      query: _query,
      results: _results,
      loading: _isLoading,
      message: _errorMessage,
      onQueryChanged: _onSearchChanged,
      onCopyWorkNumber: _copyToClipboard,
      onCall: callAdminPhone,
    );
  }
}
