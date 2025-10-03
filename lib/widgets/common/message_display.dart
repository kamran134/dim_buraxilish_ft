import 'package:flutter/material.dart';
import '../../design/app_theme.dart';

/// Переиспользуемый виджет отображения сообщений (успех/ошибка)
class MessageDisplay extends StatelessWidget {
  final String message;
  final MessageType type;
  final IconData? customIcon;
  final Color? customColor;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final VoidCallback? onDismiss;

  const MessageDisplay({
    super.key,
    required this.message,
    this.type = MessageType.info,
    this.customIcon,
    this.customColor,
    this.margin,
    this.padding,
    this.borderRadius = 12,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getMessageConfig();

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 20),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (customColor ?? config.color).withOpacity(0.9),
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
      ),
      child: Row(
        children: [
          Icon(
            customIcon ?? config.icon,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  _MessageConfig _getMessageConfig() {
    switch (type) {
      case MessageType.success:
        return _MessageConfig(
          color: Colors.green,
          icon: Icons.check_circle,
        );
      case MessageType.error:
        return _MessageConfig(
          color: AppColors.errorRed,
          icon: Icons.error_outline,
        );
      case MessageType.warning:
        return _MessageConfig(
          color: Colors.orange,
          icon: Icons.warning_outlined,
        );
      case MessageType.info:
      default:
        return _MessageConfig(
          color: Colors.blue,
          icon: Icons.info_outline,
        );
    }
  }
}

/// Тип сообщения
enum MessageType {
  success,
  error,
  warning,
  info,
}

/// Конфигурация для типа сообщения
class _MessageConfig {
  final Color color;
  final IconData icon;

  _MessageConfig({
    required this.color,
    required this.icon,
  });
}
