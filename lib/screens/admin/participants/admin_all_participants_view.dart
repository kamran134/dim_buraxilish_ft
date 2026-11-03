import 'package:flutter/material.dart';

import '../../../design/app_theme.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/common/message_display.dart';
import '../statistics/admin_person_rows.dart';
import '../statistics/admin_person_tile.dart';

/// Bütün iştirakçılar: server-side search (the field debounces) and an
/// endless list — [onLoadMore] fires when the last loaded row scrolls into
/// view. Pure view; the loader owns the pages.
class AdminAllParticipantsView extends StatelessWidget {
  final String? subtitle;

  /// Loaded rows; null until the first page arrived.
  final List<AdminPersonRow>? rows;

  /// Rows the server holds for the current query.
  final int totalCount;

  /// The trimmed query the rows belong to (empty = no search).
  final String query;

  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  /// Failure of the last "load more": shown at the list end with a retry.
  final String? moreError;

  /// false when no exam is selected.
  final bool hasExam;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final VoidCallback? onRetry;
  final ValueChanged<AdminPersonRow>? onOpenPerson;

  const AdminAllParticipantsView({
    super.key,
    this.subtitle,
    this.rows,
    this.totalCount = 0,
    this.query = '',
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
    this.moreError,
    this.hasExam = true,
    required this.onQueryChanged,
    required this.onLoadMore,
    required this.onRefresh,
    this.onRetry,
    this.onOpenPerson,
  });

  static const String _title = 'Bütün iştirakçılar';

  @override
  Widget build(BuildContext context) {
    if (!hasExam) {
      return const AdminPage(
        title: _title,
        body: AdminEmptyState(
          icon: Icons.event_busy,
          title: 'İmtahan seçilməyib',
          message: 'İştirakçıları görmək üçün imtahan seçin',
        ),
      );
    }

    final header = AdminSearchField(
      hint: 'Soyadı, adı, ata adı və ya iş nömrəsi',
      onChanged: onQueryChanged,
    );

    final loaded = rows;
    if (loaded == null) {
      return AdminPage(
        title: _title,
        subtitle: subtitle,
        headerBottom: header,
        onRefresh: onRefresh,
        body: error != null && !loading
            ? AdminErrorState(message: error!, onRetry: onRetry)
            : const AdminLoading(),
      );
    }

    if (loaded.isEmpty) {
      return AdminPage(
        title: _title,
        subtitle: subtitle,
        headerBottom: header,
        onRefresh: onRefresh,
        body: loading
            ? const AdminLoading()
            : AdminEmptyState(
                icon: query.isEmpty ? Icons.inbox_outlined : Icons.search_off,
                title: query.isEmpty
                    ? 'Bu imtahanda iştirakçı tapılmadı'
                    : 'Axtarışa uyğun nəticə tapılmadı',
                message: query.isEmpty ? null : 'Başqa axtarış termini cəhd edin',
              ),
      );
    }

    // 0: counter, 1..n: rows, last: loading / retry footer.
    final hasFooter = hasMore || moreError != null;
    return AdminPage.builder(
      title: _title,
      subtitle: subtitle,
      headerBottom: header,
      onRefresh: onRefresh,
      itemCount: 1 + loaded.length + (hasFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _Counter(total: totalCount, query: query, error: error);
        }
        final rowIndex = index - 1;
        if (rowIndex >= loaded.length) {
          return _Footer(
            error: moreError,
            loading: loadingMore,
            onLoadMore: onLoadMore,
          );
        }
        final row = loaded[rowIndex];
        return AdminPersonTile(
          row: row,
          onTap: onOpenPerson == null ? null : () => onOpenPerson!(row),
        );
      },
    );
  }
}

class _Counter extends StatelessWidget {
  final int total;
  final String query;
  final String? error;

  const _Counter({required this.total, required this.query, this.error});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null) ...[
          MessageDisplay(
            message: error!,
            type: MessageType.error,
            margin: EdgeInsets.zero,
          ),
          AppSpacing.verticalGapSM,
        ],
        Text(
          query.isEmpty ? 'Cəmi: $total iştirakçı' : '$total nəticə · "$query"',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// End of the list: a spinner while the next page loads (and the trigger that
/// requests it once built), or the error with a retry.
class _Footer extends StatefulWidget {
  final String? error;
  final bool loading;
  final VoidCallback onLoadMore;

  const _Footer({
    required this.error,
    required this.loading,
    required this.onLoadMore,
  });

  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  @override
  void initState() {
    super.initState();
    _requestIfIdle();
  }

  void _requestIfIdle() {
    if (widget.error != null || widget.loading) return;
    // After the frame: the loader calls setState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.error == null && !widget.loading) {
        widget.onLoadMore();
      }
    });
  }

  @override
  void didUpdateWidget(_Footer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A finished page that left the footer on screen (short pages): ask on.
    if (oldWidget.loading && !widget.loading) _requestIfIdle();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.error != null) {
      return Column(
        children: [
          _MessageText(widget.error!),
          AppSpacing.verticalGapSM,
          AdminActionButton(
            label: 'Yenidən cəhd et',
            icon: Icons.refresh,
            style: AdminActionStyle.glass,
            onPressed: widget.onLoadMore,
          ),
        ],
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

/// White text line for status messages on the gradient.
class _MessageText extends StatelessWidget {
  final String text;

  const _MessageText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
    );
  }
}
