import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../screens/exam_select_screen.dart';
import '../session_switcher_sheet.dart';

/// Header strip for statistics screens: the active slot's label
/// ([AuthProvider.activeExamHeaderLabel]) plus the shared slot switcher
/// ([showSessionSwitcherSheet]). Statistics always follow the selected slot —
/// screens have no date picker of their own. [onSwitched] runs after a
/// completed switch so the screen can reload its data.
class ActiveSlotBar extends StatefulWidget {
  final VoidCallback onSwitched;

  /// true on the blue (primary) screen background, false on the regular
  /// light/dark surface.
  final bool onPrimary;

  const ActiveSlotBar({
    super.key,
    required this.onSwitched,
    this.onPrimary = true,
  });

  @override
  State<ActiveSlotBar> createState() => _ActiveSlotBarState();
}

class _ActiveSlotBarState extends State<ActiveSlotBar> {
  bool _switching = false;

  Future<void> _openSwitcher() async {
    setState(() => _switching = true);
    try {
      await showSessionSwitcherSheet(
        context: context,
        onSwitched: widget.onSwitched,
      );
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fg;
    final Color bg;
    if (widget.onPrimary) {
      fg = Colors.white;
      bg = Colors.white.withValues(alpha: 0.15);
    } else {
      fg = isDark ? Colors.white : AppColors.primaryBlue;
      bg = isDark
          ? AppColors.surfaceDark
          : AppColors.primaryBlue.withValues(alpha: 0.1);
    }

    final label = context.watch<AuthProvider>().activeExamHeaderLabel;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: fg.withValues(alpha: 0.8), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label ?? 'İmtahan seçilməyib',
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (label != null)
            IconButton(
              tooltip: 'Slotu dəyiş',
              onPressed: _switching ? null : _openSwitcher,
              icon: _switching
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    )
                  : Icon(Icons.swap_horiz, color: fg),
            ),
        ],
      ),
    );
  }
}

/// Shown by statistics screens when no slot is active: nothing to filter
/// by, so no request is made — the user is sent to the slot picker instead.
class NoActiveSlotView extends StatelessWidget {
  /// true on the blue (primary) screen background.
  final bool onPrimary;

  const NoActiveSlotView({super.key, this.onPrimary = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = onPrimary || isDark ? Colors.white70 : Colors.black54;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 64, color: fg),
            const SizedBox(height: 16),
            Text(
              'İmtahan seçilməyib',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExamSelectScreen()),
                );
              },
              icon: const Icon(Icons.event_available),
              label: const Text('İmtahan seçin'),
              style: onPrimary
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
