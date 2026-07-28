import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/rbac_models.dart';
import '../rbac_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(usersFilterProvider.notifier).setSearch(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!Permissions.canManageUsers(auth.permissions)) {
      return _accessDenied(context);
    }

    final filters = ref.watch(usersFilterProvider);
    final usersAsync = ref.watch(usersListProvider);
    final rolesAsync = ref.watch(allRolesProvider);

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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh list',
            label: 'Refresh',
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
            ),
            onPressed: () => ref.read(usersListProvider.notifier).refresh(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: SizedBox(
              height: 38,
              child: FilledButton.icon(
                onPressed: () => _showAddUserDialog(context, rolesAsync),
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
            _buildFilterBar(context, filters, rolesAsync),
            Expanded(
              child: usersAsync.when(
                data: (users) {
                  if (users.isEmpty) {
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
                            'No users found matching filters.',
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
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    itemCount: users.length,
                    itemBuilder: (context, index) => _UserCard(
                      user: users[index],
                      onCredentials: () => _showCredentialsDialog(context, users[index]),
                      onEdit: () => _showEditUserDialog(context, users[index], rolesAsync),
                      onDelete: () => _confirmDelete(context, users[index]),
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load users\n$err', 
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.read(usersListProvider.notifier).refresh(),
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
    UsersFilterState filters,
    AsyncValue<List<RoleSummary>> rolesAsync,
  ) {
    final roles = rolesAsync.value ?? const <RoleSummary>[];
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
              onChanged: _onSearchChanged,
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
            ),
          ),
          const SizedBox(width: 12),
          _filterDropdown(
            label: 'Status',
            value: filters.status,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'true', child: Text('Active')),
              DropdownMenuItem(value: 'false', child: Text('Inactive')),
            ],
            onChanged: (v) {
              if (v != null) ref.read(usersFilterProvider.notifier).setStatus(v);
            },
          ),
          const SizedBox(width: 12),
          _filterDropdown(
            label: 'Role',
            value: filters.roleId,
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Roles')),
              ...roles.map(
                (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
              ),
            ],
            onChanged: (v) {
              if (v != null) ref.read(usersFilterProvider.notifier).setRoleId(v);
            },
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
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
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
    BuildContext context,
    AsyncValue<List<RoleSummary>> rolesAsync,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final employeeIdController = TextEditingController();
    String? roleId;
    final roles = rolesAsync.value ?? const <RoleSummary>[];

    final ok = await showDialog<bool>(
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
          'Create User Account',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: employeeIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Employee ID',
                  hintText: 'e.g. 1',
                  helperText: 'The internal employee ID (numeric)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
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
            child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final empId = int.tryParse(employeeIdController.text.trim());
    if (empId == null || roleId == null || roleId!.isEmpty) {
      _showSnack('Please enter a valid employee ID and select a role.');
      return;
    }

    try {
      await ref.read(usersListProvider.notifier).createUser({
        'employeeId': empId,
        'roleId': roleId,
      });
      if (mounted) _showSnack('User account created.');
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showEditUserDialog(
    BuildContext context,
    UserAccount user,
    AsyncValue<List<RoleSummary>> rolesAsync,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var isActive = user.isActive;
    var roleId = user.roleId;
    final roles = rolesAsync.value ?? const <RoleSummary>[];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
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
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
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
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCredentialsDialog(context, user);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                    side: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFFCFD8DC),
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
                  onChanged: (v) => setLocal(() => roleId = v ?? roleId),
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
                  onChanged: (v) => setLocal(() => isActive = v ?? isActive),
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

    try {
      await ref.read(usersListProvider.notifier).updateUser(user.id, payload);
      if (mounted) _showSnack('User updated.');
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showCredentialsDialog(BuildContext context, UserAccount user) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _CredentialsDialog(user: user),
    );
  }

  Future<void> _confirmDelete(BuildContext context, UserAccount user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
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

    try {
      await ref.read(usersListProvider.notifier).deleteUser(user.id);
      if (mounted) _showSnack('User deleted.');
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onCredentials,
    required this.onEdit,
    required this.onDelete,
  });

  final UserAccount user;
  final VoidCallback onCredentials;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
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
                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFF263238).withOpacity(0.15),
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
                      _badge(user.role.name, isDark ? const Color(0xFFC5A059) : const Color(0xFF263238)),
                      _badge(
                        user.isActive ? 'ACTIVE' : 'INACTIVE',
                        user.isActive ? Colors.green : Colors.red,
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
                            color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Credentials',
                  onPressed: onCredentials,
                  icon: const Icon(Icons.key_outlined, color: Color(0xFFC5A059), size: 18),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFFC5A059), size: 18),
                ),
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
        color: soft ? color.withOpacity(0.12) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }
}

class _CredentialsDialog extends ConsumerStatefulWidget {
  const _CredentialsDialog({required this.user});

  final UserAccount user;

  @override
  ConsumerState<_CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends ConsumerState<_CredentialsDialog> {
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
      final creds = await ref.read(rbacRepositoryProvider).getUserCredentials(widget.user.id);
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
      final result = await ref.read(rbacRepositoryProvider).resetPassword(
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
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber, width: 1.2),
                      ),
                      child: const Text(
                        'Account inactive or missing login ID.',
                        style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w700),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
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
                      hintText: 'Optional custom password (min 8 chars)',
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
                          color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFF263238).withOpacity(0.5),
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
