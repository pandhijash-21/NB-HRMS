import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/utils/password_policy.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../admin/domain/admin_models.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/rbac_repository.dart';
import '../../domain/rbac_models.dart';
import '../bloc/admin_users_bloc.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<AdminUsersBloc>();
    if (bloc.state.status == LoadStatus.initial) {
      bloc.add(const AdminUsersLoadRequested());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      context.read<AdminUsersBloc>().add(AdminUsersFiltersChanged(search: value.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!Permissions.canManageUsers(auth.permissions, auth.user?.role)) {
      return _accessDenied(context);
    }

    final usersState = context.watch<AdminUsersBloc>().state;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'System Users',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: const AppBackButton(),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh list',
            label: 'Refresh',
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF212F3D),
            ),
            onPressed: () => context.read<AdminUsersBloc>().add(const AdminUsersLoadRequested()),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: SizedBox(
              height: 38,
              child: FilledButton.icon(
                onPressed: () => _showAddUserDialog(usersState.roles),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add User', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
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
            _buildFilterBar(context, usersState),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (usersState.status == LoadStatus.loading && usersState.users.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                    );
                  }
                  if (usersState.status == LoadStatus.failure && usersState.users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load users\n${usersState.errorMessage ?? ''}', 
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => context.read<AdminUsersBloc>().add(const AdminUsersLoadRequested()),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final currentUserRole = auth.user?.role;
                  final isSuperAdmin = Permissions.isSuperAdmin(currentUserRole);
                  final scopedUsers = isSuperAdmin
                      ? usersState.users
                      : usersState.users.where((u) => !Permissions.isSuperAdmin(u.role.name) && (u.username?.toLowerCase() != 'superadmin')).toList();
                  final visible = usersState.lockedOnly
                      ? scopedUsers.where((u) => u.isLoginLocked).toList()
                      : scopedUsers;
                  if (visible.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 64,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            usersState.lockedOnly
                                ? 'No locked / blocked logins right now.'
                                : 'No users found matching filters.',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white30 : const Color(0xFF607D8B).withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final u = visible[index];
                      final isTargetAdmin = Permissions.isAdmin(u.role.name);
                      final isTargetSuperAdmin = Permissions.isSuperAdmin(u.role.name);
                      final canManageTargetAdmin = isSuperAdmin || !isTargetAdmin;
                      final canManageTargetAccount = isSuperAdmin || !isTargetSuperAdmin;
                      return _UserCard(
                        user: u,
                        isAdmin: Permissions.isAdmin(currentUserRole),
                        isSuperAdmin: isSuperAdmin,
                        canEdit: canManageTargetAdmin,
                        canDelete: canManageTargetAdmin,
                        canUnblock: canManageTargetAdmin,
                        canViewCredentials: canManageTargetAccount,
                        onCredentials: () => _showCredentialsDialog(u),
                        onEdit: () => _showEditUserDialog(u, usersState.roles),
                        onDelete: () => _confirmDelete(u),
                        onUnblock: () => _unblockLogin(u),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accessDenied(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              'You do not have permission to manage users.',
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

  Widget _buildFilterBar(
    BuildContext context,
    AdminUsersState state,
  ) {
    final roles = state.roles;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.12) : const Color(0xFFCFD8DC),
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
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or code...',
                hintStyle: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF607D8B).withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFC5A059), size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFFCFD8DC),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
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
            ),
          ),
          const SizedBox(width: 12),
          _filterDropdown(
            label: 'Status',
            value: state.statusFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'true', child: Text('Active')),
              DropdownMenuItem(value: 'false', child: Text('Inactive')),
            ],
            onChanged: (v) {
              if (v != null) context.read<AdminUsersBloc>().add(AdminUsersFiltersChanged(status: v));
            },
          ),
          const SizedBox(width: 12),
          _filterDropdown(
            label: 'Role',
            value: state.roleIdFilter,
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Roles')),
              ...roles.map(
                (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
              ),
            ],
            onChanged: (v) {
              if (v != null) context.read<AdminUsersBloc>().add(AdminUsersFiltersChanged(roleId: v));
            },
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('Locked only'),
            selected: state.lockedOnly,
            avatar: Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: state.lockedOnly ? Colors.white : Colors.orange,
            ),
            selectedColor: Colors.orange,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: state.lockedOnly
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF263238)),
            ),
            onSelected: (v) =>
                context.read<AdminUsersBloc>().add(AdminUsersFiltersChanged(lockedOnly: v)),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
          width: 1.2,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((i) => i.value == value) ? value : items.first.value,
          dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D), 
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFC5A059)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _showAddUserDialog(
    List<RoleSummary> allRoles,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserRole = context.read<AuthBloc>().state.user?.role;
    final isSuperAdmin = Permissions.isSuperAdmin(currentUserRole);

    // Form controllers
    bool isCompanyAdminMode = isSuperAdmin;
    final companyNameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController(text: '01011998');
    final employeeInputController = TextEditingController();

    final defaultSystemAdminRoleId = allRoles
        .firstWhere(
          (r) => r.name == 'SYSTEM_ADMIN' || r.name == 'ADMIN',
          orElse: () => allRoles.first,
        )
        .id;
    String? roleId = isSuperAdmin ? defaultSystemAdminRoleId : null;

    int? selectedEmployeeId;
    String? selectedEmployeeCode;
    final roles = allRoles.where((r) {
      if (isSuperAdmin) return true;
      return !Permissions.isAdmin(r.name);
    }).toList();
    List<EmployeeNameOption> names = const [];
    try {
      names = await context.read<AdminRepository>().listEmployeeNames();
    } catch (_) {}
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFFCFD8DC),
              width: 1.5,
            ),
          ),
          title: Text(
            isSuperAdmin && isCompanyAdminMode
                ? 'Create Company System Admin'
                : 'Create User Account',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF212F3D),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSuperAdmin) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.25) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() {
                                isCompanyAdminMode = true;
                                roleId = defaultSystemAdminRoleId;
                              }),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isCompanyAdminMode
                                      ? (isDark ? const Color(0xFFC5A059) : const Color(0xFF263238))
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                                ),
                                child: Text(
                                  'Client Company Admin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isCompanyAdminMode
                                        ? (isDark ? const Color(0xFF1A1816) : Colors.white)
                                        : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() {
                                isCompanyAdminMode = false;
                                roleId = null;
                              }),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !isCompanyAdminMode
                                      ? (isDark ? const Color(0xFFC5A059) : const Color(0xFF263238))
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                                ),
                                child: Text(
                                  'Employee User',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: !isCompanyAdminMode
                                        ? (isDark ? const Color(0xFF1A1816) : Colors.white)
                                        : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isSuperAdmin) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.12) : const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.3) : const Color(0xFFFFD54F),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFFF57F17),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Only Superadmin can create Admin accounts.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF795548),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isSuperAdmin && isCompanyAdminMode) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.08) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFF93C5FD),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.business_rounded, size: 18, color: isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Create a System Admin account for a client company. They will manage their own company CRM.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF1E40AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: companyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Company / Organization Name',
                        hintText: 'e.g. Acme Corp, Alpha Builders Ltd.',
                        helperText: 'The tenant company receiving this CRM instance',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Admin Username',
                        hintText: 'e.g. acme_admin, company_admin',
                        helperText: 'Unique login identifier for the company admin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Initial Password',
                        hintText: 'e.g. 01011998',
                        helperText: 'Password given to the company admin (default: 01011998)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: roleId,
                      dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF212F3D), fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        labelText: 'Admin Role Tier',
                        helperText: 'Leave as SYSTEM_ADMIN for full company CRM control',
                        border: OutlineInputBorder(),
                      ),
                      items: allRoles
                          .where((r) => Permissions.isAdmin(r.name))
                          .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                          .toList(),
                      onChanged: (v) => roleId = v,
                    ),
                  ] else ...[
                    if (names.isNotEmpty) ...[
                      DropdownButtonFormField<EmployeeNameOption?>(
                        initialValue: null,
                        dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF212F3D), fontWeight: FontWeight.w600, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Select Employee',
                          helperText: 'Pick an employee to automatically link',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Choose from list or type below...')),
                          ...names.map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e.displayLabel,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (opt) {
                          setDialogState(() {
                            if (opt != null) {
                              selectedEmployeeId = opt.employeeId;
                              selectedEmployeeCode = opt.employeeCode;
                              employeeInputController.text = opt.employeeCode ?? opt.employeeId?.toString() ?? '';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextField(
                      controller: employeeInputController,
                      decoration: const InputDecoration(
                        labelText: 'Employee Code or ID',
                        hintText: 'e.g. 007, IT5, or numeric ID',
                        helperText: 'Enter employee code (e.g. 007) or employee database ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: null,
                      dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF212F3D), fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        labelText: 'Assign Role',
                        border: OutlineInputBorder(),
                      ),
                      items: roles
                          .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                          .toList(),
                      onChanged: (v) => roleId = v,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                isSuperAdmin && isCompanyAdminMode ? 'Provision Company Admin' : 'Create Account',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    if (isSuperAdmin && isCompanyAdminMode) {
      final username = usernameController.text.trim();
      final companyName = companyNameController.text.trim();
      final password = passwordController.text.trim();
      if (username.isEmpty || roleId == null || roleId!.isEmpty) {
        _showSnack('Please provide an admin username and role.');
        return;
      }
      final payload = <String, dynamic>{
        'roleId': roleId,
        'username': username,
        'password': password.isNotEmpty ? password : '01011998',
        if (companyName.isNotEmpty) 'subOrganization': companyName,
      };
      context.read<AdminUsersBloc>().add(AdminUserCreated(payload));
      return;
    }

    final inputVal = employeeInputController.text.trim();
    if (inputVal.isEmpty || roleId == null || roleId!.isEmpty) {
      _showSnack('Please select or enter an employee code/ID and choose a role.');
      return;
    }

    final parsedNum = int.tryParse(inputVal);
    final finalEmpId = selectedEmployeeId ?? parsedNum;
    final finalEmpCode = (selectedEmployeeCode != null && selectedEmployeeCode!.isNotEmpty)
        ? selectedEmployeeCode
        : inputVal;

    final payload = <String, dynamic>{
      'roleId': roleId,
    };
    if (finalEmpId != null) payload['employeeId'] = finalEmpId;
    if (finalEmpCode != null && finalEmpCode.isNotEmpty) payload['employeeCode'] = finalEmpCode;

    context.read<AdminUsersBloc>().add(AdminUserCreated(payload));
  }

  Future<void> _showEditUserDialog(
    UserAccount user,
    List<RoleSummary> allRoles,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserRole = context.read<AuthBloc>().state.user?.role;
    final isSuperAdmin = Permissions.isSuperAdmin(currentUserRole);
    final targetIsSuperAdmin = Permissions.isSuperAdmin(user.role.name);
    final targetIsAdmin = Permissions.isAdmin(user.role.name);

    if (targetIsSuperAdmin && !isSuperAdmin) {
      _showSnack('Only Superadmin can modify a Superadmin account.');
      return;
    }

    var isActive = user.isActive;
    var roleId = user.roleId;
    final roles = allRoles.where((r) {
      if (isSuperAdmin) return true;
      if (r.id == user.roleId) return true;
      return !Permissions.isAdmin(r.name);
    }).toList();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFFCFD8DC),
              width: 1.5,
            ),
          ),
          title: Text(
            'Edit User Account',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF212F3D),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName, 
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.displaySubtitle, 
                        style: TextStyle(
                          color: isDark ? Colors.white30 : const Color(0xFF607D8B), 
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (targetIsAdmin && !isSuperAdmin) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.12) : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.3) : const Color(0xFFFFD54F),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFFF57F17),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin accounts can only be modified by Superadmin.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF795548),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCredentialsDialog(user);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                    side: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.4) : const Color(0xFFCFD8DC),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.key_outlined, size: 16, color: Color(0xFFC5A059)),
                  label: const Text('View login & password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: roles.any((r) => r.id == roleId) ? roleId : null,
                  dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF212F3D), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: 'Assigned Role',
                    border: OutlineInputBorder(),
                  ),
                  items: roles
                      .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                      .toList(),
                  onChanged: (targetIsAdmin && !isSuperAdmin) ? null : (v) => setLocal(() => roleId = v ?? roleId),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<bool>(
                  initialValue: isActive,
                  dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF212F3D), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Active (Can Login)')),
                    DropdownMenuItem(value: false, child: Text('Inactive (Suspended)')),
                  ],
                  onChanged: (targetIsAdmin && !isSuperAdmin) ? null : (v) => setLocal(() => isActive = v ?? isActive),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!targetIsAdmin || isSuperAdmin)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    final payload = <String, dynamic>{};
    if (isActive != user.isActive) payload['isActive'] = isActive;
    if (roleId != user.roleId) payload['roleId'] = roleId;

    if (payload.isEmpty) return;

    context.read<AdminUsersBloc>().add(AdminUserUpdated(id: user.id, data: payload));
  }

  Future<void> _showCredentialsDialog(UserAccount user) async {
    final currentUserRole = context.read<AuthBloc>().state.user?.role;
    final isSuperAdmin = Permissions.isSuperAdmin(currentUserRole);
    if (Permissions.isSuperAdmin(user.role.name) && !isSuperAdmin) {
      _showSnack('Only Superadmin can view or modify Superadmin credentials.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => _CredentialsDialog(user: user),
    );
  }

  Future<void> _confirmDelete(UserAccount user) async {
    final currentUserRole = context.read<AuthBloc>().state.user?.role;
    final isSuperAdmin = Permissions.isSuperAdmin(currentUserRole);
    if (Permissions.isAdmin(user.role.name) && !isSuperAdmin) {
      _showSnack('Only Superadmin can delete Admin accounts.');
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
        title: Text(
          'Delete User',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to delete the user account for ${user.displayName}?',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF607D8B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    context.read<AdminUsersBloc>().add(AdminUserDeleted(user.id));
  }

  Future<void> _unblockLogin(UserAccount user) async {
    final currentUserRole = context.read<AuthBloc>().state.user?.role;
    final isSuperAdmin = Permissions.isSuperAdmin(currentUserRole);
    if (Permissions.isAdmin(user.role.name) && !isSuperAdmin) {
      _showSnack('Only Superadmin can unblock or activate Admin accounts.');
      return;
    }

    final willActivate = !user.isActive;
    final isLocked = user.isLoginLocked;

    final actionTitle = (willActivate && isLocked)
        ? 'Unblock & Activate Account'
        : willActivate
            ? 'Activate Account'
            : 'Unblock Login';

    final actionMsg = (willActivate && isLocked)
        ? 'Allow ${user.displayName} to sign in again? This will activate their account and clear failed login locks.'
        : willActivate
            ? 'Activate account for ${user.displayName} so they can sign in?'
            : 'Allow ${user.displayName} to sign in again? Failed-password lock will reset.';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(actionTitle),
        content: Text(actionMsg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: Text(actionTitle),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<AdminUsersBloc>().add(AdminUserUnblocked(user.id));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isAdmin,
    required this.isSuperAdmin,
    required this.canEdit,
    required this.canDelete,
    required this.canUnblock,
    required this.canViewCredentials,
    required this.onCredentials,
    required this.onEdit,
    required this.onDelete,
    required this.onUnblock,
  });

  final UserAccount user;
  final bool isAdmin;
  final bool isSuperAdmin;
  final bool canEdit;
  final bool canDelete;
  final bool canUnblock;
  final bool canViewCredentials;
  final VoidCallback onCredentials;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final initials = user.displayName
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFF263238).withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFECEFF1),
                child: Text(
                  initials.isEmpty ? '??' : initials, 
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238), 
                    fontWeight: FontWeight.bold, 
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName, 
                    style: TextStyle(
                      fontWeight: FontWeight.w800, 
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.displaySubtitle,
                    style: TextStyle(
                      fontSize: 11, 
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (Permissions.isSuperAdmin(user.role.name))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFF7C3AED), width: 1.2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFF7C3AED)),
                              SizedBox(width: 4),
                              Text(
                                'SUPERADMIN · SUPREME',
                                style: TextStyle(
                                  color: Color(0xFF7C3AED),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (Permissions.isSystemAdmin(user.role.name))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC5A059).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFFC5A059), width: 1.2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.admin_panel_settings_rounded, size: 12, color: Color(0xFFC5A059)),
                              SizedBox(width: 4),
                              Text(
                                'SYSTEM ADMIN',
                                style: TextStyle(
                                  color: Color(0xFFC5A059),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        _badge(user.role.name, isDark ? const Color(0xFFC5A059) : const Color(0xFF263238)),
                      _badge(
                        user.isActive ? 'ACTIVE' : 'INACTIVE',
                        user.isActive ? Colors.green : Colors.red,
                        soft: true,
                      ),
                      if (user.loginBlocked)
                        _badge('BLOCKED — NEEDS ADMIN', Colors.red, soft: true)
                      else if (user.loginTemporarilyLocked)
                        _badge(
                          user.loginLockedUntil != null
                              ? 'LOCKED UNTIL ${_formatDateTime(user.loginLockedUntil!)}'
                              : 'TEMP LOCKED',
                          Colors.orange,
                          soft: true,
                        ),
                      const SizedBox(width: 4),
                      if (user.lastLoginAt != null)
                        Text(
                          'Last login: ${_formatDate(user.lastLoginAt!)}',
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white30 : const Color(0xFF607D8B),
                          ),
                        )
                      else
                        Text(
                          'Never logged in',
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white30 : const Color(0xFF607D8B).withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                  if (isAdmin && canUnblock && (!user.isActive || user.isLoginLocked)) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: onUnblock,
                        icon: Icon(
                          (!user.isActive && user.isLoginLocked)
                              ? Icons.lock_open_rounded
                              : !user.isActive
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.lock_open_rounded,
                          size: 16,
                        ),
                        label: Text(
                          (!user.isActive && user.isLoginLocked)
                              ? 'Unblock & Activate Account'
                              : !user.isActive
                                  ? 'Activate Account'
                                  : (user.loginBlocked ? 'Unblock Login' : 'Clear Temp Lock'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          foregroundColor: !user.isActive
                              ? const Color(0xFF1B5E20)
                              : user.loginBlocked
                                  ? Colors.red.shade800
                                  : Colors.orange.shade900,
                          backgroundColor: !user.isActive
                              ? const Color(0xFFE8F5E9)
                              : user.loginBlocked
                                  ? Colors.red.withValues(alpha: 0.12)
                                  : Colors.orange.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAdmin && canUnblock && (!user.isActive || user.isLoginLocked))
                  IconButton(
                    tooltip: (!user.isActive && user.isLoginLocked)
                        ? 'Unblock & Activate'
                        : !user.isActive
                            ? 'Activate Account'
                            : 'Unblock login',
                    onPressed: onUnblock,
                    icon: Icon(
                      !user.isActive ? Icons.check_circle_outline_rounded : Icons.lock_open_rounded,
                      color: !user.isActive ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                  ),
                if (canViewCredentials)
                  IconButton(
                    tooltip: 'Credentials',
                    onPressed: onCredentials,
                    icon: const Icon(Icons.key_outlined, color: Color(0xFFC5A059), size: 18),
                  ),
                if (canEdit)
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFFC5A059), size: 18),
                  ),
                if (canDelete)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color, {bool soft = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: soft ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5),
      ),
    );
  }

  String _formatDateTime(DateTime d) {
    final local = d.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$min';
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }
}

