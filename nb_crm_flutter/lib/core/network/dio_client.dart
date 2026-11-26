import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../logging/app_logger.dart';
import 'api_envelope.dart';
import 'app_config.dart';
import 'transport_crypto.dart';
import '../services/branding_config.dart';

/// Mutable hook so [DioClient] can notify auth without circular construction.
class UnauthorizedGate {
  final List<Future<void> Function({String? reason})> _handlers = [];
  DateTime? _lastNotifiedAt;

  void bind(Future<void> Function({String? reason}) handler) {
    if (!_handlers.contains(handler)) {
      _handlers.add(handler);
    }
  }

  void unbind(Future<void> Function({String? reason}) handler) {
    _handlers.remove(handler);
  }

  Future<void> notify({String? reason}) async {
    final now = DateTime.now();
    // Debounce notifications within 2 seconds so burst 401s don't trigger repeated kick logic
    if (_lastNotifiedAt != null &&
        now.difference(_lastNotifiedAt!).inMilliseconds < 2000) {
      return;
    }
    _lastNotifiedAt = now;
    final copy = List<Future<void> Function({String? reason})>.from(_handlers);
    for (final h in copy) {
      try {
        await h(reason: reason);
      } catch (_) {}
    }
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
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-client-platform': kIsWeb ? 'browser' : 'app',
          transportEncHeader: '$transportEncVersion',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final extraToken = options.extra['bearer'];
          final token = extraToken is String && extraToken.isNotEmpty
              ? extraToken
              : await readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (BrandingConfig.hasActiveBypass && BrandingConfig.bypassToken != null) {
            options.headers['x-maintenance-bypass'] = BrandingConfig.bypassToken;
          }
          options.headers[transportEncHeader] = '$transportEncVersion';
          final data = options.data;
          if (data != null &&
              data is! FormData &&
              data is! List<int> &&
              !isEncryptedEnvelope(data)) {
            try {
              options.data = await wrapEncrypted(data);
            } catch (e) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'Unable to secure request',
                  type: DioExceptionType.unknown,
                ),
              );
            }
          }
          AppLogger.network.d('${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) async {
          AppLogger.network.d(
            '${response.requestOptions.method} ${response.requestOptions.path} → ${response.statusCode}',
          );
          if (response.requestOptions.responseType == ResponseType.bytes) {
            handler.next(response);
            return;
          }
          try {
            response.data = await unwrapTransportBody(response.data);
          } catch (_) {
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: 'Unable to read secure response',
                type: DioExceptionType.badResponse,
              ),
            );
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final method = error.requestOptions.method;
          AppLogger.network.w('$method $path → ${status ?? error.type.name}');
          if (error.response != null) {
            try {
              error.response!.data = await unwrapTransportBody(error.response!.data);
            } catch (_) {}
          }
          final isAuthPublic = path.contains('auth/login') ||
              path.contains('auth/forgot-password') ||
              path.contains('auth/release-session');
          if (status == 401 && !isAuthPublic) {
            // Check if the 401 was for the CURRENT active session.
            // If the request was made with an obsolete, stale or null token, do NOT kick the active session!
            final reqAuth = error.requestOptions.headers['Authorization']?.toString();
            final reqToken = reqAuth != null && reqAuth.startsWith('Bearer ')
                ? reqAuth.substring(7).trim()
                : null;
            final currentToken = (await readToken())?.trim();

            if (currentToken != null && currentToken.isNotEmpty) {
              if (reqToken != null && reqToken == currentToken) {
                // Extract server error message if available
                String? serverMessage;
                final resData = error.response?.data;
                if (resData is Map) {
                  serverMessage = resData['error']?.toString() ??
                      resData['message']?.toString();
                }
                await unauthorizedGate.notify(reason: serverMessage);
              } else {
                AppLogger.network.w(
                  'Ignored 401 on $path because request token does not match current active token',
                );
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio dio;

  String get baseUrl => dio.options.baseUrl;

  void updateBaseUrl(String url) {
    dio.options.baseUrl = _normalizeBaseUrl(url);
  }

  static String _normalizeBaseUrl(String url) {
    // Trailing slash so relative paths like `auth/login` resolve under `/api/`.
    if (url.endsWith('/')) return url;
    return '$url/';
  }

  /// Parses Express envelope; throws [ApiException] with a clean message.
  Future<T> postEnvelope<T>(
    String path, {
    Object? data,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    String? bearer,
    required T Function(Object? raw) parse,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
          extra: {if (bearer != null) 'bearer': bearer},
        ),
      );
      final result = _unwrap(response.data, response.statusCode, parse);
      return result;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<T> postMultipartEnvelope<T>(
    String path, {
    required FormData data,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    required T Function(Object? raw) parse,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: _timeoutOptions(sendTimeout: sendTimeout, receiveTimeout: receiveTimeout),
      );
      final result = _unwrap(response.data, response.statusCode, parse);
      return result;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Options? _timeoutOptions({Duration? sendTimeout, Duration? receiveTimeout}) {
    if (sendTimeout == null && receiveTimeout == null) return null;
    return Options(sendTimeout: sendTimeout, receiveTimeout: receiveTimeout);
  }

  Future<T> getEnvelope<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? bearer,
    required T Function(Object? raw) parse,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: Options(extra: {if (bearer != null) 'bearer': bearer}),
      );
      final result = _unwrap(response.data, response.statusCode, parse);
      return result;
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
      final result = _unwrap(response.data, response.statusCode, parse);
      return result;
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
      final result = _unwrap(response.data, response.statusCode, parse);
      return result;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<T> deleteEnvelope<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    required T Function(Object? raw) parse,
  }) async {
    try {
      final response = await dio.delete<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      final result = _unwrap(response.data, response.statusCode, parse);
      return result;
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
    final path = e.requestOptions.path;
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
        final url = dio.options.baseUrl;
        return ApiException(
          'Unable to reach server at $url. If running locally, check that the backend is started, or switch to the Live Server.',
        );
      default:
        final status = e.response?.statusCode;
        if (status == 404 && (path.contains('subtasks') || path.contains('boq') || path.contains('erp/resources'))) {
          return const ApiException(
            'API not found on this server. In debug, use local backend (127.0.0.1:4000) or deploy the latest backend.',
            statusCode: 404,
          );
        }
        if (status == 502 || status == 503 || status == 504) {
          return ApiException(
            'Server is momentarily restarting or undergoing updates. Please try again in a few seconds.',
            statusCode: status,
          );
        }
        if (status == 500) {
          return const ApiException(
            'Server encountered an unexpected error. Please try again later.',
            statusCode: 500,
          );
        }
        return ApiException(
          e.message ?? 'Something went wrong. Please try again.',
          statusCode: status,
        );
    }
  }
}
