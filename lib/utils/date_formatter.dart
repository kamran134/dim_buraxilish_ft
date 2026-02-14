import 'package:flutter/foundation.dart';

/// Utility functions for date formatting
class DateFormatter {
  /// Convert Azerbaijani date format to MM/dd/yyyy format
  /// Example: "29 sentyabr 2025-ci il" -> "09/29/2025"
  static String dateToAzToDate(String azDate) {
    try {
      final parts = azDate.split(' ');
      if (parts.length < 3) {
        return azDate; // Return original if format is unexpected
      }

      final day = parts[0].padLeft(2, '0'); // Add leading zero if needed
      final monthName = parts[1];
      final yearPart = parts[2].substring(0, 4); // Extract year from "2025-ci"

      String month;
      switch (monthName) {
        case 'yanvar':
          month = '01';
          break;
        case 'fevral':
          month = '02';
          break;
        case 'mart':
          month = '03';
          break;
        case 'aprel':
          month = '04';
          break;
        case 'may':
          month = '05';
          break;
        case 'iyun':
          month = '06';
          break;
        case 'iyul':
          month = '07';
          break;
        case 'avqust':
          month = '08';
          break;
        case 'sentyabr':
          month = '09';
          break;
        case 'oktyabr':
          month = '10';
          break;
        case 'noyabr':
          month = '11';
          break;
        case 'dekabr':
          month = '12';
          break;
        default:
          month = '01';
      }

      return '$month/$day/$yearPart';
    } catch (e) {
      // If any error occurs, return original date
      return azDate;
    }
  }

  /// Convert MM/dd/yyyy back to Azerbaijani format
  /// Example: "09/29/2025" -> "29 sentyabr 2025-ci il"
  static String dateFromAzToDate(String usDate) {
    try {
      final parts = usDate.split('/');
      if (parts.length != 3) {
        return usDate; // Return original if format is unexpected
      }

      final month = parts[0];
      final day = parts[1];
      final year = parts[2];

      String monthName;
      switch (month) {
        case '01':
          monthName = 'yanvar';
          break;
        case '02':
          monthName = 'fevral';
          break;
        case '03':
          monthName = 'mart';
          break;
        case '04':
          monthName = 'aprel';
          break;
        case '05':
          monthName = 'may';
          break;
        case '06':
          monthName = 'iyun';
          break;
        case '07':
          monthName = 'iyul';
          break;
        case '08':
          monthName = 'avqust';
          break;
        case '09':
          monthName = 'sentyabr';
          break;
        case '10':
          monthName = 'oktyabr';
          break;
        case '11':
          monthName = 'noyabr';
          break;
        case '12':
          monthName = 'dekabr';
          break;
        default:
          monthName = 'yanvar';
      }

      return '$day $monthName $year-ci il';
    } catch (e) {
      // If any error occurs, return original date
      return usDate;
    }
  }

  /// Map of Azerbaijani month names to numbers
  static const Map<String, int> _azerbaijaniMonths = {
    'yanvar': 1,
    'fevral': 2,
    'mart': 3,
    'aprel': 4,
    'may': 5,
    'iyun': 6,
    'iyul': 7,
    'avqust': 8,
    'sentyabr': 9,
    'oktyabr': 10,
    'noyabr': 11,
    'dekabr': 12,
  };

  /// Parse Azerbaijani date string to DateTime
  /// Example: "10 oktyabr 2025-ci il" -> DateTime(2025, 10, 10)
  static DateTime? parseAzerbaijaniDate(String azDate) {
    try {
      // Remove common suffixes and clean the string
      String cleanDate = azDate
          .replaceAll('-ci il', '')
          .replaceAll('-cü il', '')
          .replaceAll('-cu il', '')
          .replaceAll('-cı il', '')
          .trim();

      final parts = cleanDate.split(' ');
      if (parts.length < 3) {
        return null;
      }

      // Parse day
      final dayStr = parts[0];
      final day = int.tryParse(dayStr);
      if (day == null || day < 1 || day > 31) {
        return null;
      }

      // Parse month
      final monthName = parts[1].toLowerCase();
      final month = _azerbaijaniMonths[monthName];
      if (month == null) {
        return null;
      }

      // Parse year
      final yearStr = parts[2];
      final year = int.tryParse(yearStr);
      if (year == null || year < 1900 || year > 2100) {
        return null;
      }

      final result = DateTime(year, month, day);
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Convert Azerbaijani date to ISO string (for API calls)
  /// Example: "10 oktyabr 2025-ci il" -> "2025-10-10T00:00:00.000Z"
  static String? azerbaijaniDateToISO(String azDate) {
    final date = parseAzerbaijaniDate(azDate);
    if (date == null) return null;

    // Return ISO string for date only (no time component)
    final isoString = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}T00:00:00.000Z';

    return isoString;
  }

  /// Convert Azerbaijani date to ISO date only (YYYY-MM-DD)
  /// Example: "10 oktyabr 2025-ci il" -> "2025-10-10"
  static String? azerbaijaniDateToISODateOnly(String azDate) {
    final date = parseAzerbaijaniDate(azDate);
    if (date == null) return null;

    final isoDate = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    return isoDate;
  }

  /// Format DateTime to Azerbaijani locale string
  /// Example: DateTime(2025, 10, 10, 14, 30) -> "10.10.2025 14:30"
  static String formatDateTimeToAz(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.'
        '${dateTime.month.toString().padLeft(2, '0')}.'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Format DateTime to Azerbaijani date only
  /// Example: DateTime(2025, 10, 10) -> "10.10.2025"
  static String formatDateToAz(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  /// Parse ISO date string to formatted Azerbaijani date
  /// Example: "2025-10-10T14:30:00.000Z" -> "10.10.2025 14:30"
  static String formatISOToAz(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return formatDateTimeToAz(date);
    } catch (e) {
      return isoString;
    }
  }
}
