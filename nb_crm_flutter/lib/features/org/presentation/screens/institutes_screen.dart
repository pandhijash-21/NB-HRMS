import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/org_models.dart';
import '../org_providers.dart';
import '../widgets/company_details_form.dart';

class InstitutesScreen extends ConsumerWidget {
  const InstitutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final role = auth.user?.role ?? '';
    final hasAccess = Permissions.canManageUsers(auth.permissions, role) ||
        Permissions.canManageInstitutes(auth.permissions, role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!hasAccess) {
      return Scaffold(
        body: Center(
          child: Text(
            'You do not have access to Institutes.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      );
    }

    final institutesAsync = ref.watch(institutesListProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Institutes',
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
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/admin/configurations'),
        ),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh',
            label: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFFC5A059)),
            onPressed: () => ref.invalidate(institutesListProvider),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add institute'),
        backgroundColor: const Color(0xFFc2410c),
        foregroundColor: Colors.white,
      ),
      body: institutesAsync.when(
        data: (institutes) {
          if (institutes.isEmpty) {
            return const Center(child: Text('No institutes configured yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: institutes.length,
            itemBuilder: (context, index) =>
                _instituteRow(context, ref, institutes[index], isDark),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFC5A059)),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load institutes\n$err', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(institutesListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instituteRow(
    BuildContext context,
    WidgetRef ref,
    Institute inst,
    bool isDark,
  ) {
    final parentLabel = inst.parentOrganization?.name;
    return Opacity(
      opacity: inst.isActive ? 1 : 0.5,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark
                ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: () => context.push('/admin/institutes/${inst.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.business_rounded,
                    color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inst.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          inst.code,
                          if (inst.isChildCompany && parentLabel != null)
                            'Child of $parentLabel',
                          if (inst.profile.city != null) inst.profile.city!,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _openEditor(context, ref, existing: inst),
                ),
                Switch(
                  value: inst.isActive,
                  onChanged: (checked) => _toggleActive(context, ref, inst.id, checked),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                  onPressed: () => _confirmDelete(context, ref, inst),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white24 : Colors.grey,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    String id,
    bool isActive,
  ) async {
    try {
      await ref.read(orgRepositoryProvider).updateInstitute(id, {'isActive': isActive});
      ref.invalidate(institutesListProvider);
      ref.invalidate(activeInstitutesProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update institute: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Institute inst,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete institute?'),
        content: Text('Delete “${inst.name}”? If in use it will be deactivated.'),
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
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(orgRepositoryProvider).deleteInstitute(inst.id);
      ref.invalidate(institutesListProvider);
      ref.invalidate(activeInstitutesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Institute removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Institute? existing,
  }) async {
    List<Organization> orgs = const [];
    String? orgsError;
    try {
      orgs = await ref.read(activeOrganizationsProvider.future);
    } catch (e) {
      try {
        final all = await ref.read(organizationsListProvider.future);
        orgs = all.where((o) => o.isActive).toList();
      } catch (e2) {
        orgsError = '$e2';
      }
    }
    if (!context.mounted) return;

    final result = await showInstituteEditorDialog(
      context,
      existing: existing,
      organizations: orgs,
      organizationsError: orgsError,
    );
    if (result == null || !context.mounted) return;

    try {
      if (existing == null) {
        await ref.read(orgRepositoryProvider).createInstitute(result.body);
      } else {
        await ref.read(orgRepositoryProvider).updateInstitute(existing.id, result.body);
      }
      ref.invalidate(institutesListProvider);
      ref.invalidate(activeInstitutesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null ? 'Institute created' : 'Institute updated'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
