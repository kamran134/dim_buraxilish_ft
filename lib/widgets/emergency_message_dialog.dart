import 'package:flutter/material.dart';

class EmergencyMessageDialog extends StatelessWidget {
  final String title;
  final String body;
  final int importance;
  final VoidCallback? onAcknowledge;

  const EmergencyMessageDialog({
    super.key,
    required this.title,
    required this.body,
    required this.importance,
    this.onAcknowledge,
  });

  Color get _accentColor {
    switch (importance) {
      case 2:
        return const Color(0xFFD32F2F);
      case 1:
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFF1565C0);
    }
  }

  Color get _bgColor {
    switch (importance) {
      case 2:
        return const Color(0xFFFFEBEE);
      case 1:
        return const Color(0xFFFFF8E1);
      default:
        return const Color(0xFFE3F2FD);
    }
  }

  IconData get _icon {
    switch (importance) {
      case 2:
        return Icons.campaign_rounded;
      case 1:
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String get _badge {
    switch (importance) {
      case 2:
        return 'TƏCİLİ ELAN';
      case 1:
        return 'XƏBƏRDARLIQ';
      default:
        return 'MƏLUMAT';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              color: _accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(_icon, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    _badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Container(
              color: _bgColor,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF212121),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        onAcknowledge?.call();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Bağla',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
