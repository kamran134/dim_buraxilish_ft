import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../common/message_display.dart';

// White at 90 % — body text on the gradient.
final Color _white90 = Colors.white.withValues(alpha: 0.9);

/// Centres [child] in a bounded area (scrolling if it does not fit) and just
/// pads it when the parent is unbounded, e.g. a child of a `ListView`.
class _CenteredState extends StatelessWidget {
  final Widget child;

  const _CenteredState({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padded = Padding(padding: AppSpacing.paddingLG, child: child);
        if (!constraints.hasBoundedHeight) return Center(child: padded);
        return Center(child: SingleChildScrollView(child: padded));
      },
    );
  }
}

/// Loading indicator on the gradient: white spinner and optional caption.
class AdminLoading extends StatelessWidget {
  final String? message;

  const AdminLoading({super.key, this.message = 'Məlumatlar yüklənir...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLG,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            if (message != null) ...[
              AppSpacing.verticalGapMD,
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: _white90),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty list / nothing to show: large white icon, title and hint.
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const AdminEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 80, color: Colors.white70),
          AppSpacing.verticalGapMD,
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h5.copyWith(color: _white90),
          ),
          if (message != null) ...[
            AppSpacing.verticalGapSM,
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
            ),
          ],
          if (action != null) ...[AppSpacing.verticalGapLG, action!],
        ],
      ),
    );
  }
}

/// Error with a "Yenidən cəhd et" button ([onRetry] hides it when null).
class AdminErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AdminErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.white70),
          AppSpacing.verticalGapMD,
          MessageDisplay(
            message: message,
            type: MessageType.error,
            margin: EdgeInsets.zero,
          ),
          if (onRetry != null) ...[
            AppSpacing.verticalGapLG,
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yenidən cəhd et'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                minimumSize: const Size(0, AppSpacing.buttonHeight),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
