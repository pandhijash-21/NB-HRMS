import 'package:dio/dio.dart';

import 'api_envelope.dart';
import 'app_config.dart';

/// Mutable hook so [DioClient] can notify auth without circular construction.
class UnauthorizedGate {
  Future<void> Function()? _handler;

  void bind(Future<void> Function() handler) => _handler = handler;

  Future<void> notify() async {
    final h = _handler;
    if (h != null) await h();
  }
}

/// Shared Dio client: Bearer token + 401 → clear session (except login).
class DioClient {
  DioClient({
    required Future<String?> Function() readToken,
    required UnauthorizedGate unauthorizedGate,
    String? baseUrl,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: _normalizeBaseUrl(baseUrl ?? AppConfig.apiBaseUrl),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final isLogin = path.contains('auth/login');
          if (status == 401 && !isLogin) {
            await unauthorizedGate.notify();
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio dio;

  static String _normalizeBaseUrl(String url) {
    // Trailing slash so relative paths like `auth/login` resolve under `/api/`.
    if (url.endsWith('/')) return url;
    return '$url/';
  }

  /// Parses Express envelope; throws [ApiException] with a clean message.
  Future<T> postEnvelope<T>(
    String path, {
    Object? data,
    Duration? receiveTimeout,
    required T Function(Object? raw) parse,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: receiveTimeout == null
            ? null
            : Options(receiveTimeout: receiveTimeout),
      );
      return _unwrap(response.data, response.statusCode, parse);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<T> getEnvelope<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Object? raw) parse,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return _unwrap(response.data, response.statusCode, parse);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<T> patchEnvelope<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    required T Function(Object? raw) parse,
  }) async {
    try {
      final response = await dio.patch<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _unwrap(response.data, response.statusCode, parse);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<T> putEnvelope<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    required T Function(Object? raw) parse,
  }) async {
    try {
      final response = await dio.put<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _unwrap(response.data, response.statusCode, parse);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<T> deleteEnvelope<T>(
    String path, {
    required T Function(Object? raw) parse,
  }) async {
    try {
      final response = await dio.delete<Map<String, dynamic>>(path);
      return _unwrap(response.data, response.statusCode, parse);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  T _unwrap<T>(
    Map<String, dynamic>? body,
    int? statusCode,
    T Function(Object? raw) parse,
  ) {
    if (body == null) {
      throw ApiException('Empty response from server', statusCode: statusCode);
    }
    final envelope = ApiEnvelope.fromJson(body, parse);
    if (!envelope.success) {
      throw ApiException(
        envelope.error ?? 'Request failed',
        statusCode: statusCode,
      );
    }
    // Successful APIs may legitimately return `data: null` for nullable T
    // (for example, no pending profile change request).
    if (envelope.data == null && null is! T) {
      throw ApiException(
        envelope.error ?? 'Request returned no data',
        statusCode: statusCode,
      );
    }
    return envelope.data as T;
  }

  ApiException _mapDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        return ApiException(error, statusCode: e.response?.statusCode);
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return ApiException(message, statusCode: e.response?.statusCode);
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          'Connection timed out. Check that the API server is running.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          'Unable to reach the server. Check your network and API URL.',
        );
      default:
        return ApiException(
          e.message ?? 'Something went wrong. Please try again.',
          statusCode: e.response?.statusCode,
        );
    }
  }
}
