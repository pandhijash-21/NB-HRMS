import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class CrmDashboardEvent extends Equatable {
  const CrmDashboardEvent();

  @override
  List<Object?> get props => [];
}

class CrmDashboardLoadRequested extends CrmDashboardEvent {
  const CrmDashboardLoadRequested();
}

class CrmDashboardRefreshRequested extends CrmDashboardEvent {
  const CrmDashboardRefreshRequested();
}

class CrmDashboardFollowUpCompleted extends CrmDashboardEvent {
  const CrmDashboardFollowUpCompleted(this.id, {this.remarks});
  final String id;
  final String? remarks;

  @override
  List<Object?> get props => [id, remarks];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class CrmDashboardState extends Equatable {
  const CrmDashboardState({
    this.status = LoadStatus.initial,
    this.kpiMetrics,
    this.todayFollowUps = const [],
    this.settings,
    this.isActing = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  final LoadStatus status;
  final CrmKpiMetrics? kpiMetrics;
  final List<CrmFollowUp> todayFollowUps;
  final CrmSettings? settings;
  final bool isActing;
  final String? errorMessage;
  final String? actionSuccessMessage;

  CrmDashboardState copyWith({
    LoadStatus? status,
    CrmKpiMetrics? kpiMetrics,
    List<CrmFollowUp>? todayFollowUps,
    CrmSettings? settings,
    bool? isActing,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return CrmDashboardState(
      status: status ?? this.status,
      kpiMetrics: kpiMetrics ?? this.kpiMetrics,
      todayFollowUps: todayFollowUps ?? this.todayFollowUps,
      settings: settings ?? this.settings,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        kpiMetrics,
        todayFollowUps,
        settings,
        isActing,
        errorMessage,
        actionSuccessMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class CrmDashboardBloc extends Bloc<CrmDashboardEvent, CrmDashboardState> {
  CrmDashboardBloc({required CrmRepository crmRepository})
      : _crmRepository = crmRepository,
        super(const CrmDashboardState()) {
    on<CrmDashboardLoadRequested>(_onLoad);
    on<CrmDashboardRefreshRequested>(_onRefresh);
    on<CrmDashboardFollowUpCompleted>(_onFollowUpCompleted);
  }

  final CrmRepository _crmRepository;

  Future<void> _fetchData(Emitter<CrmDashboardState> emit) async {
    try {
      final results = await Future.wait([
        _crmRepository.getKpiMetrics(),
        _crmRepository.getFollowUps(filter: 'today'),
        _crmRepository.getSettings(),
      ]);

      emit(state.copyWith(
        status: LoadStatus.success,
        kpiMetrics: results[0] as CrmKpiMetrics,
        todayFollowUps: results[1] as List<CrmFollowUp>,
        settings: results[2] as CrmSettings,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoad(
    CrmDashboardLoadRequested event,
    Emitter<CrmDashboardState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchData(emit);
  }

  Future<void> _onRefresh(
    CrmDashboardRefreshRequested event,
    Emitter<CrmDashboardState> emit,
  ) async {
    await _fetchData(emit);
  }

  Future<void> _onFollowUpCompleted(
    CrmDashboardFollowUpCompleted event,
    Emitter<CrmDashboardState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.completeFollowUp(event.id, remarks: event.remarks);
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Follow-up completed',
      ));
      await _fetchData(emit);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
