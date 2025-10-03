import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ExamDateDropdown extends StatelessWidget {
  final String? selectedDate;
  final ValueChanged<String?> onChanged;
  final bool forceLight; // Принудительное использование светлой темы

  const ExamDateDropdown({
    Key? key,
    required this.selectedDate,
    required this.onChanged,
    this.forceLight = false, // По умолчанию адаптируется к теме
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final examDates = authProvider.examDates;

        if (examDates.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  forceLight || Theme.of(context).brightness == Brightness.light
                      ? Colors.grey[50]
                      : Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: forceLight ||
                          Theme.of(context).brightness == Brightness.light
                      ? Colors.grey[300]!
                      : Colors.grey[600]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: forceLight ||
                          Theme.of(context).brightness == Brightness.light
                      ? Colors.grey[600]
                      : Colors.grey[400],
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'İmtahan tarixləri yüklənir...',
                    style: TextStyle(
                      color: forceLight ||
                              Theme.of(context).brightness == Brightness.light
                          ? Colors.grey[600]
                          : Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ),
                if (authProvider.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          );
        }

        return DropdownButtonFormField<String>(
          value: selectedDate,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'İmtahan tarixini seçin',
            hintStyle: TextStyle(
              color:
                  forceLight || Theme.of(context).brightness == Brightness.light
                      ? Colors.grey[600]
                      : Colors.grey[400],
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.calendar_today_outlined,
              color:
                  forceLight || Theme.of(context).brightness == Brightness.light
                      ? Colors.grey[600]
                      : Colors.grey[400],
              size: 22,
            ),
            filled: true,
            fillColor:
                forceLight || Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[50]
                    : Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: forceLight ||
                        Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[300]!
                    : Colors.grey[600]!,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: forceLight ||
                        Theme.of(context).brightness == Brightness.light
                    ? Colors.grey[300]!
                    : Colors.grey[600]!,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.deepBlue,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          items: examDates.map((date) {
            return DropdownMenuItem<String>(
              value: date,
              child: Text(
                date,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: forceLight ||
                          Theme.of(context).brightness == Brightness.light
                      ? Colors.black87
                      : Colors.white,
                ),
              ),
            );
          }).toList(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'İmtahan tarixi seçilməlidir';
            }
            return null;
          },
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey,
          ),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: forceLight ||
                    Theme.of(context).brightness == Brightness.light
                ? Colors
                    .black87 // Тёмный цвет текста для светлой темы/принудительно
                : Colors.white, // Светлый цвет текста для темной темы
          ),
          isExpanded: true,
        );
      },
    );
  }
}
