import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth token + session persistence with an in-memory cache.
///
/// On web, [FlutterSecureStorage] (WebCrypto) can fail to decrypt between
/// navigations and return null — that made Dio send no Bearer and triggered
/// a 401 logout. Web uses [SharedPreferences] (localStorage) instead.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _secure = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  static const _sessionKey = 'auth_session_json';
  static const _rememberMeKey = 'remember_me';
  static const _rememberIdentifierKey = 'remember_identifier';
  static const _rememberPasswordKey = 'remember_password';

  final FlutterSecureStorage _secure;

  String? _cachedToken;
  String? _cachedSessionJson;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _webPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String?> readToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    final value = kIsWeb
        ? (await _webPrefs()).getString(_tokenKey)
        : await _secure.read(key: _tokenKey);
    _cachedToken = value;
    return value;
  }

  Future<void> writeToken(String token) async {
    _cachedToken = token;
    if (kIsWeb) {
      await (await _webPrefs()).setString(_tokenKey, token);
    } else {
      await _secure.write(key: _tokenKey, value: token);
    }
  }

  Future<String?> readSessionJson() async {
    if (_cachedSessionJson != null && _cachedSessionJson!.isNotEmpty) {
      return _cachedSessionJson;
    }
    final value = kIsWeb
        ? (await _webPrefs()).getString(_sessionKey)
        : await _secure.read(key: _sessionKey);
    _cachedSessionJson = value;
    return value;
  }

  Future<void> writeSessionJson(String json) async {
    _cachedSessionJson = json;
    if (kIsWeb) {
      await (await _webPrefs()).setString(_sessionKey, json);
    } else {
      await _secure.write(key: _sessionKey, value: json);
    }
  }

  Future<void> clearAuth() async {
    _cachedToken = null;
    _cachedSessionJson = null;
    if (kIsWeb) {
      final prefs = await _webPrefs();
      await prefs.remove(_tokenKey);
      await prefs.remove(_sessionKey);
    } else {
      await _secure.delete(key: _tokenKey);
      await _secure.delete(key: _sessionKey);
    }
  }

  /// Whether the user opted to remember login fields (survives logout).
  Future<bool> readRememberMe() async {
    final prefs = await _webPrefs();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  Future<({String identifier, String password})?>
      readRememberedCredentials() async {
    final prefs = await _webPrefs();
    if (prefs.getBool(_rememberMeKey) != true) return null;

    final identifier = prefs.getString(_rememberIdentifierKey)?.trim() ?? '';
    if (identifier.isEmpty) return null;

    final password = kIsWeb
        ? (prefs.getString(_rememberPasswordKey) ?? '')
        : (await _secure.read(key: _rememberPasswordKey) ?? '');

    return (identifier: identifier, password: password);
  }

  Future<void> writeRememberedCredentials({
    required String identifier,
    required String password,
  }) async {
    final prefs = await _webPrefs();
    final trimmed = identifier.trim();
    await prefs.setBool(_rememberMeKey, true);
    await prefs.setString(_rememberIdentifierKey, trimmed);
    if (kIsWeb) {
      await prefs.setString(_rememberPasswordKey, password);
    } else {
      await _secure.write(key: _rememberPasswordKey, value: password);
    }
  }

  Future<void> clearRememberedCredentials() async {
    final prefs = await _webPrefs();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_rememberIdentifierKey);
    if (kIsWeb) {
      await prefs.remove(_rememberPasswordKey);
    } else {
      await _secure.delete(key: _rememberPasswordKey);
    }
  }
}
