import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/statistics_type.dart';
import '../providers/participant_provider.dart';
import '../providers/supervisor_provider.dart';
import '../widgets/statistics_component.dart';
import '../widgets/statistics/statistics_widgets.dart';
import '../widgets/statistics/active_slot_bar.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import '../services/statistics_service.dart';
import '../services/sync_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  StatisticsPeopleType _currentType = StatisticsPeopleType.statistics;
  late AnimationController _refreshController;
  bool _isRefreshing = false;

  final StatisticsService _statisticsService = StatisticsService();
  // Статистика всегда по выбранному слоту (X-Exam-Slot); без слота
  // показываем NoActiveSlotView вместо данных.
  bool _noActiveSlot = false;

  // SyncService pulls the server aggregate only after its own sync cycles,
  // and those run only while this device keeps scanning (idle-stop after
  // 10 min). A device that just watches the stats would freeze on its local
  // numbers, so poll the server aggregate while the screen is open.
  static const Duration _pollInterval = Duration(seconds: 30);
  Timer? _pollTimer;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Загружаем данные при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollServerStatistics());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final participantProvider =
        Provider.of<ParticipantProvider>(context, listen: false);
    final supervisorProvider =
        Provider.of<SupervisorProvider>(context, listen: false);

    final hasSlot = await _statisticsService.hasActiveSlot();
    if (!mounted) return;
    setState(() {
      _noActiveSlot = !hasSlot;
    });
    if (!hasSlot) return;

    // Only trigger network loads if the provider is not already loading
    // Prevents cross-contamination of isLoading with scanning screens
    if (!participantProvider.isLoading) participantProvider.loadExamDetails();
    if (!supervisorProvider.isLoading) {
      supervisorProvider.loadSupervisorDetails();
    }
  }

  /// Silent background refresh: no spinners, keeps current numbers when
  /// offline (the providers' refreshServerStatistics are no-ops then).
  Future<void> _pollServerStatistics() async {
    if (!mounted || _noActiveSlot || _isPolling || _isRefreshing) return;
    // Only the summary tab shows the aggregate; the lists are local DB.
    if (_currentType != StatisticsPeopleType.statistics) return;
    _isPolling = true;
    try {
      final participantProvider =
          Provider.of<ParticipantProvider>(context, listen: false);
      final supervisorProvider =
          Provider.of<SupervisorProvider>(context, listen: false);
      await Future.wait([
        if (!participantProvider.isLoading)
          participantProvider.refreshServerStatistics(),
        if (!supervisorProvider.isLoading)
          supervisorProvider.refreshServerStatistics(),
      ]);
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _refreshStatistics() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    _refreshController.repeat();

    try {
      _loadData();
      await Future.delayed(
          const Duration(milliseconds: 1000)); // Минимальное время анимации
    } finally {
      _refreshController.stop();
      _refreshController.reset();
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        title: Text(
          'Statistika',
          style: AppTextStyles.appBarTitle,
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Выбранный слот + переключатель
          ActiveSlotBar(onSwitched: _loadData),

          if (_noActiveSlot)
            const Expanded(child: NoActiveSlotView())
          else ...[
            // Табы
            StatisticsTabBar(
              currentType: _currentType,
              onTypeChanged: (type) {
                setState(() {
                  _currentType = type;
                });
              },
            ),

            // Контент
            Expanded(
              child: _buildContent(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentType) {
      case StatisticsPeopleType.statistics:
        return _buildMonitorStatisticsView();
      case StatisticsPeopleType.participant:
        return _buildParticipantsView();
      case StatisticsPeopleType.supervisor:
        return _buildSupervisorsView();
    }
  }

  Widget _buildMonitorStatisticsView() {
    return Column(
      children: [
        Expanded(
          child: Consumer2<ParticipantProvider, SupervisorProvider>(
            builder: (context, participantProvider, supervisorProvider, child) {
              final participantStats = participantProvider.examDetails;
              final supervisorStats = supervisorProvider.supervisorDetails;

              if (participantProvider.isLoading ||
                  supervisorProvider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              }

              return StatisticsComponent(
                allMan: participantStats?.allManCount ?? 0,
                allWoman: participantStats?.allWomanCount ?? 0,
                regMan: participantStats?.regManCount ?? 0,
                regWoman: participantStats?.regWomanCount ?? 0,
                allSupervisors: supervisorStats?.allPersonCount ?? 0,
                registeredSupervisors: supervisorStats?.regPersonCount ?? 0,
              );
            },
          ),
        ),

        // Buttons row: Refresh (local stats) + Manual Sync (send to server)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              // Refresh local stats
              Expanded(
                child: StatisticsRefreshButton(
                  isRefreshing: _isRefreshing,
                  onRefresh: _refreshStatistics,
                  animationController: _refreshController,
                ),
              ),
              const SizedBox(width: 12),
              // Manual sync to server
              Expanded(
                child: _buildSyncButton(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncButton() {
    return ListenableBuilder(
      listenable: SyncService.instance,
      builder: (context, _) {
        final sync = SyncService.instance;
        final pending = sync.pendingTotal;
        final isSyncing = sync.isSyncing;
        final lastSuccess = sync.lastSyncSuccess;

        Color btnColor = AppColors.primary;
        IconData btnIcon = Icons.cloud_upload_outlined;
        String btnLabel = 'Sinxronizasiya';

        if (isSyncing) {
          btnLabel = 'Göndərilir...';
          btnIcon = Icons.sync;
        } else if (pending > 0) {
          btnLabel = 'Göndər ($pending)';
          btnIcon = Icons.cloud_upload_outlined;
          btnColor = Colors.orange.shade700;
        } else if (lastSuccess == true) {
          btnLabel = 'Sinxron edildi';
          btnIcon = Icons.cloud_done_outlined;
          btnColor = Colors.green.shade700;
        } else if (lastSuccess == false) {
          btnLabel = 'Yenidən cəhd et';
          btnIcon = Icons.cloud_off_outlined;
          btnColor = Colors.red.shade700;
        }

        return ElevatedButton.icon(
          onPressed: isSyncing
              ? null
              : () async {
                  await SyncService.instance.syncNow();
                  if (mounted) {
                    // Reload local stats after sync
                    _loadData();
                  }
                },
          icon: isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(btnIcon, size: 16),
          label: Text(
            btnLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticipantsView() {
    return const StatisticsListView(
      key: ValueKey('participants'),
      isParticipants: true,
    );
  }

  Widget _buildSupervisorsView() {
    return const StatisticsListView(
      key: ValueKey('supervisors'),
      isParticipants: false,
    );
  }
}
