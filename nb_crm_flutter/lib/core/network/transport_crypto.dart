import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

import 'app_config.dart';

const transportEncHeader = 'X-NB-Enc';
const transportEncVersion = 2;

final _aes = AesGcm.with256bits(nonceLength: 12);
final _sha = Sha256();
final _keyCache = <String, SecretKey>{};

Future<SecretKey> _secret(String layer) async {
  final cached = _keyCache[layer];
  if (cached != null) return cached;
  final hash = await _sha.hash(utf8.encode('${AppConfig.transportSecret}|$layer|v2'));
  final key = SecretKey(hash.bytes);
  _keyCache[layer] = key;
  return key;
}

Future<Uint8List> _encryptLayer(SecretKey key, List<int> plain) async {
  final box = await _aes.encrypt(plain, secretKey: key);
  return Uint8List.fromList([...box.nonce, ...box.mac.bytes, ...box.cipherText]);
}

Future<Uint8List> _decryptLayer(SecretKey key, List<int> blob) async {
  if (blob.length < 28) {
    throw const FormatException('Invalid encrypted payload');
  }
  final nonce = blob.sublist(0, 12);
  final mac = Mac(blob.sublist(12, 28));
  final cipherText = blob.sublist(28);
  final clear = await _aes.decrypt(
    SecretBox(cipherText, nonce: nonce, mac: mac),
    secretKey: key,
  );
  return Uint8List.fromList(clear);
}

Future<Map<String, dynamic>> wrapEncrypted(Object? data) async {
  final innerKey = await _secret('inner');
  final outerKey = await _secret('outer');
  final inner = await _encryptLayer(innerKey, utf8.encode(jsonEncode(data)));
  final outer = await _encryptLayer(outerKey, inner);
  return {'v': transportEncVersion, 'p': base64Encode(outer)};
}

Future<Object?> unwrapEncrypted(String payload) async {
  final innerKey = await _secret('inner');
  final outerKey = await _secret('outer');
  final outer = await _decryptLayer(outerKey, base64Decode(payload));
  final inner = await _decryptLayer(innerKey, outer);
  return jsonDecode(utf8.decode(inner));
}

bool isEncryptedEnvelope(Object? data) {
  return data is Map && data['v'] == transportEncVersion && data['p'] is String;
}

Future<Object?> unwrapTransportBody(Object? data) async {
  if (isEncryptedEnvelope(data)) {
    return unwrapEncrypted((data as Map)['p'] as String);
  }
  return data;
}

Interceptor transportEncryptionInterceptor() {
  return InterceptorsWrapper(
    onRequest: (options, handler) async {
      options.headers[transportEncHeader] = '$transportEncVersion';
      final data = options.data;
      if (data != null && data is! FormData && data is! List<int> && !isEncryptedEnvelope(data)) {
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
      handler.next(options);
    },
    onResponse: (response, handler) async {
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
      if (error.response != null) {
        try {
          error.response!.data = await unwrapTransportBody(error.response!.data);
        } catch (_) {}
      }
      handler.next(error);
    },
  );
}
