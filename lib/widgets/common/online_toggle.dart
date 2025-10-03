import 'package:flutter/material.dart';

/// Переиспользуемый переключатель онлайн/офлайн режима
class OnlineToggle extends StatelessWidget {
  final bool isOnlineMode;
  final VoidCallback onToggle;
  final String onlineText;
  final String offlineText;
  final String onlineDescription;
  final String offlineDescription;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;

  const OnlineToggle({
    super.key,
    required this.isOnlineMode,
    required this.onToggle,
    this.onlineText = 'Online rejim',
    this.offlineText = 'Oflayn rejim',
    this.onlineDescription = 'İnternet bağlantısı aktivdir',
    this.offlineDescription = 'Lokal bazadan istifadə edilir',
    this.backgroundColor,
    this.padding,
    this.margin,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        margin: margin,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(borderRadius ?? 12),
        ),
        child: Row(
          children: [
            Icon(
              isOnlineMode ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnlineMode ? onlineText : offlineText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isOnlineMode ? onlineDescription : offlineDescription,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isOnlineMode,
              onChanged: (_) => onToggle(),
              activeColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}
