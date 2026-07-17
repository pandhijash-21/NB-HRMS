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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!Permissions.canManageRoles(auth.permissions)) {
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
              const Text(
                'Access Denied: Role management permission required.',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
          ),
          onPressed: () => context.go('/admin/roles'),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Matrix',
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
            ),
            onPressed: () {
              ref.invalidate(roleDetailProvider(roleId));
              ref.invalidate(systemModulesProvider);
              ref.invalidate(rolePermissionsProvider(roleId));
            },
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
      body: roleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
        error: (err, _) => Center(
          child: Text(
            'Failed to load role: $err', 
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
          ),
        ),
        data: (role) {
          return modulesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
            error: (err, _) => Center(
              child: Text(
                'Failed to load modules: $err', 
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
              ),
            ),
            data: (modules) {
              return permsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
                error: (err, _) => Center(
                  child: Text(
                    'Failed to load permissions: $err', 
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
                  ),
                ),
                data: (permissions) {
                  final permByKey = {
                    for (final p in permissions) p.moduleKey: p,
                  };

                  return TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0.0, 20.0 * (1.0 - value)),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: SingleChildScrollView(
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
                            onPatched: () => ref.invalidate(rolePermissionsProvider(roleId)),
                          ),
                        ],
                      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                role.name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFF263238).withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Permission Matrix',
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
            role.description ?? 'No description provided for this position.',
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF607D8B), 
              fontSize: 13,
              fontWeight: FontWeight.w600,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            isDark ? const Color(0xFF121212).withOpacity(0.4) : const Color(0xFFF1F5F9),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<EmployeeViewScope>(
                                value: perm.employeeViewScope,
                                isDense: true,
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFC5A059), size: 18),
                                dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                                ),
                                items: const [
                                  DropdownMenuItem(value: EmployeeViewScope.none, child: Text('Off')),
                                  DropdownMenuItem(value: EmployeeViewScope.self, child: Text('Self Only')),
                                  DropdownMenuItem(value: EmployeeViewScope.institute, child: Text('Institute Only')),
                                  DropdownMenuItem(value: EmployeeViewScope.university, child: Text('University-Wide')),
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
                        activeColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                        activeTrackColor: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFF263238).withOpacity(0.3),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey.withOpacity(0.2),
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
