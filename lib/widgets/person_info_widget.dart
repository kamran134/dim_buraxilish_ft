import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:convert';

/// Базовый виджет для отображения информации о человеке (участник или нəzarətçi)
/// Переиспользуется между ParticipantScreen и SupervisorScreen
class PersonInfoWidget extends StatelessWidget {
  final String? fullName;
  final String? cardNumber;
  final String? photoBase64;
  final String? message;
  final bool isRepeatEntry;
  final String nextButtonText;
  final VoidCallback onNextPressed;
  final List<PersonDetailRow>? additionalDetails;

  const PersonInfoWidget({
    Key? key,
    this.fullName,
    this.cardNumber,
    this.photoBase64,
    this.message,
    this.isRepeatEntry = false,
    this.nextButtonText = 'Növbəti',
    required this.onNextPressed,
    this.additionalDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status message (for repeat entries, errors, etc.)
          if (message != null && message!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRepeatEntry
                    ? Colors.red.withOpacity(0.1)
                    : colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: isRepeatEntry
                    ? Border.all(color: Colors.red, width: 2)
                    : null,
              ),
              child: Text(
                message!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isRepeatEntry ? Colors.red : colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Photo
          if (photoBase64 != null && photoBase64!.isNotEmpty)
            Container(
              width: 280,
              height: 280,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isRepeatEntry ? Colors.red : colorScheme.primary,
                  width: isRepeatEntry ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildPhoto(),
              ),
            ),

          // Full name
          if (fullName != null && fullName!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                fullName!,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Card number
          if (cardNumber != null && cardNumber!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.credit_card,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Vəsiqə nömrəsi: ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    cardNumber!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

          // Additional details (if provided)
          if (additionalDetails != null && additionalDetails!.isNotEmpty)
            ...additionalDetails!.map((detail) => _buildDetailRow(
                  context: context,
                  label: detail.label,
                  value: detail.value,
                  icon: detail.icon,
                )),

          // Next button
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onNextPressed,
              icon: const Icon(Icons.arrow_forward),
              label: Text(
                nextButtonText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    if (photoBase64 == null || photoBase64!.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(
          Icons.person,
          size: 80,
          color: Colors.grey,
        ),
      );
    }

    try {
      // Handle both with and without data URI prefix
      String base64String = photoBase64!;
      if (base64String.startsWith('data:')) {
        base64String = base64String.split(',')[1];
      }

      final Uint8List bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Icon(
              Icons.broken_image,
              size: 80,
              color: Colors.grey,
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(
          Icons.broken_image,
          size: 80,
          color: Colors.grey,
        ),
      );
    }
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required String label,
    required String value,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
          ],
          Text(
            '$label: ',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Класс для дополнительных деталей информации о человеке
class PersonDetailRow {
  final String label;
  final String value;
  final IconData? icon;

  const PersonDetailRow({
    required this.label,
    required this.value,
    this.icon,
  });
}
