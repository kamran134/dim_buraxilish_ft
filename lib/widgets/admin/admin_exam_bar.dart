import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../screens/exam_select_screen.dart';
import '../session_switcher_sheet.dart';

/// Active-exam strip: the slot label, a swap button (opens the session
/// switcher) and a "Dəyiş" link (back to the exam picker). Glass style, for
/// the gradient background.
///
/// This widget is pure — it only renders what it is given. Use
/// [AdminExamBar.connected] to get the version wired to [AuthProvider] and
/// the shared switcher flow.
class AdminExamBar extends StatelessWidget {
  final String? label;
  final bool switching;

  /// Null hides the swap button.
  final VoidCallback? onSwitch;

  /// Null hides the "Dəyiş" link.
  final VoidCallback? onChange;

  const AdminExamBar({
    super.key,
    required this.label,
    this.switching = false,
    this.onSwitch,
    this.onChange,
  });

  /// Reads [AuthProvider.activeExamHeaderLabel] and drives the shared
  /// [showSessionSwitcherSheet] flow; [onSwitched] runs after a completed
  /// switch so the screen can reload its data.
  static Widget connected({Key? key, VoidCallback? onSwitched}) =>
      _ConnectedAdminExamBar(key: key, onSwitched: onSwitched);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.buttonHeight),
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLG),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Colors.white70, size: 20),
          AppSpacing.horizontalGapSM,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                label ?? 'İmtahan seçilməyib',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (onSwitch != null)
            IconButton(
              tooltip: 'Seansı dəyiş',
              onPressed: switching ? null : onSwitch,
              icon: switching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.swap_horiz, color: Colors.white),
            ),
          if (onChange != null)
            TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(48, AppSpacing.buttonHeight),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text(
                'Dəyiş',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            AppSpacing.horizontalGapSM,
        ],
      ),
    );
  }
}

class _ConnectedAdminExamBar extends StatefulWidget {
  final VoidCallback? onSwitched;

  const _ConnectedAdminExamBar({super.key, this.onSwitched});

  @override
  State<_ConnectedAdminExamBar> createState() => _ConnectedAdminExamBarState();
}

class _ConnectedAdminExamBarState extends State<_ConnectedAdminExamBar> {
  // Set while a session switch (sync + clear + re-download) is running, so
  // the sheet can't be reopened mid-flight.
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
    final auth = context.watch<AuthProvider>();
    return AdminExamBar(
      label: auth.activeExamHeaderLabel,
      switching: _switching,
      onSwitch: auth.hasActiveExam ? _openSwitcher : null,
      onChange: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ExamSelectScreen()),
        );
      },
    );
  }
}
