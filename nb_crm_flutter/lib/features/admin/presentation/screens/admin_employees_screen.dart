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
          OutlinedButton.icon(
            onPressed: () => _showPositionsDialog(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
              side: BorderSide(
                color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFF263238).withOpacity(0.5),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFC5A059)),
            label: const Text('Positions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 8),
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
            _buildPositionsOverview(context),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1816) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: positionsAsync.when(
        data: (positions) {
          if (positions.isEmpty) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    'No positions yet. Use Manage to create one.',
                    style: TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white30 : const Color(0xFF607D8B),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showPositionsDialog(context),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFC5A059)),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Create Position', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFC5A059)),
                  const SizedBox(width: 8),
                  Text(
                    'Institutional Positions (${positions.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showPositionsDialog(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFC5A059),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    child: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: positions
                      .map(
                        (p) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  p.linkedRoleName,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFFC5A059) : const Color(0xFF607D8B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(color: Color(0xFFC5A059)),
        error: (_, __) => Row(
          children: [
            const Expanded(
              child: Text(
                'Failed to load positions.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      title: Text(
        'Onboard New Employee',
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF212F3D),
          fontWeight: FontWeight.w800,
        ),
      ),
      scrollable: true,
      content: SizedBox(
        width: 440,
        child: Form(
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
                dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF212F3D), fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'Employee Category',
                  border: OutlineInputBorder(),
                ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF212F3D),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickJoiningDate,
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFC5A059)),
                    icon: const Icon(Icons.calendar_today_rounded, size: 14),
                    label: const Text('Select Date', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
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
          child: const Text('Onboard Employee', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
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
        SnackBar(content: Text('Onboarding failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildDialogField(String label, TextEditingController ctrl, {bool required = false, bool isEmail = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      title: Text(
        'Institutional Positions',
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF212F3D),
          fontWeight: FontWeight.w800,
        ),
      ),
      scrollable: true,
      content: SizedBox(
        width: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            positionsAsync.when(
              data: (positions) {
                if (positions.isEmpty) {
                  return const Text(
                    'No positions yet. Create one below, then configure permissions in Roles.',
                    style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                  );
                }
                return Column(
                  children: positions
                      .map(
                        (p) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            title: Text(p.name, style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D))),
                            subtitle: Text('Role: ${p.linkedRoleName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
              error: (err, _) => Column(
                children: [
                  Text('Failed to load: $err', style: const TextStyle(color: Colors.red)),
                  TextButton(
                    onPressed: () => ref.invalidate(positionsListProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Text(
              'Create New Position',
              style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D), fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _displayNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Position Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final suggested = _suggestRoleCode(v);
                if (_roleNameCtrl.text.isEmpty || _roleNameCtrl.text == _suggestRoleCode(_displayNameCtrl.text)) {
                  _roleNameCtrl.text = suggested;
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Role Code',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: TextStyle(
              color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        FilledButton(
          onPressed: _creating ||
                  _displayNameCtrl.text.trim().isEmpty ||
                  _roleNameCtrl.text.trim().isEmpty
              ? null
              : _createPosition,
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _creating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create Position', style: TextStyle(fontWeight: FontWeight.w800)),
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
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
