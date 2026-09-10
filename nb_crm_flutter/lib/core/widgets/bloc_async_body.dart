import 'package:flutter/material.dart';

import '../bloc/load_status.dart';

/// High-performance shared async list/body widget for BLoC architecture.
/// Replaces Riverpod's AppAsyncBody with pure BLoC / LoadStatus integration.
class BlocAsyncBody<T> extends StatelessWidget {
  const BlocAsyncBody({
    super.key,
    required this.status,
    required this.data,
    required this.builder,
    this.errorMessage,
    this.emptyMessage = 'Nothing here yet.',
    this.onRetry,
    this.isEmpty,
    this.loadingWidget,
  });

  final LoadStatus status;
  final T? data;
  final Widget Function(T data) builder;
  final String? errorMessage;
  final String emptyMessage;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? loadingWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (status.isLoading || (status.isInitial && data == null)) {
      return loadingWidget ??
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Loading…',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          );
    }

    if (status.isFailure && data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 44,
                  color: theme.colorScheme.error.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 12),
                Text(
                  'Something went wrong',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage ?? 'An unexpected error occurred.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (data == null) {
      return Center(
        child: Text(
          emptyMessage,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    final isDataEmpty = isEmpty?.call(data as T) ?? (data is List && (data as List).isEmpty);
    if (isDataEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.28),
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return builder(data as T);
  }
}
