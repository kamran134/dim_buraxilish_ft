/// Result pattern for better error handling
/// Encapsulates success and failure states without throwing exceptions
abstract class Result<T> {
  const Result();

  /// Returns true if this is a success result
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a failure result
  bool get isFailure => this is Failure<T>;

  /// Returns the success value or null if this is a failure
  T? get valueOrNull => isSuccess ? (this as Success<T>).value : null;

  /// Returns the error or null if this is a success
  Exception? get errorOrNull => isFailure ? (this as Failure<T>).error : null;

  /// Maps the success value to another type
  Result<U> map<U>(U Function(T) mapper) {
    if (isSuccess) {
      try {
        return Success(mapper((this as Success<T>).value));
      } catch (e) {
        return Failure(Exception('Mapping failed: $e'));
      }
    }
    return Failure((this as Failure<T>).error);
  }

  /// Flat maps the success value to another Result
  Result<U> flatMap<U>(Result<U> Function(T) mapper) {
    if (isSuccess) {
      try {
        return mapper((this as Success<T>).value);
      } catch (e) {
        return Failure(Exception('FlatMapping failed: $e'));
      }
    }
    return Failure((this as Failure<T>).error);
  }

  /// Executes a function on success
  Result<T> onSuccess(void Function(T) action) {
    if (isSuccess) {
      action((this as Success<T>).value);
    }
    return this;
  }

  /// Executes a function on failure
  Result<T> onFailure(void Function(Exception) action) {
    if (isFailure) {
      action((this as Failure<T>).error);
    }
    return this;
  }
}

/// Success result containing a value
class Success<T> extends Result<T> {
  final T value;

  const Success(this.value);

  @override
  bool operator ==(Object other) {
    return other is Success<T> && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// Failure result containing an error
class Failure<T> extends Result<T> {
  final Exception error;

  const Failure(this.error);

  @override
  bool operator ==(Object other) {
    return other is Failure<T> && other.error == error;
  }

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

/// Extension methods for easier Result usage
extension ResultExtensions<T> on Result<T> {
  /// Gets the value or throws the error
  T get valueOrThrow {
    if (isSuccess) {
      return (this as Success<T>).value;
    }
    throw (this as Failure<T>).error;
  }

  /// Gets the value or returns a default
  T getOrDefault(T defaultValue) {
    return isSuccess ? (this as Success<T>).value : defaultValue;
  }

  /// Gets the value or computes it from the error
  T getOrElse(T Function(Exception) onError) {
    return isSuccess
        ? (this as Success<T>).value
        : onError((this as Failure<T>).error);
  }
}

/// Helper functions for creating Results
class ResultUtils {
  /// Creates a Success result
  static Result<T> success<T>(T value) => Success(value);

  /// Creates a Failure result
  static Result<T> failure<T>(Exception error) => Failure(error);

  /// Executes a function and wraps the result
  static Result<T> tryCatch<T>(T Function() action) {
    try {
      return Success(action());
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Executes an async function and wraps the result
  static Future<Result<T>> tryCatchAsync<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Success(result);
    } catch (e) {
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }
}
