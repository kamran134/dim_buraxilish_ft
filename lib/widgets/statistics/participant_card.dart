import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/participant_models.dart';
import '../../design/app_colors.dart';

/// Карточка участника для отображения в списке статистики
class ParticipantCard extends StatelessWidget {
  final Participant participant;

  const ParticipantCard({
    Key? key,
    required this.participant,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: participant.photo != null &&
                        participant.photo!.isNotEmpty &&
                        participant.photo != 'null'
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Image.memory(
                          const Base64Decoder().convert(participant.photo!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${participant.soy} ${participant.adi}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16, // bodyLarge
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (participant.baba.isNotEmpty)
                      Text(
                        participant.baba,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14, // bodyMedium
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Qeydiyyatlı',
                  style: TextStyle(
                    color: AppColors.successGreen,
                    fontSize: 12, // bodySmall
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.badge,
            'İş nömrəsi',
            participant.isN.toString(),
          ),
          _buildInfoRow(
            Icons.access_time,
            'Qeydiyyat vaxtı',
            _formatDate(participant.qeydiyyat),
          ),
          _buildInfoRow(
            Icons.location_on,
            'Yer',
            '${participant.bina} - ${participant.zal} - ${participant.mertebe} - ${participant.sira} - ${participant.yer}',
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
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'null') {
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
