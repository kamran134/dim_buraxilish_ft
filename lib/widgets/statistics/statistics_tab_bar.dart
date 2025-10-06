import 'package:flutter/material.dart';
import '../../constants/statistics_type.dart';
import '../../design/app_colors.dart';

/// Компонент для табов статистики
class StatisticsTabBar extends StatelessWidget {
  final StatisticsPeopleType currentType;
  final Function(StatisticsPeopleType) onTypeChanged;
  final bool isAdmin;

  const StatisticsTabBar({
    Key? key,
    required this.currentType,
    required this.onTypeChanged,
    this.isAdmin = false,
  }) : super(key: key);

  /// Получает доступные типы табов в зависимости от роли пользователя
  List<StatisticsPeopleType> _getAvailableTypes() {
    return StatisticsPeopleType.values;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: _getAvailableTypes()
              .map((type) => _buildTabButton(type))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTabButton(StatisticsPeopleType type) {
    final isActive = currentType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTypeChanged(type),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryBlue.withOpacity(0.8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                type.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      isActive ? Colors.white : Colors.white.withOpacity(0.8),
                  fontSize: isActive ? 15 : 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              if (isActive)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
