import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/leave_repository.dart';
import '../../domain/leave_models.dart';

String _formatYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Dedicated Work From Home (WFH) Section displayed in Leave Hub
class WfhSectionCard extends StatefulWidget {
  const WfhSectionCard({
    super.key,
    required this.canAdmin,
    this.onRefresh,
  });

  final bool canAdmin;
  final VoidCallback? onRefresh;

  @override
  State<WfhSectionCard> createState() => _WfhSectionCardState();
}

class _WfhSectionCardState extends State<WfhSectionCard> {
  bool _loading = true;
  bool _isEligible = false;
  bool _isAdmin = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadEligibility();
  }

  Future<void> _loadEligibility() async {
    try {
      final repo = context.read<LeaveRepository>();
      final res = await repo.getWfhEligibility();
      final myApps = await repo.getMyWfhApplications();
      if (mounted) {
        setState(() {
          _isEligible = res['eligible'] == true;
          _isAdmin = res['isAdmin'] == true || widget.canAdmin;
          _pendingCount = myApps.where((a) => a.status.toUpperCase() == 'PENDING').length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isEligible = widget.canAdmin;
          _isAdmin = widget.canAdmin;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (!_isEligible && !_isAdmin) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = Color(0xFF0D9488); // Teal-600

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Work From Home (WFH)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF212F3D),
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 12, color: accentColor),
                  const SizedBox(width: 4),
                  Text(
                    _isAdmin ? 'Admin / WFH Enabled' : 'Eligible for WFH',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF162522) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.25 : 0.2),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.08 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.home_work_rounded,
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remote Working & WFH Requests',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF212F3D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submit your work from home requests with full 3-tier approval. Once approved, dates automatically display in your attendance calendar.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => showApplyWfhDialog(
                      context,
                      onSuccess: () {
                        _loadEligibility();
                        widget.onRefresh?.call();
                      },
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.add_task_rounded, size: 16),
                    label: const Text(
                      'Apply for WFH',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showMyWfhRequestsDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : const Color(0xFF212F3D),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                    ),
                    label: Text(
                      _pendingCount > 0
                          ? 'My Requests ($_pendingCount Pending)'
                          : 'My WFH Requests',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  if (_isAdmin)
                    OutlinedButton.icon(
                      onPressed: () => showAdminWfhConfigDialog(
                        context,
                        onSaved: () {
                          _loadEligibility();
                        },
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: const BorderSide(color: accentColor, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.checklist_rounded, size: 16),
                      label: const Text(
                        'Manage Employee WFH Access',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dialog: Apply for Work From Home (From Date, To Date, Reason)
Future<void> showApplyWfhDialog(BuildContext context, {VoidCallback? onSuccess}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  const accentColor = Color(0xFF0D9488);

  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  final reasonCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isSubmitting = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dlgCtx) {
      return StatefulBuilder(
        builder: (ctx, setDlgState) {
          final daysDiff = toDate.difference(fromDate).inDays + 1;
          final workingDays = daysDiff < 1 ? 1 : daysDiff;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.home_work_rounded, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Apply for WFH',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select the date range and provide a reason for your remote working period.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Date range selectors
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'From Date *',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: fromDate,
                                      firstDate: DateTime(DateTime.now().year - 1),
                                      lastDate: DateTime(DateTime.now().year + 2),
                                    );
                                    if (picked != null) {
                                      setDlgState(() {
                                        fromDate = picked;
                                        if (toDate.isBefore(fromDate)) {
                                          toDate = fromDate;
                                        }
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF8FAFC),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 16, color: accentColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatYmd(fromDate),
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'To Date *',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: toDate.isBefore(fromDate) ? fromDate : toDate,
                                      firstDate: fromDate,
                                      lastDate: DateTime(DateTime.now().year + 2),
                                    );
                                    if (picked != null) {
                                      setDlgState(() => toDate = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF8FAFC),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 16, color: accentColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatYmd(toDate),
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: accentColor),
                            const SizedBox(width: 8),
                            Text(
                              'Duration: $workingDays calendar day${workingDays > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Reason for WFH *',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: reasonCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter reason (e.g. Project delivery, personal emergency, etc.)...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.grey.shade400,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: accentColor, width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a reason for your WFH request';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDlgState(() => isSubmitting = true);
                        try {
                          final repo = context.read<LeaveRepository>();
                          await repo.applyWfh(
                            fromDate: _formatYmd(fromDate),
                            toDate: _formatYmd(toDate),
                            reason: reasonCtrl.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('WFH request submitted successfully. Sent for reporting approvals.'),
                                backgroundColor: Color(0xFF0D9488),
                              ),
                            );
                            onSuccess?.call();
                          }
                        } catch (e) {
                          setDlgState(() => isSubmitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to submit WFH request: $e')),
                            );
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit WFH Request', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Dialog: Admin WFH Configuration (Multi-select Checkboxes for all Employees)
Future<void> showAdminWfhConfigDialog(BuildContext context, {VoidCallback? onSaved}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  const accentColor = Color(0xFF0D9488);

  final repo = context.read<LeaveRepository>();
  Map<String, dynamic>? config;
  bool loading = true;
  String? error;

  try {
    config = await repo.getAdminWfhConfig();
    loading = false;
  } catch (e) {
    error = e.toString();
    loading = false;
  }

  if (!context.mounted) return;

  final searchCtrl = TextEditingController();
  final selectedIds = Set<int>.from(
    (config?['allowedEmployeeIds'] as List<dynamic>? ?? []).map((e) => (e as num).toInt()),
  );
  final allEmployees = List<Map<String, dynamic>>.from(
    (config?['employees'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
  );
  bool isSaving = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dlgCtx) {
      return StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (loading) {
            return const AlertDialog(
              content: SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(color: accentColor),
                ),
              ),
            );
          }

          if (error != null) {
            return AlertDialog(
              title: const Text('Error Loading WFH Config'),
              content: Text(error),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = allEmployees.where((emp) {
            final name = (emp['fullName'] ?? '').toString().toLowerCase();
            final code = (emp['employeeCode'] ?? '').toString().toLowerCase();
            final dept = (emp['department'] ?? '').toString().toLowerCase();
            final desig = (emp['designation'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                code.contains(query) ||
                dept.contains(query) ||
                desig.contains(query);
          }).toList();

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.manage_accounts_rounded, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WFH Employee Access',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Select employees who are allowed to view and apply for WFH',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 480,
              child: Column(
                children: [
                  // Search & Quick Select Strip
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (_) => setDlgState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search employee name, code, department...',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white38 : Colors.grey.shade400,
                            ),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            suffixIcon: searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      setDlgState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${selectedIds.length} of ${allEmployees.length} Selected',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setDlgState(() {
                            for (final e in filtered) {
                              final id = (e['id'] as num).toInt();
                              selectedIds.add(id);
                            }
                          });
                        },
                        icon: const Icon(Icons.done_all_rounded, size: 14),
                        label: const Text('Select All Filtered', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () {
                          setDlgState(() {
                            for (final e in filtered) {
                              final id = (e['id'] as num).toInt();
                              selectedIds.remove(id);
                            }
                          });
                        },
                        icon: const Icon(Icons.remove_done_rounded, size: 14),
                        label: const Text('Deselect Filtered', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  // Employee list with checkboxes
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No employees match your search.',
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (listCtx, i) {
                              final emp = filtered[i];
                              final id = (emp['id'] as num).toInt();
                              final isSelected = selectedIds.contains(id);
                              final name = emp['fullName']?.toString() ?? 'Employee #$id';
                              final code = emp['employeeCode']?.toString() ?? '';
                              final dept = emp['department']?.toString() ?? '';
                              final desig = emp['designation']?.toString() ?? '';

                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: accentColor,
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                onChanged: (val) {
                                  setDlgState(() {
                                    if (val == true) {
                                      selectedIds.add(id);
                                    } else {
                                      selectedIds.remove(id);
                                    }
                                  });
                                },
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    if (code.isNotEmpty) 'ID: $code',
                                    if (dept.isNotEmpty) dept,
                                    if (desig.isNotEmpty) desig,
                                  ].join(' • '),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDlgState(() => isSaving = true);
                        try {
                          await repo.updateAdminWfhConfig(selectedIds.toList());
                          if (context.mounted) {
                            Navigator.pop(dlgCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'WFH access updated. ${selectedIds.length} employee${selectedIds.length == 1 ? '' : 's'} can now view and apply for WFH.',
                                ),
                                backgroundColor: accentColor,
                              ),
                            );
                            onSaved?.call();
                          }
                        } catch (e) {
                          setDlgState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to save WFH configuration: $e')),
                            );
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Save Permissions (${selectedIds.length})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Dialog: Show Employee's WFH Requests History & Approval Progress
Future<void> showMyWfhRequestsDialog(BuildContext context) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  const accentColor = Color(0xFF0D9488);

  final repo = context.read<LeaveRepository>();
  List<LeaveApplication> apps = [];
  bool loading = true;
  String? error;

  try {
    apps = await repo.getMyWfhApplications();
    loading = false;
  } catch (e) {
    error = e.toString();
    loading = false;
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dlgCtx) {
      return AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.history_rounded, color: accentColor, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'My WFH Requests',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 400,
          child: loading
              ? const Center(child: CircularProgressIndicator(color: accentColor))
              : error != null
                  ? Center(child: Text(error))
                  : apps.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.home_work_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No WFH requests submitted yet.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: apps.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final app = apps[i];
                            final statusStr = app.status.toUpperCase();
                            final isApproved = statusStr == 'APPROVED';
                            final isRejected = statusStr == 'REJECTED';

                            final statusColor = isApproved
                                ? const Color(0xFF0D9488)
                                : isRejected
                                    ? Colors.red
                                    : Colors.orange;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        app.applicationNo,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          statusStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Dates: ${app.fromDate} to ${app.toDate} (${app.totalDays.toInt()} day${app.totalDays > 1 ? 's' : ''})',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                  ),
                                  if (app.reason.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Reason: ${app.reason}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                                      ),
                                    ),
                                  ],
                                  if (app.approvalSteps.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: app.approvalSteps.map((step) {
                                        final isDone = step.action != null;
                                        final isStepApproved = (step.action ?? '').toUpperCase() == 'APPROVED' ||
                                            (step.action ?? '').toUpperCase() == 'RECOMMENDED';
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isDone
                                                    ? (isStepApproved ? Icons.check_circle_rounded : Icons.cancel_rounded)
                                                    : Icons.radio_button_unchecked_rounded,
                                                size: 13,
                                                color: isDone
                                                    ? (isStepApproved ? const Color(0xFF0D9488) : Colors.red)
                                                    : Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Tier ${step.stepNumber}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
