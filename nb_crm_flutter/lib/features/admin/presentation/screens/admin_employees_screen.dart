import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../auth/domain/permissions.dart';
import '../../presentation/admin_notifier.dart';
import '../../../profile/domain/profile_models.dart';
import '../../../org/presentation/org_providers.dart';

class AdminEmployeesScreen extends ConsumerStatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  ConsumerState<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends ConsumerState<AdminEmployeesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Gate screen with RBAC
    final hasAccess = Permissions.canViewWorkforce(
      authState.permissions,
      authState.user?.employeeViewScope,
    );

    if (!hasAccess) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gpp_bad, size: 64, color: AppColors.error),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.midnight),
              ),
              SizedBox(height: 8),
              Text(
                'You do not have permission to view the workforce administration.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final filters = ref.watch(workforceFilterProvider);
    final workforceListAsync = ref.watch(workforceListProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Workforce Directory'),
        actions: [
          OutlinedButton.icon(
            onPressed: () => _showPositionsDialog(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            icon: const Icon(Icons.shield_outlined, size: 16),
            label: const Text('Positions'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(workforceListProvider.notifier).refresh(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEmployeeDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bronze,
                foregroundColor: AppColors.midnight,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Employee'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPositionsOverview(context),
          _buildFilterBar(context, filters),
          Expanded(
            child: workforceListAsync.when(
              data: (data) {
                final List<EmployeeProfile> list = data['items'] as List<EmployeeProfile>;
                final total = data['total'] as int;

                if (list.isEmpty) {
                  return const Center(child: Text('No employees found matching filters.'));
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final emp = list[index];
                          return _buildEmployeeCard(context, emp);
                        },
                      ),
                    ),
                    _buildPaginationControls(context, filters, total),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.bronze),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Failed to load employee list\n$err', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.read(workforceListProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, WorkforceFilterState filters) {
    return Container(
      color: AppColors.midnight,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or code...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white60),
                filled: true,
                fillColor: AppColors.slate,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                // Instantly update search state in filter notifier
                ref.read(workforceFilterProvider.notifier).setSearch(val.trim());
              },
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.slate,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: filters.status.isEmpty ? 'ALL' : filters.status,
                dropdownColor: AppColors.midnight,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'ON_LEAVE', child: Text('On Leave')),
                  DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                  DropdownMenuItem(value: 'RESIGNED', child: Text('Resigned')),
                  DropdownMenuItem(value: 'TERMINATED', child: Text('Terminated')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(workforceFilterProvider.notifier).setStatus(val == 'ALL' ? '' : val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(BuildContext context, EmployeeProfile emp) {
    final statusColor = _getStatusColor(emp.status);
    final initials = emp.generalInfo?.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join('') ?? '?';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/admin/employees/${emp.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.mist,
                backgroundImage: emp.photoUrl != null && emp.photoUrl!.isNotEmpty
                    ? NetworkImage(emp.photoUrl!)
                    : null,
                child: emp.photoUrl == null || emp.photoUrl!.isEmpty
                    ? Text(
                        initials.length > 2 ? initials.substring(0, 2).toUpperCase() : initials.toUpperCase(),
                        style: const TextStyle(color: AppColors.midnight, fontWeight: FontWeight.bold, fontSize: 14),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.generalInfo?.fullName ?? 'Unnamed Employee',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.midnight),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${emp.generalInfo?.designation ?? "No Designation"}  |  ${emp.generalInfo?.department ?? "No Dept"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (emp.generalInfo?.employeeCode != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Code: ${emp.generalInfo!.employeeCode}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ]
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      emp.status,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    onPressed: () => _showConfirmDeleteDialog(context, emp),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls(BuildContext context, WorkforceFilterState filters, int total) {
    final totalPages = (total / filters.limit).ceil();
    final currentPage = filters.page;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${filters.page * filters.limit + 1} - ${List.of([
              (filters.page + 1) * filters.limit,
              total
            ]).reduce((a, b) => a < b ? a : b)} of $total',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 0
                    ? () => ref.read(workforceFilterProvider.notifier).setPage(currentPage - 1)
                    : null,
              ),
              Text(
                'Page ${currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage < totalPages - 1
                    ? () => ref.read(workforceFilterProvider.notifier).setPage(currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'ON_LEAVE':
        return Colors.orange;
      case 'INACTIVE':
      case 'RESIGNED':
      case 'RETIRED':
        return Colors.grey;
      case 'TERMINATED':
        return Colors.red;
      default:
        return AppColors.bronze;
    }
  }

  void _showConfirmDeleteDialog(BuildContext context, EmployeeProfile emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Employee'),
        content: Text('Are you sure you want to deactivate ${emp.generalInfo?.fullName ?? "this employee"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await ref.read(workforceListProvider.notifier).deleteEmployee(emp.id);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Employee deactivated successfully')),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Deactivation failed: $e'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('Deactivate', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showAddEmployeeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddEmployeeDialog(),
    ).then((created) {
      if (created is EmployeeProfile) {
        final name = created.generalInfo?.fullName ?? '';
        if (name.isNotEmpty) {
          _searchController.text = name;
        }
      }
    });
  }

  void _showPositionsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _PositionsDialog(),
    );
  }

  Widget _buildPositionsOverview(BuildContext context) {
    final positionsAsync = ref.watch(positionsListProvider);

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: positionsAsync.when(
        data: (positions) {
          if (positions.isEmpty) {
            return Row(
              children: [
                const Expanded(
                  child: Text(
                    'No positions yet. Use Positions to create one.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showPositionsDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Position'),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: AppColors.midnight),
                  const SizedBox(width: 8),
                  Text(
                    'Institutional Positions (${positions.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.midnight,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showPositionsDialog(context),
                    child: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: positions
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.midnight.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.midnight,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.linkedRoleName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(color: AppColors.bronze),
        error: (_, __) => Row(
          children: [
            const Expanded(
              child: Text(
                'Failed to load positions.',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(positionsListProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ADD EMPLOYEE DIALOG
// =============================================================================

class _AddEmployeeDialog extends ConsumerStatefulWidget {
  const _AddEmployeeDialog();

  @override
  ConsumerState<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends ConsumerState<_AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _personalEmailCtrl = TextEditingController();
  final _instEmailCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _employeeCodeCtrl = TextEditingController();
  final _subOrgCtrl = TextEditingController(text: 'GIT');
  String _category = 'TEACHING';
  DateTime _joiningDate = DateTime.now();

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _personalEmailCtrl.dispose();
    _instEmailCtrl.dispose();
    _designationCtrl.dispose();
    _departmentCtrl.dispose();
    _employeeCodeCtrl.dispose();
    _subOrgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Onboard New Employee'),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildDialogField('Full Name', _fullNameCtrl, required: true),
            _buildDialogField('Personal Email', _personalEmailCtrl, required: true, isEmail: true),
            _buildDialogField('Institutional Email', _instEmailCtrl, isEmail: true),
            _buildDialogField('Employee Code', _employeeCodeCtrl, required: true),
            _buildDialogField('Designation', _designationCtrl, required: true),
            _buildDialogField('Department', _departmentCtrl, required: true),
            _buildDialogField('Sub-Organization (e.g. GIT, GIC)', _subOrgCtrl),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Employee Category'),
              items: const [
                DropdownMenuItem(value: 'TEACHING', child: Text('Teaching / Faculty')),
                DropdownMenuItem(value: 'NON_TEACHING', child: Text('Non-Teaching / Admin')),
                DropdownMenuItem(value: 'SUPPORT', child: Text('Support Staff')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Joining Date: ${_formatDate(_joiningDate)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: _pickJoiningDate,
                  child: const Text('Select Date'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Onboard')),
      ],
    );
  }

  Future<void> _pickJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _joiningDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'fullName': _fullNameCtrl.text.trim(),
      'personalEmail': _personalEmailCtrl.text.trim(),
      'institutionalEmail': _instEmailCtrl.text.trim().isEmpty ? null : _instEmailCtrl.text.trim(),
      'employeeCode': _employeeCodeCtrl.text.trim(),
      'designation': _designationCtrl.text.trim(),
      'department': _departmentCtrl.text.trim(),
      'subOrganization': _subOrgCtrl.text.trim().isEmpty ? null : _subOrgCtrl.text.trim(),
      'employeeCategory': _category,
      'joiningDate': _joiningDate.toIso8601String(),
    };

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref.read(workforceListProvider.notifier).createEmployee(data);
      navigator.pop(created);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Onboarding failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildDialogField(String label, TextEditingController ctrl, {bool required = false, bool isEmail = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: required ? '$label *' : label),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) {
            return '$label is required';
          }
          if (isEmail && v != null && v.trim().isNotEmpty) {
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(v.trim())) {
              return 'Enter a valid email address';
            }
          }
          return null;
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _PositionsDialog extends ConsumerStatefulWidget {
  const _PositionsDialog();

  @override
  ConsumerState<_PositionsDialog> createState() => _PositionsDialogState();
}

class _PositionsDialogState extends ConsumerState<_PositionsDialog> {
  final _displayNameCtrl = TextEditingController();
  final _roleNameCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _roleNameCtrl.dispose();
    super.dispose();
  }

  String _suggestRoleCode(String label) {
    final words = label.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    if (words.length == 1) return words.first.toUpperCase().substring(0, words.first.length.clamp(0, 12));
    return words.map((w) => w[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final positionsAsync = ref.watch(positionsListProvider);

    return AlertDialog(
      title: const Text('Institutional Positions'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            positionsAsync.when(
              data: (positions) {
                if (positions.isEmpty) {
                  return const Text(
                    'No positions yet. Create one below, then configure permissions in Roles.',
                    style: TextStyle(color: AppColors.textSecondary),
                  );
                }
                return Column(
                  children: positions
                      .map(
                        (p) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Role: ${p.linkedRoleName}'),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bronze)),
              error: (err, _) => Column(
                children: [
                  Text('Failed to load: $err'),
                  TextButton(
                    onPressed: () => ref.invalidate(positionsListProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            const Text(
              'Create position',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.midnight),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _displayNameCtrl,
              decoration: const InputDecoration(labelText: 'Position name'),
              onChanged: (v) {
                final suggested = _suggestRoleCode(v);
                if (_roleNameCtrl.text.isEmpty || _roleNameCtrl.text == _suggestRoleCode(_displayNameCtrl.text)) {
                  _roleNameCtrl.text = suggested;
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _roleNameCtrl,
              decoration: const InputDecoration(labelText: 'Role code'),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton(
          onPressed: _creating ||
                  _displayNameCtrl.text.trim().isEmpty ||
                  _roleNameCtrl.text.trim().isEmpty
              ? null
              : _createPosition,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.bronze,
            foregroundColor: AppColors.midnight,
          ),
          child: _creating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create position'),
        ),
      ],
    );
  }

  Future<void> _createPosition() async {
    setState(() => _creating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orgRepositoryProvider).createPosition(
            displayName: _displayNameCtrl.text.trim(),
            roleName: _roleNameCtrl.text.trim().toUpperCase(),
          );
      _displayNameCtrl.clear();
      _roleNameCtrl.clear();
      ref.invalidate(positionsListProvider);
      ref.invalidate(positionDesignationsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Position created')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
