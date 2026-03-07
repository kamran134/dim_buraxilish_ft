import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/supervisor_models.dart';
import '../../design/app_colors.dart';
import '../../design/app_text_styles.dart';

/// Карточка супервизора для отображения в списке статистики
class SupervisorCard extends StatelessWidget {
  final Supervisor supervisor;
  final bool isRegistered;

  const SupervisorCard({
    Key? key,
    required this.supervisor,
    this.isRegistered = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isRegistered ? AppColors.materialGreen : Colors.red.shade400;
    final bgColor = isRegistered
        ? Colors.green.withOpacity(0.07)
        : Colors.red.withOpacity(0.07);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: supervisor.image.isNotEmpty &&
                              supervisor.image != 'null'
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: Image.memory(
                                base64Decode(supervisor.image),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.supervisor_account,
                                    color: Colors.white,
                                    size: 24,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.supervisor_account,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Name block
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${supervisor.lastName} ${supervisor.firstName}',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (supervisor.fatherName.isNotEmpty)
                            Text(
                              supervisor.fatherName,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28), // space for corner badge
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.credit_card,
                  'Kart nömrəsi',
                  supervisor.cardNumber,
                ),
                _buildInfoRow(
                  Icons.access_time,
                  'Qeydiyyat vaxtı',
                  _formatDate(supervisor.registerDate),
                ),
                _buildInfoRow(
                  Icons.business,
                  'Bina kodu',
                  supervisor.buildingCode.toString(),
                ),
              ],
            ),
          ),
          // Corner status badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: borderColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRegistered ? Icons.check : Icons.close,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty || dateStr == 'null') {
      return 'Məlum deyil';
    }
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
