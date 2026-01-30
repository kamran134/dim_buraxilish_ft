/// Базовый результат операции
class Result {
  final bool success;
  final String message;

  Result({
    required this.success,
    required this.message,
  });

  Result.success({required this.message}) : success = true;
  Result.error({required this.message}) : success = false;
}

/// Результат с данными
class DataResult<T> extends Result {
  final T? data;

  DataResult({
    required bool success,
    required String message,
    this.data,
  }) : super(success: success, message: message);

  DataResult.success({
    required this.data,
    required String message,
  }) : super(success: true, message: message);

  DataResult.error({
    required String message,
  })  : data = null,
        super(success: false, message: message);
}

/// Результат со списком данных
class ListResult<T> extends Result {
  final List<T>? data;

  ListResult({
    required bool success,
    required String message,
    this.data,
  }) : super(success: success, message: message);

  ListResult.success({
    required this.data,
    required String message,
  }) : super(success: true, message: message);

  ListResult.error({
    required String message,
  })  : data = null,
        super(success: false, message: message);
}

/// Simple response model (similar to backend ResponseModel)
class ResponseModel {
  final bool success;
  final String message;

  ResponseModel({
    required this.success,
    required this.message,
  });

  factory ResponseModel.fromJson(Map<String, dynamic> json) {
    return ResponseModel(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
    );
  }
}
