import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../../core/widgets/header_action_button.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Leave Admin',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: const AppBackButton(fallbackLocation: '/leave'),
        actions: [
          HeaderActionButton(
            tooltip: 'Leave Approvals',
            label: 'Approvals',
            icon: const Icon(Icons.rule_rounded, size: 18, color: Color(0xFFC5A059)),
            onPressed: () => context.go('/approvals'),
          ),
          HeaderActionButton(
            tooltip: 'Settings',
            label: 'Settings',
            icon: const Icon(Icons.settings_rounded, size: 18, color: Color(0xFFC5A059)),
            onPressed: () => context.go('/admin/leaves/settings'),
          ),
          HeaderActionButton(
            tooltip: 'Holidays',
            label: 'Holidays',
            icon: const Icon(Icons.event_rounded, size: 18, color: Color(0xFFC5A059)),
            onPressed: () => context.go('/admin/leaves/holidays'),
          ),
          HeaderActionButton(
            tooltip: 'Apply on behalf',
            label: 'Apply on behalf',
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFFC5A059)),
            onPressed: () => showAdminApplyOnBehalfDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0.0, 30.0 * (1.0 - value)),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Search name, code, app no, or ID',
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFC5A059), size: 18),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(adminApplicationsFilterProvider.notifier).setSearch('');
                                setState(() {});
                              },
                            ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
                      ),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    onChanged: (v) {
                      ref.read(adminApplicationsFilterProvider.notifier).setSearch(v);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: filters.status.isEmpty ? '' : filters.status,
                          dropdownColor: isDark ? const Color(0xFF2B2722) : Colors.white,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('All')),
                            DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                            DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                            DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                            DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                          ],
                          onChanged: (v) => ref.read(adminApplicationsFilterProvider.notifier).setStatus(v ?? ''),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: filters.year,
                          dropdownColor: isDark ? const Color(0xFF2B2722) : Colors.white,
                          decoration: InputDecoration(
                            labelText: 'Year',
                            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: List.generate(5, (i) {
                            final y = DateTime.now().year - 2 + i;
                            return DropdownMenuItem<int?>(
                              value: y,
                              child: Text('$y'),
                            );
                          }),
                          onChanged: (v) => ref.read(adminApplicationsFilterProvider.notifier).setYear(v),
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
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_busy_rounded, size: 64, color: isDark ? Colors.white10 : Colors.black12),
                            const SizedBox(height: 16),
                            Text(
                              'No leave applications.',
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
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: page.items.length,
                          itemBuilder: (ctx, i) {
                            final app = page.items[i];
                            final isPending = app.status.toUpperCase() == 'PENDING';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: LeaveApplicationCard(
                                application: app,
                                subtitle: app.employee?.fullName ??
                                    (app.employee != null ? 'Employee #${app.employee!.id}' : null),
                                trailing: isPending
                                    ? TextButton(
                                        onPressed: () => context.go('/approvals'),
                                        child: const Text('Review in Approvals'),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                      _PagingBar(
                        page: filters.page,
                        pageSize: filters.limit,
                        total: page.total,
                        onPrev: filters.page > 0
                            ? () => ref.read(adminApplicationsFilterProvider.notifier).setPage(filters.page - 1)
                            : null,
                        onNext: (filters.page + 1) * filters.limit < page.total
                            ? () => ref.read(adminApplicationsFilterProvider.notifier).setPage(filters.page + 1)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAdminApplyOnBehalfDialog(context, ref),
        backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
        foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Apply on behalf', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$from–$to of $total',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF212F3D),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            style: IconButton.styleFrom(
              backgroundColor: onPrev != null
                  ? (isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC).withOpacity(0.3))
                  : Colors.transparent,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            style: IconButton.styleFrom(
              backgroundColor: onNext != null
                  ? (isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC).withOpacity(0.3))
                  : Colors.transparent,
            ),
          ),
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
  bool _uploadingDoc = false;
  String? _documentUrl;
  String? _documentName;

  LeaveType? get _selectedType {
    if (_leaveTypeId == null) return null;
    try {
      return widget.types.firstWhere((t) => t.id == _leaveTypeId);
    } catch (_) {
      return null;
    }
  }

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
    if (_selectedType?.requiresDocument == true &&
        (_documentUrl == null || _documentUrl!.isEmpty)) {
      return 'Supporting document is required for this leave type.';
    }
    return null;
  }

  Future<void> _pickDocument() async {
    final empId = int.tryParse(_employeeIdCtrl.text.trim());
    if (empId == null || empId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter employee ID before uploading a document.')),
      );
      return;
    }
    final picked = await pickFileFromDevice(
      imagesOnly: false,
      extensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked == null) return;
    setState(() => _uploadingDoc = true);
    try {
      final url = await widget.parentRef.read(leaveRepositoryProvider).uploadLeaveDocument(
            employeeId: empId,
            bytes: picked.bytes,
            filename: picked.name,
          );
      if (!mounted) return;
      setState(() {
        _documentUrl = url;
        _documentName = picked.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingDoc = false);
    }
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
        if (_documentUrl != null) 'documentUrl': _documentUrl,
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

  InputDecoration _styledInput(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Apply leave on behalf',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF212F3D),
        ),
      ),
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
                decoration: _styledInput('Employee ID *', isDark).copyWith(
                  hintText: 'Numeric employee ID',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _leaveTypeId,
                decoration: _styledInput('Leave type *', isDark),
                dropdownColor: isDark ? const Color(0xFF2B2722) : Colors.white,
                items: widget.types
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(
                          '${t.code} — ${t.name}${t.employeeCanApply ? '' : ' (admin)'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _leaveTypeId = v;
                  _documentUrl = null;
                  _documentName = null;
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                        ),
                      ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(
                          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                        ),
                      ),
                      onPressed: _isHalfDay
                          ? null
                          : () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _toDate ?? _fromDate ?? DateTime.now(),
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (d != null) setState(() => _toDate = d);
                            },
                      child: Text(
                        _isHalfDay
                            ? (_fromDate == null ? 'To (= from)' : formatDateYmd(_fromDate!))
                            : (_toDate == null ? 'To *' : formatDateYmd(_toDate!)),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _isHalfDay
                              ? (isDark ? Colors.white38 : Colors.grey)
                              : (isDark ? Colors.white : const Color(0xFF212F3D)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC),
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    'Half day',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                  value: _isHalfDay,
                  activeColor: const Color(0xFFC5A059),
                  onChanged: (v) => setState(() {
                    _isHalfDay = v;
                    if (v) {
                      _toDate = _fromDate;
                    } else {
                      _halfDaySession = null;
                    }
                  }),
                ),
              ),
              if (_isHalfDay) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _halfDaySession,
                  decoration: _styledInput('Session *', isDark),
                  dropdownColor: isDark ? const Color(0xFF2B2722) : Colors.white,
                  items: const [
                    DropdownMenuItem(value: 'MORNING', child: Text('Morning')),
                    DropdownMenuItem(value: 'AFTERNOON', child: Text('Afternoon')),
                  ],
                  onChanged: (v) => setState(() => _halfDaySession = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _reasonCtrl,
                decoration: _styledInput('Reason *', isDark),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: _styledInput(
                  _selectedType?.requiresDocument == true
                      ? 'Supporting document *'
                      : 'Supporting document',
                  isDark,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _documentName ??
                            (_selectedType?.requiresDocument == true
                                ? 'Upload required (PDF/image)'
                                : 'Optional PDF or image'),
                        style: TextStyle(
                          color: _documentUrl != null
                              ? (isDark ? Colors.white : const Color(0xFF212F3D))
                              : (isDark ? Colors.white54 : const Color(0xFF607D8B)),
                        ),
                      ),
                    ),
                    if (_documentUrl != null)
                      TextButton(
                        onPressed: _uploadingDoc || _submitting
                            ? null
                            : () => setState(() {
                                  _documentUrl = null;
                                  _documentName = null;
                                }),
                        child: const Text('Remove'),
                      ),
                    TextButton(
                      onPressed: _uploadingDoc || _submitting ? null : _pickDocument,
                      child: _uploadingDoc
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_documentUrl == null ? 'Upload' : 'Replace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting || _uploadingDoc ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF607D8B))),
        ),
        FilledButton(
          onPressed: _submitting || _uploadingDoc ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            _submitting ? 'Applying…' : 'Apply Leave',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
