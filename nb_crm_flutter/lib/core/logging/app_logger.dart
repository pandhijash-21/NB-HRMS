import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// App-wide structured logger. Prefer this over [print] / [debugPrint].
class AppLogger {
  AppLogger._(this.name);

  final String name;

  static final AppLogger app = AppLogger._('NB');
  static final AppLogger router = AppLogger._('Router');
  static final AppLogger network = AppLogger._('Network');
  static final AppLogger tracking = AppLogger._('Tracking');
  static final AppLogger auth = AppLogger._('Auth');

  factory AppLogger.named(String name) => AppLogger._(name);

  void d(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(message, level: 500, error: error, stackTrace: stackTrace);

  void i(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(message, level: 800, error: error, stackTrace: stackTrace);

  void w(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(message, level: 900, error: error, stackTrace: stackTrace);

  void e(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(message, level: 1000, error: error, stackTrace: stackTrace);

  void _log(
    String message, {
    required int level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
    if (kDebugMode) {
      final prefix = switch (level) {
        >= 1000 => 'E',
        >= 900 => 'W',
        >= 800 => 'I',
        _ => 'D',
      };
      final err = error == null ? '' : ' | $error';
      debugPrint('[$prefix/$name] $message$err');
    }
  }
}
