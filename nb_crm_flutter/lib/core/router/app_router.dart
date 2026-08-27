import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../logging/app_logger.dart';
import 'app_navigation.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/verify_emails_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/admin/presentation/screens/admin_employees_screen.dart';
import '../../features/admin/presentation/screens/admin_employee_detail_screen.dart';
import '../../features/admin/presentation/screens/admin_approvals_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
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
import '../widgets/responsive_shell.dart';

/// Listenable bridge so GoRouter refreshes when [AuthState] changes.
class GoRouterAuthRefresh extends ChangeNotifier {
  GoRouterAuthRefresh(Ref ref) {
    _subscription = ref.listen<AuthState>(authNotifierProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterAuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  // Fresh per provider instance — avoids ShellRoute GlobalKey collisions on
  // hot reload (go_router keys navigators with GlobalObjectKey(hashCode)).
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
  final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shellNav');

  // Bump when route table changes so hot-restart rebuilds GoRouter cleanly.
  const routerRevision = 16;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    observers: [AppGoRouterObserver()],
    redirect: (context, state) {
      // Touch revision so analyzer/tree-shaking keep the constant.
      assert(routerRevision >= 1);
      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      if (auth.status == AuthStatus.unknown) {
        // Hold current location while restoring session — do not bounce to login.
        return null;
      }

      final loggingIn = loc == '/login';
      final changingPassword = loc == '/change-password';
      final verifyingEmails = loc == '/verify-emails';
      final trackingSetup = loc == '/tracking/setup';
      final authenticated = auth.isAuthenticated;

      String? next;
      if (!authenticated) {
        next = loggingIn ? null : '/login';
      } else if (auth.isFirstLogin) {
        next = changingPassword ? null : '/change-password';
      } else if (auth.needsEmailVerification) {
        next = verifyingEmails ? null : '/verify-emails';
      } else if (changingPassword || verifyingEmails) {
        next = '/home';
      } else if (loggingIn) {
        next = '/home';
      } else if (trackingSetup) {
        next = null; // allow full-screen tracking setup
      }

      if (next != null) {
        AppLogger.router.i('redirect $loc → $next');
      }
      return next;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/login'),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
            path: '/home',
            builder: (context, state) => const HomeScreen(),
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
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/admin/roles',
            builder: (context, state) => const AdminRolesScreen(),
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
              return AdminRoleDetailScreen(roleId: id);
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
});
