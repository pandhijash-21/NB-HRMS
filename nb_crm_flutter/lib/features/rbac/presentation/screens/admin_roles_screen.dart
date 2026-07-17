import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../org/presentation/org_providers.dart';
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF212F3D),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh list',
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF212F3D),
            ),
            onPressed: () => ref.read(rolesListProvider.notifier).refresh(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: SizedBox(
              height: 38,
              child: FilledButton.icon(
                onPressed: () => _showCreatePositionDialog(context),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Create Position',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
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
            _buildSearchBar(context),
            _buildInfoBanner(context),
            Expanded(
              child: rolesAsync.when(
                data: (_) {
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
                            'No designations / positions found.\nCreate one with “Create Position”.',
                            textAlign: TextAlign.center,
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: filtered.length,
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
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load roles: $err',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
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
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => ref.read(rolesFilterProvider.notifier).setSearch(v),
        decoration: InputDecoration(
          hintText: 'Find positions...',
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
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: const BorderSide(color: Color(0xFFC5A059), width: 4),
          top: BorderSide(color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC)),
          right: BorderSide(color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC)),
          bottom: BorderSide(color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFC5A059), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Each row is a designation / institutional position. Open its matrix to turn permissions on or off. New positions appear here automatically.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreatePositionDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    void suggestRoleCode(String label) {
      final words = label.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      if (words.isEmpty) {
        roleCtrl.text = '';
        return;
      }
      if (words.length == 1) {
        roleCtrl.text = words.first.toUpperCase().substring(
              0,
              words.first.length.clamp(0, 12),
            );
      } else {
        roleCtrl.text = words.map((w) => w[0].toUpperCase()).join();
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? const Color(0xFFC5A059).withValues(alpha: 0.2)
                : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
        title: Text(
          'Create Position',
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
              Text(
                'Creates a designation (position type) linked to a role. It will show up in this list so you can set its permission matrix.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: displayCtrl,
                onChanged: suggestRoleCode,
                decoration: const InputDecoration(
                  labelText: 'Display name *',
                  hintText: 'e.g. Head of Institute',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Role code *',
                  hintText: 'e.g. HOI',
                  helperText: 'Uppercase letters / underscores',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
              foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
            ),
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final displayName = displayCtrl.text.trim();
    final roleName = roleCtrl.text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '_');
    if (displayName.isEmpty || roleName.isEmpty) {
      _snack('Display name and role code are required.');
      return;
    }

    try {
      final result = await ref.read(orgRepositoryProvider).createPosition(
            displayName: displayName,
            roleName: roleName,
            description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          );
      await ref.read(rolesListProvider.notifier).refresh();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Position "$displayName" created.')),
      );
      final newRoleId = result.role.id;
      if (newRoleId.isNotEmpty && mounted) {
        context.go('/admin/roles/$newRoleId');
      }
    } catch (e) {
      if (mounted) {
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, RoleSummary role) async {
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
          'Delete Role',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to delete the position role ${role.name}?',
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: TextStyle(
                      fontWeight: FontWeight.w800, 
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      role.name,
                      style: TextStyle(
                        fontSize: 9, 
                        fontWeight: FontWeight.w800, 
                        color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                        letterSpacing: 0.5,
                      ),
                    ),
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
              icon: const Icon(Icons.settings_outlined, size: 16, color: Color(0xFFC5A059)),
              label: const Text('Matrix', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                side: BorderSide(
                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFF263238).withOpacity(0.5),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
