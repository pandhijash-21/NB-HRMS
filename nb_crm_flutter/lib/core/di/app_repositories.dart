import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/app_config.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage_service.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/attendance/data/attendance_repository.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/collaboration/data/chat_repository.dart';
import '../../features/collaboration/data/meet_repository.dart';
import '../../features/crm/data/crm_repository.dart';
import '../../features/erp/data/boq_repository.dart';
import '../../features/erp/data/dpr_repository.dart';
import '../../features/erp/data/project_repository.dart';
import '../../features/erp/data/tender_repository.dart';
import '../../features/erp/data/work_order_repository.dart';
import '../../features/leave/data/leave_repository.dart';
import '../../features/letters/data/letters_repository.dart';
import '../../features/lookups/data/lookup_repository.dart';
import '../../features/org/data/org_repository.dart';
import '../../features/org_tree/data/org_tree_repository.dart';
import '../../features/platform/data/platform_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/rbac/data/rbac_repository.dart';
import '../../features/recruitment/data/recruitment_repository.dart';
import '../../features/reimbursements/data/reimbursements_repository.dart';
import '../../features/repository/data/repository_repository.dart';
import '../../features/salary/data/salary_repository.dart';
import '../../features/tasks/data/tasks_repository.dart';

/// Container that holds all core singleton services and repositories.
class AppRepositories {
  AppRepositories() {
    storage = SecureStorageService();
    unauthorizedGate = UnauthorizedGate();
    dioClient = DioClient(
      readToken: storage.readToken,
      unauthorizedGate: unauthorizedGate,
      baseUrl: AppConfig.apiBaseUrl,
    );
    authRepository = AuthRepository(
      dioClient: dioClient,
      storage: storage,
    );
    lookupRepository = LookupRepository(dioClient: dioClient);
  }

  late final SecureStorageService storage;
  late final UnauthorizedGate unauthorizedGate;
  late final DioClient dioClient;
  late final AuthRepository authRepository;
  late final LookupRepository lookupRepository;

  Widget wrapWithProviders({required Widget child}) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: storage),
        RepositoryProvider.value(value: unauthorizedGate),
        RepositoryProvider.value(value: dioClient),
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider<PlatformRepository>(
          create: (_) => PlatformRepository(dioClient: dioClient),
        ),
        RepositoryProvider<AdminRepository>(
          create: (_) => AdminRepository(dioClient: dioClient),
        ),
        RepositoryProvider<AttendanceRepository>(
          create: (_) => AttendanceRepository(dioClient: dioClient),
        ),
        RepositoryProvider<CrmRepository>(
          create: (_) => CrmRepository(dioClient: dioClient),
        ),
        RepositoryProvider<LeaveRepository>(
          create: (_) => LeaveRepository(dioClient: dioClient),
        ),
        RepositoryProvider<SalaryRepository>(
          create: (_) => SalaryRepository(dioClient: dioClient),
        ),
        RepositoryProvider<ProfileRepository>(
          create: (_) => ProfileRepository(dioClient: dioClient),
        ),
        RepositoryProvider<RbacRepository>(
          create: (_) => RbacRepository(dioClient: dioClient),
        ),
        RepositoryProvider<OrgRepository>(
          create: (_) => OrgRepository(dioClient: dioClient),
        ),
        RepositoryProvider<OrgTreeRepository>(
          create: (_) => OrgTreeRepository(dioClient: dioClient),
        ),
        RepositoryProvider<TasksRepository>(
          create: (_) => TasksRepository(dioClient: dioClient),
        ),
        RepositoryProvider<LookupRepository>(
          create: (_) => LookupRepository(dioClient: dioClient),
        ),
        RepositoryProvider<LettersRepository>(
          create: (_) => LettersRepository(dioClient: dioClient),
        ),
        RepositoryProvider<RecruitmentRepository>(
          create: (_) => RecruitmentRepository(dioClient: dioClient),
        ),
        RepositoryProvider<ReimbursementsRepository>(
          create: (_) => ReimbursementsRepository(dioClient: dioClient),
        ),
        RepositoryProvider<CompanyRepository>(
          create: (_) => CompanyRepository(dioClient: dioClient),
        ),
        RepositoryProvider<ChatRepository>(
          create: (_) => ChatRepository(dioClient: dioClient),
        ),
        RepositoryProvider<MeetRepository>(
          create: (_) => MeetRepository(dioClient: dioClient),
        ),
        RepositoryProvider<BoqRepository>(
          create: (_) => BoqRepository(dioClient: dioClient),
        ),
        RepositoryProvider<DprRepository>(
          create: (_) => DprRepository(dioClient: dioClient),
        ),
        RepositoryProvider<ProjectRepository>(
          create: (_) => ProjectRepository(dioClient: dioClient),
        ),
        RepositoryProvider<TenderRepository>(
          create: (_) => TenderRepository(dioClient: dioClient),
        ),
        RepositoryProvider<WorkOrderRepository>(
          create: (_) => WorkOrderRepository(dioClient: dioClient),
        ),
      ],
      child: child,
    );
  }
}
