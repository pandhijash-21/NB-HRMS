import 'package:flutter/material.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'radial_menu.dart';

import '../../features/auth/domain/permissions.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/collaboration/presentation/chat_inbox.dart';
import '../../features/collaboration/presentation/notification_bell.dart';
import '../../features/tracking_hub/presentation/location_alert_watch.dart';
import '../app_module.dart';
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
  final _navSearch = TextEditingController();

  @override
  void dispose() {
    _navSearch.dispose();
    super.dispose();
  }

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
          onTap: () {
            ref.read(appModuleProvider.notifier).setModule(AppModule.hrms);
            context.go('/home');
          },
        ),
        RadialMenuItem(
          icon: Icons.account_balance_rounded,
          label: 'ERP',
          backgroundColor: itemBgColor,
          foregroundColor: itemFgColor,
          onTap: () {
            ref.read(appModuleProvider.notifier).setModule(AppModule.erp);
            context.go('/erp/home');
          },
        ),
        RadialMenuItem(
          icon: Icons.support_agent_rounded,
          label: 'CRM',
          backgroundColor: itemBgColor,
          foregroundColor: itemFgColor,
          onTap: () {
            ref.read(appModuleProvider.notifier).setModule(AppModule.crm);
            context.go('/chat');
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
    final isAdmin = Permissions.isAdmin(auth.user?.role);

    final currentPath = GoRouterState.of(context).matchedLocation;
    final module = ref.watch(appModuleProvider);
    final brandTitle = shellBrandTitle(module);

    final inferred = inferAppModule(currentPath, module);
    if (inferred != module) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(appModuleProvider.notifier).syncFromPath(currentPath);
      });
    }

    const sharedCollab = <_Destination>[
      _Destination(
        '/org-tree',
        Icons.account_tree_outlined,
        Icons.account_tree,
        'Employee tree',
        section: 'Collaboration',
      ),
      _Destination(
        '/tasks',
        Icons.task_alt_outlined,
        Icons.task_alt,
        'Tasks',
        section: 'Collaboration',
      ),
      _Destination(
        '/chat',
        Icons.chat_outlined,
        Icons.chat,
        'Chat',
        section: 'Collaboration',
      ),
      _Destination(
        '/meet',
        Icons.videocam_outlined,
        Icons.videocam,
        'Meet',
        section: 'Collaboration',
      ),
    ];

    final destinations = <_Destination>[
      if (module == AppModule.hrms) ...[
        if (canAccessAdmin)
          const _Destination(
            '/admin/dashboard',
            Icons.dashboard_outlined,
            Icons.dashboard,
            'Dashboard',
            section: 'Main',
          ),
        const _Destination('/home', Icons.home_outlined, Icons.home, 'Home', section: 'Main'),
        const _Destination(
          '/profile',
          Icons.person_outline,
          Icons.person,
          'Profile',
          section: 'Main',
        ),
      ] else if (module == AppModule.erp) ...[
        const _Destination('/erp/home', Icons.home_outlined, Icons.home, 'Home', section: 'ERP'),
        const _Destination(
          '/erp/projects',
          Icons.apartment_outlined,
          Icons.apartment,
          'Projects',
          section: 'ERP',
        ),
        const _Destination(
          '/erp/work-orders',
          Icons.assignment_outlined,
          Icons.assignment,
          'Work Orders',
          section: 'ERP',
        ),
        if (canAccessAdmin)
          const _Destination(
            '/erp/configurations',
            Icons.settings_outlined,
            Icons.settings,
            'Configurations',
            section: 'ERP',
          ),
      ],
      ...sharedCollab,
      if (module == AppModule.hrms) ...[
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
            section: 'HR',
          ),
        if (Permissions.canReadAttendance(auth.permissions))
          const _Destination(
            '/attendance',
            Icons.fingerprint_outlined,
            Icons.fingerprint,
            'Attendance',
            section: 'HR',
          ),
        if (hasWorkforce)
          const _Destination(
            '/admin/employees',
            Icons.people_outline,
            Icons.people,
            'Workforce',
            section: 'Organisation',
          ),
        if (canManageUsers)
          const _Destination(
            '/admin/users',
            Icons.manage_accounts_outlined,
            Icons.manage_accounts,
            'Users',
            section: 'Organisation',
          ),
        if (canManageRoles)
          const _Destination(
            '/admin/roles',
            Icons.shield_outlined,
            Icons.shield,
            'Roles',
            section: 'Organisation',
          ),
        if (isAdmin)
          const _Destination(
            '/admin/storage',
            Icons.cloud_outlined,
            Icons.cloud,
            'Storage',
            section: 'Organisation',
          ),
        if (isHR)
          const _Destination(
            '/admin/approvals',
            Icons.assignment_turned_in_outlined,
            Icons.assignment_turned_in,
            'Profile Approvals',
            section: 'Organisation',
          ),
        if (canTrackField)
          const _Destination(
            '/admin/live-tracking',
            Icons.location_on_outlined,
            Icons.location_on,
            'Live Tracking',
            section: 'Tracking',
          ),
        if (canTrackField)
          const _Destination(
            '/admin/trips',
            Icons.route_outlined,
            Icons.route,
            'Trips',
            section: 'Tracking',
          ),
        if (canTrackField)
          const _Destination(
            '/admin/tracking-hub',
            Icons.insights_outlined,
            Icons.insights,
            'Tracking Hub',
            section: 'Tracking',
            alertBadge: true,
          ),
      ],
    ];

    final trackingAlerts = ref.watch(locationAlertWatchProvider);
    final alertCount = canTrackField ? trackingAlerts.count : 0;
    final chatUnread = ref.watch(chatUnreadProvider);

    bool isSelected(_Destination d) {
      if (d.route == '/leave') {
        return currentPath.startsWith('/leave') ||
            currentPath.startsWith('/approvals') ||
            currentPath.startsWith('/admin/leaves');
      }
      if (d.route == '/home') return currentPath == '/home';
      return currentPath.startsWith(d.route);
    }

    final query = _navSearch.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? destinations
        : destinations
            .where((d) =>
                d.label.toLowerCase().contains(query) ||
                d.section.toLowerCase().contains(query))
            .toList();

    void goTo(_Destination d, {bool closeDrawer = false}) {
      if (closeDrawer) Navigator.pop(context);
      context.go(d.route);
    }

    if (!useSidebar) {
      return _wrapExitConfirm(
        context,
        Scaffold(
        appBar: AppBar(
          title: Text(brandTitle),
          actions: [
            IconButton(
              tooltip: 'Employee tree',
              icon: const NbIcon(Icons.account_tree_rounded),
              onPressed: () => context.go('/org-tree'),
            ),
            const NotificationBellButton(),
            IconButton(
              icon: NbIcon(isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () =>
                  ref.read(themeModeProvider.notifier).toggleTheme(),
            ),
            IconButton(
              icon: const NbIcon(Icons.logout),
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
                          brandTitle,
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
                    const SizedBox(height: 16),
                    _buildNavSearchField(isDark, expandedHint: true),
                  ],
                ),
              ),
              // Destinations list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  children: [
                    ..._buildSectionedNav(
                      visible,
                      isDark,
                      expanded: true,
                      alertCount: alertCount,
                      chatUnread: chatUnread,
                      isSelected: isSelected,
                      onTap: (d) => goTo(d, closeDrawer: true),
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
                            NbIcon(
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
                            NbIcon(
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
                visible,
                isSelected,
                goTo,
                isDark,
                brandTitle: brandTitle,
                allowExpanded: allowExpandedSidebar,
                alertCount: alertCount,
                chatUnread: chatUnread,
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

  Widget _buildNavSearchField(bool isDark, {required bool expandedHint}) {
    return TextField(
      controller: _navSearch,
      onChanged: (_) => setState(() {}),
      style: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white : const Color(0xFF212F3D),
      ),
      decoration: InputDecoration(
        hintText: 'Search pages',
        hintStyle: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
        ),
        prefixIcon: NbIcon(
          Icons.search_rounded,
          size: 20,
          color: isDark ? Colors.white54 : const Color(0xFF607D8B),
        ),
        suffixIcon: _navSearch.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const NbIcon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _navSearch.clear();
                  setState(() {});
                },
              ),
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF261F1A) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSectionedNav(
    List<_Destination> destinations,
    bool isDark, {
    required bool expanded,
    required int alertCount,
    required int chatUnread,
    required bool Function(_Destination) isSelected,
    required void Function(_Destination) onTap,
  }) {
    const order = ['Main', 'Collaboration', 'HR', 'Organisation', 'Tracking'];
    final grouped = <String, List<_Destination>>{};
    for (final d in destinations) {
      grouped.putIfAbsent(d.section, () => []).add(d);
    }
    final widgets = <Widget>[];
    final sections = [
      ...order.where(grouped.containsKey),
      ...grouped.keys.where((k) => !order.contains(k)),
    ];
    if (destinations.isEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Text(
            'No matching pages',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
            ),
          ),
        ),
      );
      return widgets;
    }
    for (final section in sections) {
      final items = grouped[section] ?? [];
      if (items.isEmpty) continue;
      if (expanded) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 4),
            child: Text(
              section.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: isDark ? const Color(0xFFE2D6BE).withOpacity(0.55) : const Color(0xFF78909C),
              ),
            ),
          ),
        );
      } else if (widgets.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Divider(
              height: 8,
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            ),
          ),
        );
      }
      for (final d in items) {
        widgets.add(_buildNavTile(
          d,
          isDark,
          expanded: expanded,
          selected: isSelected(d),
          alertCount: alertCount,
          chatUnread: chatUnread,
          onTap: () => onTap(d),
        ));
      }
    }
    return widgets;
  }

  Widget _buildNavTile(
    _Destination d,
    bool isDark, {
    required bool expanded,
    required bool selected,
    required int alertCount,
    required int chatUnread,
    required VoidCallback onTap,
  }) {
    final badgeCount = d.route == '/chat' ? chatUnread : (d.alertBadge ? alertCount : 0);
    final iconColor = selected
        ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238))
        : (isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF607D8B).withOpacity(0.7));
    final icon = switch (d.route) {
      '/chat' => selected
          ? NbIcon(Icons.chat, color: iconColor, size: 22)
          : NbIcon(Icons.chat_outlined, color: iconColor, size: 22),
      '/meet' => selected
          ? NbIcon(Icons.videocam, color: iconColor, size: 22)
          : NbIcon(Icons.videocam_outlined, color: iconColor, size: 22),
      _ => NbIcon(
          selected ? d.selectedIcon : d.icon,
          color: iconColor,
          size: 22,
        ),
    };
    final tile = Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 8, vertical: 2),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            alignment: expanded ? Alignment.centerLeft : Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? (isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFDFE6E9))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.25) : const Color(0xFFB0BEC5),
                      width: 1.2,
                    )
                  : null,
            ),
            child: expanded
                ? Row(
                    children: [
                      const SizedBox(width: 12),
                      icon,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          d.label,
                          style: TextStyle(
                            color: selected
                                ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238))
                                : (isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF607D8B).withOpacity(0.8)),
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeCount > 0) _alertCountBadge(badgeCount),
                      const SizedBox(width: 12),
                    ],
                  )
                : Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      icon,
                      if (badgeCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: _alertCountBadge(badgeCount, compact: true),
                        ),
                    ],
                  ),
          ),
        ),
    );
    if (!expanded) {
      return Tooltip(
        message: d.label,
        waitDuration: const Duration(milliseconds: 400),
        child: tile,
      );
    }
    return tile;
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
    List<_Destination> destinations,
    bool Function(_Destination) isSelected,
    void Function(_Destination d, {bool closeDrawer}) goTo,
    bool isDark, {
    required String brandTitle,
    bool allowExpanded = true,
    int alertCount = 0,
    int chatUnread = 0,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            height: expanded ? 90 : 108,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
            alignment: expanded ? Alignment.centerLeft : Alignment.center,
            child: expanded
                ? Row(
                    children: [
                      _buildLogo(context),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          brandTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: isDark ? Colors.white : const Color(0xFF212F3D),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: NbIcon(
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
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: allowExpanded ? 'Expand sidebar' : brandTitle,
                        child: InkWell(
                          onTap: allowExpanded
                              ? () => setState(() => _isExpanded = true)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: _buildLogo(context),
                        ),
                      ),
                      if (allowExpanded)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                          icon: NbIcon(
                            Icons.menu_rounded,
                            size: 20,
                            color: isDark
                                ? Colors.white.withOpacity(0.5)
                                : const Color(0xFF607D8B).withOpacity(0.7),
                          ),
                          onPressed: () {
                            setState(() => _isExpanded = true);
                          },
                          tooltip: 'Expand sidebar',
                        ),
                    ],
                  ),
          ),
          
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _buildNavSearchField(isDark, expandedHint: true),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: IconButton(
                  tooltip: 'Search pages',
                  onPressed: allowExpanded
                      ? () => setState(() => _isExpanded = true)
                      : null,
                  icon: NbIcon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                  ),
                ),
              ),
            ),

          // Destinations
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: _buildSectionedNav(
                destinations,
                isDark,
                expanded: expanded,
                alertCount: alertCount,
                chatUnread: chatUnread,
                isSelected: isSelected,
                onTap: (d) => goTo(d),
              ),
            ),
          ),
          
          // Bottom Actions
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.fromLTRB(expanded ? 16 : 10, 8, expanded ? 16 : 10, 16),
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
                NotificationBellButton(
                  variant: NotificationBellVariant.sidebar,
                  expanded: expanded,
                ),
                Tooltip(
                  message: isDark ? 'Light Mode' : 'Dark Mode',
                  child: InkWell(
                    onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 44,
                      child: expanded
                          ? Row(
                              children: [
                                const SizedBox(width: 12),
                                NbIcon(
                                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                  color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF263238),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isDark ? 'Light Mode' : 'Dark Mode',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF263238),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: NbIcon(
                                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF263238),
                                size: 22,
                              ),
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
                Tooltip(
                  message: 'Sign out',
                  child: InkWell(
                    onTap: () => ref.read(authNotifierProvider.notifier).logout(),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 44,
                      child: expanded
                          ? Row(
                              children: [
                                const SizedBox(width: 12),
                                NbIcon(
                                  Icons.logout_rounded,
                                  color: const Color(0xFFEF4444).withOpacity(0.9),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Sign out',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: NbIcon(
                                Icons.logout_rounded,
                                color: const Color(0xFFEF4444).withOpacity(0.9),
                                size: 22,
                              ),
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
    this.section = 'Main',
    this.alertBadge = false,
  });
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String section;
  final bool alertBadge;
}
