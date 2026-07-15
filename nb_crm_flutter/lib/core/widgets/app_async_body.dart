import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';

/// Shared async list/body pattern used across leave, org, rbac, salary.
class AppAsyncBody<T> extends StatelessWidget {
  const AppAsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.emptyMessage = 'Nothing here yet.',
    this.onRetry,
    this.isEmpty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final String emptyMessage;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.bronze),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$err', textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
      data: (data) {
        final empty = isEmpty?.call(data) ??
            (data is List && data.isEmpty);
        if (empty) {
          return Center(child: Text(emptyMessage));
        }
        return builder(data);
      },
    );
  }
}
