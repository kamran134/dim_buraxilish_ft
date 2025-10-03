import 'package:flutter/material.dart';
import '../../design/app_colors.dart';

/// Элемент нижней навигации
class BottomNavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });
}

/// Переиспользуемая нижняя навигация
class CustomBottomNavigation extends StatelessWidget {
  final List<BottomNavItem> items;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;

  const CustomBottomNavigation({
    super.key,
    required this.items,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.darkGradient2,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) => _buildNavItem(item)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BottomNavItem item) {
    final selectedColor = this.selectedColor ?? Colors.white;
    final unselectedColor = this.unselectedColor ?? Colors.grey[300]!;

    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: item.isSelected
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              color: item.isSelected ? selectedColor : unselectedColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: item.isSelected ? selectedColor : unselectedColor,
                fontSize: 12,
                fontWeight:
                    item.isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
