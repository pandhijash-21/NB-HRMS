import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/project_repository.dart';
import '../../domain/project_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class ErpProjectsEvent extends Equatable {
  const ErpProjectsEvent();

  @override
  List<Object?> get props => [];
}

class ErpProjectsLoadRequested extends ErpProjectsEvent {
  const ErpProjectsLoadRequested({this.includeInactive = false});
  final bool includeInactive;

  @override
  List<Object?> get props => [includeInactive];
}

class ErpProjectDetailRequested extends ErpProjectsEvent {
  const ErpProjectDetailRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpProjectNextNumberRequested extends ErpProjectsEvent {
  const ErpProjectNextNumberRequested();
}

class ErpProjectCreated extends ErpProjectsEvent {
  const ErpProjectCreated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

class ErpProjectUpdated extends ErpProjectsEvent {
  const ErpProjectUpdated({required this.id, required this.body});
  final String id;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [id, body];
}

class ErpProjectDeleted extends ErpProjectsEvent {
  const ErpProjectDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class ErpProjectsState extends Equatable {
  const ErpProjectsState({
    this.status = LoadStatus.initial,
    this.projects = const [],
    this.employees = const [],
    this.selectedProject,
    this.nextDisplayId,
    this.isActing = false,
    this.errorMessage,
    this.actionMessage,
  });

  final LoadStatus status;
  final List<ErpProject> projects;
  final List<ProjectEmployeeOption> employees;
  final ErpProject? selectedProject;
  final String? nextDisplayId;
  final bool isActing;
  final String? errorMessage;
  final String? actionMessage;

  ErpProjectsState copyWith({
    LoadStatus? status,
    List<ErpProject>? projects,
    List<ProjectEmployeeOption>? employees,
    ErpProject? selectedProject,
    bool clearSelectedProject = false,
    String? nextDisplayId,
    bool? isActing,
    String? errorMessage,
    String? actionMessage,
  }) {
    return ErpProjectsState(
      status: status ?? this.status,
      projects: projects ?? this.projects,
      employees: employees ?? this.employees,
      selectedProject: clearSelectedProject
          ? null
          : (selectedProject ?? this.selectedProject),
      nextDisplayId: nextDisplayId ?? this.nextDisplayId,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        projects,
        employees,
        selectedProject,
        nextDisplayId,
        isActing,
        errorMessage,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class ErpProjectsBloc extends Bloc<ErpProjectsEvent, ErpProjectsState> {
  ErpProjectsBloc({required ProjectRepository projectRepository})
      : _projectRepository = projectRepository,
        super(const ErpProjectsState()) {
    on<ErpProjectsLoadRequested>(_onLoadRequested);
    on<ErpProjectDetailRequested>(_onDetailRequested);
    on<ErpProjectNextNumberRequested>(_onNextNumberRequested);
    on<ErpProjectCreated>(_onProjectCreated);
    on<ErpProjectUpdated>(_onProjectUpdated);
    on<ErpProjectDeleted>(_onProjectDeleted);
  }

  final ProjectRepository _projectRepository;

  Future<void> _onLoadRequested(
    ErpProjectsLoadRequested event,
    Emitter<ErpProjectsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final results = await Future.wait([
        _projectRepository.list(includeInactive: event.includeInactive),
        _projectRepository.listEmployees(),
      ]);
      emit(state.copyWith(
        status: LoadStatus.success,
        projects: results[0] as List<ErpProject>,
        employees: results[1] as List<ProjectEmployeeOption>,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onDetailRequested(
    ErpProjectDetailRequested event,
    Emitter<ErpProjectsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final project = await _projectRepository.getById(event.id);
      emit(state.copyWith(
        status: LoadStatus.success,
        selectedProject: project,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onNextNumberRequested(
    ErpProjectNextNumberRequested event,
    Emitter<ErpProjectsState> emit,
  ) async {
    try {
      final next = await _projectRepository.nextNumber();
      emit(state.copyWith(nextDisplayId: next.displayId));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onProjectCreated(
    ErpProjectCreated event,
    Emitter<ErpProjectsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final project = await _projectRepository.create(event.body);
      final updatedList = [project, ...state.projects];
      emit(state.copyWith(
        isActing: false,
        projects: updatedList,
        actionMessage: 'Project created successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onProjectUpdated(
    ErpProjectUpdated event,
    Emitter<ErpProjectsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final project = await _projectRepository.update(event.id, event.body);
      final updatedList = state.projects.map((p) => p.id == project.id ? project : p).toList();
      emit(state.copyWith(
        isActing: false,
        projects: updatedList,
        selectedProject: project,
        actionMessage: 'Project updated successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onProjectDeleted(
    ErpProjectDeleted event,
    Emitter<ErpProjectsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _projectRepository.remove(event.id);
      final updatedList = state.projects.where((p) => p.id != event.id).toList();
      emit(state.copyWith(
        isActing: false,
        projects: updatedList,
        actionMessage: 'Project deleted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
