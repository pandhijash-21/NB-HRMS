import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return value.when(
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238)),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$err', 
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry, 
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                    foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
      data: (data) {
        if (data is List && data.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 64,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: TextStyle(
                      color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return builder(data);
      },
    );
  }
}

Color leaveStatusColor(BuildContext context, String status) {
  switch (status.toUpperCase()) {
    case 'APPROVED':
      return Colors.green;
    case 'REJECTED':
    case 'CANCELLED':
      return Colors.red;
    default:
      return Colors.orange;
  }
}

Widget leaveStatusChip(BuildContext context, String status) {
  final color = leaveStatusColor(context, status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      border: Border.all(color: color, width: 1.2),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      status.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeName = application.leaveType?.name ?? application.leaveTypeId;
    final employeeName = application.employee?.fullName;

    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final cardBorder = isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC);
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      typeName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                  ),
                  leaveStatusChip(context, application.status),
                ],
              ),
              Divider(
                height: 24,
                thickness: 1.2,
                color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : Colors.black.withOpacity(0.06),
              ),
              if (employeeName != null) ...[
                Text(
                  employeeName,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (subtitle != null) ...[
                Text(
                  subtitle!, 
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF607D8B).withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (application.approvalSteps.isNotEmpty) ...[
                LeaveApprovalPipeline(steps: application.approvalSteps),
                const SizedBox(height: 10),
              ],
              Text(
                '${application.fromDate} → ${application.toDate}'
                '${application.isHalfDay ? ' (Half day${application.halfDaySession != null ? ': ${application.halfDaySession}' : ''})' : ''}',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${application.totalDays} day(s) · ${application.applicationNo}',
                style: TextStyle(
                  color: isDark ? Colors.white38 : const Color(0xFF607D8B), 
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (application.reason.isNotEmpty) ...[
                Divider(
                  height: 24,
                  thickness: 1,
                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : Colors.black.withOpacity(0.06),
                ),
                Text(
                  application.reason,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF263238).withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(height: 16),
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

class LeaveApprovalPipeline extends StatelessWidget {
  const LeaveApprovalPipeline({super.key, required this.steps});

  final List<LeaveApprovalStep> steps;

  @override
  Widget build(BuildContext context) {
    final active = steps
        .where((s) => !s.isSuperseded)
        .toList()
      ..sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
    if (active.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Approval status',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white60 : const Color(0xFF607D8B),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: active.map((step) => _StepChip(step: step, isDark: isDark)).toList(),
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.step, required this.isDark});

  final LeaveApprovalStep step;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final who = (step.approverName?.trim().isNotEmpty == true)
        ? step.approverName!.trim()
        : step.roleLabel;

    Color bg;
    Color border;
    Color text;
    if (step.isDone) {
      bg = Colors.green.withValues(alpha: 0.12);
      border = Colors.green;
      text = Colors.green.shade700;
    } else if (step.isRejected) {
      bg = Colors.red.withValues(alpha: 0.12);
      border = Colors.red;
      text = Colors.red.shade700;
    } else {
      bg = Colors.orange.withValues(alpha: 0.12);
      border = Colors.orange;
      text = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$who · ${step.statusLabel}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }
}
