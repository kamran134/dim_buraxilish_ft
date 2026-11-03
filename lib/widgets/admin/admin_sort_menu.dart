import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

class AdminSortOption<T> {
  final T value;
  final String label;

  const AdminSortOption({required this.value, required this.label});
}

/// Sort picker (by code, name, registration %): a menu button for the
/// header. Picking another option selects it ascending; picking the current
/// one flips the direction. [onChanged] receives the new key and direction.
class AdminSortMenu<T> extends StatelessWidget {
  final List<AdminSortOption<T>> options;
  final T selected;
  final bool ascending;
  final void Function(T value, bool ascending) onChanged;

  const AdminSortMenu({
    super.key,
    required this.options,
    required this.selected,
    required this.ascending,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: 'Sıralama',
      icon: const Icon(Icons.sort, color: Colors.white),
      onSelected: (value) =>
          onChanged(value, value == selected ? !ascending : true),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<T>(
            value: option.value,
            child: Row(
              children: [
                SizedBox(
                  width: AppSpacing.iconMD,
                  child: option.value == selected
                      ? Icon(
                          ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: AppSpacing.iconSM,
                        )
                      : null,
                ),
                AppSpacing.horizontalGapSM,
                Flexible(
                  child: Text(
                    option.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
