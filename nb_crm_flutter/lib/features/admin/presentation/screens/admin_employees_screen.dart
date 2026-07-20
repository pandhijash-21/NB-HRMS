import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/name_utils.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../auth/domain/permissions.dart';
import '../../presentation/admin_notifier.dart';
import '../../../profile/domain/profile_models.dart';
import '../../domain/admin_models.dart';
import '../../../org/presentation/org_providers.dart';
import '../../../lookups/presentation/lookup_providers.dart';
import '../../../rbac/presentation/rbac_providers.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Gate screen with RBAC
    final hasAccess = Permissions.canViewWorkforce(
      authState.permissions,
      authState.user?.employeeViewScope,
    );

    if (!hasAccess) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gpp_bad_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w800, 
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to view the workforce administration.',
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filters = ref.watch(workforceFilterProvider);
    final workforceListAsync = ref.watch(workforceListProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Workforce Directory',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh list',
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
            ),
            onPressed: () => ref.read(workforceListProvider.notifier).refresh(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: SizedBox(
              height: 38,
              child: FilledButton.icon(
                onPressed: () => _showAddEmployeeDialog(context),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Employee', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ),
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
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Column(
          children: [
            _buildFilterBar(context, filters),
            Expanded(
              child: workforceListAsync.when(
                data: (data) {
                  final List<EmployeeProfile> list = data['items'] as List<EmployeeProfile>;
                  final total = data['total'] as int;

                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_alt_rounded,
                            size: 64,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No employees found matching filters.',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load employee list\n$err', 
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, WorkforceFilterState filters) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or code...',
                hintStyle: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFC5A059), size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFC5A059),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF212F3D),
                fontSize: 14,
              ),
              onChanged: (val) {
                ref.read(workforceFilterProvider.notifier).setSearch(val.trim());
              },
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                width: 1.2,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: filters.status.isEmpty ? 'ALL' : filters.status,
                dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF212F3D), 
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFC5A059)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(emp.status);
    final initials = emp.generalInfo?.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join('') ?? '?';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/admin/employees/${emp.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFF263238).withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFECEFF1),
                  backgroundImage: emp.photoUrl != null && emp.photoUrl!.isNotEmpty
                      ? NetworkImage(emp.photoUrl!)
                      : null,
                  child: emp.photoUrl == null || emp.photoUrl!.isEmpty
                      ? Text(
                          initials.length > 2 ? initials.substring(0, 2).toUpperCase() : initials.toUpperCase(),
                          style: TextStyle(
                            color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238), 
                            fontWeight: FontWeight.bold, 
                            fontSize: 13,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.generalInfo?.fullName ?? 'Unnamed Employee',
                      style: TextStyle(
                        fontWeight: FontWeight.w800, 
                        fontSize: 15, 
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${emp.generalInfo?.designation ?? "No Designation"}  ·  ${emp.generalInfo?.department ?? "No Dept"}',
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                    ),
                    if (emp.generalInfo?.employeeCode != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2B2722) : const Color(0xFFECEFF1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Code: ${emp.generalInfo!.employeeCode}',
                          style: TextStyle(
                            fontSize: 10, 
                            color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238), 
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      border: Border.all(color: statusColor, width: 1.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      emp.status,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                    onPressed: () => _showConfirmDeleteDialog(context, emp),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Deactivate Employee',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${filters.page * filters.limit + 1} - ${List.of([
              (filters.page + 1) * filters.limit,
              total
            ]).reduce((a, b) => a < b ? a : b)} of $total',
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: currentPage > 0 
                      ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238)) 
                      : Colors.grey.withOpacity(0.4),
                ),
                onPressed: currentPage > 0
                    ? () => ref.read(workforceFilterProvider.notifier).setPage(currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Page ${currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF263238),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: currentPage < totalPages - 1
                      ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238)) 
                      : Colors.grey.withOpacity(0.4),
                ),
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
        return isDark(context) ? const Color(0xFFC5A059) : const Color(0xFF263238);
    }
  }

  bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  void _showConfirmDeleteDialog(BuildContext context, EmployeeProfile emp) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
        title: Text(
          'Deactivate Employee',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to deactivate ${emp.generalInfo?.fullName ?? "this employee"}?',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF607D8B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
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
                  SnackBar(content: Text('Deactivation failed: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Deactivate', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showAddEmployeeDialog(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (_) => const _AddEmployeeDialog(),
    ).then((created) {
      if (created is! ({EmployeeProfile profile, String? initialPassword})) return;
      final name = created.profile.generalInfo?.fullName ?? '';
      if (name.isNotEmpty) {
        _searchController.text = name;
      }
      final pwd = created.initialPassword;
      if (!mounted) return;
      if (pwd != null && pwd.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 12),
            content: Text(
              'Employee created. Temporary password (DOB): $pwd — they must change it on first login.',
            ),
          ),
        );
      }
    });
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
  static const _fallbackOrgs = ['Gandhinagar University', 'Platinum Foundation'];
  static const _fallbackCategories = ['TEACHING', 'NON_TEACHING', 'CONTRACT', 'VISITING'];

  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _personalEmailCtrl = TextEditingController();
  final _instEmailCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _employeeCodeCtrl = TextEditingController();
  final _abbreviationCtrl = TextEditingController();

  String? _organization;
  String? _instituteId;
  String? _designation;
  String? _roleId;
  String _category = 'TEACHING';
  DateTime? _joiningDate;
  DateTime? _birthDate;
  String? _firstApproverUserId;
  String? _secondApproverUserId;
  String? _thirdApproverUserId;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _personalEmailCtrl.dispose();
    _instEmailCtrl.dispose();
    _departmentCtrl.dispose();
    _employeeCodeCtrl.dispose();
    _abbreviationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final institutesAsync = ref.watch(activeInstitutesProvider);
    final designationsAsync = ref.watch(jobDesignationsProvider);
    final rolesAsync = ref.watch(allRolesProvider);
    final namesAsync = ref.watch(employeeNamesProvider);
    final orgLookups = ref.watch(activeLookupsByCategoryProvider('ORGANIZATION'));
    final catLookups = ref.watch(activeLookupsByCategoryProvider('EMPLOYEE_CATEGORY'));
    final institutes = institutesAsync.asData?.value ?? const [];
    final designations = designationsAsync.asData?.value ?? const [];
    final roles = rolesAsync.asData?.value ?? const [];
    final names = namesAsync.asData?.value ?? const [];
    final organizations = (orgLookups.asData?.value ?? const [])
        .map((o) => o.label)
        .toList();
    final orgItems = organizations.isNotEmpty ? organizations : _fallbackOrgs;
    final categories = (catLookups.asData?.value ?? const [])
        .map((o) => o.code)
        .toList();
    final categoryItems = categories.isNotEmpty ? categories : _fallbackCategories;
    final organizationValue = _organization ??
        (orgItems.contains('Gandhinagar University')
            ? 'Gandhinagar University'
            : orgItems.first);

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Onboard New Employee',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF212F3D),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Establish a new institutional record. Login password defaults to birth date (DDMMYYYY).',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : const Color(0xFF607D8B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      scrollable: true,
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildDialogField('Full Name', _fullNameCtrl, required: true, hint: 'e.g. Dr. Rajesh Kumar', onChanged: (v) {
                setState(() => _abbreviationCtrl.text = generateAbbreviation(v));
              }),
              _buildDialogField('Employee Code', _employeeCodeCtrl, required: true, hint: 'e.g. GU1234'),
              _buildReadOnlyDialogField(
                'Abbreviation',
                _abbreviationCtrl.text.isEmpty ? '—' : _abbreviationCtrl.text,
                helper: 'Auto-generated from name (e.g. Jash Pandhi → JP)',
              ),
              _buildDialogField('Personal Email (Gmail)', _personalEmailCtrl, required: true, isEmail: true, hint: 'yourname@gmail.com'),
              _buildDialogField(
                'Institutional Email (Optional)',
                _instEmailCtrl,
                isEmail: true,
                hint: 'firstname.lastname@gandhinagaruni.ac.in',
                helper: 'Format: firstname.lastname@gandhinagaruni.ac.in',
              ),
              _buildDropdown(
                isDark: isDark,
                label: 'Role',
                value: _roleId,
                helper: 'RBAC role for permissions. Leave empty for default EMPLOYEE.',
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Default (EMPLOYEE)')),
                  ...roles.map(
                    (r) => DropdownMenuItem<String?>(value: r.id, child: Text(r.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _roleId = v),
              ),
              _buildDropdown(
                isDark: isDark,
                label: 'Organization *',
                value: organizationValue,
                items: orgItems
                    .map((org) => DropdownMenuItem<String?>(value: org, child: Text(org)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _organization = v);
                },
              ),
              _buildDropdown(
                isDark: isDark,
                label: 'Institute *',
                value: _instituteId,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Select institute...')),
                  ...institutes.map(
                    (inst) => DropdownMenuItem<String?>(value: inst.id, child: Text(inst.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _instituteId = v),
                validator: (v) => v == null ? 'Institute is required' : null,
              ),
              _buildDropdown(
                isDark: isDark,
                label: 'Designation *',
                value: _designation,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Select designation...')),
                  ...designations.map(
                    (d) => DropdownMenuItem<String?>(value: d.name, child: Text(d.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _designation = v),
                validator: (v) => v == null || v.isEmpty ? 'Designation is required' : null,
              ),
              _buildDialogField('Department', _departmentCtrl, required: true, hint: 'e.g. Comp. Science'),
              _buildDropdown(
                isDark: isDark,
                label: 'Engagement Category *',
                value: categoryItems.contains(_category) ? _category : categoryItems.first,
                items: categoryItems
                    .map((c) => DropdownMenuItem<String?>(
                          value: c,
                          child: Text(c.replaceAll('_', ' ')),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
              _buildDateRow(isDark),
              _buildBirthDateRow(isDark),
              _buildApproverDropdown(isDark, '1st Reporting', _firstApproverUserId, names, (v) {
                setState(() => _firstApproverUserId = v);
              }),
              _buildApproverDropdown(isDark, '2nd Reporting', _secondApproverUserId, names, (v) {
                setState(() => _secondApproverUserId = v);
              }),
              _buildApproverDropdown(isDark, '3rd Reporting', _thirdApproverUserId, names, (v) {
                setState(() => _thirdApproverUserId = v);
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Finalize Records', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _buildDateRow(bool isDark) {
    final label = _joiningDate == null
        ? 'Appointment Date *'
        : 'Appointment Date *: ${_formatDate(_joiningDate!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF212F3D),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _pickJoiningDate,
            icon: const Icon(Icons.calendar_today_rounded, size: 14),
            label: const Text('Select Date'),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthDateRow(bool isDark) {
    final label = _birthDate == null
        ? 'Birth Date * (login password)'
        : 'Birth Date *: ${_formatDate(_birthDate!)} → ${_dobPassword(_birthDate!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF212F3D),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _pickBirthDate,
                icon: const Icon(Icons.cake_outlined, size: 14),
                label: const Text('Select DOB'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 0, top: 2),
            child: Text(
              'Temporary password is DDMMYYYY from this date (e.g. 15 Mar 1998 → 15031998).',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : const Color(0xFF607D8B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dobPassword(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd$mm$yyyy';
  }

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Widget _buildDropdown({
    required bool isDark,
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
    String? helper,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: value,
            dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF212F3D),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            items: items,
            onChanged: onChanged,
            validator: validator,
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                helper,
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF607D8B)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApproverDropdown(
    bool isDark,
    String label,
    String? value,
    List<EmployeeNameOption> names,
    ValueChanged<String?> onChanged,
  ) {
    return _buildDropdown(
      isDark: isDark,
      label: label,
      value: value,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('NULL (bypass this layer)'),
        ),
        ...names.map(
          (item) => DropdownMenuItem<String?>(
            value: item.userId,
            child: Text(item.displayLabel),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Future<void> _pickJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _joiningDate = picked);
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      helpText: 'Select birth date (becomes login password)',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_joiningDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment date is required'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Birth date is required (sets the login password)'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_instituteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Institute is required'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_designation == null || _designation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Designation is required'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'fullName': _fullNameCtrl.text.trim(),
      'personalEmail': _personalEmailCtrl.text.trim(),
      'institutionalEmail': _instEmailCtrl.text.trim().isEmpty ? null : _instEmailCtrl.text.trim(),
      'employeeCode': _employeeCodeCtrl.text.trim(),
      'abbreviation': generateAbbreviation(_fullNameCtrl.text.trim()),
      'organization': _organization ?? 'Gandhinagar University',
      'designation': _designation,
      'department': _departmentCtrl.text.trim(),
      'instituteId': _instituteId,
      'employeeCategory': _category,
      'joiningDate': _joiningDate!.toIso8601String(),
      'birthDate': _ymd(_birthDate!),
      'roleId': _roleId,
      'firstApproverUserId': _firstApproverUserId,
      'secondApproverUserId': _secondApproverUserId,
      'thirdApproverUserId': _thirdApproverUserId,
    };

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref.read(workforceListProvider.notifier).createEmployee(data);
      navigator.pop(created);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Onboarding failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildReadOnlyDialogField(String label, String value, {String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(helper, style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B))),
            ),
        ],
      ),
    );
  }

  Widget _buildDialogField(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    bool isEmail = false,
    String? hint,
    String? helper,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: ctrl,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: required ? '$label *' : label,
              hintText: hint,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              if (required && (v == null || v.trim().isEmpty)) {
                return '$label is required';
              }
              if (isEmail && v != null && v.trim().isNotEmpty) {
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(v.trim())) {
                  return 'Enter a valid email address';
                }
                if (label.toLowerCase().contains('gmail') &&
                    !v.trim().toLowerCase().endsWith('@gmail.com')) {
                  return 'Personal email must be a Gmail address';
                }
              }
              return null;
            },
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(helper, style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B))),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
