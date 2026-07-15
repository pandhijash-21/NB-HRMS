import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/rbac_models.dart';
import '../rbac_providers.dart';

class AdminRolesScreen extends ConsumerStatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  ConsumerState<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends ConsumerState<AdminRolesScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    if (!Permissions.canManageRoles(auth.permissions)) {
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
                'You do not have permission to manage roles.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final filters = ref.watch(rolesFilterProvider);
    final rolesAsync = ref.watch(rolesListProvider);

    final filtered = rolesAsync.maybeWhen(
      data: (roles) {
        final q = filters.search.trim().toLowerCase();
        if (q.isEmpty) return roles;
        return roles.where((r) {
          return r.name.toLowerCase().contains(q) ||
              (r.description ?? '').toLowerCase().contains(q) ||
              (r.positionName ?? '').toLowerCase().contains(q);
        }).toList();
      },
      orElse: () => const <RoleSummary>[],
    );

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Roles & Permissions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(rolesListProvider.notifier).refresh(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateRoleDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bronze,
                foregroundColor: AppColors.midnight,
                elevation: 0,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Role'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.midnight,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => ref.read(rolesFilterProvider.notifier).setSearch(v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Find positions…',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
                      filled: true,
                      fillColor: AppColors.slate,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Only institutional positions appear here. Create positions from Workforce, then edit permissions below.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: rolesAsync.when(
              data: (_) {
                if (filtered.isEmpty) {
                  return const Center(child: Text('No roles found.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final role = filtered[index];
                    return _RoleCard(
                      role: role,
                      onMatrix: () => context.go('/admin/roles/${role.id}'),
                      onDelete: () => _confirmDelete(context, role),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.bronze),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to load roles: $err'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.read(rolesListProvider.notifier).refresh(),
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

  Future<void> _showCreateRoleDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Role'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Role Name',
                  hintText: 'e.g. HR_MANAGER',
                  helperText: 'Uppercase with underscores only',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      _snack('Role name is required.');
      return;
    }

    try {
      await ref.read(rolesListProvider.notifier).createRole({
        'name': name,
        if (descController.text.trim().isNotEmpty) 'description': descController.text.trim(),
      });
      if (mounted) _snack('Role created.');
    } catch (e) {
      if (mounted) {
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, RoleSummary role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text('Are you sure you want to delete the position role ${role.name}?'),
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
      await ref.read(rolesListProvider.notifier).deleteRole(role.id);
      if (mounted) _snack('Role deleted.');
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.onMatrix,
    required this.onDelete,
  });

  final RoleSummary role;
  final VoidCallback onMatrix;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = role.positionName ?? role.name;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.midnight)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.midnight.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      role.name,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.midnight),
                    ),
                  ),
                  if (role.description != null && role.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      role.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${role.userCount} users assigned',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onMatrix,
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Matrix'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.midnight,
                side: BorderSide(color: AppColors.midnight.withValues(alpha: 0.2)),
              ),
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
}
