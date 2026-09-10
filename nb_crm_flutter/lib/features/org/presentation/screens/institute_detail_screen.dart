import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/org_repository.dart';
import '../../domain/org_models.dart';

class InstituteDetailScreen extends StatefulWidget {
  const InstituteDetailScreen({super.key, required this.instituteId});

  final String instituteId;

  @override
  State<InstituteDetailScreen> createState() => _InstituteDetailScreenState();
}

class _InstituteDetailScreenState extends State<InstituteDetailScreen> {
  bool _loading = false;
  String? _error;
  InstituteMembersPayload? _data;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await context.read<OrgRepository>().getInstituteMembers(widget.instituteId);
      if (mounted) {
        setState(() {
          _data = payload;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final role = authState.user?.role ?? '';
    final hasAccess = Permissions.canManageUsers(authState.permissions, role) ||
        Permissions.canManageInstitutes(authState.permissions, role) ||
        Permissions.canViewWorkforce(authState.permissions, authState.user?.employeeViewScope);

    if (!hasAccess) {
      return const Scaffold(
        body: Center(child: Text('Access Denied')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Institute Detail'),
        leading: const AppBackButton(fallbackLocation: '/admin/institutes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMembers,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _data == null) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
      );
    }
    if (_error != null && _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load institute\n$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/admin/institutes'),
              child: const Text('← Back to institutes'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loadMembers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_data == null) {
      return const SizedBox.shrink();
    }
    return _buildContent(_data!);
  }

  Widget _buildContent(InstituteMembersPayload data) {
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
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        Text(
          data.institute.code,
          style: TextStyle(
            fontFamily: 'monospace',
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _statCard('Employees', '${data.employees.length}')),
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
                  children: data.employees.map((emp) => _employeeRow(emp)).toList(),
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
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
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

  Widget _employeeRow(InstituteMember emp) {
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
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
