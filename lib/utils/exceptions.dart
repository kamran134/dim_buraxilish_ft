/// Custom exceptions for the DIM Buraxilish application
/// Provides type-safe error handling across the application

/// Base exception class
abstract class AppException implements Exception {
  final String message;
  final int? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (code != null) {
      buffer.write(' (Code: $code)');
    }
    if (originalError != null) {
      buffer.write('\nOriginal error: $originalError');
    }
    return buffer.toString();
  }
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory NetworkException.connectionError() {
    return const NetworkException(
      message: 'Şəbəkə bağlantısı xətası',
      code: 1001,
    );
  }

  factory NetworkException.timeout() {
    return const NetworkException(
      message: 'Sorğu müddəti doldu',
      code: 1002,
    );
  }

  factory NetworkException.serverError({int? statusCode}) {
    return NetworkException(
      message: 'Server xətası${statusCode != null ? " ($statusCode)" : ""}',
      code: 1003,
    );
  }
}

/// Authentication and authorization exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory AuthException.invalidCredentials() {
    return const AuthException(
      message: 'İstifadəçi adı və ya şifrə səhvdir',
      code: 2001,
    );
  }

  factory AuthException.tokenExpired() {
    return const AuthException(
      message: 'Sessiya müddəti bitib. Yenidən daxil olun',
      code: 2002,
    );
  }

  factory AuthException.tokenInvalid() {
    return const AuthException(
      message: 'Giriş token səhvdir',
      code: 2003,
    );
  }

  factory AuthException.unauthorized() {
    return const AuthException(
      message: 'Bu əməliyyat üçün icazəniz yoxdur',
      code: 2004,
    );
  }
}

/// Database-related exceptions
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory DatabaseException.queryFailed(String operation) {
    return DatabaseException(
      message: 'Verilənlər bazası əməliyyatı uğursuz oldu: $operation',
      code: 3001,
    );
  }

  factory DatabaseException.notFound(String entity) {
    return DatabaseException(
      message: '$entity tapılmadı',
      code: 3002,
    );
  }

  factory DatabaseException.duplicateEntry() {
    return const DatabaseException(
      message: 'Bu qeyd artıq mövcuddur',
      code: 3003,
    );
  }
}

/// Validation exceptions
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    this.fieldErrors,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory ValidationException.invalidInput(String field) {
    return ValidationException(
      message: 'Səhv məlumat: $field',
      code: 4001,
      fieldErrors: {field: 'Zəhmət olmasa düzgün məlumat daxil edin'},
    );
  }

  factory ValidationException.requiredField(String field) {
    return ValidationException(
      message: 'Məcburi sahə: $field',
      code: 4002,
      fieldErrors: {field: 'Bu sahə mütləqdir'},
    );
  }

  factory ValidationException.invalidFormat(String field, String format) {
    return ValidationException(
      message: 'Səhv format: $field',
      code: 4003,
      fieldErrors: {field: 'Gözlənilən format: $format'},
    );
  }
}

/// QR Scanner exceptions
class ScannerException extends AppException {
  const ScannerException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory ScannerException.cameraPermissionDenied() {
    return const ScannerException(
      message: 'Kamera icazəsi verilməyib',
      code: 5001,
    );
  }

  factory ScannerException.cameraNotAvailable() {
    return const ScannerException(
      message: 'Kamera əlçatan deyil',
      code: 5002,
    );
  }

  factory ScannerException.invalidQRCode() {
    return const ScannerException(
      message: 'Keçərsiz QR kod',
      code: 5003,
    );
  }
}

/// API-related exceptions
class ApiException extends AppException {
  const ApiException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory ApiException.badRequest(String details) {
    return ApiException(
      message: 'Səhv sorğu: $details',
      code: 6001,
    );
  }

  factory ApiException.notFound(String resource) {
    return ApiException(
      message: '$resource tapılmadı',
      code: 6002,
    );
  }

  factory ApiException.serverError() {
    return const ApiException(
      message: 'Server xətası baş verdi',
      code: 6003,
    );
  }

  factory ApiException.parseError() {
    return const ApiException(
      message: 'Cavab emal edilə bilmədi',
      code: 6004,
    );
  }
}

/// Storage-related exceptions
class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory StorageException.readError(String key) {
    return StorageException(
      message: 'Məlumat oxuna bilmədi: $key',
      code: 7001,
    );
  }

  factory StorageException.writeError(String key) {
    return StorageException(
      message: 'Məlumat yazıla bilmədi: $key',
      code: 7002,
    );
  }

  factory StorageException.deleteError(String key) {
    return StorageException(
      message: 'Məlumat silinə bilmədi: $key',
      code: 7003,
    );
  }
}

/// Utility class for handling exceptions
class ExceptionHandler {
  /// Converts various exception types to user-friendly messages
  static String getUserMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }

    if (error is FormatException) {
      return 'Məlumat formatı səhvdir';
    }

    if (error is TypeError) {
      return 'Məlumat tipi uyğunsuzluğu';
    }

    // Generic fallback
    return 'Gözlənilməz xəta baş verdi';
  }

  /// Determines if error should be logged
  static bool shouldLog(Object error) {
    // Always log non-app exceptions as they are unexpected
    if (error is! AppException) {
      return true;
    }

    // Don't log validation errors (user errors)
    if (error is ValidationException) {
      return false;
    }

    // Log all other app exceptions
    return true;
  }
}
