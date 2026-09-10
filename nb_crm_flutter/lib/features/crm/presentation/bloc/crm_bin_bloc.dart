import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class CrmBinEvent extends Equatable {
  const CrmBinEvent();

  @override
  List<Object?> get props => [];
}

class CrmBinLoadRequested extends CrmBinEvent {
  const CrmBinLoadRequested({this.module = 'PRE_SALES'});
  final String module;

  @override
  List<Object?> get props => [module];
}

class CrmBinRefreshRequested extends CrmBinEvent {
  const CrmBinRefreshRequested();
}

class CrmBinModuleChanged extends CrmBinEvent {
  const CrmBinModuleChanged(this.module);
  final String module;

  @override
  List<Object?> get props => [module];
}

class CrmBinLeadRestored extends CrmBinEvent {
  const CrmBinLeadRestored(this.leadId);
  final String leadId;

  @override
  List<Object?> get props => [leadId];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class CrmBinState extends Equatable {
  const CrmBinState({
    this.status = LoadStatus.initial,
    this.module = 'PRE_SALES',
    this.leads = const [],
    this.isActing = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  final LoadStatus status;
  final String module;
  final List<CrmLead> leads;
  final bool isActing;
  final String? errorMessage;
  final String? actionSuccessMessage;

  CrmBinState copyWith({
    LoadStatus? status,
    String? module,
    List<CrmLead>? leads,
    bool? isActing,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return CrmBinState(
      status: status ?? this.status,
      module: module ?? this.module,
      leads: leads ?? this.leads,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        module,
        leads,
        isActing,
        errorMessage,
        actionSuccessMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class CrmBinBloc extends Bloc<CrmBinEvent, CrmBinState> {
  CrmBinBloc({required CrmRepository crmRepository})
      : _crmRepository = crmRepository,
        super(const CrmBinState()) {
    on<CrmBinLoadRequested>(_onLoad);
    on<CrmBinRefreshRequested>(_onRefresh);
    on<CrmBinModuleChanged>(_onModuleChanged);
    on<CrmBinLeadRestored>(_onLeadRestored);
  }

  final CrmRepository _crmRepository;

  Future<void> _fetchData(Emitter<CrmBinState> emit, {required String module}) async {
    try {
      final binLeads = await _crmRepository.getBinLeads(module: module);
      emit(state.copyWith(
        status: LoadStatus.success,
        module: module,
        leads: binLeads,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoad(
    CrmBinLoadRequested event,
    Emitter<CrmBinState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, module: event.module));
    await _fetchData(emit, module: event.module);
  }

  Future<void> _onRefresh(
    CrmBinRefreshRequested event,
    Emitter<CrmBinState> emit,
  ) async {
    await _fetchData(emit, module: state.module);
  }

  Future<void> _onModuleChanged(
    CrmBinModuleChanged event,
    Emitter<CrmBinState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, module: event.module));
    await _fetchData(emit, module: event.module);
  }

  Future<void> _onLeadRestored(
    CrmBinLeadRestored event,
    Emitter<CrmBinState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.restoreFromBin(event.leadId);
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Lead restored successfully',
      ));
      await _fetchData(emit, module: state.module);
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
