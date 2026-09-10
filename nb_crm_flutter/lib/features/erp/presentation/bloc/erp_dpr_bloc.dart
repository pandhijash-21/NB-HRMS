import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/dpr_repository.dart';
import '../../domain/dpr_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class ErpDprEvent extends Equatable {
  const ErpDprEvent();

  @override
  List<Object?> get props => [];
}

class ErpDprListRequested extends ErpDprEvent {
  const ErpDprListRequested({this.projectId});
  final String? projectId;

  @override
  List<Object?> get props => [projectId];
}

class ErpDprDetailRequested extends ErpDprEvent {
  const ErpDprDetailRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpDprCreated extends ErpDprEvent {
  const ErpDprCreated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

class ErpDprDeleted extends ErpDprEvent {
  const ErpDprDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpDprContractorResourcesRequested extends ErpDprEvent {
  const ErpDprContractorResourcesRequested({
    required this.contractorId,
    this.date,
  });

  final String contractorId;
  final DateTime? date;

  @override
  List<Object?> get props => [contractorId, date];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class ErpDprState extends Equatable {
  const ErpDprState({
    this.status = LoadStatus.initial,
    this.dprs = const [],
    this.selectedDpr,
    this.contractorMaterials = const [],
    this.contractorMachines = const [],
    this.isActing = false,
    this.errorMessage,
    this.actionMessage,
  });

  final LoadStatus status;
  final List<ErpDpr> dprs;
  final ErpDpr? selectedDpr;
  final List<ErpDprMaterialLine> contractorMaterials;
  final List<ErpDprMachineLine> contractorMachines;
  final bool isActing;
  final String? errorMessage;
  final String? actionMessage;

  ErpDprState copyWith({
    LoadStatus? status,
    List<ErpDpr>? dprs,
    ErpDpr? selectedDpr,
    bool clearSelectedDpr = false,
    List<ErpDprMaterialLine>? contractorMaterials,
    List<ErpDprMachineLine>? contractorMachines,
    bool? isActing,
    String? errorMessage,
    String? actionMessage,
  }) {
    return ErpDprState(
      status: status ?? this.status,
      dprs: dprs ?? this.dprs,
      selectedDpr: clearSelectedDpr ? null : (selectedDpr ?? this.selectedDpr),
      contractorMaterials: contractorMaterials ?? this.contractorMaterials,
      contractorMachines: contractorMachines ?? this.contractorMachines,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        dprs,
        selectedDpr,
        contractorMaterials,
        contractorMachines,
        isActing,
        errorMessage,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class ErpDprBloc extends Bloc<ErpDprEvent, ErpDprState> {
  ErpDprBloc({required DprRepository dprRepository})
      : _dprRepository = dprRepository,
        super(const ErpDprState()) {
    on<ErpDprListRequested>(_onListRequested);
    on<ErpDprDetailRequested>(_onDetailRequested);
    on<ErpDprCreated>(_onDprCreated);
    on<ErpDprDeleted>(_onDprDeleted);
    on<ErpDprContractorResourcesRequested>(_onContractorResourcesRequested);
  }

  final DprRepository _dprRepository;

  Future<void> _onListRequested(
    ErpDprListRequested event,
    Emitter<ErpDprState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final dprs = await _dprRepository.list(projectId: event.projectId);
      emit(state.copyWith(status: LoadStatus.success, dprs: dprs));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onDetailRequested(
    ErpDprDetailRequested event,
    Emitter<ErpDprState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final dpr = await _dprRepository.getById(event.id);
      emit(state.copyWith(status: LoadStatus.success, selectedDpr: dpr));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onDprCreated(
    ErpDprCreated event,
    Emitter<ErpDprState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final dpr = await _dprRepository.create(event.body);
      final updated = [dpr, ...state.dprs];
      emit(state.copyWith(
        isActing: false,
        dprs: updated,
        actionMessage: 'DPR submitted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onDprDeleted(
    ErpDprDeleted event,
    Emitter<ErpDprState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _dprRepository.remove(event.id);
      final updated = state.dprs.where((d) => d.id != event.id).toList();
      emit(state.copyWith(
        isActing: false,
        dprs: updated,
        actionMessage: 'DPR deleted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onContractorResourcesRequested(
    ErpDprContractorResourcesRequested event,
    Emitter<ErpDprState> emit,
  ) async {
    try {
      final res = await _dprRepository.getContractorResources(
        event.contractorId,
        date: event.date,
      );
      emit(state.copyWith(
        contractorMaterials: (res['materials'] as List<ErpDprMaterialLine>?) ?? [],
        contractorMachines: (res['machines'] as List<ErpDprMachineLine>?) ?? [],
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
