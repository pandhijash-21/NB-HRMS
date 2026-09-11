import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/rbac_models.dart';
import '../bloc/admin_role_detail_bloc.dart';

class AdminRoleDetailScreen extends StatefulWidget {
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
  State<AdminRoleDetailScreen> createState() => _AdminRoleDetailScreenState();
}

class _AdminRoleDetailScreenState extends State<AdminRoleDetailScreen> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<AdminRoleDetailBloc>();
    if (bloc.state.status == LoadStatus.initial || bloc.state.role?.id != widget.roleId) {
      bloc.add(RoleDetailLoadRequested(widget.roleId));
    }
  }

  Future<void> _showAddModuleDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyController = TextEditingController();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'HRMS';

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
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_box_rounded, color: isDark ? const Color(0xFFC5A059) : const Color(0xFF4338CA), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Register System Module',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.12) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: 16,
                          color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'System Admin has full RBAC authority to register new custom modules. Once created, granular permissions can be configured across all roles.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: keyController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Module Key (Identifier) *',
                      hintText: 'e.g. LOGISTICS_FLEET',
                      helperText: 'Upper snake-case identifier. Used for permission mapping.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Module Name *',
                      hintText: 'e.g. Logistics & Fleet Management',
                      helperText: 'Human-readable module title displayed across the app.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF212F3D), fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'HRMS', child: Text('HRMS (Human Resources)')),
                      DropdownMenuItem(value: 'CRM', child: Text('CRM (Customer Relations)')),
                      DropdownMenuItem(value: 'ERP', child: Text('ERP (Enterprise Resource Planning)')),
                      DropdownMenuItem(value: 'COLLABORATION', child: Text('COLLABORATION (Chat, Meets, Tasks)')),
                      DropdownMenuItem(value: 'SYSTEM', child: Text('SYSTEM (Core Settings & Audit)')),
                    ],
                    onChanged: (v) => setLocal(() => selectedCategory = v ?? 'HRMS'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Purpose of this module and data scope',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B), fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC5A059),
                foregroundColor: const Color(0xFF1A1816),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Register Module', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    final key = keyController.text.trim().toUpperCase().replaceAll(' ', '_');
    final name = nameController.text.trim();
    final desc = descController.text.trim();

    if (key.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Module Key and Module Name are required.')),
      );
      return;
    }

    context.read<AdminRoleDetailBloc>().add(CustomModuleCreated(
      roleId: widget.roleId,
      data: {
        'key': key,
        'name': name,
        'category': selectedCategory,
        'description': desc.isNotEmpty ? desc : null,
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!Permissions.canManageRoles(authState.permissions)) {
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
                'Role management permission required to access matrix.',
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

    final detailState = context.watch<AdminRoleDetailBloc>().state;

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
              context.read<AdminRoleDetailBloc>().add(RoleDetailLoadRequested(widget.roleId));
            },
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: SizedBox(
              height: 38,
              child: FilledButton.icon(
                onPressed: _showAddModuleDialog,
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: const Icon(Icons.add_box_outlined, size: 16),
                label: const Text('Add Module', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ),
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
      body: BlocListener<AdminRoleDetailBloc, AdminRoleDetailState>(
        listenWhen: (prev, curr) =>
            prev.actionMessage != curr.actionMessage ||
            prev.errorMessage != curr.errorMessage,
        listener: (context, state) {
          if (state.actionMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.actionMessage!)));
          } else if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage!.replaceFirst('Exception: ', ''))));
          }
        },
        child: Builder(
          builder: (context) {
            if (detailState.status == LoadStatus.loading && detailState.role == null) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059)));
            }
            if (detailState.status == LoadStatus.failure && detailState.role == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load role: ${detailState.errorMessage ?? "Unknown error"}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.read<AdminRoleDetailBloc>().add(RoleDetailLoadRequested(widget.roleId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final role = detailState.role;
            if (role == null) {
              return const Center(child: Text('Role not found'));
            }
            final modules = detailState.modules;
            final permissions = detailState.permissions;
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
                  _ModularMatrixTable(
                    modules: modules,
                    permByKey: permByKey,
                    roleId: widget.roleId,
                    roleName: role.name,
                  ),
                ],
              ),
            );
          },
        ),
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
            role.description ?? 'Configure granular submodule permissions for this role.',
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF607D8B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.people_outline_rounded,
                size: 14,
                color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
              ),
              const SizedBox(width: 4),
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
          if (Permissions.isSuperAdmin(role.name)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 20, color: Color(0xFF7C3AED)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Superadmin holds permanent, unrestricted full access across all system modules. Permissions are non-restrictable.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (Permissions.isSystemAdmin(role.name)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.12) : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.3) : const Color(0xFFFFD54F),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 20,
                    color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFFF57F17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'System Admin possesses full administrative authority across all modules. Operates directly under Superadmin.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF795548),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModularMatrixTable extends StatefulWidget {
  const _ModularMatrixTable({
    required this.modules,
    required this.permByKey,
    required this.roleId,
    required this.roleName,
  });

  final List<SystemModule> modules;
  final Map<String, ModulePermission> permByKey;
  final String roleId;
  final String roleName;

  @override
  State<_ModularMatrixTable> createState() => _ModularMatrixTableState();
}

