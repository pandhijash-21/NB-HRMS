import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth token + session persistence with an in-memory cache.
///
/// On web, [FlutterSecureStorage] (WebCrypto) can fail to decrypt between
/// navigations and return null — that made Dio send no Bearer and triggered
/// a 401 logout. Web uses [SharedPreferences] (localStorage) instead.
///
/// Default construction is a process-wide singleton so every caller (Dio,
/// web live tracking, auth) shares the same token cache. Otherwise a second
/// instance can keep a stale JWT after re-login and spam 401s on tracking.
class SecureStorageService {
  factory SecureStorageService({FlutterSecureStorage? storage}) {
    if (storage != null) {
      return SecureStorageService._(storage);
    }
    return _instance ??= SecureStorageService._(const FlutterSecureStorage());
  }

  SecureStorageService._(this._secure);

  static SecureStorageService? _instance;

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

    var password = prefs.getString(_rememberPasswordKey) ?? '';

    // Migrate legacy native installs that stored password in secure storage.
    if (password.isEmpty && !kIsWeb) {
      password = await _secure.read(key: _rememberPasswordKey) ?? '';
      if (password.isNotEmpty) {
        await prefs.setString(_rememberPasswordKey, password);
        await _secure.delete(key: _rememberPasswordKey);
      }
    }

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
    await prefs.setString(_rememberPasswordKey, password);
    if (!kIsWeb) {
      await _secure.delete(key: _rememberPasswordKey);
    }
  }

  Future<void> clearRememberedCredentials() async {
    final prefs = await _webPrefs();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_rememberIdentifierKey);
    await prefs.remove(_rememberPasswordKey);
    if (!kIsWeb) {
      await _secure.delete(key: _rememberPasswordKey);
    }
  }

  String _biometricKey(int employeeId) => 'biometric_token_employee_$employeeId';

  Future<String?> readBiometricToken(int employeeId) async {
    final key = _biometricKey(employeeId);
    if (kIsWeb) {
      return (await _webPrefs()).getString(key);
    }
    return _secure.read(key: key);
  }

  Future<void> writeBiometricToken(int employeeId, String token) async {
    final key = _biometricKey(employeeId);
    if (kIsWeb) {
      await (await _webPrefs()).setString(key, token);
    } else {
      await _secure.write(key: key, value: token);
    }
  }

  Future<void> clearBiometricToken(int employeeId) async {
    final key = _biometricKey(employeeId);
    if (kIsWeb) {
      await (await _webPrefs()).remove(key);
    } else {
      await _secure.delete(key: key);
    }
  }
}
