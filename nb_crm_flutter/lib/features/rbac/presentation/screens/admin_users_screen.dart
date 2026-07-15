import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/rbac_models.dart';
import '../rbac_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
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
    if (!Permissions.canManageUsers(auth.permissions)) {
      return _accessDenied();
    }

    final filters = ref.watch(usersFilterProvider);
    final usersAsync = ref.watch(usersListProvider);
    final rolesAsync = ref.watch(allRolesProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('System Users'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(usersListProvider.notifier).refresh(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showAddUserDialog(context, rolesAsync),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bronze,
                foregroundColor: AppColors.midnight,
                elevation: 0,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add User'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(context, filters, rolesAsync),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return const Center(
                    child: Text('No users found matching filters.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _UserCard(
                    user: users[index],
                    onCredentials: () => _showCredentialsDialog(context, users[index]),
                    onEdit: () => _showEditUserDialog(context, users[index], rolesAsync),
                    onDelete: () => _confirmDelete(context, users[index]),
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.bronze),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Failed to load users\n$err', textAlign: TextAlign.center),
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
    );
  }

  Widget _accessDenied() {
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
              'You do not have permission to manage users.',
              style: TextStyle(color: AppColors.textSecondary),
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

    return Container(
      color: AppColors.midnight,
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or code…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
                filled: true,
                fillColor: AppColors.slate,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((i) => i.value == value) ? value : items.first.value,
          dropdownColor: AppColors.slate,
          style: const TextStyle(color: Colors.white),
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
    final employeeIdController = TextEditingController();
    String? roleId;
    final roles = rolesAsync.value ?? const <RoleSummary>[];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create User Account'),
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
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Assign Role'),
                items: roles
                    .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                    .toList(),
                onChanged: (v) => roleId = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create Account'),
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
    var isActive = user.isActive;
    var roleId = user.roleId;
    final roles = rolesAsync.value ?? const <RoleSummary>[];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edit User Account'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(user.displaySubtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCredentialsDialog(context, user);
                  },
                  icon: const Icon(Icons.key_outlined, size: 18),
                  label: const Text('View login & password'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: roles.any((r) => r.id == roleId) ? roleId : null,
                  decoration: const InputDecoration(labelText: 'Assigned Role'),
                  items: roles
                      .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => roleId = v ?? roleId),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<bool>(
                  initialValue: isActive,
                  decoration: const InputDecoration(labelText: 'Status'),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Changes'),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete the user account for ${user.displayName}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.midnight,
              foregroundColor: AppColors.bronze,
              child: Text(initials.isEmpty ? '??' : initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.midnight)),
                  Text(
                    user.displaySubtitle,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _badge(user.role.name, AppColors.midnight),
                      _badge(
                        user.isActive ? 'ACTIVE' : 'INACTIVE',
                        user.isActive ? AppColors.success : AppColors.error,
                        soft: true,
                      ),
                      if (user.lastLoginAt != null)
                        Text(
                          'Last login: ${_formatDate(user.lastLoginAt!)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        )
                      else
                        const Text(
                          'Never logged in',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Credentials',
              onPressed: onCredentials,
              icon: const Icon(Icons.key_outlined, color: AppColors.textSecondary),
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color, {bool soft = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: soft ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
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

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.key_outlined, color: AppColors.midnight),
          const SizedBox(width: 8),
          Expanded(child: Text('Credentials — ${widget.user.displayName}')),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppColors.bronze)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_creds?.canLogin == false)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade100),
                      ),
                      child: const Text(
                        'Account inactive or missing login id.',
                        style: TextStyle(fontSize: 12, color: Colors.amber),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.mist,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LOGIN ID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        Row(
                          children: [
                            Expanded(child: Text(loginId ?? '—', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold))),
                            if (loginId != null)
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: () => _copy(loginId, 'Login ID'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('PASSWORD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        Row(
                          children: [
                            Expanded(child: Text(password ?? '—', style: const TextStyle(fontFamily: 'monospace'))),
                            if (password != null)
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: () => _copy(password, 'Password'),
                              ),
                          ],
                        ),
                        if (_creds != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _creds!.passwordNote,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Reset password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customPasswordController,
                    decoration: const InputDecoration(
                      hintText: 'Optional custom password (min 8 chars)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _resetting ? null : _resetPassword,
                    icon: _resetting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: Text(_resetting ? 'Resetting…' : 'Reset & show new password'),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
