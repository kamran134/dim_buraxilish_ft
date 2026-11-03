import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/participant_light_dto.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/statistics_service.dart';
import '../statistics/admin_person_detail_screen.dart';
import '../statistics/admin_person_rows.dart';
import 'admin_all_participants_view.dart';

/// Loader of Bütün iştirakçılar: loads the participants of the active slot
/// page by page (50 at a time), searches on the server and opens the
/// participant detail of the Statistika drill-down on tap.
class AdminAllParticipantsScreen extends StatefulWidget {
  const AdminAllParticipantsScreen({super.key});

  @override
  State<AdminAllParticipantsScreen> createState() =>
      _AdminAllParticipantsScreenState();
}

class _AdminAllParticipantsScreenState
    extends State<AdminAllParticipantsScreen> {
  static const int _pageSize = 50;

  final StatisticsService _service = StatisticsService();

  final List<ParticipantLightDto> _people = [];
  Set<int> _violators = {};
  String _query = '';
  int _page = 0;
  int _totalCount = 0;
  bool _hasMore = false;

  bool _loading = false;
  bool _loadingMore = false;
  bool _loaded = false;
  String? _error;
  String? _moreError;

  // Bumped by every restart (search / refresh); answers of older generations
  // are dropped.
  int _generation = 0;
  String? _slotLabel;
  bool _slotLabelKnown = false;

  @override
  void initState() {
    super.initState();
    _restart();
    _loadViolators();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A slot switch: the whole list belongs to another exam.
    final label = Provider.of<AuthProvider>(context).activeExamHeaderLabel;
    if (_slotLabelKnown && label != _slotLabel) {
      _slotLabel = label;
      _people.clear();
      _loaded = false;
      _restart();
      _loadViolators();
    }
    _slotLabel = label;
    _slotLabelKnown = true;
  }

  Future<void> _loadViolators() async {
    final violators = await _service.getAllViolatorCardNumbers();
    if (mounted) setState(() => _violators = violators);
  }

  /// Reloads page 1 for the current query.
  Future<void> _restart() async {
    final generation = ++_generation;
    if (!context.read<AuthProvider>().hasActiveExam) {
      setState(() => _loaded = true);
      return;
    }
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _moreError = null;
    });

    final result = await _service.getParticipantsPage(
      page: 1,
      pageSize: _pageSize,
      searchTerm: _query,
    );
    if (!mounted || generation != _generation) return;

    setState(() {
      _loading = false;
      final data = result.data;
      if (result.success && data != null) {
        _people
          ..clear()
          ..addAll(data.items);
        _page = 1;
        _totalCount = data.totalCount;
        _hasMore = data.hasNextPage && data.items.isNotEmpty;
        _loaded = true;
      } else {
        // A failed refresh keeps the rows that are on screen.
        _error = result.message;
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });

    final result = await _service.getParticipantsPage(
      page: _page + 1,
      pageSize: _pageSize,
      searchTerm: _query,
    );
    if (!mounted || generation != _generation) return;

    setState(() {
      _loadingMore = false;
      final data = result.data;
      if (result.success && data != null) {
        _people.addAll(data.items);
        _page += 1;
        _totalCount = data.totalCount;
        _hasMore = data.hasNextPage && data.items.isNotEmpty;
      } else {
        _moreError = result.message;
      }
    });
  }

  void _onQueryChanged(String value) {
    final query = value.trim();
    if (query == _query) return;
    _query = query;
    _restart();
  }

  void _openPerson(AdminPersonRow row) {
    final source = row.source;
    if (source is! ParticipantLightDto ||
        source.cardNumber == null ||
        (source.buildingCode ?? '').isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminPersonDetailScreen.participant(
          cardNumber: source.cardNumber!,
          buildingCode: source.buildingCode!,
        ),
      ),
    ).then((_) {
      // The registration may have been cancelled there.
      if (mounted) _restart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AdminAllParticipantsView(
      subtitle: auth.activeExamHeaderLabel,
      hasExam: auth.hasActiveExam,
      rows: _loaded
          ? AdminPersonRow.participants(
              _people,
              violators: _violators,
              showBuilding: true,
            )
          : null,
      totalCount: _totalCount,
      query: _query,
      loading: _loading,
      loadingMore: _loadingMore,
      hasMore: _hasMore,
      error: _error,
      moreError: _moreError,
      onQueryChanged: _onQueryChanged,
      onLoadMore: _loadMore,
      onRefresh: _restart,
      onRetry: _restart,
      onOpenPerson: _openPerson,
    );
  }
}
