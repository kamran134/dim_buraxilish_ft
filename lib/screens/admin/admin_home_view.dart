import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../models/exam_details_dto.dart';
import '../../models/exam_statistics_dto.dart';
import '../../services/statistics_service.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/common/message_display.dart';
import 'admin_sections.dart';

/// Numbers shown on Əsas, derived from the dashboard and combined exam
/// statistics. Pure, so it can be unit-tested.
class AdminHomeSummary {
  static const int lowestCount = 5;

  final int totalParticipants;
  final int registeredParticipants;
  final int unregisteredParticipants;
  final double participantRate;

  final int totalSupervisors;
  final int registeredSupervisors;
  final double supervisorRate;

  final int totalMonitors;
  final int registeredMonitors;
  final double monitorRate;

  /// Buildings with the lowest registration %, worst first.
  final List<ExamDetailsDto> lowestBuildings;

  const AdminHomeSummary({
    required this.totalParticipants,
    required this.registeredParticipants,
    required this.unregisteredParticipants,
    required this.participantRate,
    required this.totalSupervisors,
    required this.registeredSupervisors,
    required this.supervisorRate,
    required this.totalMonitors,
    required this.registeredMonitors,
    required this.monitorRate,
    required this.lowestBuildings,
  });

  factory AdminHomeSummary.from(
    DashboardStatistics stats,
    List<ExamStatisticsDto> examStats,
  ) {
    final totalSupervisors =
        examStats.fold<int>(0, (sum, s) => sum + (s.supervisorCount ?? 0));
    final registeredSupervisors =
        examStats.fold<int>(0, (sum, s) => sum + (s.regSupervisorCount ?? 0));
    // Imtahan rəhbərləri are counted globally: every row carries the same
    // totals, so only the first one is used.
    final totalMonitors =
        examStats.isEmpty ? 0 : (examStats.first.monitorCount ?? 0);
    final registeredMonitors =
        examStats.isEmpty ? 0 : (examStats.first.regMonitorCount ?? 0);

    double rate(int done, int total) => total == 0 ? 0 : done / total * 100;

    final lowest = stats.examDetails
        .where((building) => building.totalParticipants > 0)
        .toList()
      ..sort((a, b) => a.registrationRate.compareTo(b.registrationRate));

    return AdminHomeSummary(
      totalParticipants: stats.totalParticipants,
      registeredParticipants: stats.totalRegistered,
      unregisteredParticipants: stats.totalUnregistered,
      participantRate: stats.registrationRate,
      totalSupervisors: totalSupervisors,
      registeredSupervisors: registeredSupervisors,
      supervisorRate: rate(registeredSupervisors, totalSupervisors),
      totalMonitors: totalMonitors,
      registeredMonitors: registeredMonitors,
      monitorRate: rate(registeredMonitors, totalMonitors),
      lowestBuildings: lowest.take(lowestCount).toList(),
    );
  }
}

/// Əsas — the admin home. Pure view: data and callbacks come from
/// `AdminHomeScreen`.
class AdminHomeView extends StatelessWidget {
  final String userName;
  final String roleLabel;

  /// The exam strip shown in the hero block (`AdminExamBar`).
  final Widget examBar;

  final DashboardStatistics? stats;
  final List<ExamStatisticsDto> examStats;
  final bool loading;
  final String? error;
  final bool noActiveSlot;
  final bool inShell;

  final Future<void> Function() onRefresh;
  final VoidCallback? onRetry;
  final VoidCallback? onSelectExam;
  final VoidCallback? onMenu;
  final ValueChanged<ExamDetailsDto>? onOpenBuilding;
  final ValueChanged<AdminSection>? onOpenSection;

  const AdminHomeView({
    super.key,
    required this.userName,
    required this.roleLabel,
    required this.examBar,
    required this.onRefresh,
    this.stats,
    this.examStats = const [],
    this.loading = false,
    this.error,
    this.noActiveSlot = false,
    this.inShell = true,
    this.onRetry,
    this.onSelectExam,
    this.onMenu,
    this.onOpenBuilding,
    this.onOpenSection,
  });

