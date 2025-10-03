import 'package:flutter/material.dart';
import '../../design/app_theme.dart';

/// Переиспользуемая карточка информации с фото, именем и деталями
class InfoCard extends StatelessWidget {
  final String fullName;
  final String? subtitle;
  final Widget? photoWidget;
  final List<InfoDetail> details;
  final Widget? actionButton;
  final bool isRepeatEntry;
  final Color? cardColor;
  final Color? borderColor;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const InfoCard({
    super.key,
    required this.fullName,
    this.subtitle,
    this.photoWidget,
    this.details = const [],
    this.actionButton,
    this.isRepeatEntry = false,
    this.cardColor,
    this.borderColor,
    this.borderRadius = 20,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor ?? Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Repeat entry indicator
          if (isRepeatEntry)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: Text(
                'TƏKRAR GİRİŞ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkRed,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Photo section
          if (photoWidget != null) ...[
            Container(
              width: double.infinity,
              height: 280,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.lightGrey200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isRepeatEntry
                      ? AppColors.darkRed
                      : borderColor ?? Colors.green,
                  width: 3,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: photoWidget,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Name
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.blackText,
            ),
            textAlign: TextAlign.center,
          ),

          // Subtitle (like card number or ID)
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ),
          ],

          // Action button
          if (actionButton != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(flex: 2, child: Container()),
                Expanded(flex: 3, child: actionButton!),
                Expanded(flex: 2, child: Container()),
              ],
            ),
          ],

          // Details grid
          if (details.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildDetailsGrid(),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: _buildDetailRows(),
      ),
    );
  }

  List<Widget> _buildDetailRows() {
    List<Widget> rows = [];

    for (int i = 0; i < details.length; i += 2) {
      List<Widget> rowChildren = [];

      // First item in row
      rowChildren.add(
        Expanded(child: _buildDetailItem(details[i])),
      );

      // Second item in row (if exists)
      if (i + 1 < details.length) {
        rowChildren.add(const SizedBox(width: 16));
        rowChildren.add(
          Expanded(child: _buildDetailItem(details[i + 1])),
        );
      } else {
        // If odd number of items, add empty space
        rowChildren.add(Expanded(child: Container()));
      }

      rows.add(Row(children: rowChildren));

      // Add spacing between rows (except for last row)
      if (i + 2 < details.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return rows;
  }

  Widget _buildDetailItem(InfoDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${detail.label}:',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail.value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Класс для хранения детальной информации
class InfoDetail {
  final String label;
  final String value;

  const InfoDetail({
    required this.label,
    required this.value,
  });
}
