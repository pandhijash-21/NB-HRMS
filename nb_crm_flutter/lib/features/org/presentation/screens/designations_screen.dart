import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/org_models.dart';
import '../org_providers.dart';

class DesignationsScreen extends ConsumerStatefulWidget {
  const DesignationsScreen({super.key});

  @override
  ConsumerState<DesignationsScreen> createState() => _DesignationsScreenState();
}

class _DesignationsScreenState extends ConsumerState<DesignationsScreen> {
  final _nameCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final role = auth.user?.role ?? '';
    final hasAccess = Permissions.canManageUsers(auth.permissions, role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!hasAccess) {
      return _accessDenied(isDark);
    }

    final jobDesignations = ref.watch(jobDesignationsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Designations',
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
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/admin/configurations'),
        ),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh',
            label: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFFC5A059)),
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 8),
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
            child: Opacity(opacity: value, child: child),
          );
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Text(
              'Create and manage job titles for employees.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : const Color(0xFF607D8B),
              ),
            ),
            const SizedBox(height: 20),
            _buildCreateDesignationCard(isDark),
            const SizedBox(height: 20),
            jobDesignations.when(
              data: (list) => _buildDesignationsList(list, isDark),
              loading: () => _LoadingCard(isDark: isDark),
              error: (err, _) => _ErrorCard(
                isDark: isDark,
                message: 'Failed to load designations',
                detail: '$err',
                onRetry: () => ref.invalidate(jobDesignationsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshAll() {
    ref.invalidate(jobDesignationsProvider);
  }

  Widget _buildCreateDesignationCard(bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_rounded, color: Color(0xFFC5A059), size: 20),
                const SizedBox(width: 10),
                Text(
                  'Add Job Designation',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'For employees (Professor, Clerk, …). Creates a matching RBAC role for permissions.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : const Color(0xFF607D8B),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                prefixIcon: const Icon(Icons.work_rounded, color: Color(0xFFC5A059), size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
                ),
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: _creating || _nameCtrl.text.trim().isEmpty ? null : _createDesignation,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                    foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                    disabledBackgroundColor: isDark ? const Color(0xFFC5A059).withOpacity(0.3) : const Color(0xFFCFD8DC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _creating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    _creating ? 'Adding…' : 'Add',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesignationsList(List<Designation> list, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: Color(0xFFC5A059), size: 20),
              const SizedBox(width: 10),
              Text(
                'Job Designations',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                  ),
                ),
                child: Text(
                  '${list.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (list.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.badge_rounded, size: 64, color: isDark ? Colors.white10 : Colors.black12),
                  const SizedBox(height: 16),
                  Text(
                    'No designations yet.',
                    style: TextStyle(
                      color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...list.map((d) => _designationRow(d, isDark)),
      ],
    );
  }

  Widget _designationRow(Designation d, bool isDark) {
    return Opacity(
      opacity: d.isActive ? 1 : 0.5,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                  ),
                ),
                child: Icon(
                  Icons.work_rounded,
                  color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  d.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: d.isActive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  border: Border.all(
                    color: d.isActive ? Colors.green : Colors.grey,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  d.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: d.isActive ? Colors.green : Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Switch(
                value: d.isActive,
                activeColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                onChanged: (checked) => _toggleDesignation(d.id, checked),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                onPressed: () => _confirmDeleteDesignation(d),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createDesignation() async {
    setState(() => _creating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orgRepositoryProvider).createDesignation(
            name: _nameCtrl.text.trim(),
          );
      _nameCtrl.clear();
      ref.invalidate(jobDesignationsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Designation added')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _toggleDesignation(String id, bool isActive) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orgRepositoryProvider).updateDesignation(id, isActive: isActive);
      ref.invalidate(jobDesignationsProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDeleteDesignation(Designation d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete designation?'),
        content: Text(
          'Delete "${d.name}"?\n\n'
          'If employees or salary structures still use it, it will be deactivated instead.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orgRepositoryProvider).deleteDesignation(d.id);
      ref.invalidate(jobDesignationsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Designation deleted / deactivated')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _accessDenied(bool isDark) {
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
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.isDark,
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final bool isDark;
  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF212F3D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF607D8B)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

