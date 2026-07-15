import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/domain/permissions.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final user = auth.user;
    final name = user?.name ?? 'there';
    final role = user?.role ?? '';
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final medium = MediaQuery.sizeOf(context).width >= 720;

    Future<void> logout() async {
      await ref.read(authNotifierProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }

    final hasWorkforce = Permissions.canViewWorkforce(auth.permissions, auth.user?.employeeViewScope);
    final isHR = const ['ADMIN', 'HR'].contains(role.toUpperCase());
    final canApproveLeave = Permissions.canApproveLeave(auth.permissions);
    final canAdminLeave = Permissions.canAdminLeave(
      auth.permissions,
      role,
      auth.user?.employeeViewScope,
    );
    final canAdminAttendance = Permissions.canAdminAttendance(auth.permissions, role);
    final canAccessAdmin = Permissions.canAccessAdminPortal(
      auth.permissions,
      auth.user?.employeeViewScope,
    );
    final canManageUsers = Permissions.canManageUsers(auth.permissions, role);
    final canManageRoles = Permissions.canManageRoles(auth.permissions, role);
    final canManageInstitutes = Permissions.canManageInstitutes(auth.permissions, role);

    final modules = <_ModuleCardData>[
      _ModuleCardData(
        title: 'Leave',
        subtitle: 'Balances, apply, and history',
        icon: Icons.event_available_outlined,
        route: '/leave',
        enabled: Permissions.canReadLeave(auth.permissions) ||
            Permissions.canWriteLeave(auth.permissions) ||
            user?.employeeId != null,
      ),
      _ModuleCardData(
        title: 'Attendance',
        subtitle: 'Calendar and punch history',
        icon: Icons.fingerprint_outlined,
        route: '/attendance',
        enabled: Permissions.canReadAttendance(auth.permissions) ||
            user?.employeeId != null,
      ),
      _ModuleCardData(
        title: 'Profile',
        subtitle: 'View and update your profile',
        icon: Icons.person_outline,
        route: '/profile',
        enabled: true,
      ),
      _ModuleCardData(
        title: 'Payroll',
        subtitle: Permissions.canReadSalary(auth.permissions)
            ? 'Records, entry, structures'
            : 'No salary access',
        icon: Icons.payments_outlined,
        route: '/admin/salary/records',
        enabled: Permissions.canReadSalary(auth.permissions),
      ),
      if (canApproveLeave)
        _ModuleCardData(
          title: 'Leave Approvals',
          subtitle: 'Pending leave requests to review',
          icon: Icons.rule_outlined,
          route: '/approvals',
          enabled: true,
        ),
      if (hasWorkforce)
        _ModuleCardData(
          title: 'Workforce',
          subtitle: 'Manage workforce directory',
          icon: Icons.people_outline,
          route: '/admin/employees',
          enabled: true,
        ),
      if (canAccessAdmin)
        _ModuleCardData(
          title: 'Admin Dashboard',
          subtitle: 'HR system overview and KPIs',
          icon: Icons.dashboard_outlined,
          route: '/admin/dashboard',
          enabled: true,
        ),
      if (canManageUsers)
        _ModuleCardData(
          title: 'Users',
          subtitle: 'Manage login accounts and roles',
          icon: Icons.manage_accounts_outlined,
          route: '/admin/users',
          enabled: true,
        ),
      if (canManageRoles)
        _ModuleCardData(
          title: 'Roles',
          subtitle: 'Position permissions matrix',
          icon: Icons.shield_outlined,
          route: '/admin/roles',
          enabled: true,
        ),
      if (canManageUsers || canManageInstitutes)
        _ModuleCardData(
          title: 'Institutes',
          subtitle: 'Campuses and sub-organizations',
          icon: Icons.business_outlined,
          route: '/admin/institutes',
          enabled: true,
        ),
      if (canManageUsers)
        _ModuleCardData(
          title: 'Designations',
          subtitle: 'Job titles and alias accounts',
          icon: Icons.badge_outlined,
          route: '/admin/designations',
          enabled: true,
        ),
      if (isHR)
        _ModuleCardData(
          title: 'Profile Approvals',
          subtitle: 'Review employee profile changes',
          icon: Icons.assignment_turned_in_outlined,
          route: '/admin/approvals',
          enabled: true,
        ),
      if (canAdminLeave)
        _ModuleCardData(
          title: 'Leave Admin',
          subtitle: 'Policies, holidays, and settings',
          icon: Icons.calendar_month_outlined,
          route: '/admin/leaves',
          enabled: true,
        ),
      if (canAdminAttendance)
        _ModuleCardData(
          title: 'Attendance Admin',
          subtitle: 'Manage attendance records',
          icon: Icons.admin_panel_settings_outlined,
          route: '/admin/attendance',
          enabled: true,
        ),
      if (canAccessAdmin)
        _ModuleCardData(
          title: 'Audit',
          subtitle: 'Change history (REST pending)',
          icon: Icons.history_edu_outlined,
          route: '/admin/audit',
          enabled: true,
        ),
    ];

    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.midnight,
              ),
        ),
        if (role.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.mist,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              role,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.slate,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          "Here's what's available in NB Developer today.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );

    final grid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 3 : (medium ? 2 : 1),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: medium ? 1.55 : 2.6,
      ),
      itemBuilder: (context, index) {
        final item = modules[index];
        return _ModuleCard(
          data: item,
          onTap: item.enabled && item.route != null
              ? () => context.go(item.route!)
              : null,
        );
      },
    );

    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Padding(
        padding: EdgeInsets.fromLTRB(medium ? 28 : 16, 24, medium ? 28 : 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            greeting,
            const SizedBox(height: 28),
            Text(
              'Modules',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.midnight,
                  ),
            ),
            const SizedBox(height: 12),
            grid,
          ],
        ),
      ),
    );

    if (!wide) {
      return Scaffold(
        backgroundColor: AppColors.sand,
        appBar: AppBar(
          title: const Text('NB Developer'),
          actions: [
            TextButton(
              onPressed: logout,
              child: const Text('Sign out', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: SingleChildScrollView(child: content),
      );
    }

    final railRoutes = <String>[
      '/home',
      if (Permissions.canReadLeave(auth.permissions) ||
          Permissions.canWriteLeave(auth.permissions))
        '/leave',
      if (Permissions.canReadAttendance(auth.permissions)) '/attendance',
      '/profile',
      if (hasWorkforce) '/admin/employees',
      if (canManageUsers) '/admin/users',
      if (canManageRoles) '/admin/roles',
      if (canAccessAdmin) '/admin/dashboard',
      if (canApproveLeave) '/approvals',
      if (isHR) '/admin/approvals',
    ];

    return Scaffold(
      backgroundColor: AppColors.sand,
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AppColors.midnight,
            selectedIndex: 0,
            extended: true,
            minExtendedWidth: 220,
            selectedIconTheme: const IconThemeData(color: AppColors.midnight),
            unselectedIconTheme:
                IconThemeData(color: Colors.white.withValues(alpha: 0.75)),
            selectedLabelTextStyle: const TextStyle(
              color: AppColors.midnight,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
            ),
            indicatorColor: AppColors.bronze,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bronze,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'NB',
                      style: TextStyle(
                        color: AppColors.midnight,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'NB Developer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Home'),
              ),
              if (Permissions.canReadLeave(auth.permissions) ||
                  Permissions.canWriteLeave(auth.permissions))
                const NavigationRailDestination(
                  icon: Icon(Icons.event_available_outlined),
                  selectedIcon: Icon(Icons.event_available),
                  label: Text('Leave'),
                ),
              if (Permissions.canReadAttendance(auth.permissions))
                const NavigationRailDestination(
                  icon: Icon(Icons.fingerprint_outlined),
                  selectedIcon: Icon(Icons.fingerprint),
                  label: Text('Attendance'),
                ),
              const NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Profile'),
              ),
              if (hasWorkforce)
                const NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Workforce'),
                ),
              if (canManageUsers)
                const NavigationRailDestination(
                  icon: Icon(Icons.manage_accounts_outlined),
                  selectedIcon: Icon(Icons.manage_accounts),
                  label: Text('Users'),
                ),
              if (canManageRoles)
                const NavigationRailDestination(
                  icon: Icon(Icons.shield_outlined),
                  selectedIcon: Icon(Icons.shield),
                  label: Text('Roles'),
                ),
              if (canAccessAdmin)
                const NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
              if (canApproveLeave)
                const NavigationRailDestination(
                  icon: Icon(Icons.rule_outlined),
                  selectedIcon: Icon(Icons.rule),
                  label: Text('Leave Approvals'),
                ),
              if (isHR)
                const NavigationRailDestination(
                  icon: Icon(Icons.assignment_turned_in_outlined),
                  selectedIcon: Icon(Icons.assignment_turned_in),
                  label: Text('Profile Approvals'),
                ),
            ],
            onDestinationSelected: (index) {
              if (index < railRoutes.length) {
                context.go(railRoutes[index]);
              }
            },
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: TextButton.icon(
                    onPressed: logout,
                    icon: Icon(
                      Icons.logout,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    label: Text(
                      'Sign out',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: SingleChildScrollView(child: content)),
        ],
      ),
    );
  }
}

class _ModuleCardData {
  const _ModuleCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.enabled,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? route;
  final bool enabled;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.data, this.onTap});

  final _ModuleCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: AppColors.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: enabled
                        ? AppColors.bronze.withValues(alpha: 0.18)
                        : AppColors.mist,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    data.icon,
                    color: enabled ? AppColors.midnight : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.midnight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