class _CredentialsDialog extends StatefulWidget {
  const _CredentialsDialog({required this.user});

  final UserAccount user;

  @override
  State<_CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<_CredentialsDialog> {
  AccountCredentials? _creds;
  String? _revealedPassword;
  bool _loading = true;
  bool _resetting = false;
  final _customPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final creds = await context.read<RbacRepository>().getUserCredentials(widget.user.id);
      if (mounted) {
        setState(() {
          _creds = creds;
          _revealedPassword = creds.password;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _resetting = true);
    try {
      final custom = _customPasswordController.text.trim();
      if (custom.isNotEmpty) {
        final issue = validateNewPassword(custom);
        if (issue != null) {
          setState(() => _resetting = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(issue)));
          return;
        }
      }
      final result = await context.read<RbacRepository>().resetPassword(
            widget.user.id,
            password: custom.isEmpty ? null : custom,
          );
      if (mounted) {
        setState(() {
          _revealedPassword = result.password;
          if (result.loginId != null && _creds != null) {
            _creds = AccountCredentials(
              userId: _creds!.userId,
              loginId: result.loginId,
              accountType: _creds!.accountType,
              isFirstLogin: _creds!.isFirstLogin,
              password: result.password,
              passwordNote: _creds!.passwordNote,
              canLogin: _creds!.canLogin,
            );
          }
          _resetting = false;
        });
        _customPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset — share with the account holder')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resetting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  bool _activating = false;

    Future<void> _activateAndUnblock() async {
    setState(() => _activating = true);
    try {
      await context.read<RbacRepository>().unblockLogin(widget.user.id);
      if (!mounted) return;
      await context.read<RbacRepository>().updateUser(widget.user.id, {'isActive': true});
      if (!mounted) return;
      context.read<AdminUsersBloc>().add(const AdminUsersLoadRequested());
      await _load();
      if (mounted) {
        setState(() => _activating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account successfully activated & unblocked! User can log in now.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _activating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginId = _creds?.loginId;
    final password = _revealedPassword ?? _creds?.password;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      title: Row(
        children: [
          const Icon(Icons.key_outlined, color: Color(0xFFC5A059)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Credentials',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF212F3D),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_creds?.canLogin == false)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Account inactive or blocked from logging in.',
                                  style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _activating ? null : _activateAndUnblock,
                            icon: _activating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.lock_open_rounded, size: 16),
                            label: Text(
                              _activating ? 'Activating...' : 'Unblock & Activate Account',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LOGIN ID', 
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                loginId ?? '—', 
                                style: TextStyle(
                                  fontFamily: 'monospace', 
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                                ),
                              ),
                            ),
                            if (loginId != null)
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFFC5A059)),
                                onPressed: () => _copy(loginId, 'Login ID'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'PASSWORD', 
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                password ?? '—', 
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                                ),
                              ),
                            ),
                            if (password != null)
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFFC5A059)),
                                onPressed: () => _copy(password, 'Password'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        if (_creds != null) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1, thickness: 1),
                          const SizedBox(height: 10),
                          Text(
                            _creds!.passwordNote,
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white30 : const Color(0xFF607D8B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Reset Account Password', 
                    style: TextStyle(
                      fontWeight: FontWeight.w800, 
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customPasswordController,
                    decoration: const InputDecoration(
                      hintText: 'Optional custom password (6+ chars, A-z and a number)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _resetting ? null : _resetPassword,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                        side: BorderSide(
                          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.4) : const Color(0xFF263238).withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _resetting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC5A059)))
                          : const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFC5A059)),
                      label: Text(
                        _resetting ? 'Resetting…' : 'Reset & Show New Password',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
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
      ],
    );
  }
}
