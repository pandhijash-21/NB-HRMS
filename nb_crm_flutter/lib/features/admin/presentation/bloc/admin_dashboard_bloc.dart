import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../leave/data/leave_repository.dart';
import '../../../leave/domain/leave_models.dart';
import '../../../profile/domain/profile_models.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class AdminDashboardEvent extends Equatable {
  const AdminDashboardEvent();

  @override
  List<Object?> get props => [];
}

class AdminDashboardLoadRequested extends AdminDashboardEvent {
  const AdminDashboardLoadRequested();
}

class AdminDashboardRefreshRequested extends AdminDashboardEvent {
  const AdminDashboardRefreshRequested();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class AdminDashboardState extends Equatable {
  const AdminDashboardState({
    this.status = LoadStatus.initial,
    this.totalEmployees = 0,
    this.activeEmployees = 0,
    this.probationEmployees = 0,
    this.noticeEmployees = 0,
    this.allEmployees = const [],
    this.recentEmployees = const [],
    this.pendingApprovalsCount = 0,
    this.pendingLeaveCount = 0,
    this.errorMessage,
  });

  final LoadStatus status;
  final int totalEmployees;
  final int activeEmployees;
  final int probationEmployees;
  final int noticeEmployees;
  final List<EmployeeProfile> allEmployees;
  final List<EmployeeProfile> recentEmployees;
  final int pendingApprovalsCount;
  final int pendingLeaveCount;
  final String? errorMessage;

  AdminDashboardState copyWith({
    LoadStatus? status,
    int? totalEmployees,
    int? activeEmployees,
    int? probationEmployees,
    int? noticeEmployees,
    List<EmployeeProfile>? allEmployees,
    List<EmployeeProfile>? recentEmployees,
    int? pendingApprovalsCount,
    int? pendingLeaveCount,
    String? errorMessage,
  }) {
    return AdminDashboardState(
      status: status ?? this.status,
      totalEmployees: totalEmployees ?? this.totalEmployees,
      activeEmployees: activeEmployees ?? this.activeEmployees,
      probationEmployees: probationEmployees ?? this.probationEmployees,
      noticeEmployees: noticeEmployees ?? this.noticeEmployees,
      allEmployees: allEmployees ?? this.allEmployees,
      recentEmployees: recentEmployees ?? this.recentEmployees,
      pendingApprovalsCount: pendingApprovalsCount ?? this.pendingApprovalsCount,
      pendingLeaveCount: pendingLeaveCount ?? this.pendingLeaveCount,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        totalEmployees,
        activeEmployees,
        probationEmployees,
        noticeEmployees,
        allEmployees,
        recentEmployees,
        pendingApprovalsCount,
        pendingLeaveCount,
        errorMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class AdminDashboardBloc
    extends Bloc<AdminDashboardEvent, AdminDashboardState> {
  AdminDashboardBloc({
    required AdminRepository adminRepository,
    required LeaveRepository leaveRepository,
  })  : _adminRepository = adminRepository,
        _leaveRepository = leaveRepository,
        super(const AdminDashboardState()) {
    on<AdminDashboardLoadRequested>(_onLoad);
    on<AdminDashboardRefreshRequested>(_onRefresh);
  }

  final AdminRepository _adminRepository;
  final LeaveRepository _leaveRepository;

  Future<void> _fetchDashboard(Emitter<AdminDashboardState> emit) async {
    try {
      final results = await Future.wait([
        _adminRepository.listEmployees(limit: 1000, offset: 0).catchError((_) => <String, dynamic>{'items': <EmployeeProfile>[], 'total': 0}),
        _adminRepository.listEmployees(limit: 5, offset: 0).catchError((_) => <String, dynamic>{'items': <EmployeeProfile>[], 'total': 0}),
        _adminRepository.listApprovals(status: 'PENDING').catchError((_) => <ChangeRequest>[]),
        _leaveRepository.getAdminApplications(
          status: 'PENDING',
          page: 0,
          limit: 1,
        ).catchError((_) => const LeaveApplicationsPage(items: [], total: 0)),
      ]);

      final allMap = results[0] as Map<String, dynamic>;
      final allItems = (allMap['items'] as List? ?? []).cast<EmployeeProfile>();
      final total = allMap['total'] as int? ?? allItems.length;

      var active = 0;
      var probation = 0;
      var notice = 0;
      for (final emp in allItems) {
        final s = emp.status.toUpperCase();
        if (s == 'ACTIVE') active++;
        if (s == 'PROBATION') probation++;
        if (s == 'NOTICE' || s == 'NOTICE_PERIOD') notice++;
      }

      final recentMap = results[1] as Map<String, dynamic>;
      final recent = (recentMap['items'] as List? ?? []).cast<EmployeeProfile>();

      final approvals = results[2] as List;
      final leavePage = results[3] as dynamic;
      final leaveCount = leavePage.total as int? ?? 0;

      emit(state.copyWith(
        status: LoadStatus.success,
        totalEmployees: total,
        activeEmployees: active,
        probationEmployees: probation,
        noticeEmployees: notice,
        allEmployees: allItems,
        recentEmployees: recent,
        pendingApprovalsCount: approvals.length,
        pendingLeaveCount: leaveCount,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoad(
    AdminDashboardLoadRequested event,
    Emitter<AdminDashboardState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchDashboard(emit);
  }

  Future<void> _onRefresh(
    AdminDashboardRefreshRequested event,
    Emitter<AdminDashboardState> emit,
  ) async {
    await _fetchDashboard(emit);
  }
}
