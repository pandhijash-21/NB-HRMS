import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../logging/app_logger.dart';
import 'app_navigation.dart';
import 'go_router_refresh_stream.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/domain/permissions.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/superadmin_login_screen.dart';
import '../../features/auth/presentation/verify_emails_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/admin/presentation/screens/admin_employees_screen.dart';
import '../../features/admin/presentation/screens/admin_employee_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_approvals_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_storage_screen.dart';
import '../../features/admin/presentation/screens/admin_live_tracking_screen.dart';
import '../../features/admin/presentation/screens/admin_employee_live_tracking_screen.dart';
import '../../features/tracking_hub/presentation/screens/tracking_hub_screen.dart';
import '../../features/tracking/presentation/screens/autostart_onboarding_screen.dart';

import '../../features/tracking_hub/presentation/screens/trip_detail_hub_screen.dart';
import '../../features/tracking_hub/presentation/screens/tracking_hub_employee_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_trips_screen.dart';
import '../../features/admin/presentation/screens/admin_trip_replay_screen.dart';
import '../../features/admin/presentation/screens/admin_audit_stub_screen.dart';
import '../../features/org/presentation/screens/institutes_screen.dart';
import '../../features/org/presentation/screens/institute_detail_screen.dart';
import '../../features/org/presentation/screens/organizations_screen.dart';
import '../../features/org/presentation/screens/designations_screen.dart';
import '../../features/lookups/presentation/screens/configurations_hub_screen.dart';
import '../../features/lookups/presentation/screens/lookup_category_screen.dart';
import '../../features/letters/presentation/screens/admin_letters_screen.dart';
import '../../features/tasks/presentation/screens/tasks_hub_screen.dart';
import '../../features/leave/presentation/screens/leave_hub_screen.dart';
import '../../features/leave/presentation/screens/leave_apply_screen.dart';
import '../../features/leave/presentation/screens/leave_history_screen.dart';
import '../../features/leave/presentation/screens/leave_approvals_screen.dart';
import '../../features/leave/presentation/screens/leave_approvals_history_screen.dart';
import '../../features/leave/presentation/screens/admin_leaves_screen.dart';
import '../../features/leave/presentation/screens/admin_leaves_pending_screen.dart';
import '../../features/leave/presentation/screens/admin_leaves_settings_screen.dart';
import '../../features/leave/presentation/screens/admin_leaves_holidays_screen.dart';
import '../../features/reimbursements/presentation/screens/reimbursements_hub_screen.dart';
import '../../features/reimbursements/presentation/screens/reimbursement_apply_screen.dart';
import '../../features/recruitment/presentation/screens/recruitment_hub_screen.dart';
import '../../features/recruitment/presentation/screens/candidate_detail_screen.dart';
import '../../features/repository/presentation/screens/repository_hub_screen.dart';
import '../../features/attendance/presentation/screens/attendance_screen.dart';
import '../../features/attendance/presentation/screens/admin_attendance_screen.dart';
import '../../features/attendance/presentation/screens/admin_employee_attendance_history_screen.dart';
import '../../features/attendance/presentation/screens/device_attendance_screen.dart';
import '../../features/attendance/presentation/screens/admin_locations_screen.dart';
import '../../features/salary/presentation/screens/admin_salary_commissions_screen.dart';
import '../../features/salary/presentation/screens/admin_salary_commission_detail_screen.dart';
import '../../features/salary/presentation/screens/admin_salary_structures_screen.dart';
import '../../features/salary/presentation/screens/admin_salary_structure_detail_screen.dart';
import '../../features/salary/presentation/screens/admin_salary_entry_screen.dart';
import '../../features/salary/presentation/screens/admin_salary_records_screen.dart';
import '../../features/salary/presentation/screens/admin_salary_slip_screen.dart';
import '../../features/salary/presentation/screens/admin_payroll_month_screen.dart';
import '../../features/salary/presentation/screens/employee_salary_slip_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/rbac/data/rbac_repository.dart';
import '../../features/rbac/presentation/bloc/admin_users_bloc.dart';
import '../../features/rbac/presentation/bloc/admin_roles_bloc.dart';
import '../../features/rbac/presentation/bloc/admin_role_detail_bloc.dart';
import '../../features/rbac/presentation/screens/admin_users_screen.dart';
import '../../features/rbac/presentation/screens/admin_roles_screen.dart';
import '../../features/rbac/presentation/screens/admin_role_detail_screen.dart';
import '../../features/org_tree/presentation/screens/employee_tree_screen.dart';
import '../../features/erp/presentation/screens/erp_home_screen.dart';
import '../../features/erp/presentation/screens/erp_configurations_screen.dart';
import '../../features/erp/presentation/screens/projects_list_screen.dart';
import '../../features/erp/presentation/screens/project_form_screen.dart';
import '../../features/erp/presentation/screens/project_structure_screen.dart';
import '../../features/erp/presentation/screens/tower_form_screen.dart';
import '../../features/erp/presentation/screens/tower_units_screen.dart';
import '../../features/erp/presentation/screens/unit_form_screen.dart';
import '../../features/erp/presentation/screens/work_orders_list_screen.dart';
import '../../features/erp/presentation/screens/work_order_detail_screen.dart';
import '../../features/erp/presentation/screens/work_order_form_screen.dart';
import '../../features/erp/presentation/screens/activities_config_screen.dart';
import '../../features/erp/presentation/screens/contractors_config_screen.dart';
import '../../features/erp/presentation/screens/contractor_form_screen.dart';
import '../../features/erp/presentation/screens/boq_list_screen.dart';
import '../../features/erp/presentation/screens/boq_form_screen.dart';
import '../../features/erp/presentation/screens/store_config_screen.dart';
import '../../features/erp/presentation/screens/labour_config_screen.dart';
import '../../features/erp/presentation/screens/tender_list_screen.dart';
import '../../features/erp/presentation/screens/tender_form_screen.dart';
import '../../features/erp/presentation/screens/tender_applications_screen.dart';
import '../../features/erp/presentation/screens/tender_application_form_screen.dart';
import '../../features/erp/presentation/screens/dpr_list_screen.dart';
import '../../features/erp/presentation/screens/dpr_form_screen.dart';
import '../../features/erp/presentation/screens/dpr_detail_screen.dart';
import '../../features/collaboration/presentation/screens/chat_hub_screen.dart';
import '../../features/collaboration/presentation/screens/meet_hub_screen.dart';
import '../../features/collaboration/presentation/screens/meet_list_screen.dart';
import '../../features/collaboration/presentation/screens/meet_schedule_screen.dart';
import '../../features/collaboration/presentation/screens/meet_invite_people_screen.dart';
import '../../features/collaboration/presentation/screens/meet_room_screen.dart';
import '../../features/collaboration/presentation/meet_helpers.dart';
import '../../features/collaboration/presentation/screens/meet_recording_screen.dart';
import '../../features/crm/presentation/screens/crm_dashboard_screen.dart';
import '../../features/crm/presentation/screens/crm_pre_sales_screen.dart';
import '../../features/crm/presentation/screens/crm_headers_screen.dart';
import '../../features/crm/presentation/screens/crm_post_sales_screen.dart';
import '../../features/crm/presentation/screens/crm_settings_screen.dart';
import '../../features/crm/presentation/screens/crm_bin_screen.dart';
import '../../features/platform/presentation/screens/platform_console_screen.dart';
import '../widgets/responsive_shell.dart';

