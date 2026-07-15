import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/org_models.dart';
import '../org_providers.dart';

class InstituteDetailScreen extends ConsumerWidget {
  const InstituteDetailScreen({super.key, required this.instituteId});

  final String instituteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final role = auth.user?.role ?? '';
    final hasAccess = Permissions.canManageUsers(auth.permissions, role) ||
        Permissions.canManageInstitutes(auth.permissions, role) ||
        Permissions.canViewWorkforce(auth.permissions, auth.user?.employeeViewScope);

    if (!hasAccess) {
      return const Scaffold(
        body: Center(child: Text('Access Denied')),
      );
    }

    final membersAsync = ref.watch(instituteMembersProvider(instituteId));

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Institute Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(instituteMembersProvider(instituteId)),
          ),
        ],
      ),
      body: membersAsync.when(
        data: (data) => _buildContent(context, data),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.bronze),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load institute\n$err', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/admin/institutes'),
                child: const Text('← Back to institutes'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(instituteMembersProvider(instituteId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, InstituteMembersPayload data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextButton(
          onPressed: () => context.go('/admin/institutes'),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text('← All institutes'),
          ),
        ),
        Text(
          data.institute.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.midnight,
              ),
        ),
        Text(
          data.institute.code,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _statCard('Employees', '${data.employees.length}')),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Alias accounts', '${data.aliases.length}')),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Employees',
          child: data.employees.isEmpty
              ? const Text(
                  'No employees assigned to this institute.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              : Column(
                  children: data.employees.map((emp) => _employeeRow(context, emp)).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Alias accounts',
          subtitle:
              'Logins scoped to this institute (e.g. HOI-GIT). Matched by institute code or login suffix.',
          child: data.aliases.isEmpty
              ? const Text(
                  'No alias accounts for this institute.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              : Column(
                  children: data.aliases.map((alias) => _aliasRow(alias)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.midnight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.midnight),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _employeeRow(BuildContext context, InstituteMember emp) {
    final name = emp.generalInfo?.fullName ?? 'Employee #${emp.id}';
    return InkWell(
      onTap: () => context.push('/admin/employees/${emp.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.midnight,
                    ),
                  ),
                  if (emp.generalInfo?.employeeCode != null)
                    Text(
                      emp.generalInfo!.employeeCode!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            Text(
              emp.generalInfo?.designation ?? '—',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aliasRow(AliasAccount alias) {
    final active = alias.userActive ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alias.code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: AppColors.midnight,
                  ),
                ),
                Text(alias.name, style: const TextStyle(fontSize: 13)),
                Text(
                  'Position: ${alias.designationName} · ${alias.linkedRoleName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active ? AppColors.successSoft : AppColors.mist,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              active ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
