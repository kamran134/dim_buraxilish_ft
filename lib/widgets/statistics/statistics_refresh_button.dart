import 'package:flutter/material.dart';

/// Кнопка обновления статистики с анимацией
class StatisticsRefreshButton extends StatelessWidget {
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final AnimationController animationController;

  const StatisticsRefreshButton({
    Key? key,
    required this.isRefreshing,
    required this.onRefresh,
    required this.animationController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: isRefreshing ? null : onRefresh,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.9),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          minimumSize: const Size(double.infinity, 60),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRefreshing)
              RotationTransition(
                turns: animationController,
                child: const Icon(Icons.refresh, size: 24),
              )
            else
              const Icon(Icons.refresh, size: 24),
            const SizedBox(width: 8),
            Text(
              'Yenilə',
              style: const TextStyle(
                fontSize: 16, // bodyLarge
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
