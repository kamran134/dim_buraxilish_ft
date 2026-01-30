import 'package:flutter/foundation.dart';

/// Centralized logging utility for the application
/// Uses conditional logging based on build mode (debug vs release)
class AppLogger {
  /// Log level for filtering messages
  static LogLevel _minLogLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  /// Set minimum log level
  static void setLogLevel(LogLevel level) {
    _minLogLevel = level;
  }

  /// Debug log - only in debug mode
  static void debug(String message, {String? tag}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  /// Info log
  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// Warning log
  static void warning(String message, {String? tag}) {
    _log(LogLevel.warning, message, tag: tag);
  }

  /// Error log
  static void error(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag);
    if (error != null) {
      _log(LogLevel.error, 'Error details: $error', tag: tag);
    }
    if (stackTrace != null && kDebugMode) {
      _log(LogLevel.error, 'Stack trace: $stackTrace', tag: tag);
    }
  }

  /// Internal logging method
  static void _log(LogLevel level, String message, {String? tag}) {
    // Skip if log level is below minimum
    if (level.index < _minLogLevel.index) {
      return;
    }

    // In release mode, only log warnings and errors
    if (!kDebugMode && level.index < LogLevel.warning.index) {
      return;
    }

    final emoji = _getEmoji(level);
    final levelStr = level.name.toUpperCase().padRight(7);
    final tagStr = tag != null ? '[$tag] ' : '';
    final timestamp =
        DateTime.now().toString().substring(11, 23); // HH:mm:ss.mmm

    debugPrint('$emoji $timestamp $levelStr $tagStr$message');
  }

  /// Get emoji for log level
  static String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
    }
  }
}

/// Log levels for filtering
enum LogLevel {
  debug,
  info,
  warning,
  error,
}
