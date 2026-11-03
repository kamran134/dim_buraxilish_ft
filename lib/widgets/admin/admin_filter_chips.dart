import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

class AdminFilterOption<T> {
  final T value;
  final String label;

  const AdminFilterOption({required this.value, required this.label});
}

/// Wrapping row of filter pills for the gradient background (all / online /
/// offline …). The selected pill is white; each pill has a 48 dp tap target.
class AdminFilterChips<T> extends StatelessWidget {
  final List<AdminFilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const AdminFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final option in options) _buildChip(option),
      ],
    );
  }

  Widget _buildChip(AdminFilterOption<T> option) {
    final isSelected = option.value == selected;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXL),
        onTap: () => onChanged(option.value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXL),
              ),
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: isSelected ? AppColors.primary : Colors.white,
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
