import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/leave_models.dart';

class LeaveAsyncBody<T> extends StatelessWidget {
  const LeaveAsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.emptyMessage = 'Nothing here yet.',
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final String emptyMessage;
  final VoidCallback? onRetry;

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
        if (data is List && data.isEmpty) {
          return Center(child: Text(emptyMessage));
        }
        return builder(data);
      },
    );
  }
}

Color leaveStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'APPROVED':
      return AppColors.success;
    case 'REJECTED':
    case 'CANCELLED':
      return AppColors.error;
    default:
      return AppColors.bronzeDark;
  }
}

Widget leaveStatusChip(String status) {
  final color = leaveStatusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      status,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class LeaveApplicationCard extends StatelessWidget {
  const LeaveApplicationCard({
    super.key,
    required this.application,
    this.trailing,
    this.subtitle,
    this.onTap,
  });

  final LeaveApplication application;
  final Widget? trailing;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final typeName = application.leaveType?.name ?? application.leaveTypeId;
    final employeeName = application.employee?.fullName;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      typeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.midnight,
                      ),
                    ),
                  ),
                  leaveStatusChip(application.status),
                ],
              ),
              if (employeeName != null) ...[
                const SizedBox(height: 4),
                Text(
                  employeeName,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 8),
              Text(
                '${application.fromDate} → ${application.toDate}'
                '${application.isHalfDay ? ' (Half day${application.halfDaySession != null ? ': ${application.halfDaySession}' : ''})' : ''}',
              ),
              const SizedBox(height: 4),
              Text(
                '${application.totalDays} day(s) · ${application.applicationNo}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (application.reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(application.reason),
              ],
              if (trailing != null) ...[
                const SizedBox(height: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String formatIsoTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  } catch (_) {
    return iso;
  }
}

String formatDateYmd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
