import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// Headless API check (no Flutter plugins).
/// Run: dart run tool/verify_login.dart
Future<void> main() async {
  const base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:4000/api/',
  );
  final dio = Dio(BaseOptions(baseUrl: base.endsWith('/') ? base : '$base/'));

  stdout.writeln('POST ${dio.options.baseUrl}auth/login');
  final response = await dio.post<Map<String, dynamic>>(
    'auth/login',
    data: {'identifier': '1', 'password': '01011998'},
  );

  final body = response.data!;
  if (body['success'] != true) {
    stderr.writeln('FAIL: ${body['error']}');
    exit(1);
  }

  final data = body['data'] as Map<String, dynamic>;
  final user = data['user'] as Map<String, dynamic>;
  stdout.writeln('OK user=${user['name']} role=${user['role']}');
  stdout.writeln('isFirstLogin=${data['isFirstLogin']}');
  stdout.writeln('tokenLength=${(data['token'] as String).length}');
  stdout.writeln(jsonEncode({'permissionsModules': (data['permissions'] as Map).keys.length}));
}
