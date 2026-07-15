import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/rbac_models.dart';
import '../rbac_providers.dart';

class AdminRoleDetailScreen extends ConsumerWidget {
  const AdminRoleDetailScreen({super.key, required this.roleId});

  final String roleId;

  static const _columns = [
    _PermColumn(key: 'canRead', label: 'Read / View'),
    _PermColumn(key: 'canWrite', label: 'Create / Edit'),
    _PermColumn(key: 'canApprove', label: 'Approve'),
    _PermColumn(key: 'canDelete', label: 'Delete'),
    _PermColumn(key: 'canExport', label: 'Export'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    if (!Permissions.canManageRoles(auth.permissions)) {
      return const Scaffold(
        body: Center(child: Text('Access Denied: Role management permission required.')),
      );
    }

    final roleAsync = ref.watch(roleDetailProvider(roleId));
    final modulesAsync = ref.watch(systemModulesProvider);
    final permsAsync = ref.watch(rolePermissionsProvider(roleId));

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Permission Matrix'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/roles'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(roleDetailProvider(roleId));
              ref.invalidate(systemModulesProvider);
              ref.invalidate(rolePermissionsProvider(roleId));
            },
          ),
        ],
      ),
      body: roleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (err, _) => Center(child: Text('Failed to load role: $err')),
        data: (role) {
          return modulesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bronze)),
            error: (err, _) => Center(child: Text('Failed to load modules: $err')),
            data: (modules) {
              return permsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bronze)),
                error: (err, _) => Center(child: Text('Failed to load permissions: $err')),
                data: (permissions) {
                  final permByKey = {
                    for (final p in permissions) p.moduleKey: p,
                  };

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RoleHeader(role: role),
                        const SizedBox(height: 16),
                        _MatrixTable(
                          modules: modules,
                          permByKey: permByKey,
                          roleId: roleId,
                          onPatched: () => ref.invalidate(rolePermissionsProvider(roleId)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PermColumn {
  const _PermColumn({required this.key, required this.label});

  final String key;
  final String label;
}

class _RoleHeader extends StatelessWidget {
  const _RoleHeader({required this.role});

  final RoleSummary role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                role.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.midnight,
                    ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.midnight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Permission Matrix',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midnight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            role.description ?? 'No description provided.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MatrixTable extends ConsumerStatefulWidget {
  const _MatrixTable({
    required this.modules,
    required this.permByKey,
    required this.roleId,
    required this.onPatched,
  });

  final List<SystemModule> modules;
  final Map<String, ModulePermission> permByKey;
  final String roleId;
  final VoidCallback onPatched;

  @override
  ConsumerState<_MatrixTable> createState() => _MatrixTableState();
}

class _MatrixTableState extends ConsumerState<_MatrixTable> {
  final Set<String> _updating = {};

  Future<void> _patch(String moduleKey, Map<String, dynamic> data) async {
    final key = '$moduleKey-${data.keys.join()}';
    setState(() => _updating.add(key));
    try {
      await ref.read(rbacRepositoryProvider).patchRolePermission(
            widget.roleId,
            moduleKey,
            data,
          );
      widget.onPatched();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(key));
    }
  }

  ModulePermission _permFor(String moduleKey) {
    return widget.permByKey[moduleKey] ??
        ModulePermission(
          moduleKey: moduleKey,
          canRead: false,
          canWrite: false,
          canApprove: false,
          canDelete: false,
          canExport: false,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.midnight.withValues(alpha: 0.04)),
          columns: [
            const DataColumn(label: Text('System Module', style: TextStyle(fontWeight: FontWeight.bold))),
            ...AdminRoleDetailScreen._columns.map(
              (c) => DataColumn(
                label: Text(c.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
          ],
          rows: widget.modules.map((module) {
            final perm = _permFor(module.key);
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(module.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (module.description != null && module.description!.isNotEmpty)
                          Text(
                            module.description!,
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        if (module.key == 'PERSONAL_INFO') ...[
                          const SizedBox(height: 8),
                          const Text(
                            'VIEW EMPLOYEES',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                          DropdownButton<EmployeeViewScope>(
                            value: perm.employeeViewScope,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: EmployeeViewScope.none, child: Text('Off')),
                              DropdownMenuItem(value: EmployeeViewScope.self, child: Text('Self only')),
                              DropdownMenuItem(value: EmployeeViewScope.institute, child: Text('Institute only')),
                              DropdownMenuItem(value: EmployeeViewScope.university, child: Text('University-wide')),
                            ],
                            onChanged: _updating.any((k) => k.startsWith('${module.key}-'))
                                ? null
                                : (scope) {
                                    if (scope == null) return;
                                    _patch(module.key, {
                                      'employeeViewScope': employeeViewScopeToJson(scope),
                                    });
                                  },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ...AdminRoleDetailScreen._columns.map((col) {
                  final fieldKey = col.key;
                  final value = _boolForField(perm, fieldKey);
                  final updating = _updating.any((k) => k.startsWith('${module.key}-') && k.contains(fieldKey));

                  return DataCell(
                    Center(
                      child: Switch(
                        value: value,
                        activeThumbColor: AppColors.success,
                        onChanged: updating
                            ? null
                            : (next) => _patch(module.key, {fieldKey: next}),
                      ),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _boolForField(ModulePermission perm, String field) {
    switch (field) {
      case 'canRead':
        return perm.canRead;
      case 'canWrite':
        return perm.canWrite;
      case 'canApprove':
        return perm.canApprove;
      case 'canDelete':
        return perm.canDelete;
      case 'canExport':
        return perm.canExport;
      default:
        return false;
    }
  }
}
