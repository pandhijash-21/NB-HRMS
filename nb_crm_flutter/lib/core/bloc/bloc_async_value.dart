import 'package:flutter/widgets.dart';

import 'load_status.dart';

/// Lightweight helper that provides a familiar `.when()` pattern
/// for consuming BLoC state data in existing screens during migration.
class BlocAsyncValue<T> {
  const BlocAsyncValue({
    required this.status,
    this.value,
    this.error,
  });

  final LoadStatus status;
  final T? value;
  final Object? error;

  bool get isLoading => status.isLoading;
  bool get hasError => status.isFailure;
  bool get hasValue => value != null;

  Widget when({
    required Widget Function(T data) data,
    required Widget Function() loading,
    required Widget Function(Object error, StackTrace? stackTrace) error,
  }) {
    if (isLoading && value == null) {
      return loading();
    }
    if (hasError && value == null) {
      return error(this.error ?? 'An unexpected error occurred.', null);
    }
    if (value != null) {
      return data(value as T);
    }
    if (isLoading) {
      return loading();
    }
    return error(this.error ?? 'No data found.', null);
  }

  Widget maybeWhen({
    Widget Function(T data)? data,
    Widget Function()? loading,
    Widget Function(Object error, StackTrace? stackTrace)? error,
    required Widget Function() orElse,
  }) {
    if (isLoading && value == null) {
      return loading != null ? loading() : orElse();
    }
    if (hasError && value == null) {
      return error != null ? error(this.error ?? 'Error', null) : orElse();
    }
    if (value != null) {
      return data != null ? data(value as T) : orElse();
    }
    return orElse();
  }
}
