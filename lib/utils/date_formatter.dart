/// Utility functions for date formatting.
///
/// Full-switch (9.2): the API-oriented converters that used to translate the
/// legacy Azerbaijani-worded exam date string into request parameters
/// (`dateToAzToDate`, `dateToAzToDateWithSession`, `dateFromAzToDate`,
/// `parseAzerbaijaniDate`, `azerbaijaniDateToISO*`) are gone — every endpoint
/// now gets its exam scope from the `X-Exam-Slot` header alone (contract
/// §1). Only the display-only formatters below remain, unrelated to the
/// exam-identity migration.
class DateFormatter {
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
