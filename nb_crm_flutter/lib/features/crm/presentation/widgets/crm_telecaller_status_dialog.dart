import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';

void showTelecallerStatusDialog(
  BuildContext context, {
  VoidCallback? onDispatched,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _TelecallerStatusDialog(onDispatched: onDispatched),
  );
}

class _TelecallerStatusDialog extends StatefulWidget {
  final VoidCallback? onDispatched;

  const _TelecallerStatusDialog({this.onDispatched});

  @override
  State<_TelecallerStatusDialog> createState() => _TelecallerStatusDialogState();
}

class _TelecallerStatusDialogState extends State<_TelecallerStatusDialog> {
  bool _isLoading = true;
  bool _isDistributing = false;
  String? _errorMessage;
  WaitingQueueStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<CrmRepository>();
      final res = await repo.getWaitingQueueStatus();
      if (mounted) {
        setState(() {
          _status = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDistribute() async {
    setState(() => _isDistributing = true);
    try {
      final repo = context.read<CrmRepository>();
      final res = await repo.dispatchWaitingQueue();
      final dispatched = res['dispatchedCount'] ?? 0;
      final remaining = res['remainingQueuedCount'] ?? 0;
      final active = res['activeTelecallersCount'] ?? 0;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⚡ Distributed $dispatched leads across $active active telecallers! ($remaining still in Waiting List)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        widget.onDispatched?.call();
        await _loadStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Failed to distribute: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDistributing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final primaryColor = isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.people_alt_rounded, color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Telecaller Activity & Waiting List',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Live telecaller attendance, screen presence & workload allocation',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh Status',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _isLoading ? null : _loadStatus,
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadStatus,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_status != null) ...[
                // Metric Summary Row
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildMetricPill(
                      title: 'Waiting List (WL)',
                      value: '${_status!.queuedLeadsCount} Leads',
                      icon: Icons.hourglass_top_rounded,
                      color: const Color(0xFFD97706),
                      isDark: isDark,
                    ),
                    _buildMetricPill(
                      title: 'Active on Screen',
                      value: '${_status!.activeTelecallersCount} / ${_status!.totalTelecallersCount}',
                      icon: Icons.screen_search_desktop_rounded,
                      color: const Color(0xFF16A34A),
                      isDark: isDark,
                    ),
                    _buildMetricPill(
                      title: 'Available Capacity',
                      value: '${_status!.totalAvailableCapacity} Slots',
                      icon: Icons.bolt_rounded,
                      color: const Color(0xFF2563EB),
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Distribute Banner / Action
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: (_status!.queuedLeadsCount > 0 && _status!.activeTelecallersCount > 0)
                        ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                        : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (_status!.queuedLeadsCount > 0 && _status!.activeTelecallersCount > 0)
                          ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                          : borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_mode_rounded,
                        size: 20,
                        color: (_status!.queuedLeadsCount > 0 && _status!.activeTelecallersCount > 0)
                            ? const Color(0xFF16A34A)
                            : textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _status!.queuedLeadsCount > 0
                              ? '${_status!.queuedLeadsCount} leads waiting. Auto-distribution allocates to punched-in, active telecallers with free workload capacity.'
                              : 'Waiting list is clear! All leads are currently assigned.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: (_isDistributing || _status!.queuedLeadsCount == 0 || _status!.activeTelecallersCount == 0)
                            ? null
                            : _handleDistribute,
                        icon: _isDistributing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.bolt_rounded, size: 16),
                        label: Text(_isDistributing ? 'Distributing...' : 'Distribute Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Telecallers List
                Row(
                  children: [
                    Text(
                      'Telecalling Staff Status (${_status!.telecallers.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    Text('Auto-refreshes on CRM activity', style: TextStyle(fontSize: 11, color: textMuted)),
                  ],
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: _status!.telecallers.isEmpty
                      ? Center(
                          child: Text(
                            'No telecallers configured for this CRM scope.',
                            style: TextStyle(color: textMuted, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _status!.telecallers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final t = _status!.telecallers[index];
                            return _buildTelecallerRow(t, isDark, borderColor, textMuted, primaryColor);
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelecallerRow(
    TelecallerPresenceInfo t,
    bool isDark,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    final bool isOnline = t.isActiveOnScreen && t.presenceStatus == 'ACTIVE';
    final double workloadRatio = t.maxCapacity > 0 ? (t.currentWorkload / t.maxCapacity).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with Status Dot
          Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: primaryColor.withValues(alpha: 0.15),
                child: Text(
                  t.fullName.isNotEmpty ? t.fullName[0].toUpperCase() : 'T',
                  style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 14),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF1E1B18) : Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Name and info
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.fullName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '${t.designation ?? "Telecaller"} ${t.subOrganization != null ? "• ${t.subOrganization}" : ""}',
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ),
          ),

          // Attendance Punch Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: t.isPunchedIn
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : (isDark ? Colors.white12 : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  t.isPunchedIn ? Icons.how_to_reg_rounded : Icons.person_off_rounded,
                  size: 13,
                  color: t.isPunchedIn ? const Color(0xFF059669) : textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  t.isPunchedIn ? 'Punched In' : 'Not Punched In',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: t.isPunchedIn ? const Color(0xFF059669) : textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Screen Activity Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? Icons.check_circle_rounded : Icons.coffee_rounded,
                  size: 13,
                  color: isOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'Active' : 'On Break (${t.inactiveDurationFormatted})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Workload Progress & Available slots
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Workload', style: TextStyle(fontSize: 10, color: textMuted)),
                    Text(
                      '${t.currentWorkload}/${t.maxCapacity} (${t.availableCapacity} free)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: t.availableCapacity > 0 ? const Color(0xFF10B981) : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: workloadRatio,
                    minHeight: 5,
                    backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      workloadRatio > 0.85
                          ? Colors.red
                          : (workloadRatio > 0.6 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Eligibility status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: t.isEligibleForDispatch
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              t.isEligibleForDispatch ? '⚡ Eligible' : '⏸️ ${t.ineligibleReason ?? "Unavailable"}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: t.isEligibleForDispatch ? const Color(0xFF059669) : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