GoRouter createAppRouter(AuthBloc authBloc) {
  final refresh = GoRouterRefreshStream(authBloc.stream);

  // Fresh per router instance — avoids ShellRoute GlobalKey collisions on
  // hot reload (go_router keys navigators with GlobalObjectKey(hashCode)).
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
  final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shellNav');

  // Bump when route table changes so hot-restart rebuilds GoRouter cleanly.
  const routerRevision = 22;

  String resolveInitialLocation() {
    if (kIsWeb) {
      final base = Uri.base.toString().toLowerCase();
      final path = Uri.base.path;
      final fragment = Uri.base.fragment;
      if (base.contains('superadmin')) {
        return '/superadmin/login';
      }
      if (fragment.isNotEmpty && fragment != '/') {
        return fragment.startsWith('/') ? fragment : '/$fragment';
      }
      if (path.isNotEmpty && path != '/' && path != '/index.html') {
        return path;
      }
    }
    return '/login';
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: resolveInitialLocation(),
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    observers: [AppGoRouterObserver()],
    redirect: (context, state) {
      // Touch revision so analyzer/tree-shaking keep the constant.
      assert(routerRevision >= 1);
      final auth = authBloc.state;
      final loc = state.matchedLocation;

      if (auth.status == AuthStatus.unknown) {
        // Hold current location while restoring session — do not bounce to login.
        return null;
      }

      final loggingIn = loc == '/login';
      final isSuperAdminLogin = loc == '/superadmin/login';
      final isSuperAdminPath = loc == '/superadmin' || loc.startsWith('/superadmin/');
      final changingPassword = loc == '/change-password';
      final verifyingEmails = loc == '/verify-emails';
      final trackingSetup = loc == '/tracking/setup';
      final guestMeet = loc.startsWith('/meet/guest') || loc.startsWith('/meet/r/');
      final authenticated = auth.isAuthenticated;
      final isSuperAdmin = Permissions.isSuperAdmin(auth.user?.role);
      final isPlatformPath = loc.startsWith('/platform');

      String? next;
      if (!authenticated) {
        if (kIsWeb) {
          final base = Uri.base.toString().toLowerCase();
          final path = Uri.base.path.toLowerCase();
          final fragment = Uri.base.fragment.toLowerCase();
          final hasSuperadminUrl = base.contains('superadmin') || path.contains('superadmin') || fragment.contains('superadmin');
          if (hasSuperadminUrl && (loc == '/login' || loc == '/' || loc.isEmpty)) {
            return '/superadmin/login';
          }
        }
        if (loc == '/superadmin') {
          next = '/superadmin/login';
        } else if (isSuperAdminLogin) {
          next = null;
        } else {
          next = (loggingIn || guestMeet) ? null : '/login';
        }
      } else if (auth.isFirstLogin) {
        next = changingPassword ? null : '/change-password';
      } else if (auth.needsEmailVerification) {
        next = verifyingEmails ? null : '/verify-emails';
      } else if (isSuperAdmin) {
        // SaaS Platform Superadmin is dedicated strictly to the platform console
        if (!isPlatformPath) {
          next = '/platform';
        }
      } else {
        // Client company users and employees cannot access platform console or superadmin portal
        if (isPlatformPath || isSuperAdminPath) {
          next = '/home';
        } else if (changingPassword || verifyingEmails || loggingIn) {
          next = '/home';
        } else if (trackingSetup) {
          next = null; // allow full-screen tracking setup
        } else {
          // Module license enforcement for tenant users: bounce if suite revoked
          final enabled = auth.user?.enabledModules ?? const ['HRMS', 'CRM', 'ERP'];
          final isErp = loc.startsWith('/erp');
          final isCrm = loc.startsWith('/crm');
          final isHrms = loc == '/home' ||
              loc.startsWith('/admin') ||
              loc.startsWith('/leave') ||
              loc.startsWith('/attendance') ||
              loc.startsWith('/salary') ||
              loc.startsWith('/reimbursements') ||
              loc.startsWith('/recruitment') ||
              loc.startsWith('/letters') ||
              loc.startsWith('/lookups');

          final defaultRoute = enabled.contains('HRMS')
              ? '/home'
              : (enabled.contains('ERP')
                  ? '/erp/home'
                  : (enabled.contains('CRM') ? '/crm/dashboard' : '/home'));

          if (isErp && !enabled.contains('ERP')) {
            next = defaultRoute;
          } else if (isCrm && !enabled.contains('CRM')) {
            next = defaultRoute;
          } else if (isHrms && !enabled.contains('HRMS')) {
            next = defaultRoute;
          } else {
            // Granular RBAC feature gating per role matrix
            final perms = auth.permissions;
            final role = auth.user?.role;
            final isChat = loc == '/chat' || loc.startsWith('/chat/');
            final isMeet = (loc == '/meet' || loc.startsWith('/meet/')) && !guestMeet;
            final isTasks = loc == '/tasks' || loc.startsWith('/tasks/');
            final isOrgTree = loc == '/org-tree' || loc.startsWith('/org-tree/');

            if (isChat && !Permissions.canReadChat(perms, role)) {
              next = defaultRoute;
            } else if (isMeet && !Permissions.canReadMeetings(perms, role)) {
              next = defaultRoute;
            } else if (isTasks && !Permissions.canReadTasks(perms, role)) {
              next = defaultRoute;
            } else if (isOrgTree && !Permissions.canReadOrgTree(perms, role)) {
              next = defaultRoute;
            } else if (loc.startsWith('/erp/projects') && !Permissions.canReadProjects(perms, role)) {
              next = '/erp/home';
            } else if (loc.startsWith('/erp/work-orders') && !Permissions.canReadWorkOrders(perms, role)) {
              next = '/erp/home';
            } else if (loc.startsWith('/erp/boq') && !Permissions.canReadBoq(perms, role)) {
              next = '/erp/home';
            } else if (loc.startsWith('/erp/store') && !Permissions.canReadStore(perms, role)) {
              next = '/erp/home';
            } else if ((loc.startsWith('/erp/tenders') || loc.startsWith('/erp/tender-applications')) &&
                !Permissions.canReadTenders(perms, role) &&
                !Permissions.canReadTenderApplications(perms, role)) {
              next = '/erp/home';
            } else if (loc.startsWith('/erp/dpr') && !Permissions.canReadDpr(perms, role)) {
              next = '/erp/home';
            } else if (loc.startsWith('/erp/configurations') &&
                !Permissions.isAdmin(role) &&
                !Permissions.canReadErpConfig(perms, role)) {
              next = '/erp/home';
            } else if (loc.startsWith('/crm/dashboard') && !Permissions.canReadCrmDashboard(perms, role)) {
              next = Permissions.canReadCrmPreSales(perms, role) ? '/crm/pre-sales' : defaultRoute;
            } else if (loc.startsWith('/crm/pre-sales/headers') && !Permissions.canReadCrmHeaders(perms, role)) {
              next = '/crm/pre-sales';
            } else if (loc.startsWith('/crm/pre-sales') && !Permissions.canReadCrmPreSales(perms, role)) {
              next = Permissions.canReadCrmDashboard(perms, role) ? '/crm/dashboard' : defaultRoute;
            } else if (loc.startsWith('/crm/post-sales') && !Permissions.canReadCrmPostSales(perms, role)) {
              next = '/crm/pre-sales';
            } else if (loc.startsWith('/crm/bin') && !Permissions.canReadCrmBin(perms, role)) {
              next = '/crm/pre-sales';
            } else if (loc.startsWith('/crm/settings') && !Permissions.canReadCrmSettings(perms, role)) {
              next = '/crm/pre-sales';
            } else if (loc.startsWith('/admin/roles') && !Permissions.canManageRoles(perms, role)) {
              next = defaultRoute;
            } else if (loc.startsWith('/admin/users') && !Permissions.canManageUsers(perms, role)) {
              next = defaultRoute;
            } else if (loc.startsWith('/repository') && !Permissions.canReadRepository(perms, role)) {
              next = defaultRoute;
            } else if (loc.startsWith('/recruitment') && !Permissions.canReadRecruitment(perms, role)) {
              next = defaultRoute;
            } else if (loc.startsWith('/reimbursements') &&
                !Permissions.canReadReimbursements(perms, role) &&
                auth.user?.employeeId == null) {
              next = defaultRoute;
            }
          }
        }
      }

      if (next != null) {
        AppLogger.router.i('redirect $loc → $next');
      }
      return next;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/login'),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/superadmin', redirect: (context, state) => '/superadmin/login'),
      GoRoute(
        path: '/superadmin/login',
        builder: (context, state) => const SuperadminLoginScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/verify-emails',
        builder: (context, state) => const VerifyEmailsScreen(),
      ),
      GoRoute(
        path: '/tracking/setup',
        builder: (context, state) => const AutostartOnboardingScreen(),
      ),
      GoRoute(
        path: '/meet/recording/:id',
        builder: (context, state) => MeetRecordingScreen(
          meetingId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/meet/r/:code',
        builder: (context, state) {
          final flags = meetRouteFlags(state.uri);
          return MeetRoomScreen(
            code: sanitizeMeetCode(state.pathParameters['code']),
            voiceOnly: flags.voice,
            autoJoin: flags.auto,
          );
        },
      ),
      GoRoute(
        path: '/meet/guest/:code',
        builder: (context, state) {
          final flags = meetRouteFlags(state.uri);
          return MeetRoomScreen(
            code: sanitizeMeetCode(state.pathParameters['code']),
            asGuest: true,
            voiceOnly: flags.voice,
            autoJoin: flags.auto,
          );
        },
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        // pageBuilder (without state.pageKey) avoids Duplicate GlobalKey int
        // assertions that ShellRoute.builder can trigger on hot reload/push.
        pageBuilder: (context, state, child) {
          return NoTransitionPage<void>(
            child: ResponsiveShell(child: child),
          );
        },
        routes: [
          GoRoute(
            path: '/platform',
            builder: (context, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
              return PlatformConsoleScreen(
                key: ValueKey('platform_console_screen_$tab'),
                initialTab: tab,
              );
            },
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/crm',
            redirect: (context, state) => '/crm/dashboard',
          ),
          GoRoute(
            path: '/crm/dashboard',
            builder: (context, state) => const CrmDashboardScreen(),
          ),
          GoRoute(
            path: '/crm/pre-sales',
            builder: (context, state) => const CrmPreSalesScreen(),
          ),
          GoRoute(
            path: '/crm/pre-sales/headers',
            builder: (context, state) => const CrmHeadersScreen(),
          ),
          GoRoute(
            path: '/crm/headers',
            redirect: (context, state) => '/crm/pre-sales/headers',
          ),
          GoRoute(
            path: '/crm/presales',
            redirect: (context, state) => '/crm/pre-sales',
          ),
          GoRoute(
            path: '/crm/post-sales',
            builder: (context, state) => const CrmPostSalesScreen(),
          ),
          GoRoute(
            path: '/crm/postsales',
            redirect: (context, state) => '/crm/post-sales',
          ),
          GoRoute(
            path: '/crm/bin',
            builder: (context, state) => const CrmBinScreen(),
          ),
          GoRoute(
            path: '/crm/settings',
            builder: (context, state) => const CrmSettingsScreen(),
          ),
          GoRoute(
            path: '/org-tree',
            builder: (context, state) => const EmployeeTreeScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksHubScreen(),
          ),
          GoRoute(
            path: '/erp/home',
            builder: (context, state) => const ErpHomeScreen(),
          ),
          GoRoute(
            path: '/erp/projects',
            builder: (context, state) => const ProjectsListScreen(),
          ),
          GoRoute(
            path: '/erp/projects/new',
            builder: (context, state) => const ProjectFormScreen(),
          ),
          GoRoute(
            path: '/erp/projects/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              if (id == null || id.isEmpty) {
                return const Scaffold(body: Center(child: Text('Invalid project')));
              }
              return ProjectFormScreen(projectId: id);
            },
          ),
          GoRoute(
            path: '/erp/structure/:projectId',
            builder: (context, state) {
              return ProjectStructureScreen(
                projectId: state.pathParameters['projectId'] ?? '',
              );
            },
            routes: [
              GoRoute(
                path: 'towers/new',
                builder: (context, state) {
                  return TowerFormScreen(
                    projectId: state.pathParameters['projectId'] ?? '',
                  );
                },
              ),
              GoRoute(
                path: 'towers/:towerId/units/:unitId',
                builder: (context, state) {
                  return UnitFormScreen(
                    projectId: state.pathParameters['projectId'] ?? '',
                    towerId: state.pathParameters['towerId'] ?? '',
                    unitId: state.pathParameters['unitId'] ?? '',
                  );
                },
              ),
              GoRoute(
                path: 'towers/:towerId/units',
                builder: (context, state) {
                  return TowerUnitsScreen(
                    projectId: state.pathParameters['projectId'] ?? '',
                    towerId: state.pathParameters['towerId'] ?? '',
                  );
                },
              ),
              GoRoute(
                path: 'towers/:towerId',
                builder: (context, state) {
                  return TowerFormScreen(
                    projectId: state.pathParameters['projectId'] ?? '',
                    towerId: state.pathParameters['towerId'],
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/erp/configurations',
            builder: (context, state) => const ErpConfigurationsScreen(),
          ),
          GoRoute(
            path: '/erp/configurations/activities',
            builder: (context, state) => const ActivitiesConfigScreen(),
          ),
          GoRoute(
            path: '/erp/configurations/contractors',
            builder: (context, state) => const ContractorsConfigScreen(),
          ),
          GoRoute(
            path: '/erp/configurations/contractors/new',
            builder: (context, state) => const ContractorFormScreen(),
          ),
          GoRoute(
            path: '/erp/configurations/contractors/:id/edit',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return ContractorFormScreen(id: id);
            },
          ),
          GoRoute(
            path: '/erp/configurations/lookups/:category',
            builder: (context, state) {
              final category = state.pathParameters['category'] ?? '';
              return LookupCategoryScreen(
                category: category,
                fallbackLocation: '/erp/configurations',
              );
            },
          ),
          GoRoute(
            path: '/erp/work-orders',
            builder: (context, state) => const WorkOrdersListScreen(),
          ),
          GoRoute(
            path: '/erp/work-orders/new',
            builder: (context, state) => const WorkOrderFormScreen(),
          ),
          GoRoute(
            path: '/erp/work-orders/:id/edit',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return WorkOrderFormScreen(id: id);
            },
          ),
          GoRoute(
            path: '/erp/work-orders/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return WorkOrderDetailScreen(id: id);
            },
          ),
          GoRoute(
            path: '/erp/boq',
            builder: (context, state) => const BoqListScreen(),
          ),
          GoRoute(
            path: '/erp/boq/new',
            builder: (context, state) => const BoqFormScreen(),
          ),
          GoRoute(
            path: '/erp/boq/:id/edit',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return BoqFormScreen(id: id);
            },
          ),
          GoRoute(
            path: '/erp/tenders',
            builder: (context, state) => const TenderListScreen(),
          ),
          GoRoute(
            path: '/erp/tenders/new',
            builder: (context, state) => const TenderFormScreen(),
          ),
          GoRoute(
            path: '/erp/tenders/:id/edit',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return TenderFormScreen(id: id);
            },
          ),
          GoRoute(
            path: '/erp/tender-applications',
            builder: (context, state) => const TenderApplicationsScreen(),
          ),
          GoRoute(
            path: '/erp/tender-applications/new',
            builder: (context, state) => const TenderApplicationFormScreen(),
          ),
          GoRoute(
            path: '/erp/dpr',
            builder: (context, state) => const DprListScreen(),
          ),
          GoRoute(
            path: '/erp/dpr/new',
            builder: (context, state) => const DprFormScreen(),
          ),
          GoRoute(
            path: '/erp/dpr/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return DprDetailScreen(id: id);
            },
          ),
          GoRoute(
            path: '/erp/store',
            builder: (context, state) => const StoreConfigScreen(),
          ),
          GoRoute(
            path: '/erp/configurations/store',
            builder: (context, state) => const StoreConfigScreen(),
          ),
          GoRoute(
            path: '/erp/configurations/materials',
            builder: (context, state) => const StoreConfigScreen(initialTab: 0),
          ),
          GoRoute(
            path: '/erp/configurations/machines',
            builder: (context, state) => const StoreConfigScreen(initialTab: 1),
          ),
          GoRoute(
            path: '/erp/configurations/labour',
            builder: (context, state) => const LabourConfigScreen(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatHubScreen(),
          ),
          GoRoute(
            path: '/meet/invite-people',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is MeetInviteResult) {
                return MeetInvitePeopleScreen(
                  initialSelected: extra.ids,
                  initialPeople: extra.people,
                );
              }
              return const MeetInvitePeopleScreen();
            },
          ),
          GoRoute(
            path: '/meet/schedule/:id',
            builder: (context, state) => MeetScheduleScreen(
              meetingId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            path: '/meet/schedule',
            builder: (context, state) => const MeetScheduleScreen(),
          ),
          GoRoute(
            path: '/meet/scheduled',
            builder: (context, state) => const MeetListScreen(kind: MeetListKind.scheduled),
          ),
          GoRoute(
            path: '/meet/past',
            builder: (context, state) => const MeetListScreen(kind: MeetListKind.past),
          ),
          GoRoute(
            path: '/meet/org',
            builder: (context, state) => const MeetListScreen(kind: MeetListKind.org),
          ),
          GoRoute(
            path: '/meet',
            builder: (context, state) => const MeetHubScreen(),
          ),
          GoRoute(
            path: '/leave',
            builder: (context, state) => const LeaveHubScreen(),
          ),
          GoRoute(
            path: '/leave/apply',
            builder: (context, state) => const LeaveApplyScreen(),
          ),
          GoRoute(
            path: '/leave/history',
            builder: (context, state) => const LeaveHistoryScreen(),
          ),
          GoRoute(
            path: '/reimbursements',
            builder: (context, state) => const ReimbursementsHubScreen(),
          ),
          GoRoute(
            path: '/reimbursements/apply',
            builder: (context, state) => const ReimbursementApplyScreen(),
          ),
          GoRoute(
            path: '/reimbursements/admin',
            builder: (context, state) => const ReimbursementsAdminScreen(),
          ),
          GoRoute(
            path: '/recruitment',
            builder: (context, state) => const RecruitmentHubScreen(),
          ),
          GoRoute(
            path: '/repository',
            builder: (context, state) => const RepositoryHubScreen(),
          ),
          GoRoute(
            path: '/recruitment/candidates/:id',
            builder: (context, state) => CandidateDetailScreen(
              candidateId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '/approvals',
            builder: (context, state) => const LeaveApprovalsScreen(),
          ),
          GoRoute(
            path: '/approvals/history',
            builder: (context, state) => const LeaveApprovalsHistoryScreen(),
          ),
          GoRoute(
            path: '/admin/leaves',
            builder: (context, state) => const AdminLeavesScreen(),
          ),
          GoRoute(
            path: '/admin/leaves/pending',
            builder: (context, state) => const AdminLeavesPendingScreen(),
          ),
          GoRoute(
            path: '/admin/leaves/settings',
            builder: (context, state) => const AdminLeavesSettingsScreen(),
          ),
          GoRoute(
            path: '/admin/leaves/holidays',
            builder: (context, state) => const AdminLeavesHolidaysScreen(),
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/admin/attendance',
            builder: (context, state) => const AdminAttendanceScreen(),
          ),
          GoRoute(
            path: '/admin/attendance/device',
            builder: (context, state) => const DeviceAttendanceScreen(),
          ),
          GoRoute(
            path: '/admin/attendance/locations',
            builder: (context, state) => const AdminLocationsScreen(),
          ),
          GoRoute(
            path: '/admin/attendance/employee/:employeeId',
            builder: (context, state) {
              final id =
                  int.tryParse(state.pathParameters['employeeId'] ?? '') ?? 0;
              return AdminEmployeeAttendanceHistoryScreen(employeeId: id);
            },
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) {
              final idStr = state.uri.queryParameters['employeeId'];
              final id = idStr != null ? int.tryParse(idStr) : null;
              return ProfileScreen(employeeId: id);
            },
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (context, state) {
              final idStr = state.uri.queryParameters['employeeId'];
              final id = idStr != null ? int.tryParse(idStr) : null;
              return ProfileEditScreen(employeeId: id);
            },
          ),
          GoRoute(
            path: '/profile/salary-slip/:recordId',
            builder: (context, state) {
              final recordId = state.pathParameters['recordId'] ?? '';
              final employeeId =
                  int.tryParse(state.uri.queryParameters['employeeId'] ?? '') ??
                  0;
              if (recordId.isEmpty || employeeId == 0) {
                return const Scaffold(
                  body: Center(child: Text('Invalid slip request')),
                );
              }
              return EmployeeSalarySlipScreen(
                recordId: recordId,
                employeeId: employeeId,
              );
            },
          ),
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/configurations',
            builder: (context, state) => const ConfigurationsHubScreen(),
          ),
          GoRoute(
            path: '/admin/configurations/organizations',
            builder: (context, state) => const OrganizationsScreen(),
          ),
          GoRoute(
            path: '/admin/configurations/letters',
            builder: (context, state) => const AdminLettersConfigScreen(),
          ),
          GoRoute(
            path: '/admin/storage',
            builder: (context, state) => const AdminStorageScreen(),
          ),
          GoRoute(
            path: '/admin/configurations/lookups/:category',
            builder: (context, state) {
              final category = state.pathParameters['category'] ?? '';
              return LookupCategoryScreen(category: category);
            },
          ),
          // Keep legacy path working (redirect-style alias)
          GoRoute(
            path: '/admin/organizations',
            redirect: (context, state) => '/admin/configurations/organizations',
          ),
          GoRoute(
            path: '/admin/institutes',
            builder: (context, state) => const InstitutesScreen(),
          ),
          GoRoute(
            path: '/admin/institutes/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              if (id == null || id.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('Invalid Institute ID')),
                );
              }
              return InstituteDetailScreen(instituteId: id);
            },
          ),
          GoRoute(
            path: '/admin/designations',
            builder: (context, state) => const DesignationsScreen(),
          ),
          GoRoute(
            path: '/admin/employees',
            builder: (context, state) => const AdminEmployeesScreen(),
          ),
          GoRoute(
            path: '/admin/employees/:id',
            builder: (context, state) {
              final idStr = state.pathParameters['id'];
              final id = idStr != null ? int.tryParse(idStr) : null;
              if (id == null) {
                return const Scaffold(
                  body: Center(child: Text('Invalid Employee ID')),
                );
              }
              return AdminEmployeeDetailScreen(employeeId: id);
            },
          ),
          GoRoute(
            path: '/admin/approvals',
            builder: (context, state) => const AdminApprovalsScreen(),
          ),
          GoRoute(
            path: '/admin/live-tracking',
            builder: (context, state) => const AdminLiveTrackingScreen(),
          ),
          GoRoute(
            path: '/admin/live-tracking/employee/:employeeId',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['employeeId'] ?? '');
              if (id == null) {
                return const Scaffold(
                  body: Center(child: Text('Invalid Employee ID')),
                );
              }
              return AdminEmployeeLiveTrackingScreen(employeeId: id);
            },
          ),
          GoRoute(
            path: '/admin/tracking-hub',
            builder: (context, state) => TrackingHubScreen(
              initialDate: state.uri.queryParameters['date'],
              initialEmployeeId: state.uri.queryParameters['employeeId'],
            ),
          ),
          GoRoute(
            path: '/admin/tracking-hub/employee/:employeeId',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['employeeId'] ?? '');
              if (id == null) {
                return const Scaffold(
                  body: Center(child: Text('Invalid Employee ID')),
                );
              }
              return TrackingHubEmployeeDetailScreen(
                employeeId: id,
                date: state.uri.queryParameters['date'],
              );
            },
          ),
          GoRoute(
            path: '/admin/tracking-hub/trip/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              if (id == null || id.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('Invalid Trip ID')),
                );
              }
              return TripDetailHubScreen(tripId: id);
            },
          ),
          GoRoute(
            path: '/admin/trips',
            builder: (context, state) => const AdminTripsScreen(),
          ),
          GoRoute(
            path: '/admin/trips/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              if (id == null || id.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('Invalid Trip ID')),
                );
              }
              return AdminTripReplayScreen(tripId: id);
            },
          ),
          GoRoute(
            path: '/admin/audit',
            builder: (context, state) => const AdminAuditStubScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => BlocProvider(
              create: (context) => AdminUsersBloc(
                rbacRepository: context.read<RbacRepository>(),
              ),
              child: const AdminUsersScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/roles',
            builder: (context, state) => BlocProvider(
              create: (context) => AdminRolesBloc(
                rbacRepository: context.read<RbacRepository>(),
              ),
              child: const AdminRolesScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/roles/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              if (id == null || id.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('Invalid Role ID')),
                );
              }
              return BlocProvider(
                create: (context) => AdminRoleDetailBloc(
                  rbacRepository: context.read<RbacRepository>(),
                ),
                child: AdminRoleDetailScreen(roleId: id),
              );
            },
          ),
          GoRoute(
            path: '/admin/salary/commissions',
            builder: (context, state) => const AdminSalaryCommissionsScreen(),
          ),
          GoRoute(
            path: '/admin/salary/commissions/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              if (id == null || id.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('Invalid commission ID')),
                );
              }
              return AdminSalaryCommissionDetailScreen(commissionId: id);
            },
          ),
          GoRoute(
            path: '/admin/salary/structures',
            builder: (context, state) => const AdminSalaryStructuresScreen(),
          ),
          GoRoute(
            path: '/admin/salary/structures/:designationId/:commission',
            builder: (context, state) {
              final designationId = state.pathParameters['designationId'];
              final commission = state.pathParameters['commission'];
              if (designationId == null || commission == null) {
                return const Scaffold(
                  body: Center(child: Text('Invalid structure route')),
                );
              }
              return AdminSalaryStructureDetailScreen(
                designationId: designationId,
                commission: commission,
                templateId: state.uri.queryParameters['templateId'],
              );
            },
          ),
          GoRoute(
            path: '/admin/salary/entry',
            builder: (context, state) => const AdminSalaryEntryScreen(),
          ),
          GoRoute(
            path: '/admin/salary/payroll',
            builder: (context, state) => const AdminPayrollMonthScreen(),
          ),
          GoRoute(
            path: '/admin/salary/records',
            builder: (context, state) => const AdminSalaryRecordsScreen(),
          ),
          GoRoute(
            path: '/admin/salary/records/:id/slip',
            builder: (context, state) {
              final id = state.pathParameters['id'];
              if (id == null || id.isEmpty) {
                return const Scaffold(
                  body: Center(child: Text('Invalid record ID')),
                );
              }
              return AdminSalarySlipScreen(recordId: id);
            },
          ),
        ],
      ),
    ],
  );
}
