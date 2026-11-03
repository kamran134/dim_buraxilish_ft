import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../models/monitor_models.dart';
import '../../../widgets/admin/admin_widgets.dart';

/// Search of imtahan rəhbərləri by name: the search field pinned under the
/// header, results as cards with the work number, room, building and phones.
/// Pure view — the loader owns the query, the debounce is in
/// [AdminSearchField].
class AdminMonitorSearchView extends StatelessWidget {
  /// Trimmed query currently searched; shorter than [minQueryLength] shows
  /// the hint instead of results.
  final String query;
  final List<Monitor> results;
  final bool loading;
  final String? message;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCopyWorkNumber;
  final ValueChanged<String> onCall;

  static const int minQueryLength = 2;

  const AdminMonitorSearchView({
    super.key,
    required this.query,
    required this.results,
    this.loading = false,
    this.message,
    required this.onQueryChanged,
    required this.onCopyWorkNumber,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final header = AdminSearchField(
      hint: 'Ad, soyad və ya ata adı',
      autofocus: true,
      onChanged: onQueryChanged,
    );

    if (loading) {
      return AdminPage(
        title: 'İmtahan rəhbəri axtar',
        headerBottom: header,
        body: const AdminLoading(message: null),
      );
    }

    if (query.length < minQueryLength) {
      return AdminPage(
        title: 'İmtahan rəhbəri axtar',
        headerBottom: header,
        body: const AdminEmptyState(
          icon: Icons.person_search,
          title: 'Axtarmaq üçün ən az 2 simvol daxil edin',
        ),
      );
    }

    if (message != null && results.isEmpty) {
      return AdminPage(
        title: 'İmtahan rəhbəri axtar',
        headerBottom: header,
        body: AdminEmptyState(icon: Icons.search_off, title: message!),
      );
    }

    return AdminPage.builder(
      title: 'İmtahan rəhbəri axtar',
      headerBottom: header,
      itemCount: results.length,
      itemBuilder: (context, index) => _ResultCard(
        monitor: results[index],
        onCopyWorkNumber: onCopyWorkNumber,
        onCall: onCall,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Monitor monitor;
  final ValueChanged<String> onCopyWorkNumber;
  final ValueChanged<String> onCall;

  const _ResultCard({
    required this.monitor,
    required this.onCopyWorkNumber,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AdminStyle.accent(context);
    final secondary = AdminStyle.textSecondary(context);
    final phones = splitAdminPhones(monitor.phone);
    final name =
        '${monitor.lastName} ${monitor.firstName} ${monitor.middleName}'.trim();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name.isEmpty ? '—' : name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AdminStyle.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          AppSpacing.verticalGapSM,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + AppSpacing.xs,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSM),
                ),
                child: Text(
                  'İş № ${monitor.workNumber}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => onCopyWorkNumber(monitor.workNumber.toString()),
                icon: Icon(Icons.copy, size: 16, color: accent),
                label: Text(
                  'Kopyala',
                  style: AppTextStyles.bodySmall.copyWith(color: accent),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
              ),
            ],
          ),
          if (monitor.roomName.isNotEmpty)
            _InfoLine(
              icon: Icons.meeting_room,
              text: monitor.roomName,
              color: secondary,
            ),
          if (monitor.buildingName.isNotEmpty)
            _InfoLine(
              icon: Icons.business,
              text: monitor.buildingName,
              color: secondary,
            ),
          if (phones.isNotEmpty) ...[
            AppSpacing.verticalGapSM,
            Divider(height: 1, color: AdminStyle.divider(context)),
            AppSpacing.verticalGapSM,
            AdminPhoneChips(phones: phones, onCall: onCall),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          AppSpacing.horizontalGapXS,
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
