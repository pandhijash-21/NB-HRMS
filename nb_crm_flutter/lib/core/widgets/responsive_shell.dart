import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'radial_menu.dart';

import '../../features/auth/domain/permissions.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/tracking_hub/presentation/location_alert_watch.dart';
import '../logging/app_logger.dart';
import '../services/location_alert_sound.dart';
import '../theme/theme_provider.dart';

class ResponsiveShell extends ConsumerStatefulWidget {
  const ResponsiveShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends ConsumerState<ResponsiveShell> {
  bool _isExpanded = true;

  Widget _buildSpeedDial(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const goldColor = Color(0xFFC5A059);
    
    // Main button colors
    final mainBgColor = isDark ? goldColor : const Color(0xFF263238);
    final mainIconColor = isDark ? const Color(0xFF1A1816) : Colors.white;
    
    // Item button colors
    final itemBgColor = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final itemFgColor = isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238);
    
    return RadialMenu(
      primaryColor: mainBgColor,
      onPrimaryColor: mainIconColor,
      items: [
        RadialMenuItem(
          icon: Icons.groups_rounded,
          label: 'HRMS',
          backgroundColor: itemBgColor,
          foregroundColor: itemFgColor,
          onTap: () => context.go('/home'),
        ),
        RadialMenuItem(
          icon: Icons.account_balance_rounded,
          label: 'ERP',
          backgroundColor: itemBgColor,
          foregroundColor: itemFgColor,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ERP Module Coming Soon')),
            );
          },
        ),
        RadialMenuItem(
          icon: Icons.support_agent_rounded,
          label: 'CRM',
          backgroundColor: itemBgColor,
          foregroundColor: itemFgColor,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CRM Module Coming Soon')),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final width = MediaQuery.sizeOf(context).width;
    // Sidebar from tablet up; phones keep the drawer.
    final useSidebar = width >= 720;
    final allowExpandedSidebar = width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasWorkforce = Permissions.canViewWorkforce(
      auth.permissions,
      auth.user?.employeeViewScope,
    );
    final isHR = const [
      'ADMIN',
      'HR',
    ].contains(auth.user?.role.toUpperCase() ?? '');
    final canTrackField = canAccessFieldTracking(auth.user?.role);
    final canApproveLeave = Permissions.canApproveLeave(auth.permissions);
    final canAccessAdmin = Permissions.canAccessAdminPortal(
      auth.permissions,
      auth.user?.employeeViewScope,
    );
    final canManageUsers = Permissions.canManageUsers(
      auth.permissions,
      auth.user?.role ?? '',
    );
    final canManageRoles = Permissions.canManageRoles(
      auth.permissions,
      auth.user?.role ?? '',
    );

    final destinations = <_Destination>[
      if (canAccessAdmin)
        const _Destination(
          '/admin/dashboard',
          Icons.dashboard_outlined,
          Icons.dashboard,
          'Dashboard',
        ),
      const _Destination('/home', Icons.home_outlined, Icons.home, 'Home'),
      const _Destination(
        '/org-tree',
        Icons.account_tree_outlined,
        Icons.account_tree,
        'Employee tree',
      ),
      const _Destination(
        '/tasks',
        Icons.task_alt_outlined,
        Icons.task_alt,
        'Tasks',
      ),
      const _Destination(
        '/profile',
        Icons.person_outline,
        Icons.person,
        'Profile',
      ),
      if (Permissions.canReadLeave(auth.permissions) ||
          Permissions.canWriteLeave(auth.permissions) ||
          canApproveLeave ||
          Permissions.canAdminLeave(
            auth.permissions,
            auth.user?.role ?? '',
            auth.user?.employeeViewScope,
          ))
        const _Destination(
          '/leave',
          Icons.event_available_outlined,
          Icons.event_available,
          'Leave',
        ),
      if (Permissions.canReadAttendance(auth.permissions))
        const _Destination(
          '/attendance',
          Icons.fingerprint_outlined,
          Icons.fingerprint,
          'Attendance',
        ),
      if (hasWorkforce)
        const _Destination(
          '/admin/employees',
          Icons.people_outline,
          Icons.people,
          'Workforce',
        ),
      if (canManageUsers)
        const _Destination(
          '/admin/users',
          Icons.manage_accounts_outlined,
          Icons.manage_accounts,
          'Users',
        ),
      if (canManageRoles)
        const _Destination(
          '/admin/roles',
          Icons.shield_outlined,
          Icons.shield,
          'Roles',
        ),
      if (isHR)
        const _Destination(
          '/admin/approvals',
          Icons.assignment_turned_in_outlined,
          Icons.assignment_turned_in,
          'Profile Approvals',
        ),
      if (canTrackField)
        const _Destination(
          '/admin/live-tracking',
          Icons.location_on_outlined,
          Icons.location_on,
          'Live Tracking',
        ),
      if (canTrackField)
        const _Destination(
          '/admin/trips',
          Icons.route_outlined,
          Icons.route,
          'Trips',
        ),
      if (canTrackField)
        const _Destination(
          '/admin/tracking-hub',
          Icons.insights_outlined,
          Icons.insights,
          'Tracking Hub',
          alertBadge: true,
        ),
    ];

    final currentPath = GoRouterState.of(context).matchedLocation;
    final alertCount = canTrackField
        ? ref.watch(locationAlertWatchProvider).count
        : 0;
    final selectedIndex = destinations
        .indexWhere((d) {
          if (d.route == '/leave') {
            return currentPath.startsWith('/leave') ||
                currentPath.startsWith('/approvals') ||
                currentPath.startsWith('/admin/leaves');
          }
          return currentPath.startsWith(d.route);
        })
        .clamp(0, destinations.length - 1);

    // Ensure index doesn't fall below 0 if not matched exactly
    final safeSelectedIndex = selectedIndex == -1 ? 0 : selectedIndex;

    void onDestinationSelected(int index) {
      context.go(destinations[index].route);
    }

    if (!useSidebar) {
      return _wrapExitConfirm(
        context,
        Scaffold(
        appBar: AppBar(
          title: const Text('NB Developer'),
          actions: [
            IconButton(
              tooltip: 'Employee tree',
              icon: const Icon(Icons.account_tree_rounded),
              onPressed: () => context.go('/org-tree'),
            ),
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () =>
                  ref.read(themeModeProvider.notifier).toggleTheme(),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: isDark ? const Color(0xFF1A1816) : const Color(0xFFECEFF1),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Custom Drawer Header matching sidebar branding
              Container(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildLogo(context),
                        const SizedBox(width: 12),
                        Text(
                          'NB Developer',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: isDark ? Colors.white : const Color(0xFF212F3D),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      auth.user?.name ?? '',
                      style: TextStyle(
                        color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF263238),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (auth.user?.role != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        auth.user!.role.toUpperCase(),
                        style: TextStyle(
                          color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Destinations list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context); // Close drawer
                            onDestinationSelected(i);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 48,
                            decoration: BoxDecoration(
                              color: safeSelectedIndex == i
                                  ? (isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFDFE6E9))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: safeSelectedIndex == i
                                  ? Border.all(color: isDark ? const Color(0xFFC5A059).withOpacity(0.25) : const Color(0xFFB0BEC5), width: 1.2)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Icon(
                                  safeSelectedIndex == i
                                      ? destinations[i].selectedIcon
                                      : destinations[i].icon,
                                  color: safeSelectedIndex == i
                                      ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238))
                                      : (isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF607D8B).withOpacity(0.7)),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    destinations[i].label,
                                    style: TextStyle(
                                      color: safeSelectedIndex == i
                                          ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238))
                                          : (isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF607D8B).withOpacity(0.8)),
                                      fontWeight: safeSelectedIndex == i ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (destinations[i].alertBadge)
                                  _alertCountBadge(alertCount),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Theme Toggle and Sign Out inside drawer bottom
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.08) : const Color(0xFFE5ECF0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.18) : const Color(0xFFCCD6DD),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(themeModeProvider.notifier).toggleTheme();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(
                              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF263238),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isDark ? 'Light Mode' : 'Dark Mode',
                                style: TextStyle(
                                  color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF263238),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(
                        height: 8,
                        color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCCD6DD),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(authNotifierProvider.notifier).logout();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(
                              Icons.logout_rounded,
                              color: const Color(0xFFEF4444).withOpacity(0.9),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sign out',
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
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
            ],
          ),
        ),
        body: Stack(
          children: [
            widget.child,
            _buildSpeedDial(context),
          ],
        ),
      ),
      );
    }

