import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!Permissions.canManageRoles(auth.permissions)) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
        body: const Center(
          child: Text(
            'Access Denied: Role management permission required.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    final roleAsync = ref.watch(roleDetailProvider(roleId));
    final modulesAsync = ref.watch(systemModulesProvider);
    final permsAsync = ref.watch(rolePermissionsProvider(roleId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Permission Matrix',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: const AppBackButton(fallbackLocation: '/admin/roles'),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh Matrix',
            label: 'Refresh',
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF212F3D),
            ),
            onPressed: () {
              ref.invalidate(roleDetailProvider(roleId));
              ref.invalidate(systemModulesProvider);
              ref.read(rolePermissionsProvider(roleId).notifier).refresh();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark
                ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: roleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
        error: (err, _) => Center(child: Text('Failed to load role: $err')),
        data: (role) {
          return modulesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
            error: (err, _) => Center(child: Text('Failed to load modules: $err')),
            data: (modules) {
              // Keep showing last known permissions while a patch is in flight —
              // never replace the whole matrix with a spinner on toggle.
              final permissions = permsAsync.asData?.value;
              if (permissions == null) {
                if (permsAsync.hasError) {
                  return Center(child: Text('Failed to load permissions: ${permsAsync.error}'));
                }
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                );
              }

              final permByKey = {
                for (final p in permissions) p.moduleKey: p,
              };

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RoleHeader(role: role),
                    const SizedBox(height: 16),
                    _MatrixTable(
                      modules: modules,
                      permByKey: permByKey,
                      roleId: roleId,
                    ),
                  ],
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = role.positionName ?? role.name;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withValues(alpha: 0.15)
              : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFFC5A059).withValues(alpha: 0.12)
                      : const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  role.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            role.description ?? 'Toggle module access for this designation / position.',
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${role.userCount} users assigned',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            ),
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
  });

  final List<SystemModule> modules;
  final Map<String, ModulePermission> permByKey;
  final String roleId;

  @override
  ConsumerState<_MatrixTable> createState() => _MatrixTableState();
}

class _MatrixTableState extends ConsumerState<_MatrixTable> {
  final Set<String> _updating = {};

  Future<void> _patch(String moduleKey, Map<String, dynamic> data) async {
    final trackKey = '$moduleKey-${data.keys.join()}';
    if (_updating.contains(trackKey)) return;
    setState(() => _updating.add(trackKey));
    try {
      await ref.read(rolePermissionsProvider(widget.roleId).notifier).patch(
            moduleKey,
            data,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(trackKey));
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withValues(alpha: 0.15)
              : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            isDark
                ? const Color(0xFF121212).withValues(alpha: 0.4)
                : const Color(0xFFF1F5F9),
          ),
          columns: [
            DataColumn(
              label: Text(
                'System Module',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
            ),
            ...AdminRoleDetailScreen._columns.map(
              (c) => DataColumn(
                label: Text(
                  c.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                  ),
                ),
              ),
            ),
          ],
          rows: widget.modules.map((module) {
            final perm = _permFor(module.key);
            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 240,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          module.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF212F3D),
                          ),
                        ),
                        if (module.description != null && module.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            module.description!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white30 : const Color(0xFF607D8B),
                            ),
                          ),
                        ],
                        if (module.key == 'PERSONAL_INFO') ...[
                          const SizedBox(height: 6),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<EmployeeViewScope>(
                              value: perm.employeeViewScope,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(
                                  value: EmployeeViewScope.none,
                                  child: Text('View: Off'),
                                ),
                                DropdownMenuItem(
                                  value: EmployeeViewScope.self,
                                  child: Text('View: Self'),
                                ),
                                DropdownMenuItem(
                                  value: EmployeeViewScope.institute,
                                  child: Text('View: Institute'),
                                ),
                                DropdownMenuItem(
                                  value: EmployeeViewScope.university,
                                  child: Text('View: University'),
                                ),
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
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ...AdminRoleDetailScreen._columns.map((col) {
                  final fieldKey = col.key;
                  final value = _boolForField(perm, fieldKey);
                  final isUpdating = _updating.contains('${module.key}-$fieldKey');

                  return DataCell(
                    Center(
                      child: Switch.adaptive(
                        value: value,
                        activeThumbColor:
                            isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                        onChanged: isUpdating
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
}
