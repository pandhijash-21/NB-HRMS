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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Institute Detail'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => ref.invalidate(instituteMembersProvider(instituteId)),
          ),
        ],
      ),
      body: membersAsync.when(
        data: (data) => _buildContent(context, data),
        loading: () => Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load institute\n$err', textAlign: TextAlign.center),
              SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/admin/institutes'),
                child: Text('← Back to institutes'),
              ),
              SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(instituteMembersProvider(instituteId)),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, InstituteMembersPayload data) {
    return ListView(
      padding: EdgeInsets.all(16),
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
          style: TextStyle(
            fontFamily: 'monospace',
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _statCard(context, 'Employees', '${data.employees.length}')),
          ],
        ),
        SizedBox(height: 16),
        _sectionCard(
          title: 'Employees',
          child: data.employees.isEmpty
              ? Text(
                  'No employees assigned to this institute.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              : Column(
                  children: data.employees.map((emp) => _employeeRow(context, emp)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
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
            SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Theme.of(context).textTheme.bodySmall?.color,
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
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.midnight),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            SizedBox(height: 12),
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
        padding: EdgeInsets.symmetric(vertical: 10),
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
}
