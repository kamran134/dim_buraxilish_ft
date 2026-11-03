import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

class AdminSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const AdminSegment({required this.value, required this.label, this.icon});
}

/// Segment switch for the gradient background (e.g. İştirakçılar /
/// Nəzarətçilər / İmtahan rəhbərləri). Labels wrap to two lines instead of
/// overflowing; every segment is at least 48 px high.
class AdminSegmented<T> extends StatelessWidget {
  final List<AdminSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  const AdminSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLG),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final segment in segments)
              Expanded(child: _buildSegment(segment)),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(AdminSegment<T> segment) {
    final isSelected = segment.value == selected;
    final fg = isSelected ? AppColors.primary : Colors.white;
    return Material(
      color: isSelected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMD),
        onTap: () => onChanged(segment.value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.buttonHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Center(
              child: Text(
                segment.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: fg,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
