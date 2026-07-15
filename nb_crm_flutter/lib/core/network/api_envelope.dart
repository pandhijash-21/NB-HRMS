/// Shared `{ success, data, error }` envelope used by Express.
class ApiEnvelope<T> {
  const ApiEnvelope({
    required this.success,
    this.data,
    this.error,
  });

  final bool success;
  final T? data;
  final String? error;

  factory ApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Object? raw)? parseData,
  ) {
    final success = json['success'] == true;
    final rawError = json['error'];
    return ApiEnvelope<T>(
      success: success,
      data: success && parseData != null ? parseData(json['data']) : null,
      error: rawError is String ? rawError : null,
    );
  }
}

/// Typed API failure with a user-facing message (never a raw stack dump).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
