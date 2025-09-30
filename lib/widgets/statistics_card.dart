import 'package:flutter/material.dart';

class StatisticsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color backgroundColor;
  final List<StatisticItem> items;
  final Widget? child;

  const StatisticsCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.backgroundColor,
    this.items = const [],
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок карточки
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white30,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Содержимое карточки
            if (child != null)
              child!
            else
              ...items.map((item) => _StatisticItemWidget(item: item)),
          ],
        ),
      ),
    );
  }
}

class StatisticItem {
  final IconData icon;
  final String label;
  final int value;
  final Color? color;
  final List<StatisticItem>? subItems;

  const StatisticItem({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.subItems,
  });
}

class _StatisticItemWidget extends StatelessWidget {
  final StatisticItem item;
  final bool isSubItem;

  const _StatisticItemWidget({
    Key? key,
    required this.item,
    this.isSubItem = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: 8,
            horizontal: isSubItem ? 32 : 0,
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: item.color ?? Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: item.color ?? Colors.white,
                  ),
                ),
              ),
              Text(
                item.value.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: item.color ?? Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Подэлементы
        if (item.subItems != null && item.subItems!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 32, top: 8),
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Colors.white30,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: item.subItems!
                  .map((subItem) => _StatisticItemWidget(
                        item: subItem.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                        isSubItem: true,
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

extension StatisticItemExtension on StatisticItem {
  StatisticItem copyWith({
    IconData? icon,
    String? label,
    int? value,
    Color? color,
    List<StatisticItem>? subItems,
  }) {
    return StatisticItem(
      icon: icon ?? this.icon,
      label: label ?? this.label,
      value: value ?? this.value,
      color: color ?? this.color,
      subItems: subItems ?? this.subItems,
    );
  }
}
