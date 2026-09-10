import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/org_repository.dart';
import '../../domain/org_models.dart';
import '../widgets/company_details_form.dart';

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  bool _loading = false;
  String? _error;
  List<Organization> _organizations = [];

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orgs = await context.read<OrgRepository>().listOrganizations(includeInactive: true);
      if (mounted) {
        setState(() {
          _organizations = orgs;
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
        Permissions.canManageInstitutes(authState.permissions, role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!hasAccess) {
      return Scaffold(
        body: Center(
          child: Text(
            'You do not have access to Organizations.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(
          'Organizations',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        leading: const AppBackButton(fallbackLocation: '/admin/configurations'),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh',
            label: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFFC5A059)),
            onPressed: _loadOrganizations,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Add organization'),
        backgroundColor: const Color(0xFF0369a1),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading && _organizations.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059)));
    }
    if (_error != null && _organizations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadOrganizations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_organizations.isEmpty) {
      return const Center(child: Text('No organizations yet. Add one to get started.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: _organizations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final org = _organizations[i];
        return Card(
          elevation: 0,
          color: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDark
                  ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                  : const Color(0xFFCFD8DC),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onTap: () => _openEditor(existing: org),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF0369a1).withValues(alpha: 0.12),
              child: const Icon(Icons.apartment_rounded, color: Color(0xFF0369a1)),
            ),
            title: Text(org.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              [
                org.code,
                if (org.profile.city != null && org.profile.city!.isNotEmpty) org.profile.city!,
                if (org.profile.email != null && org.profile.email!.isNotEmpty) org.profile.email!,
                if (org.profile.gstNo != null && org.profile.gstNo!.isNotEmpty)
                  'GST: ${org.profile.gstNo}',
                if ((org.profile.contactPerson == null || org.profile.contactPerson!.isEmpty) &&
                    (org.profile.gstNo == null || org.profile.gstNo!.isEmpty))
                  'Tap to add company details',
              ].join(' · '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: org.isActive,
                  onChanged: (v) => _toggleActive(org, v),
                ),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openEditor(existing: org),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: () => _confirmDelete(org),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleActive(Organization org, bool isActive) async {
    try {
      await context.read<OrgRepository>().updateOrganization(org.id, {
        'isActive': isActive,
      });
      _loadOrganizations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDelete(Organization org) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove organization?'),
        content: Text('“${org.name}” will be removed if unused, otherwise deactivated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<OrgRepository>().deleteOrganization(org.id);
      _loadOrganizations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openEditor({Organization? existing}) async {
    final result = await showOrganizationEditorDialog(context, existing: existing);
    if (result == null || !mounted) return;
    try {
      if (existing == null) {
        await context.read<OrgRepository>().createOrganization(result.body);
      } else {
        await context.read<OrgRepository>().updateOrganization(existing.id, result.body);
      }
      _loadOrganizations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null ? 'Organization created' : 'Organization updated'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