    return _wrapExitConfirm(
      context,
      Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              _buildSidebarContent(
                context,
                safeSelectedIndex,
                destinations,
                isDark,
                allowExpanded: allowExpandedSidebar,
                alertCount: alertCount,
              ),
              Expanded(child: widget.child),
            ],
          ),
          _buildSpeedDial(context),
        ],
      ),
    ),
    );
  }

  Widget _wrapExitConfirm(BuildContext context, Widget child) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        LocationAlertSound.unlock();
      },
      child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
          return;
        }
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exit app?'),
            content: const Text('Do you want to exit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          AppLogger.router.i('user confirmed exit');
          SystemNavigator.pop();
        }
      },
      child: child,
    ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/nbdeveloperlogo.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.primary,
            alignment: Alignment.center,
            child: const Text('NB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          );
        },
      ),
    );
  }

  Widget _alertCountBadge(int count, {bool compact = false}) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 16 : 20, minHeight: compact ? 16 : 20),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFB71C1C),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildSidebarContent(
    BuildContext context,
    int safeSelectedIndex,
    List<_Destination> destinations,
    bool isDark, {
    bool allowExpanded = true,
    int alertCount = 0,
  }) {
    final expanded = allowExpanded && _isExpanded;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: expanded ? 260 : 80,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1816) : const Color(0xFFECEFF1),
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            height: expanded ? 90 : 128,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (!expanded)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (allowExpanded)
                          IconButton(
                            icon: Icon(
                              Icons.menu_rounded,
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : const Color(0xFF607D8B).withOpacity(0.7),
                            ),
                            onPressed: () {
                              setState(() => _isExpanded = true);
                            },
                            tooltip: 'Expand sidebar',
                          )
                        else
                          _buildLogo(context),
                      ],
                    ),
                  )
                else ...[
                  _buildLogo(context),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'NB Developer',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.menu_open_rounded,
                      color: isDark
                          ? Colors.white.withOpacity(0.5)
                          : const Color(0xFF607D8B).withOpacity(0.7),
                    ),
                    onPressed: () {
                      setState(() => _isExpanded = false);
                    },
                    tooltip: 'Collapse sidebar',
                  ),
                ],
              ],
            ),
          ),
          
          // Destinations
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: destinations.asMap().entries.map((entry) {
                final index = entry.key;
                final d = entry.value;
                final isSelected = safeSelectedIndex == index;
                
                return InkWell(
                  onTap: () {
                    context.go(d.route);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? (isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFDFE6E9))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected 
                          ? Border.all(color: isDark ? const Color(0xFFC5A059).withOpacity(0.25) : const Color(0xFFB0BEC5), width: 1.2)
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: OverflowBox(
                      minWidth: 228,
                      maxWidth: 228,
                      minHeight: 48,
                      maxHeight: 48,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                isSelected ? d.selectedIcon : d.icon,
                                color: isSelected 
                                    ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238))
                                    : (isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF607D8B).withOpacity(0.7)),
                                size: 24,
                              ),
                              if (d.alertBadge && !expanded)
                                Positioned(
                                  right: -8,
                                  top: -6,
                                  child: _alertCountBadge(alertCount, compact: true),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              d.label,
                              style: TextStyle(
                                color: isSelected 
                                    ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238))
                                    : (isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF607D8B).withOpacity(0.8)),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                            ),
                          ),
                          if (d.alertBadge && expanded) _alertCountBadge(alertCount),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Bottom Actions
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.08) : const Color(0xFFE5ECF0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFFC5A059).withOpacity(0.18) : const Color(0xFFCCD6DD),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 44,
                    child: OverflowBox(
                      minWidth: 228,
                      maxWidth: 228,
                      minHeight: 44,
                      maxHeight: 44,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(
                            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF263238),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isDark ? 'Light Mode' : 'Dark Mode',
                              style: TextStyle(
                                color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF263238),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(
                    height: 8, 
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCCD6DD),
                  ),
                ),
                InkWell(
                  onTap: () => ref.read(authNotifierProvider.notifier).logout(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 44,
                    child: OverflowBox(
                      minWidth: 228,
                      maxWidth: 228,
                      minHeight: 44,
                      maxHeight: 44,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(
                            Icons.logout_rounded,
                            color: const Color(0xFFEF4444).withOpacity(0.9),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sign out',
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(
    this.route,
    this.icon,
    this.selectedIcon,
    this.label, {
    this.alertBadge = false,
  });
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool alertBadge;
}
