import 'package:flutter/material.dart';
import '../../design/app_colors.dart';

/// Статистический элемент с иконкой
class StatItem {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

/// Переиспользуемая карточка статистики
class StatisticsCard extends StatelessWidget {
  final String title;
  final List<StatItem> items;
  final Color? backgroundColor;
  final Color? titleColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;

  const StatisticsCard({
    super.key,
    required this.title,
    required this.items,
    this.backgroundColor,
    this.titleColor,
    this.padding,
    this.margin,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor ?? Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: _buildStatItems(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatItems() {
    List<Widget> widgets = [];

    for (int i = 0; i < items.length; i++) {
      widgets.add(
        Expanded(child: _buildStatItem(items[i])),
      );

      // Add divider between items (except for last item)
      if (i < items.length - 1) {
        widgets.add(
          Container(
            width: 1,
            height: 60,
            color: AppColors.white30,
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildStatItem(StatItem item) {
    return Column(
      children: [
        Icon(item.icon, color: item.color, size: 24),
        const SizedBox(height: 8),
        Text(
          item.label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.value,
          style: TextStyle(
            color: item.color,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
