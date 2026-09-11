import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/rbac_models.dart';
import '../bloc/admin_roles_bloc.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final bloc = context.read<AdminRolesBloc>();
    if (bloc.state.status == LoadStatus.initial) {
      bloc.add(const AdminRolesLoadRequested());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!Permissions.canManageRoles(auth.permissions, auth.user?.role)) {
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
                'You do not have permission to manage roles.',
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

    final rolesState = context.watch<AdminRolesBloc>().state;
    final filtered = rolesState.filteredRoles;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Roles & Permissions',
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
            tooltip: 'Add new custom role',
            label: 'Add Role',
            icon: const Icon(
              Icons.add_moderator_rounded,
              size: 18,
              color: Color(0xFFC5A059),
            ),
            onPressed: () {
              _showCreateRoleDialog(rolesState.roles);
            },
          ),
          const SizedBox(width: 8),
          HeaderActionButton(
            tooltip: 'Refresh list',
            label: 'Refresh',
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF212F3D),
            ),
            onPressed: () => context.read<AdminRolesBloc>().add(const AdminRolesLoadRequested()),
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
      body: BlocListener<AdminRolesBloc, AdminRolesState>(
        listenWhen: (prev, curr) =>
            prev.actionMessage != curr.actionMessage ||
            prev.errorMessage != curr.errorMessage,
        listener: (context, state) {
          if (state.actionMessage != null) {
            _snack(state.actionMessage!);
          } else if (state.errorMessage != null) {
            _snack(state.errorMessage!.replaceFirst('Exception: ', ''));
          }
        },
        child: TweenAnimationBuilder<double>(
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
              _buildSearchBar(context),
              _buildInfoBanner(context),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (rolesState.status == LoadStatus.loading && rolesState.roles.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                      );
                    }
                    if (rolesState.status == LoadStatus.failure && rolesState.roles.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load roles: ${rolesState.errorMessage ?? "Unknown error"}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => context.read<AdminRolesBloc>().add(const AdminRolesLoadRequested()),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 64,
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No roles found.\nTap "+ Add Role" to create a custom role.',
                              textAlign: TextAlign.center,
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final role = filtered[index];
                        return _RoleCard(
                          role: role,
                          onMatrix: () => context.go('/admin/roles/${role.id}'),
                          onEdit: () => _showEditRoleDialog(role),
                          onDelete: () => _confirmDelete(role),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
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
      child: TextField(
        controller: _searchController,
        onChanged: (v) => context.read<AdminRolesBloc>().add(AdminRolesFiltersChanged(search: v)),
        decoration: InputDecoration(
          hintText: 'Find roles...',
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
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ColoredBox(
              color: Color(0xFFC5A059),
              child: SizedBox(width: 4),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: Color(0xFFC5A059), size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Full RBAC Freedom: System Admins have full authority to manage all modules, create custom roles, and configure granular permissions across HRMS, CRM, and ERP. (Only Superadmin can create Admin accounts).',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF212F3D),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateRoleDialog(List<RoleSummary> existingRoles) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? cloneRoleId;
    final formKey = GlobalKey<FormState>();

    await showDialog<bool>(
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
          title: Row(
            children: [
              const Icon(Icons.add_moderator_rounded, color: Color(0xFFC5A059), size: 24),
              const SizedBox(width: 10),
              Text(
                'Create Custom Role',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Define a new role and optionally clone permission defaults from an existing role.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Role Name (Uppercase)',
                      hintText: 'e.g. FINANCE_LEAD, STORE_INCHARGE',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFF8FAFC),
                    ),
                    validator: (val) {
                      final v = val?.trim().toUpperCase() ?? '';
                      if (v.isEmpty) return 'Role name is required';
                      if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(v)) {
                        return 'Only uppercase letters, digits, and underscores allowed';
                      }
                      if (['SUPERADMIN', 'SYSTEM_ADMIN', 'SYSTEMADMIN', 'ADMIN'].contains(v)) {
                        return 'Reserved system administrator name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Role Description',
                      hintText: 'Brief description of duties and privileges',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFF8FAFC),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: cloneRoleId,
                    decoration: InputDecoration(
                      labelText: 'Clone Permissions From (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFF8FAFC),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Standard Defaults (Read on all modules)'),
                      ),
                      ...existingRoles.map(
                        (r) => DropdownMenuItem(
                          value: r.id,
                          child: Text('${r.name}${r.positionName != null ? ' (${r.positionName})' : ''}'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setDialogState(() => cloneRoleId = v),
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
                style: TextStyle(
                  color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC5A059),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final data = <String, dynamic>{
                  'name': nameCtrl.text.trim().toUpperCase(),
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  if (cloneRoleId != null) 'cloneRoleId': cloneRoleId,
                };
                context.read<AdminRolesBloc>().add(AdminRoleCreated(data));
                Navigator.pop(ctx, true);
              },
              child: const Text('Create Role', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditRoleDialog(RoleSummary role) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: role.name);
    final descCtrl = TextEditingController(text: role.description ?? '');
    final formKey = GlobalKey<FormState>();
    final isSystemRole = role.isSystem || ['SUPERADMIN', 'SYSTEM_ADMIN', 'ADMIN', 'EMPLOYEE'].contains(role.name);

    await showDialog<bool>(
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
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFFC5A059), size: 24),
            const SizedBox(width: 10),
            Text(
              'Edit Role: ${role.name}',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF212F3D),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isSystemRole) ...[
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Role Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFF8FAFC),
                    ),
                    validator: (val) {
                      final v = val?.trim().toUpperCase() ?? '';
                      if (v.isEmpty) return 'Role name is required';
                      if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(v)) {
                        return 'Only uppercase letters, digits, and underscores allowed';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Role Description',
                    hintText: 'Description of duties and privileges',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFF8FAFC),
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
              style: TextStyle(
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC5A059),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final data = <String, dynamic>{
                if (!isSystemRole) 'name': nameCtrl.text.trim().toUpperCase(),
                'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              };
              context.read<AdminRolesBloc>().add(AdminRoleUpdated(id: role.id, data: data));
              Navigator.pop(ctx, true);
            },
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(RoleSummary role) async {
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
          'Delete Role',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to delete the role ${role.name}?',
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
            child: const Text('Delete Role', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    context.read<AdminRolesBloc>().add(AdminRoleDeleted(role.id));
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.onMatrix,
    required this.onEdit,
    required this.onDelete,
  });

  final RoleSummary role;
  final VoidCallback onMatrix;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = role.positionName ?? role.name;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSuperAdmin = Permissions.isSuperAdmin(role.name);
    final isSystemAdmin = Permissions.isSystemAdmin(role.name);
    final isCoreSystem = role.isSystem || ['SUPERADMIN', 'SYSTEM_ADMIN', 'ADMIN', 'EMPLOYEE'].contains(role.name);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSuperAdmin
              ? const Color(0xFF9C27B0).withValues(alpha: 0.6)
              : isSystemAdmin
                  ? const Color(0xFFC5A059).withValues(alpha: 0.5)
                  : (isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC)),
          width: isSuperAdmin || isSystemAdmin ? 2.0 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isSuperAdmin) ...[
                        const Icon(Icons.workspace_premium_rounded, size: 20, color: Color(0xFFAB47BC)),
                        const SizedBox(width: 6),
                      ] else if (isSystemAdmin) ...[
                        const Icon(Icons.security_rounded, size: 20, color: Color(0xFFC5A059)),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF212F3D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSuperAdmin
                              ? const Color(0xFF4A148C).withValues(alpha: 0.25)
                              : (isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSuperAdmin
                                ? const Color(0xFFAB47BC)
                                : (isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC)),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          role.name,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isSuperAdmin
                                ? const Color(0xFFCE93D8)
                                : (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238)),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (isSuperAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B1FA2).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'SUPERADMIN · SUPREME',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFBA68C8)),
                          ),
                        )
                      else if (isSystemAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC5A059).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'SYSTEM ADMIN',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFC5A059)),
                          ),
                        )
                      else if (role.positionName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'DESIGNATION ROLE',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF616161),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'CUSTOM ROLE',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF4CAF50)),
                          ),
                        ),
                    ],
                  ),
                  if (role.description != null && role.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      role.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
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
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onMatrix,
              icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFFC5A059)),
              label: const Text('Matrix', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF212F3D),
                side: BorderSide(
                  color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.4) : const Color(0xFF263238).withValues(alpha: 0.5),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Edit Role',
              onPressed: onEdit,
              icon: Icon(
                Icons.edit_outlined,
                color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                size: 20,
              ),
            ),
            if (!isCoreSystem) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Delete Role',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
