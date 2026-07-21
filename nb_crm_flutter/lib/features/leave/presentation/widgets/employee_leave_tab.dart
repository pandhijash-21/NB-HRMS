import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../screens/admin_leaves_screen.dart';
import 'leave_shared_widgets.dart';

/// Admin HR Leave tab (port of frontend LeaveTab.tsx).
class EmployeeLeaveTab extends ConsumerStatefulWidget {
  const EmployeeLeaveTab({super.key, required this.employeeId});

  final int employeeId;

  @override
  ConsumerState<EmployeeLeaveTab> createState() => _EmployeeLeaveTabState();
}

class _EmployeeLeaveTabState extends ConsumerState<EmployeeLeaveTab> {
  late int _year;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final balancesAsync = ref.watch(
      adminEmployeeBalancesProvider(
        (employeeId: widget.employeeId, year: _year),
      ),
    );
    final appsAsync = ref.watch(
      adminEmployeeApplicationsProvider(
        (employeeId: widget.employeeId, year: _year, page: _page),
      ),
    );

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  Text(
                    'Balances and application history',
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                _year -= 1;
                _page = 0;
              }),
              icon: Icon(Icons.chevron_left),
            ),
            Text('$_year', style: TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              onPressed: _year >= DateTime.now().year
                  ? null
                  : () => setState(() {
                        _year += 1;
                        _page = 0;
                      }),
              icon: Icon(Icons.chevron_right),
            ),
            SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => showAdminApplyOnBehalfDialog(
                context,
                ref,
                presetEmployeeId: widget.employeeId,
              ),
              icon: Icon(Icons.add, size: 18),
              label: Text('Apply Leave'),
            ),
          ],
        ),
        SizedBox(height: 16),
        LeaveAsyncBody<List<LeaveBalance>>(
          value: balancesAsync,
          emptyMessage: 'No leave types / balances.',
          onRetry: () => ref.invalidate(
            adminEmployeeBalancesProvider(
              (employeeId: widget.employeeId, year: _year),
            ),
          ),
          builder: (balances) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: balances.map((b) {
              final adminOnly = !(b.leaveType?.employeeCanApply ?? true);
              return SizedBox(
                width: 160,
                child: Card(
                  elevation: 0,
                  color: adminOnly
                      ? AppColors.mist.withValues(alpha: 0.6)
                      : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.leaveType?.code ?? '—',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          b.displayAvailable.toStringAsFixed(
                            b.displayAvailable == b.displayAvailable.roundToDouble()
                                ? 0
                                : 1,
                          ),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          b.leaveType?.name ?? 'Leave',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Used ${b.used.toStringAsFixed(0)}'
                          '${b.pending > 0 ? ' · Pending ${b.pending.toStringAsFixed(0)}' : ''}',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                        if (adminOnly)
                          Text(
                            'Admin only',
                            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 24),
        Text(
          'Applications',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        SizedBox(height: 8),
        LeaveAsyncBody<LeaveApplicationsPage>(
          value: appsAsync,
          emptyMessage: 'No applications for $_year.',
          onRetry: () => ref.invalidate(
            adminEmployeeApplicationsProvider(
              (employeeId: widget.employeeId, year: _year, page: _page),
            ),
          ),
          builder: (page) {
            if (page.items.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No applications for this year.')),
              );
            }
            return Column(
              children: [
                ...page.items.map(
                  (a) => LeaveApplicationCard(
                    application: a,
                    subtitle: a.isAppliedByAdmin ? 'Applied by admin' : null,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: _page > 0
                          ? () => setState(() => _page -= 1)
                          : null,
                      icon: Icon(Icons.chevron_left),
                    ),
                    Text('Page ${_page + 1}'),
                    IconButton(
                      onPressed: (_page + 1) * 8 < page.total
                          ? () => setState(() => _page += 1)
                          : null,
                      icon: Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
