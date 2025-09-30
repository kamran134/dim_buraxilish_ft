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

      final day = parts[0];
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
}