class _ModularMatrixTableState extends State<_ModularMatrixTable> {
  final Set<String> _updating = {};
  final Set<String> _expandedCategories = {'HRMS', 'CRM', 'ERP', 'COLLABORATION'};
  String _selectedFilter = 'ALL'; // 'ALL', 'HRMS', 'CRM', 'ERP', 'COLLABORATION'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _patch(String moduleKey, Map<String, dynamic> data) async {
    if (Permissions.isSuperAdmin(widget.roleName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Superadmin holds permanent full access across all modules.')),
        );
      }
      return;
    }
    final trackKey = '$moduleKey-${data.keys.join()}';
    if (_updating.contains(trackKey)) return;
    setState(() => _updating.add(trackKey));
    try {
      context.read<AdminRoleDetailBloc>().add(RolePermissionPatched(
            roleId: widget.roleId,
            moduleKey: moduleKey,
            data: data,
          ));
      if (mounted) {
        context.read<AuthBloc>().add(const AuthPermissionsRefreshRequested());
      }
    } finally {
      if (mounted) setState(() => _updating.remove(trackKey));
    }
  }

  Future<void> _toggleAllForModule(SystemModule module, bool enable) async {
    await _patch(module.key, {
      'canRead': enable,
      'canWrite': enable,
      'canApprove': enable,
      'canDelete': enable,
      'canExport': enable,
    });
  }

  Future<void> _batchAction(List<SystemModule> targetModules, String actionType) async {
    if (Permissions.isSuperAdmin(widget.roleName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Superadmin holds permanent full access across all modules.')),
        );
      }
      return;
    }
    for (final mod in targetModules) {
      if (actionType == 'grant_all') {
        await _patch(mod.key, {
          'canRead': true,
          'canWrite': true,
          'canApprove': true,
          'canDelete': true,
          'canExport': true,
        });
      } else if (actionType == 'revoke_all') {
        await _patch(mod.key, {
          'canRead': false,
          'canWrite': false,
          'canApprove': false,
          'canDelete': false,
          'canExport': false,
        });
      } else if (actionType == 'read_only') {
        await _patch(mod.key, {
          'canRead': true,
          'canWrite': false,
          'canApprove': false,
          'canDelete': false,
          'canExport': false,
        });
      }
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_expandedCategories.contains(category)) {
        _expandedCategories.remove(category);
      } else {
        _expandedCategories.add(category);
      }
    });
  }

  void _expandAll(List<String> categories) {
    setState(() {
      _expandedCategories.addAll(categories);
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedCategories.clear();
    });
  }

  ModulePermission _permFor(String moduleKey, [String category = 'HRMS']) {
    return widget.permByKey[moduleKey] ??
        ModulePermission(
          moduleKey: moduleKey,
          category: category,
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

  bool _isAllActionsGranted(ModulePermission perm) {
    return perm.canRead && perm.canWrite && perm.canApprove && perm.canDelete && perm.canExport;
  }

  bool _hasAnyActionGranted(ModulePermission perm) {
    return perm.canRead || perm.canWrite || perm.canApprove || perm.canDelete || perm.canExport;
  }

  Color _categoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'ERP':
        return const Color(0xFF2563EB); // Blue
      case 'CRM':
        return const Color(0xFF0D9488); // Teal
      case 'HRMS':
      default:
        return const Color(0xFF7C3AED); // Purple
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'ERP':
        return Icons.apartment_rounded;
      case 'CRM':
        return Icons.campaign_rounded;
      case 'HRMS':
      default:
        return Icons.badge_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamically discover all categories present in the system modules
    final allCategories = <String>{};
    for (final m in widget.modules) {
      allCategories.add(m.category.toUpperCase());
    }

    // Standard ordering: HRMS, CRM, ERP, COLLABORATION followed by any custom category
    final orderedCategories = ['HRMS', 'CRM', 'ERP', 'COLLABORATION'];
    for (final c in allCategories) {
      if (!orderedCategories.contains(c)) orderedCategories.add(c);
    }

    // Group modules by category
    final modulesByCategory = <String, List<SystemModule>>{};
    for (final cat in orderedCategories) {
      modulesByCategory[cat] = [];
    }
    for (final m in widget.modules) {
      final cat = m.category.toUpperCase();
      if (!modulesByCategory.containsKey(cat)) {
        modulesByCategory[cat] = [];
      }
      modulesByCategory[cat]!.add(m);
    }

    // Filter modules based on search query
    final matchingModulesByCategory = <String, List<SystemModule>>{};
    for (final cat in orderedCategories) {
      final list = modulesByCategory[cat] ?? [];
      if (_searchQuery.isEmpty) {
        matchingModulesByCategory[cat] = list;
      } else {
        final q = _searchQuery.toLowerCase();
        matchingModulesByCategory[cat] = list.where((m) {
          return m.name.toLowerCase().contains(q) ||
              m.key.toLowerCase().contains(q) ||
              (m.description ?? '').toLowerCase().contains(q);
        }).toList();
      }
    }

    // Categories to display based on selected filter
    final displayedCategories = orderedCategories.where((cat) {
      if (_selectedFilter != 'ALL' && cat != _selectedFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return (matchingModulesByCategory[cat] ?? []).isNotEmpty;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── TOP CONTROL BAR: SEARCH, QUICK EXPAND/COLLAPSE, FILTERS ─────────
        _buildTopControlBar(isDark, orderedCategories),
        const SizedBox(height: 16),

        // ── CATEGORY ACCORDIONS / DROPDOWNS ─────────────────────────────────
        if (displayedCategories.isEmpty)
          _buildEmptyState(isDark)
        else
          ...displayedCategories.map((category) {
            final categoryModules = matchingModulesByCategory[category] ?? [];
            final totalCount = (modulesByCategory[category] ?? []).length;
            final activeCount = (modulesByCategory[category] ?? [])
                .where((m) => _hasAnyActionGranted(_permFor(m.key, m.category)))
                .length;

            // Auto-expand if search query is active, otherwise respect toggle state
            final isExpanded = _searchQuery.isNotEmpty || _expandedCategories.contains(category);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildCategoryDropdownSection(
                category: category,
                categoryModules: categoryModules,
                totalCount: totalCount,
                activeCount: activeCount,
                isExpanded: isExpanded,
                isDark: isDark,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTopControlBar(bool isDark, List<String> orderedCategories) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1816) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withValues(alpha: 0.15)
              : const Color(0xFFCFD8DC),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Search Bar & Expand/Collapse All
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search all submodules (e.g. DPR, Store, Leave)...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: isDark ? const Color(0xFFC5A059) : const Color(0xFF607D8B),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Expand all modules',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFFC5A059).withValues(alpha: 0.3)
                          : const Color(0xFFCFD8DC),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.unfold_more_rounded, size: 16),
                  label: const Text('Expand All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: () => _expandAll(orderedCategories),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Collapse all modules',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFFC5A059).withValues(alpha: 0.3)
                          : const Color(0xFFCFD8DC),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.unfold_less_rounded, size: 16),
                  label: const Text('Collapse All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: _collapseAll,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Quick Filter Chips (All, HRMS, CRM, ERP)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Modules', Icons.grid_view_rounded, isDark),
                ...orderedCategories.map((cat) {
                  return _buildFilterChip(cat, cat, _categoryIcon(cat), isDark);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, bool isDark) {
    final isSelected = _selectedFilter == key;
    final color = key == 'ALL' ? const Color(0xFF64748B) : _categoryColor(key);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 15,
          color: isSelected
              ? (isDark ? const Color(0xFFE2D6BE) : Colors.white)
              : color,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (isDark ? const Color(0xFFE2D6BE) : Colors.white)
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1B18) : const Color(0xFFF1F5F9),
        selectedColor: isDark
            ? color.withValues(alpha: 0.4)
            : color,
        side: BorderSide(
          color: isSelected
              ? color
              : (isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC)),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (_) => setState(() => _selectedFilter = key),
      ),
    );
  }

  Widget _buildCategoryDropdownSection({
    required String category,
    required List<SystemModule> categoryModules,
    required int totalCount,
    required int activeCount,
    required bool isExpanded,
    required bool isDark,
  }) {
    final color = _categoryColor(category);
    final icon = _categoryIcon(category);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? color.withValues(alpha: isDark ? 0.4 : 0.6)
              : (isDark
                  ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                  : const Color(0xFFCFD8DC)),
          width: isExpanded ? 1.6 : 1.2,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: color.withValues(alpha: isDark ? 0.12 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── SECTION HEADER (CLICK TO EXPAND / COLLAPSE) ───────────────────
          InkWell(
            onTap: () => _toggleCategory(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              color: isExpanded
                  ? (isDark
                      ? color.withValues(alpha: 0.12)
                      : color.withValues(alpha: 0.06))
                  : Colors.transparent,
              child: Row(
                children: [
                  // Category Icon Badge
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: color.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 14),

                  // Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              category,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: isDark ? Colors.white : const Color(0xFF212F3D),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '$activeCount / $totalCount Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalCount submodules inside ${category.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Batch Buttons for this module
                  if (categoryModules.isNotEmpty) ...[
                    _buildSectionBatchBtn(
                      label: 'Grant All',
                      icon: Icons.done_all_rounded,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                      onPressed: () => _batchAction(categoryModules, 'grant_all'),
                    ),
                    const SizedBox(width: 6),
                    _buildSectionBatchBtn(
                      label: 'Read Only',
                      icon: Icons.visibility_outlined,
                      color: const Color(0xFF0284C7),
                      isDark: isDark,
                      onPressed: () => _batchAction(categoryModules, 'read_only'),
                    ),
                    const SizedBox(width: 6),
                    _buildSectionBatchBtn(
                      label: 'Revoke All',
                      icon: Icons.remove_circle_outline_rounded,
                      color: const Color(0xFFEF4444),
                      isDark: isDark,
                      onPressed: () => _batchAction(categoryModules, 'revoke_all'),
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Expand/Collapse Chevron Indicator
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFECEFF1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── EXPANDED CONTENT (DATA TABLE OF SUBMODULES) ────────────────────
          if (isExpanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: isDark
                  ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                  : const Color(0xFFCFD8DC),
            ),
            if (categoryModules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Text(
                    'No matching submodules in $category.',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: DataTable(
                  columnSpacing: 28,
                  horizontalMargin: 20,
                  headingRowHeight: 48,
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 96,
                  headingRowColor: WidgetStateProperty.all(
                    isDark
                        ? const Color(0xFF121212).withValues(alpha: 0.4)
                        : const Color(0xFFF8FAFC),
                  ),
                  columns: [
                    DataColumn(
                      label: Text(
                        'Submodule',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
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
                    DataColumn(
                      label: Text(
                        'All Actions',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: isDark ? const Color(0xFFC5A059) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                  rows: categoryModules.map((module) {
                    final perm = _permFor(module.key, module.category);
                    final allGranted = _isAllActionsGranted(perm);
                    final isRowUpdating = _updating.any((k) => k.startsWith('${module.key}-'));

                    return DataRow(
                      cells: [
                        // 1. Submodule Name & Info
                        DataCell(
                          SizedBox(
                            width: 320,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        module.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: color.withValues(alpha: 0.3),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        module.key,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (module.description != null && module.description!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    module.description!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white38 : const Color(0xFF607D8B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (module.key == 'PERSONAL_INFO') ...[
                                  const SizedBox(height: 4),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<EmployeeViewScope>(
                                      value: perm.employeeViewScope,
                                      isDense: true,
                                      items: const [
                                        DropdownMenuItem(
                                          value: EmployeeViewScope.none,
                                          child: Text('Scope: Off', style: TextStyle(fontSize: 11)),
                                        ),
                                        DropdownMenuItem(
                                          value: EmployeeViewScope.self,
                                          child: Text('Scope: Self', style: TextStyle(fontSize: 11)),
                                        ),
                                        DropdownMenuItem(
                                          value: EmployeeViewScope.institute,
                                          child: Text('Scope: Institute', style: TextStyle(fontSize: 11)),
                                        ),
                                        DropdownMenuItem(
                                          value: EmployeeViewScope.university,
                                          child: Text('Scope: University', style: TextStyle(fontSize: 11)),
                                        ),
                                      ],
                                      onChanged: (isRowUpdating || Permissions.isSuperAdmin(widget.roleName))
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

                        // 2-6: Individual 5 Action Toggles
                        ...AdminRoleDetailScreen._columns.map((col) {
                          final fieldKey = col.key;
                          final isSuperAdminRole = Permissions.isSuperAdmin(widget.roleName);
                          final value = isSuperAdminRole ? true : _boolForField(perm, fieldKey);
                          final isUpdating = _updating.contains('${module.key}-$fieldKey') ||
                              _updating.contains('${module.key}-canReadcanWritecanApprovecanDeletecanExport');

                          return DataCell(
                            Center(
                              child: Switch.adaptive(
                                value: value,
                                activeThumbColor: isDark
                                    ? const Color(0xFFC5A059)
                                    : const Color(0xFF212F3D),
                                activeTrackColor: isDark
                                    ? const Color(0xFFC5A059).withValues(alpha: 0.35)
                                    : const Color(0xFF212F3D).withValues(alpha: 0.25),
                                onChanged: (isUpdating || isSuperAdminRole)
                                    ? null
                                    : (next) => _patch(module.key, {fieldKey: next}),
                              ),
                            ),
                          );
                        }),

                        // 7. Master Toggle for this Submodule (turns all 5 on/off)
                        DataCell(
                          Center(
                            child: Tooltip(
                              message: Permissions.isSuperAdmin(widget.roleName)
                                  ? 'Superadmin access is permanent'
                                  : (allGranted ? 'Revoke all actions' : 'Grant all 5 actions'),
                              child: IconButton(
                                icon: isRowUpdating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Icon(
                                        (allGranted || Permissions.isSuperAdmin(widget.roleName))
                                            ? Icons.check_circle_rounded
                                            : (perm.canRead
                                                ? Icons.radio_button_checked_rounded
                                                : Icons.radio_button_unchecked_rounded),
                                        size: 22,
                                        color: (allGranted || Permissions.isSuperAdmin(widget.roleName))
                                            ? const Color(0xFF10B981) // Emerald green
                                            : (perm.canRead
                                                ? (isDark ? const Color(0xFFC5A059) : const Color(0xFF212F3D))
                                                : (isDark ? Colors.white24 : Colors.black26)),
                                      ),
                                onPressed: (isRowUpdating || Permissions.isSuperAdmin(widget.roleName))
                                    ? null
                                    : () => _toggleAllForModule(module, !allGranted),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionBatchBtn({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        backgroundColor: color.withValues(alpha: isDark ? 0.12 : 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 12, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No submodules found matching "$_searchQuery"'
                  : 'No submodules found',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDark ? Colors.white54 : const Color(0xFF607D8B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