  @override
  Widget build(BuildContext context) {
    return AdminPage.list(
      title: 'Əsas',
      inShell: inShell,
      onMenu: onMenu,
      onRefresh: onRefresh,
      spacing: AppSpacing.lg,
      children: [
        _buildHero(context),
        ..._buildData(context),
        _buildSections(context),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    return AdminGlassCard(
      padding: AppSpacing.paddingMD,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: AppSpacing.iconXL,
              ),
              AppSpacing.horizontalGapMD,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DİM',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                    ),
                    Text(
                      'Admin panel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.lightGrey200,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMD,
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white70, size: 18),
              AppSpacing.horizontalGapSM,
              Expanded(
                child: Text(
                  '$userName · $roleLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.verticalGapMD,
          examBar,
        ],
      ),
    );
  }

  List<Widget> _buildData(BuildContext context) {
    if (noActiveSlot) {
      return [
        AdminEmptyState(
          icon: Icons.event_busy,
          title: 'İmtahan seçilməyib',
          action: onSelectExam == null
              ? null
              : FilledButton.icon(
                  onPressed: onSelectExam,
                  icon: const Icon(Icons.event_available),
                  label: const Text('İmtahan seçin'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, AppSpacing.buttonHeight),
                  ),
                ),
        ),
      ];
    }

    final data = stats;
    if (data == null) {
      if (error != null && !loading) {
        return [AdminErrorState(message: error!, onRetry: onRetry)];
      }
      return [const AdminLoading()];
    }

    final summary = AdminHomeSummary.from(data, examStats);
    return [
      if (error != null)
        MessageDisplay(
          message: error!,
          type: MessageType.error,
          margin: EdgeInsets.zero,
        ),
      _group('İştirakçılar', [
        AdminStatTile(
          value: '${summary.totalParticipants}',
          label: 'Ümumi iştirakçı',
          icon: Icons.school,
        ),
        AdminStatTile(
          value: '${summary.registeredParticipants}',
          label: 'Qeydiyyatdan keçən',
          icon: Icons.check_circle,
          color: AppColors.success,
        ),
        AdminStatTile(
          value: '${summary.unregisteredParticipants}',
          label: 'Qeydiyyatdan keçməyən',
          icon: Icons.cancel,
          color: AppColors.error,
        ),
        AdminStatTile(
          value: '${summary.participantRate.toStringAsFixed(1)}%',
          label: 'Qeydiyyat faizi',
          icon: Icons.percent,
          color: AdminProgressRow.colorForRate(summary.participantRate),
        ),
      ]),
      _group('Nəzarətçilər', [
        AdminStatTile(
          value: '${summary.totalSupervisors}',
          label: 'Ümumi nəzarətçi',
          icon: Icons.supervisor_account,
        ),
        AdminStatTile(
          value: '${summary.registeredSupervisors}',
          label: 'Qeydiyyatdan keçən',
          icon: Icons.check_circle,
          color: AppColors.success,
          percent: summary.supervisorRate,
        ),
      ]),
      _group('İmtahan rəhbərləri', [
        AdminStatTile(
          value: '${summary.totalMonitors}',
          label: 'Ümumi imtahan rəhbəri',
          icon: Icons.badge,
        ),
        AdminStatTile(
          value: '${summary.registeredMonitors}',
          label: 'Qeydiyyatdan keçən',
          icon: Icons.check_circle,
          color: AppColors.success,
          percent: summary.monitorRate,
        ),
      ]),
      _buildLowest(summary),
    ];
  }

  Widget _group(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title),
        AppSpacing.verticalGapSM,
        AdminGrid.tiles(children: tiles),
      ],
    );
  }

  Widget _buildLowest(AdminHomeSummary summary) {
    return AdminCard(
      title: 'Ən aşağı qeydiyyat',
      child: summary.lowestBuildings.isEmpty
          ? Builder(
              builder: (context) => Text(
                'Məlumat yoxdur',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AdminStyle.textSecondary(context),
                ),
              ),
            )
          : Column(
              children: [
                for (final building in summary.lowestBuildings)
                  AdminProgressRow(
                    label: _buildingLabel(building),
                    done: building.totalRegistered,
                    total: building.totalParticipants,
                    onTap: onOpenBuilding == null
                        ? null
                        : () => onOpenBuilding!(building),
                  ),
              ],
            ),
    );
  }

  static String _buildingLabel(ExamDetailsDto building) {
    final code = building.buildingCode ?? '';
    final name = building.buildingName ?? '';
    if (name.isEmpty) return 'Bina $code';
    return code.isEmpty ? name : 'Bina $code · $name';
  }

  Widget _buildSections(BuildContext context) {
    final sections = adminSections.where((section) => !section.isHome);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Bölmələr'),
        AppSpacing.verticalGapSM,
        AdminGrid.tiles(
          children: [
            for (final section in sections)
              AdminMenuTile(
                title: section.tileTitle,
                icon: section.icon,
                gradient: section.gradient,
                onTap: onOpenSection == null
                    ? null
                    : () => onOpenSection!(section),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.h5.copyWith(color: Colors.white),
    );
  }
}
