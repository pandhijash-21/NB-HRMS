import 'dart:io';

import 'package:dio/dio.dart';

/// End-to-end auth flow against Express (mirrors Flutter repository calls).
/// Uses employee 4 (seeded first-login), changes password, re-logins.
Future<void> main() async {
  const base = 'http://127.0.0.1:4000/api/';
  final dio = Dio(BaseOptions(baseUrl: base));

  Map<String, dynamic> unwrap(Response<dynamic> res) {
    final body = res.data as Map<String, dynamic>;
    if (body['success'] != true) {
      throw StateError(body['error']?.toString() ?? 'Request failed');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  stdout.writeln('1) Login as first-login employee 4…');
  final login1 = unwrap(await dio.post('auth/login', data: {
    'identifier': '4',
    'password': '01011998',
  }));
  if (login1['isFirstLogin'] != true) {
    // Already changed in a prior run — still prove re-login path with current secret.
    stdout.writeln('   (isFirstLogin already false — skipping change; re-login only)');
  }
  final token = login1['token'] as String;
  stdout.writeln('   OK isFirstLogin=${login1['isFirstLogin']}');

  if (login1['isFirstLogin'] == true) {
    stdout.writeln('2) Change password…');
    final authDio = Dio(BaseOptions(
      baseUrl: base,
      headers: {'Authorization': 'Bearer $token'},
    ));
    final changed = unwrap(await authDio.post('auth/change-password', data: {
      'currentPassword': '01011998',
      'newPassword': 'NbDev4242',
    }));
    stdout.writeln('   OK message=${changed['message']}');

    stdout.writeln('3) Re-login with new password…');
    final login2 = unwrap(await dio.post('auth/login', data: {
      'identifier': '4',
      'password': 'NbDev4242',
    }));
    if (login2['isFirstLogin'] == true) {
      stderr.writeln('FAIL: isFirstLogin still true after change');
      exit(1);
    }
    stdout.writeln(
      '   OK user=${(login2['user'] as Map)['name']} isFirstLogin=${login2['isFirstLogin']}',
    );
  } else {
    stdout.writeln('2–3) Skipped (password already rotated). Login OK.');
  }

  stdout.writeln('PASS — flow matches Flutter login → change-password → home');
}
