import 'package:flutter/material.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'radial_menu.dart';

import '../../features/auth/domain/permissions.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/collaboration/presentation/chat_inbox.dart';
import '../../features/collaboration/presentation/notification_bell.dart';
import '../../features/tracking_hub/presentation/location_alert_watch.dart';
import '../bloc/app_module_cubit.dart';
import '../logging/app_logger.dart';
import '../services/location_alert_sound.dart';
import '../theme/theme_cubit.dart';
import '../tour/models/tour_models.dart';
import '../tour/tour_desktop.dart';
import '../tour/widgets/tour_target.dart';
import 'backend_env_switcher.dart';

/// Sidebar palette — dark charcoal for stronger contrast with content.
class _SideC {
  static const brand = Color(0xFF101510);
  static const gold = Color(0xFFC5A36A);
  static const goldSoft = Color(0xFFD6BC85);
  static const cream = Color(0xFFE8E4DC);
  static const card = Color(0xFF1A201C);
  static const ink = Color(0xFFE8E4DC);
  static const mute = Color(0xFF9AA399);
  static const line = Color(0xFF2A322C);
  static const darkSurface = Color(0xFF161C18);
  static const darkLine = Color(0xFF2A322C);
  static const selectedBg = Color(0xFF222A25);
}
class ResponsiveShell extends ConsumerStatefulWidget {
  const ResponsiveShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends ConsumerState<ResponsiveShell> {
  bool _isExpanded = true;
  final _navSearch = TextEditingController();
  final Set<String> _expandedNavGroups = {};
  final Set<String> _collapsedNavGroups = {};

  @override
  void dispose() {
    _navSearch.dispose();
    super.dispose();
  }

  Widget _tourPageChild() => widget.child;

  Widget _buildSpeedDial(
    BuildContext context,
    List<String> accessibleSuites,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const goldColor = Color(0xFFC5A059);
    
    // Main button colors
    final mainBgColor = isDark ? goldColor : const Color(0xFF263238);
    final mainIconColor = isDark ? const Color(0xFF1A1816) : Colors.white;
    
    // Item button colors
    final itemBgColor = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final itemFgColor = isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238);
    
    final items = <RadialMenuItem>[
      if (accessibleSuites.contains('HRMS'))
        RadialMenuItem(
          icon: Icons.groups_rounded,
          label: 'HRMS',
          backgroundColor: itemBgColor,
          foregroundColor: itemFgColor,
          onTap: () {
            context.read<AppModuleCubit>().setModule(AppModule.hrms);
            context.go('/home');
          },
        ),
      if (accessibleSuites.contains('ERP'))
        RadialMenuItem(
          icon: Icons.account_balance_rounded,
          label: 'ERP',
          backgroundColor: itemBgColor,
          foregroundColor: itemFgColor,
          onTap: () {
            context.read<AppModuleCubit>().setModule(AppModule.erp);
            context.go('/erp/home');
          },
        ),
      if (accessibleSuites.contains('CRM'))
        RadialMenuItem(
          icon: Icons.support_agent_rounded,
          label: 'CRM',
          backgroundColor: itemBgColor,
          foregroundColor: itemFgColor,
          onTap: () {
            context.read<AppModuleCubit>().setModule(AppModule.crm);
            context.go('/crm/dashboard');
          },
        ),
    ];

    if (items.length <= 1) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: RadialMenu(
        primaryColor: mainBgColor,
        onPrimaryColor: mainIconColor,
        tourTargetId: 'shell.suite_switcher',
        items: items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final width = MediaQuery.sizeOf(context).width;
    // Sidebar from tablet up; phones keep the drawer.
    final useSidebar = width >= 720;
    final allowExpandedSidebar = width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isAdmin = Permissions.isAdmin(auth.user?.role);
    final isSuperAdmin = Permissions.isSuperAdmin(auth.user?.role);
    final hasWorkforce = Permissions.canViewWorkforce(
      auth.permissions,
      auth.user?.employeeViewScope,
      auth.user?.role,
    );
    final isHR = isAdmin || const [
      'ADMIN',
      'HR',
      'HR_MANAGER',
      'SYSTEMADMIN',
      'SYSTEM_ADMINISTRATOR',
    ].contains(auth.user?.role.toUpperCase() ?? '');
    final canTrackField = canAccessFieldTracking(auth.user?.role);
    final canApproveLeave = isSuperAdmin || Permissions.canApproveLeave(auth.permissions);
    final canAccessAdmin = Permissions.canAccessAdminPortal(
      auth.permissions,
      auth.user?.employeeViewScope,
      auth.user?.role,
    );
    final canManageUsers = Permissions.canManageUsers(
      auth.permissions,
      auth.user?.role ?? '',
    );
    final canManageRoles = Permissions.canManageRoles(
      auth.permissions,
      auth.user?.role ?? '',
    );
    final canManageInstitutes = Permissions.canManageInstitutes(
      auth.permissions,
      auth.user?.role,
    );
    final canAdminAttendance = Permissions.isAdmin(auth.user?.role) ||
        Permissions.canAdminAttendance(auth.permissions, auth.user?.role ?? '');

    // Superadmin has a dedicated full-screen SaaS Platform Console — no sidebar needed.
    if (isSuperAdmin) {
      return widget.child;
    }

    final currentPath = GoRouterState.of(context).matchedLocation;
    final module = context.watch<AppModuleCubit>().state;
    final brandTitle = shellBrandTitle(module);
    final enabledModules = auth.user?.enabledModules ?? const ['HRMS', 'CRM', 'ERP'];
    final accessibleSuites = Permissions.accessibleSuites(
      auth.permissions,
      enabledModules,
      auth.user?.role,
    );

    AppModule _fallbackSuite() {
      if (accessibleSuites.contains('HRMS')) return AppModule.hrms;
      if (accessibleSuites.contains('ERP')) return AppModule.erp;
      if (accessibleSuites.contains('CRM')) return AppModule.crm;
      return AppModule.hrms;
    }

    // Auto-correct active module if suite license or RBAC access was revoked
    if (module == AppModule.hrms && !accessibleSuites.contains('HRMS')) {
      final fallback = _fallbackSuite();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppModuleCubit>().setModule(fallback);
      });
    } else if (module == AppModule.erp && !accessibleSuites.contains('ERP')) {
      final fallback = _fallbackSuite();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppModuleCubit>().setModule(fallback);
      });
    } else if (module == AppModule.crm && !accessibleSuites.contains('CRM')) {
      final fallback = _fallbackSuite();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppModuleCubit>().setModule(fallback);
      });
    }

    final inferred = inferAppModule(currentPath, module);
    if (inferred != module) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AppModuleCubit>().syncFromPath(currentPath);
      });
    }

    final showSoftwareTour = TourDesktop.supported(context);

    final sharedCollab = <_Destination>[
      const _Destination(
        '/notifications',
        Icons.notifications_outlined,
        Icons.notifications,
        'Notifications',
        section: 'Collaboration',
      ),
      if (Permissions.canReadOrgTree(auth.permissions, auth.user?.role))
        const _Destination(
          '/org-tree',
          Icons.account_tree_outlined,
          Icons.account_tree,
          'Employee tree',
          section: 'Collaboration',
        ),
      if (Permissions.canReadTasks(auth.permissions, auth.user?.role))
        const _Destination(
          '/tasks',
          Icons.task_alt_outlined,
          Icons.task_alt,
          'Tasks',
          section: 'Collaboration',
        ),
      if (Permissions.canReadChat(auth.permissions, auth.user?.role))
        const _Destination(
          '/chat',
          Icons.chat_outlined,
          Icons.chat,
          'Chat',
          section: 'Collaboration',
        ),
      if (Permissions.canReadMeetings(auth.permissions, auth.user?.role))
        const _Destination(
          '/meet',
          Icons.videocam_outlined,
          Icons.videocam,
          'Meet',
          section: 'Collaboration',
        ),
    ];

    final destinations = <_Destination>[
      if (isSuperAdmin) ...[
        const _Destination(
          '/platform',
          Icons.hub_outlined,
          Icons.hub_rounded,
          'Platform Overview',
          section: 'SaaS Console',
        ),
        const _Destination(
          '/platform?tab=0',
          Icons.business_outlined,
          Icons.business_rounded,
          'Client Companies',
          section: 'SaaS Console',
        ),
        const _Destination(
          '/platform?tab=1',
          Icons.admin_panel_settings_outlined,
          Icons.admin_panel_settings_rounded,
          'Company Admins',
          section: 'SaaS Console',
        ),
        const _Destination(
          '/platform?tab=2',
          Icons.apps_outlined,
          Icons.apps_rounded,
          'Module Licensing',
          section: 'SaaS Console',
        ),
        const _Destination(
          '/platform?tab=3',
          Icons.monitor_heart_outlined,
          Icons.monitor_heart_rounded,
          'Engine Diagnostics',
          section: 'SaaS Console',
        ),
      ] else ...[
        if (module == AppModule.hrms) ...[
        if (canAccessAdmin)
          const _Destination(
            '/admin/dashboard',
            Icons.dashboard_outlined,
            Icons.dashboard,
            'Dashboard',
            section: 'Main',
          ),
        if (Permissions.canReadGoogleEarth(auth.permissions, auth.user?.role))
          const _Destination(
            '/admin/earth',
            Icons.public_outlined,
            Icons.public,
            'NB Earth',
            section: 'Earth',
          ),
        if (Permissions.canReadGoogleEarth(auth.permissions, auth.user?.role))
          const _Destination(
            '/admin/earth/dashboard',
            Icons.insights_outlined,
            Icons.insights,
            'Earth Dashboard',
            section: 'Earth',
          ),
        const _Destination('/home', Icons.home_outlined, Icons.home, 'Home', section: 'Main'),
        if (showSoftwareTour)
          const _Destination(
            '/software-tour',
            Icons.school_outlined,
            Icons.school,
            'Software Tour',
            section: 'Main',
            imageAsset: 'assets/images/mr_nb.jpg',
          ),
        if (Permissions.canOpenProfile(auth.permissions, auth.user?.role))
          const _Destination(
            '/profile',
            Icons.person_outline,
            Icons.person,
            'Profile',
            section: 'Main',
          ),
      ] else if (module == AppModule.erp) ...[
        const _Destination('/erp/home', Icons.home_outlined, Icons.home, 'Home', section: 'ERP'),
        if (showSoftwareTour)
          const _Destination(
            '/software-tour',
            Icons.school_outlined,
            Icons.school,
            'Software Tour',
            section: 'ERP',
            imageAsset: 'assets/images/mr_nb.jpg',
          ),
        if (Permissions.canReadProjects(auth.permissions, auth.user?.role))
          const _Destination(
            '/erp/projects',
            Icons.apartment_outlined,
            Icons.apartment,
            'Projects',
            section: 'ERP',
          ),
        if (Permissions.canReadWorkOrders(auth.permissions, auth.user?.role))
          const _Destination(
            '/erp/work-orders',
            Icons.assignment_outlined,
            Icons.assignment,
            'Work Orders',
            section: 'ERP',
          ),
        if (Permissions.canReadBoq(auth.permissions, auth.user?.role))
          const _Destination(
            '/erp/boq',
            Icons.receipt_long_outlined,
            Icons.receipt_long,
            'BOQ',
            section: 'ERP',
          ),
        if (Permissions.canReadStore(auth.permissions, auth.user?.role))
          const _Destination(
            '/erp/store',
            Icons.storefront_outlined,
            Icons.storefront,
            'Store',
            section: 'ERP',
          ),
        if (Permissions.canReadPurchase(auth.permissions, auth.user?.role))
          const _Destination(
            '/erp/purchase',
            Icons.shopping_cart_outlined,
            Icons.shopping_cart,
            'Purchase',
            section: 'ERP',
          ),
        if (Permissions.canReadTenders(auth.permissions, auth.user?.role) ||
            Permissions.canReadTenderApplications(auth.permissions, auth.user?.role))
          _Destination(
            '/erp/tenders',
            Icons.gavel_outlined,
            Icons.gavel,
            'Tenders',
            section: 'ERP',
            children: [
              if (Permissions.canReadTenders(auth.permissions, auth.user?.role))
                const _Destination(
                  '/erp/tenders',
                  Icons.gavel_outlined,
                  Icons.gavel,
                  'Tenders',
                  section: 'ERP',
                ),
              if (Permissions.canReadTenderApplications(auth.permissions, auth.user?.role))
                const _Destination(
                  '/erp/tender-applications',
                  Icons.handshake_outlined,
                  Icons.handshake,
                  'Tender Applications',
                  section: 'ERP',
                ),
            ],
          ),
        if (Permissions.canReadDpr(auth.permissions, auth.user?.role))
          const _Destination(
            '/erp/dpr',
            Icons.assignment_turned_in_outlined,
            Icons.assignment_turned_in,
            'DPR',
            section: 'ERP',
          ),
        if (isAdmin || Permissions.canReadErpConfig(auth.permissions, auth.user?.role))
          const _Destination(
            '/erp/configurations',
            Icons.settings_outlined,
            Icons.settings,
            'Configurations',
            section: 'ERP',
          ),
      ] else if (module == AppModule.crm) ...[
        if (showSoftwareTour)
          const _Destination(
            '/software-tour',
            Icons.school_outlined,
            Icons.school,
            'Software Tour',
            section: 'CRM',
            imageAsset: 'assets/images/mr_nb.jpg',
          ),
        if (Permissions.canReadCrmDashboard(auth.permissions, auth.user?.role))
          const _Destination(
            '/crm/dashboard',
            Icons.dashboard_outlined,
            Icons.dashboard,
            'Dashboard',
            section: 'CRM',
          ),
        if (Permissions.canReadCrmPreSales(auth.permissions, auth.user?.role))
          const _Destination(
            '/crm/pre-sales',
            Icons.point_of_sale_outlined,
            Icons.point_of_sale,
            'Pre sales',
            section: 'CRM',
          ),
        if (currentPath.startsWith('/crm/pre-sales') &&
            Permissions.canReadCrmHeaders(auth.permissions, auth.user?.role))
          const _Destination(
            '/crm/pre-sales/headers',
            Icons.view_column_outlined,
            Icons.view_column,
            '  ↳ Headers',
            section: 'CRM',
          ),
        if (Permissions.canReadCrmPostSales(auth.permissions, auth.user?.role))
          const _Destination(
            '/crm/post-sales',
            Icons.support_agent_outlined,
            Icons.support_agent,
            'Post sales',
            section: 'CRM',
          ),
        if (Permissions.canReadCrmBin(auth.permissions, auth.user?.role))
          const _Destination(
            '/crm/bin',
            Icons.delete_outline,
            Icons.delete,
            'Bin',
            section: 'CRM',
          ),
        if (Permissions.canReadCrmSettings(auth.permissions, auth.user?.role))
          const _Destination(
            '/crm/settings',
            Icons.settings_outlined,
            Icons.settings,
            'Settings',
            section: 'CRM',
          ),
      ],
      if (module == AppModule.hrms) ...[
        if (Permissions.canReadLeave(auth.permissions, auth.user?.role) ||
            Permissions.canWriteLeave(auth.permissions, auth.user?.role) ||
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
        if (Permissions.canReadAttendance(auth.permissions, auth.user?.role) ||
            canAdminAttendance)
          const _Destination(
            '/attendance',
            Icons.fingerprint_outlined,
            Icons.fingerprint,
            'Attendance',
            section: 'HR',
          ),
        if (Permissions.canReadReimbursements(auth.permissions, auth.user?.role))
          const _Destination(
            '/reimbursements',
            Icons.receipt_long_outlined,
            Icons.receipt_long,
            'Reimbursements',
            section: 'HR',
          ),
        if (Permissions.canReadRecruitment(auth.permissions, auth.user?.role))
          const _Destination(
            '/recruitment',
            Icons.work_outline_rounded,
            Icons.work_rounded,
            'Recruitment',
            section: 'HR',
          ),
        if (Permissions.canReadRepository(auth.permissions, auth.user?.role))
          const _Destination(
            '/repository',
            Icons.folder_shared_outlined,
            Icons.folder_shared,
            'Repository',
            section: 'HR',
          ),
        if (Permissions.canReadPayroll(auth.permissions, auth.user?.role))
          const _Destination(
            '/admin/salary/payroll',
            Icons.payments_outlined,
            Icons.payments,
            'Payroll',
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
        if (canManageUsers || canManageInstitutes)
          const _Destination(
            '/admin/configurations',
            Icons.tune_outlined,
            Icons.tune,
            'Configurations',
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
        if (canAccessAdmin)
          const _Destination(
            '/admin/audit',
            Icons.history_edu_outlined,
            Icons.history_edu,
            'Audit',
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
      ...sharedCollab,
      ],
    ];

    final trackingAlerts = ref.watch(locationAlertWatchProvider);
    final alertCount = canTrackField ? trackingAlerts.count : 0;
    final chatUnread = ref.watch(chatUnreadProvider);

    bool isSelected(_Destination d) {
      if (isSuperAdmin && d.route.startsWith('/platform')) {
        final dUri = Uri.parse(d.route);
        final dTab = dUri.queryParameters['tab'] ?? '';
        final curUri = GoRouterState.of(context).uri;
        final curTab = curUri.queryParameters['tab'] ?? '';
        if (dTab.isEmpty && curTab.isEmpty) return curUri.path == '/platform';
        return curUri.path == '/platform' && curTab == dTab;
      }
      if (d.children != null && d.children!.isNotEmpty) {
        return d.children!.any(isSelected);
      }
      if (d.route == '/leave') {
        return currentPath.startsWith('/leave') ||
            currentPath.startsWith('/approvals') ||
            currentPath.startsWith('/admin/leaves');
      }
      if (d.route == '/home') return currentPath == '/home';
      if (d.route == '/crm/pre-sales/headers') {
        return currentPath.startsWith('/crm/pre-sales/headers') ||
            currentPath.startsWith('/crm/headers');
      }
      if (d.route == '/crm/pre-sales') {
        return (currentPath == '/crm/pre-sales' || currentPath == '/crm/presales') &&
            !currentPath.contains('/headers');
      }
      if (d.route == '/erp/tenders') {
        return currentPath == '/erp/tenders' ||
            currentPath.startsWith('/erp/tenders/');
      }
      if (d.route == '/admin/earth/dashboard') {
        return currentPath.startsWith('/admin/earth/dashboard');
      }
      if (d.route == '/admin/earth') {
        return currentPath == '/admin/earth';
      }
      return currentPath.startsWith(d.route);
    }

    // Keep Tenders group open while on any tender route (unless user collapsed it).
    if (currentPath.startsWith('/erp/tenders') || currentPath.startsWith('/erp/tender-applications')) {
      // no-op during build; open state is derived below
    }

    final query = _navSearch.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? destinations
        : destinations.where((d) {
            if (d.label.toLowerCase().contains(query) || d.section.toLowerCase().contains(query)) {
              return true;
            }
            return d.children?.any((c) => c.label.toLowerCase().contains(query)) ?? false;
          }).toList();

    bool isGroupOpen(_Destination d) {
      if (d.children == null || d.children!.isEmpty) return false;
      if (query.isNotEmpty) return true;
      if (_collapsedNavGroups.contains(d.route)) return false;
      if (_expandedNavGroups.contains(d.route)) return true;
      if (d.route == '/erp/tenders') {
        return currentPath.startsWith('/erp/tenders') ||
            currentPath.startsWith('/erp/tender-applications');
      }
      return false;
    }

    void goTo(_Destination d, {bool closeDrawer = false}) {
      if (d.children != null && d.children!.isNotEmpty) {
        setState(() {
          if (isGroupOpen(d)) {
            _expandedNavGroups.remove(d.route);
            _collapsedNavGroups.add(d.route);
          } else {
            _collapsedNavGroups.remove(d.route);
            _expandedNavGroups.add(d.route);
          }
        });
        return;
      }
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
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(child: BackendEnvSwitcher.chip()),
            ),
            if (!isSuperAdmin && Permissions.canReadOrgTree(auth.permissions, auth.user?.role))
              IconButton(
                tooltip: 'Employee tree',
                icon: const NbIcon(Icons.account_tree_rounded),
                onPressed: () => context.go('/org-tree'),
              ),
            if (!isSuperAdmin)
              TourTarget(
                id: 'shell.notifications',
                child: const NotificationBellButton(),
              ),
            IconButton(
              icon: NbIcon(isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () =>
                  context.read<ThemeCubit>().toggleTheme(),
            ),
            IconButton(
              icon: const NbIcon(Icons.logout),
              onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: _SideC.brand,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              // Custom Drawer Header matching sidebar branding
              Container(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 18),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _SideC.line),
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
                          style: GoogleFonts.sourceSans3(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: _SideC.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      auth.user?.name ?? '',
                      style: GoogleFonts.sourceSans3(
                        color: _SideC.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (auth.user?.role != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        auth.user!.role.toUpperCase(),
                        style: GoogleFonts.sourceSans3(
                          color: _SideC.goldSoft,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _buildNavSearchField(true, expandedHint: true),
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
                      isGroupOpen: isGroupOpen,
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
                  color: _SideC.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _SideC.line),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        context.read<ThemeCubit>().toggleTheme();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            NbIcon(
                              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF263238),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isDark ? 'Light Mode' : 'Dark Mode',
                                style: TextStyle(
                                  color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF263238),
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
                        color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCCD6DD),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        context.read<AuthBloc>().add(const AuthLogoutRequested());
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            NbIcon(
                              Icons.logout_rounded,
                              color: const Color(0xFFEF4444).withValues(alpha: 0.9),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Sign out',
                                style: TextStyle(
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
            _tourPageChild(),
            if (!isSuperAdmin) _buildSpeedDial(context, accessibleSuites),
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
                isGroupOpen,
                goTo,
                isDark,
                brandTitle: brandTitle,
                allowExpanded: allowExpandedSidebar,
                alertCount: alertCount,
                chatUnread: chatUnread,
              ),
              Expanded(child: _tourPageChild()),
            ],
          ),
          if (!isSuperAdmin) _buildSpeedDial(context, accessibleSuites),
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
    return TourTarget(
      id: 'shell.search',
      child: TextField(
      controller: _navSearch,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.sourceSans3(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? _SideC.cream : _SideC.ink,
      ),
      decoration: InputDecoration(
        hintText: 'Search pages',
        hintStyle: GoogleFonts.sourceSans3(
          fontSize: 13,
          color: _SideC.mute,
        ),
        prefixIcon: NbIcon(
          Icons.search_rounded,
          size: 20,
          color: _SideC.mute,
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
        fillColor: isDark ? _SideC.darkSurface : _SideC.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? _SideC.darkLine : _SideC.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? _SideC.darkLine : _SideC.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _SideC.gold, width: 1.3),
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
    required bool Function(_Destination) isGroupOpen,
    required void Function(_Destination) onTap,
  }) {
    const order = [
      'SaaS Console',
      'Main',
      'Earth',
      'ERP',
      'CRM',
      'HR',
      'Organisation',
      'Tracking',
      'Collaboration',
    ];
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
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
            child: Text(
              section.toUpperCase(),
              style: GoogleFonts.sourceSans3(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: isDark ? _SideC.goldSoft.withValues(alpha: 0.7) : _SideC.mute,
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
              color: isDark ? _SideC.darkLine : _SideC.line,
            ),
          ),
        );
      }
      for (final d in items) {
        final hasChildren = d.children != null && d.children!.isNotEmpty;
        final groupOpen = hasChildren && isGroupOpen(d);
        widgets.add(_buildNavTile(
          d,
          isDark,
          expanded: expanded,
          selected: isSelected(d),
          alertCount: alertCount,
          chatUnread: chatUnread,
          isGroup: hasChildren,
          groupExpanded: groupOpen,
          onTap: () => onTap(d),
          childDestinations: hasChildren ? d.children : null,
          onSelectChild: hasChildren ? onTap : null,
        ));
        if (hasChildren && groupOpen && expanded) {
          for (final child in d.children!) {
            widgets.add(_buildNavTile(
              child,
              isDark,
              expanded: expanded,
              selected: isSelected(child),
              alertCount: alertCount,
              chatUnread: chatUnread,
              isChild: true,
              onTap: () => onTap(child),
            ));
          }
        }
      }
    }
    return widgets;
  }

  Widget _navFaceImage({
    required String asset,
    required Widget fallback,
  }) {
    const size = 22.0;
    return ClipOval(
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.78),
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _buildNavTile(
    _Destination d,
    bool isDark, {
    required bool expanded,
    required bool selected,
    required int alertCount,
    required int chatUnread,
    required VoidCallback onTap,
    bool isGroup = false,
    bool groupExpanded = false,
    bool isChild = false,
    List<_Destination>? childDestinations,
    void Function(_Destination child)? onSelectChild,
  }) {
    final badgeCount = d.route == '/chat' ? chatUnread : (d.alertBadge ? alertCount : 0);
    final iconColor = selected
        ? (isDark ? _SideC.goldSoft : _SideC.brand)
        : (isDark ? _SideC.cream.withValues(alpha: 0.45) : _SideC.mute);
    final icon = d.imageAsset != null
        ? _navFaceImage(
            asset: d.imageAsset!,
            fallback: NbIcon(
              selected ? d.selectedIcon : d.icon,
              color: iconColor,
              size: 22,
            ),
          )
        : switch (d.route) {
      '/chat' => selected
          ? NbIcon(Icons.chat, color: iconColor, size: 22)
          : NbIcon(Icons.chat_outlined, color: iconColor, size: 22),
      '/meet' => selected
          ? NbIcon(Icons.videocam, color: iconColor, size: 22)
          : NbIcon(Icons.videocam_outlined, color: iconColor, size: 22),
      _ => NbIcon(
          selected ? d.selectedIcon : d.icon,
          color: iconColor,
          size: isChild ? 18 : 22,
        ),
    };

    Widget tileBody({required VoidCallback tap}) {
      return Padding(
        padding: EdgeInsets.only(
          left: expanded ? (isChild ? 18 : 10) : 8,
          right: expanded ? 10 : 8,
          top: 2,
          bottom: 2,
        ),
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: isChild ? 40 : 46,
            alignment: expanded ? Alignment.centerLeft : Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? (isDark
                      ? _SideC.gold.withValues(alpha: 0.14)
                      : _SideC.card)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(
                      color: isDark
                          ? _SideC.gold.withValues(alpha: 0.35)
                          : _SideC.line,
                    )
                  : null,
            ),
            child: expanded
                ? Row(
                    children: [
                      const SizedBox(width: 10),
                      if (selected)
                        Container(
                          width: 3,
                          height: 18,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _SideC.gold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      else
                        const SizedBox(width: 11),
                      if (isChild)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            size: 14,
                            color: isDark ? _SideC.mute : _SideC.line,
                          ),
                        ),
                      icon,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          d.label,
                          style: GoogleFonts.sourceSans3(
                            color: selected
                                ? (isDark ? _SideC.goldSoft : _SideC.ink)
                                : (isDark
                                    ? _SideC.cream.withValues(alpha: 0.55)
                                    : _SideC.mute),
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: isChild ? 13 : 13.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeCount > 0) _alertCountBadge(badgeCount),
                      if (isGroup)
                        AnimatedRotation(
                          turns: groupExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: _SideC.mute,
                          ),
                        ),
                      const SizedBox(width: 6),
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
                      if (isGroup)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Icon(
                            Icons.arrow_drop_down,
                            size: 14,
                            color: _SideC.mute,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      );
    }

    final tile = tileBody(tap: onTap);
    Widget wrapped(Widget child) => TourTarget(id: TourIds.nav(d.route), child: child);
    if (!expanded && isGroup && childDestinations != null && onSelectChild != null) {
      return wrapped(
        PopupMenuButton<_Destination>(
          tooltip: d.label,
          offset: const Offset(56, 0),
          onSelected: onSelectChild,
          itemBuilder: (context) => [
            for (final child in childDestinations)
              PopupMenuItem<_Destination>(
                value: child,
                child: Row(
                  children: [
                    Icon(child.icon, size: 18),
                    const SizedBox(width: 10),
                    Text(child.label),
                  ],
                ),
              ),
          ],
          child: tileBody(tap: () {}),
        ),
      );
    }
    if (!expanded) {
      return wrapped(
        Tooltip(
          message: d.label,
          waitDuration: const Duration(milliseconds: 400),
          child: tile,
        ),
      );
    }
    return wrapped(tile);
  }

  Widget _buildLogo(BuildContext context) {
    return TourTarget(
      id: 'shell.brand',
      child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/images/nb-logo.png',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 40,
            height: 40,
            color: _SideC.brand,
            alignment: Alignment.center,
            child: Text(
              'NB',
              style: GoogleFonts.fraunces(
                color: _SideC.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
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
    bool Function(_Destination) isGroupOpen,
    void Function(_Destination d, {bool closeDrawer}) goTo,
    bool isDark, {
    required String brandTitle,
    bool allowExpanded = true,
    int alertCount = 0,
    int chatUnread = 0,
  }) {
    final expanded = allowExpanded && _isExpanded;
    // Sidebar stays dark for contrast with the cream content area.
    const sideDark = true;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: expanded ? 252 : 76,
      decoration: const BoxDecoration(
        color: _SideC.brand,
        border: Border(
          right: BorderSide(color: _SideC.line),
        ),
      ),
      child: TourTarget(
        id: 'shell.sidebar',
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            height: expanded ? 78 : 96,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0),
            alignment: expanded ? Alignment.centerLeft : Alignment.center,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _SideC.line),
              ),
            ),
            child: expanded
                ? Row(
                    children: [
                      _buildLogo(context),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          brandTitle,
                          style: GoogleFonts.sourceSans3(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            color: _SideC.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const NbIcon(
                          Icons.menu_open_rounded,
                          color: _SideC.mute,
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
                          borderRadius: BorderRadius.circular(10),
                          child: _buildLogo(context),
                        ),
                      ),
                      if (allowExpanded)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                          icon: const NbIcon(
                            Icons.menu_rounded,
                            size: 20,
                            color: _SideC.mute,
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: _buildNavSearchField(sideDark, expandedHint: true),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 6),
              child: Center(
                child: IconButton(
                  tooltip: 'Search pages',
                  onPressed: allowExpanded
                      ? () => setState(() => _isExpanded = true)
                      : null,
                  icon: const NbIcon(
                    Icons.search_rounded,
                    color: _SideC.mute,
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
                sideDark,
                expanded: expanded,
                alertCount: alertCount,
                chatUnread: chatUnread,
                isSelected: isSelected,
                isGroupOpen: isGroupOpen,
                onTap: (d) => goTo(d),
              ),
            ),
          ),
          
          // Bottom Actions
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.fromLTRB(expanded ? 12 : 8, 8, expanded ? 12 : 8, 14),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: _SideC.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _SideC.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TourTarget(
                  id: 'shell.notifications',
                  child: NotificationBellButton(
                    variant: NotificationBellVariant.sidebar,
                    expanded: expanded,
                  ),
                ),
                Tooltip(
                  message: isDark ? 'Light Mode' : 'Dark Mode',
                  child: InkWell(
                    onTap: () => context.read<ThemeCubit>().toggleTheme(),
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 42,
                      child: expanded
                          ? Row(
                              children: [
                                const SizedBox(width: 12),
                                NbIcon(
                                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                  color: _SideC.goldSoft,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isDark ? 'Light Mode' : 'Dark Mode',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.sourceSans3(
                                      color: _SideC.ink,
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
                                color: _SideC.goldSoft,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(
                    height: 8,
                    color: _SideC.line,
                  ),
                ),
                Tooltip(
                  message: 'Sign out',
                  child: InkWell(
                    onTap: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 42,
                      child: expanded
                          ? Row(
                              children: [
                                const SizedBox(width: 12),
                                NbIcon(
                                  Icons.logout_rounded,
                                  color: const Color(0xFFEF5350).withValues(alpha: 0.95),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Sign out',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.sourceSans3(
                                      color: const Color(0xFFEF5350),
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
                                color: const Color(0xFFEF5350).withValues(alpha: 0.95),
                                size: 20,
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
    this.children,
    this.imageAsset,
  });
  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String section;
  final bool alertBadge;
  final List<_Destination>? children;
  final String? imageAsset;
}
