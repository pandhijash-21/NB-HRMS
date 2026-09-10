import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/tender_repository.dart';
import '../../domain/tender_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class ErpTendersEvent extends Equatable {
  const ErpTendersEvent();

  @override
  List<Object?> get props => [];
}

class ErpTendersListRequested extends ErpTendersEvent {
  const ErpTendersListRequested({this.projectId});
  final String? projectId;

  @override
  List<Object?> get props => [projectId];
}

class ErpTenderDetailRequested extends ErpTendersEvent {
  const ErpTenderDetailRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpTenderCreated extends ErpTendersEvent {
  const ErpTenderCreated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

class ErpTenderUpdated extends ErpTendersEvent {
  const ErpTenderUpdated({required this.id, required this.body});
  final String id;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [id, body];
}

class ErpTenderDeleted extends ErpTendersEvent {
  const ErpTenderDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpTenderApplicationsRequested extends ErpTendersEvent {
  const ErpTenderApplicationsRequested({
    this.tenderId,
    this.projectId,
    this.status,
  });

  final String? tenderId;
  final String? projectId;
  final String? status;

  @override
  List<Object?> get props => [tenderId, projectId, status];
}

class ErpTenderApplicationCreated extends ErpTendersEvent {
  const ErpTenderApplicationCreated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

class ErpTenderApplicationStatusUpdated extends ErpTendersEvent {
  const ErpTenderApplicationStatusUpdated({
    required this.id,
    required this.status,
  });

  final String id;
  final String status;

  @override
  List<Object?> get props => [id, status];
}

class ErpTenderApplicationDeleted extends ErpTendersEvent {
  const ErpTenderApplicationDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class ErpTendersState extends Equatable {
  const ErpTendersState({
    this.status = LoadStatus.initial,
    this.tenders = const [],
    this.selectedTender,
    this.applications = const [],
    this.isActing = false,
    this.errorMessage,
    this.actionMessage,
  });

  final LoadStatus status;
  final List<ErpTender> tenders;
  final ErpTender? selectedTender;
  final List<ErpTenderApplication> applications;
  final bool isActing;
  final String? errorMessage;
  final String? actionMessage;

  ErpTendersState copyWith({
    LoadStatus? status,
    List<ErpTender>? tenders,
    ErpTender? selectedTender,
    bool clearSelectedTender = false,
    List<ErpTenderApplication>? applications,
    bool? isActing,
    String? errorMessage,
    String? actionMessage,
  }) {
    return ErpTendersState(
      status: status ?? this.status,
      tenders: tenders ?? this.tenders,
      selectedTender: clearSelectedTender
          ? null
          : (selectedTender ?? this.selectedTender),
      applications: applications ?? this.applications,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tenders,
        selectedTender,
        applications,
        isActing,
        errorMessage,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class ErpTendersBloc extends Bloc<ErpTendersEvent, ErpTendersState> {
  ErpTendersBloc({required TenderRepository tenderRepository})
      : _tenderRepository = tenderRepository,
        super(const ErpTendersState()) {
    on<ErpTendersListRequested>(_onListRequested);
    on<ErpTenderDetailRequested>(_onDetailRequested);
    on<ErpTenderCreated>(_onTenderCreated);
    on<ErpTenderUpdated>(_onTenderUpdated);
    on<ErpTenderDeleted>(_onTenderDeleted);
    on<ErpTenderApplicationsRequested>(_onApplicationsRequested);
    on<ErpTenderApplicationCreated>(_onApplicationCreated);
    on<ErpTenderApplicationStatusUpdated>(_onApplicationStatusUpdated);
    on<ErpTenderApplicationDeleted>(_onApplicationDeleted);
  }

  final TenderRepository _tenderRepository;

  Future<void> _onListRequested(
    ErpTendersListRequested event,
    Emitter<ErpTendersState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final tenders = await _tenderRepository.list(projectId: event.projectId);
      emit(state.copyWith(status: LoadStatus.success, tenders: tenders));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onDetailRequested(
    ErpTenderDetailRequested event,
    Emitter<ErpTendersState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final tender = await _tenderRepository.getById(event.id);
      emit(state.copyWith(status: LoadStatus.success, selectedTender: tender));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onTenderCreated(
    ErpTenderCreated event,
    Emitter<ErpTendersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final tender = await _tenderRepository.create(event.body);
      final updated = [tender, ...state.tenders];
      emit(state.copyWith(
        isActing: false,
        tenders: updated,
        actionMessage: 'Tender created successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onTenderUpdated(
    ErpTenderUpdated event,
    Emitter<ErpTendersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final tender = await _tenderRepository.update(event.id, event.body);
      final updated = state.tenders.map((t) => t.id == tender.id ? tender : t).toList();
      emit(state.copyWith(
        isActing: false,
        tenders: updated,
        selectedTender: tender,
        actionMessage: 'Tender updated successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onTenderDeleted(
    ErpTenderDeleted event,
    Emitter<ErpTendersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _tenderRepository.remove(event.id);
      final updated = state.tenders.where((t) => t.id != event.id).toList();
      emit(state.copyWith(
        isActing: false,
        tenders: updated,
        actionMessage: 'Tender deleted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onApplicationsRequested(
    ErpTenderApplicationsRequested event,
    Emitter<ErpTendersState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final apps = await _tenderRepository.listApplications(
        tenderId: event.tenderId,
        projectId: event.projectId,
        status: event.status,
      );
      emit(state.copyWith(status: LoadStatus.success, applications: apps));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onApplicationCreated(
    ErpTenderApplicationCreated event,
    Emitter<ErpTendersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final app = await _tenderRepository.createApplication(event.body);
      final updated = [app, ...state.applications];
      emit(state.copyWith(
        isActing: false,
        applications: updated,
        actionMessage: 'Tender application submitted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onApplicationStatusUpdated(
    ErpTenderApplicationStatusUpdated event,
    Emitter<ErpTendersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final app = await _tenderRepository.updateApplicationStatus(event.id, event.status);
      final updated = state.applications.map((a) => a.id == app.id ? app : a).toList();
      emit(state.copyWith(
        isActing: false,
        applications: updated,
        actionMessage: 'Application status updated to ${event.status}',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onApplicationDeleted(
    ErpTenderApplicationDeleted event,
    Emitter<ErpTendersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _tenderRepository.removeApplication(event.id);
      final updated = state.applications.where((a) => a.id != event.id).toList();
      emit(state.copyWith(
        isActing: false,
        applications: updated,
        actionMessage: 'Application removed successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
