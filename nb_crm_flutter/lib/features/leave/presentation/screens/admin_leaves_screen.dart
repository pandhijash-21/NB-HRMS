import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

class AdminLeavesScreen extends ConsumerStatefulWidget {
  const AdminLeavesScreen({super.key});

  @override
  ConsumerState<AdminLeavesScreen> createState() => _AdminLeavesScreenState();
}

class _AdminLeavesScreenState extends ConsumerState<AdminLeavesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(adminApplicationsFilterProvider);
    final appsAsync = ref.watch(adminApplicationsProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Leave Admin'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            tooltip: 'Pending queue',
            icon: const Icon(Icons.pending_actions),
            onPressed: () => context.go('/admin/leaves/pending'),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/admin/leaves/settings'),
          ),
          IconButton(
            tooltip: 'Holidays',
            icon: const Icon(Icons.event),
            onPressed: () => context.go('/admin/leaves/holidays'),
          ),
          IconButton(
            tooltip: 'Apply on behalf',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => showAdminApplyOnBehalfDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search name, code, application no, or employee ID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref
                                  .read(adminApplicationsFilterProvider.notifier)
                                  .setSearch('');
                              setState(() {});
                            },
                          ),
                  ),
                  onChanged: (v) {
                    ref
                        .read(adminApplicationsFilterProvider.notifier)
                        .setSearch(v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: filters.status.isEmpty ? '' : filters.status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('All')),
                          DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                          DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                          DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                          DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                        ],
                        onChanged: (v) => ref
                            .read(adminApplicationsFilterProvider.notifier)
                            .setStatus(v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: filters.year,
                        decoration: const InputDecoration(labelText: 'Year'),
                        items: List.generate(5, (i) {
                          final y = DateTime.now().year - 2 + i;
                          return DropdownMenuItem<int?>(
                            value: y,
                            child: Text('$y'),
                          );
                        }),
                        onChanged: (v) => ref
                            .read(adminApplicationsFilterProvider.notifier)
                            .setYear(v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: LeaveAsyncBody<LeaveApplicationsPage>(
              value: appsAsync,
              emptyMessage: 'No leave applications.',
              onRetry: () => ref.invalidate(adminApplicationsProvider),
              builder: (page) {
                if (page.items.isEmpty) {
                  return const Center(child: Text('No leave applications.'));
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: page.items.length,
                        itemBuilder: (ctx, i) {
                          final app = page.items[i];
                          final isPending = app.status.toUpperCase() == 'PENDING';
                          return LeaveApplicationCard(
                            application: app,
                            subtitle: app.employee?.fullName ??
                                (app.employee != null
                                    ? 'Employee #${app.employee!.id}'
                                    : null),
                            trailing: isPending
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Approve',
                                        icon: const Icon(Icons.check_circle_outline,
                                            color: AppColors.success),
                                        onPressed: () =>
                                            _act(app.id, approve: true),
                                      ),
                                      IconButton(
                                        tooltip: 'Reject',
                                        icon: const Icon(Icons.cancel_outlined,
                                            color: AppColors.error),
                                        onPressed: () =>
                                            _act(app.id, approve: false),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                    _PagingBar(
                      page: filters.page,
                      pageSize: filters.limit,
                      total: page.total,
                      onPrev: filters.page > 0
                          ? () => ref
                              .read(adminApplicationsFilterProvider.notifier)
                              .setPage(filters.page - 1)
                          : null,
                      onNext: (filters.page + 1) * filters.limit < page.total
                          ? () => ref
                              .read(adminApplicationsFilterProvider.notifier)
                              .setPage(filters.page + 1)
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAdminApplyOnBehalfDialog(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Apply on behalf'),
      ),
    );
  }

  Future<void> _act(String id, {required bool approve}) async {
    final remarksCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve leave' : 'Reject leave'),
        content: TextField(
          controller: remarksCtrl,
          decoration: const InputDecoration(labelText: 'Remarks (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      remarksCtrl.dispose();
      return;
    }
    try {
      final repo = ref.read(leaveRepositoryProvider);
      if (approve) {
        await repo.approveApplication(id, remarks: remarksCtrl.text.trim());
      } else {
        await repo.rejectApplication(id, remarks: remarksCtrl.text.trim());
      }
      invalidateLeaveApprovalData(ref);
      invalidateLeaveAdminData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Approved' : 'Rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      remarksCtrl.dispose();
    }
  }
}

class _PagingBar extends StatelessWidget {
  const _PagingBar({
    required this.page,
    required this.pageSize,
    required this.total,
    this.onPrev,
    this.onNext,
  });

  final int page;
  final int pageSize;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : page * pageSize + 1;
    final to = ((page + 1) * pageSize).clamp(0, total);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('$from–$to of $total'),
          const Spacer(),
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

/// Shared apply-on-behalf dialog (employee ID + admin leave types).
Future<void> showAdminApplyOnBehalfDialog(
  BuildContext context,
  WidgetRef ref, {
  int? presetEmployeeId,
}) async {
  List<LeaveType> types;
  try {
    types = await ref.read(adminLeaveTypesProvider.future);
    types = types.where((t) => t.isActive).toList();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load leave types: $e')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  if (types.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No active leave types configured.')),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => _ApplyOnBehalfDialog(
      types: types,
      presetEmployeeId: presetEmployeeId,
      parentRef: ref,
    ),
  );
}

class _ApplyOnBehalfDialog extends ConsumerStatefulWidget {
  const _ApplyOnBehalfDialog({
    required this.types,
    required this.parentRef,
    this.presetEmployeeId,
  });

  final List<LeaveType> types;
  final int? presetEmployeeId;
  final WidgetRef parentRef;

  @override
  ConsumerState<_ApplyOnBehalfDialog> createState() =>
      _ApplyOnBehalfDialogState();
}

class _ApplyOnBehalfDialogState extends ConsumerState<_ApplyOnBehalfDialog> {
  final _employeeIdCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String? _leaveTypeId;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isHalfDay = false;
  String? _halfDaySession;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.presetEmployeeId != null) {
      _employeeIdCtrl.text = '${widget.presetEmployeeId}';
    }
  }

  @override
  void dispose() {
    _employeeIdCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final empId = int.tryParse(_employeeIdCtrl.text.trim());
    if (empId == null || empId <= 0) return 'Enter a valid employee ID.';
    if (_leaveTypeId == null) return 'Select a leave type.';
    if (_fromDate == null) return 'Select from date.';
    if (!_isHalfDay && _toDate == null) return 'Select to date.';
    if (_isHalfDay && _halfDaySession == null) {
      return 'Select half-day session (Morning / Afternoon).';
    }
    final to = _isHalfDay ? _fromDate! : _toDate!;
    if (to.isBefore(_fromDate!)) return 'To date must be on or after from date.';
    if (_reasonCtrl.text.trim().length < 5) {
      return 'Reason must be at least 5 characters.';
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _submitting = true);
    final empId = int.parse(_employeeIdCtrl.text.trim());
    final to = _isHalfDay ? _fromDate! : _toDate!;
    try {
      await widget.parentRef.read(leaveRepositoryProvider).adminApplyLeave({
        'employeeId': empId,
        'leaveTypeId': _leaveTypeId,
        'fromDate': formatDateYmd(_fromDate!),
        'toDate': formatDateYmd(to),
        'isHalfDay': _isHalfDay,
        'halfDaySession': _isHalfDay ? _halfDaySession : null,
        'reason': _reasonCtrl.text.trim(),
      });
      invalidateLeaveAdminData(widget.parentRef);
      widget.parentRef.invalidate(
        adminEmployeeBalancesProvider((employeeId: empId, year: _fromDate!.year)),
      );
      widget.parentRef.invalidate(
        adminEmployeeApplicationsProvider(
          (employeeId: empId, year: _fromDate!.year, page: 0),
        ),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave applied on behalf of employee')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Apply leave on behalf'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _employeeIdCtrl,
                enabled: widget.presetEmployeeId == null,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Employee ID *',
                  hintText: 'Numeric employee ID',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _leaveTypeId,
                decoration: const InputDecoration(labelText: 'Leave type *'),
                items: widget.types
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(
                          '${t.code} — ${t.name}${t.employeeCanApply ? '' : ' (admin-only)'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _leaveTypeId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _fromDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (d != null) {
                          setState(() {
                            _fromDate = d;
                            if (_isHalfDay) _toDate = d;
                          });
                        }
                      },
                      child: Text(
                        _fromDate == null ? 'From *' : formatDateYmd(_fromDate!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isHalfDay
                          ? null
                          : () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _toDate ?? _fromDate ?? DateTime.now(),
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 365)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 730)),
                              );
                              if (d != null) setState(() => _toDate = d);
                            },
                      child: Text(
                        _isHalfDay
                            ? (_fromDate == null
                                ? 'To (= from)'
                                : formatDateYmd(_fromDate!))
                            : (_toDate == null ? 'To *' : formatDateYmd(_toDate!)),
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Half day'),
                value: _isHalfDay,
                onChanged: (v) => setState(() {
                  _isHalfDay = v;
                  if (v) {
                    _toDate = _fromDate;
                  } else {
                    _halfDaySession = null;
                  }
                }),
              ),
              if (_isHalfDay)
                DropdownButtonFormField<String>(
                  value: _halfDaySession,
                  decoration: const InputDecoration(labelText: 'Session *'),
                  items: const [
                    DropdownMenuItem(value: 'MORNING', child: Text('Morning')),
                    DropdownMenuItem(value: 'AFTERNOON', child: Text('Afternoon')),
                  ],
                  onChanged: (v) => setState(() => _halfDaySession = v),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason *'),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Applying…' : 'Apply leave'),
        ),
      ],
    );
  }
}
