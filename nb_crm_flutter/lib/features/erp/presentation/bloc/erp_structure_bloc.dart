import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/project_repository.dart';
import '../../domain/project_models.dart';
import '../../domain/structure_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class ErpStructureEvent extends Equatable {
  const ErpStructureEvent();

  @override
  List<Object?> get props => [];
}

class ErpStructureTowersRequested extends ErpStructureEvent {
  const ErpStructureTowersRequested(this.projectId);
  final String projectId;

  @override
  List<Object?> get props => [projectId];
}

class ErpStructureTowerDetailRequested extends ErpStructureEvent {
  const ErpStructureTowerDetailRequested({
    required this.projectId,
    required this.towerId,
  });

  final String projectId;
  final String towerId;

  @override
  List<Object?> get props => [projectId, towerId];
}

class ErpStructureTowerSelected extends ErpStructureEvent {
  const ErpStructureTowerSelected(this.tower);
  final ErpProjectTower? tower;

  @override
  List<Object?> get props => [tower];
}

class ErpStructureTowerCreated extends ErpStructureEvent {
  const ErpStructureTowerCreated({
    required this.projectId,
    required this.body,
  });

  final String projectId;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [projectId, body];
}

class ErpStructureTowerUpdated extends ErpStructureEvent {
  const ErpStructureTowerUpdated({
    required this.projectId,
    required this.towerId,
    required this.body,
  });

  final String projectId;
  final String towerId;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [projectId, towerId, body];
}

class ErpStructureTowerDeleted extends ErpStructureEvent {
  const ErpStructureTowerDeleted({
    required this.projectId,
    required this.towerId,
  });

  final String projectId;
  final String towerId;

  @override
  List<Object?> get props => [projectId, towerId];
}

class ErpStructureUnitsRegenerated extends ErpStructureEvent {
  const ErpStructureUnitsRegenerated({
    required this.projectId,
    required this.towerId,
  });

  final String projectId;
  final String towerId;

  @override
  List<Object?> get props => [projectId, towerId];
}

class ErpStructureUnitUpdated extends ErpStructureEvent {
  const ErpStructureUnitUpdated({
    required this.projectId,
    required this.towerId,
    required this.unitId,
    required this.body,
  });

  final String projectId;
  final String towerId;
  final String unitId;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [projectId, towerId, unitId, body];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class ErpStructureState extends Equatable {
  const ErpStructureState({
    this.status = LoadStatus.initial,
    this.projectId,
    this.project,
    this.towers = const [],
    this.selectedTower,
    this.isActing = false,
    this.errorMessage,
    this.actionMessage,
  });

  final LoadStatus status;
  final String? projectId;
  final ErpProject? project;
  final List<ErpProjectTower> towers;
  final ErpProjectTower? selectedTower;
  final bool isActing;
  final String? errorMessage;
  final String? actionMessage;

  ErpStructureState copyWith({
    LoadStatus? status,
    String? projectId,
    ErpProject? project,
    List<ErpProjectTower>? towers,
    ErpProjectTower? selectedTower,
    bool clearSelectedTower = false,
    bool? isActing,
    String? errorMessage,
    String? actionMessage,
  }) {
    return ErpStructureState(
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      project: project ?? this.project,
      towers: towers ?? this.towers,
      selectedTower: clearSelectedTower
          ? null
          : (selectedTower ?? this.selectedTower),
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        projectId,
        project,
        towers,
        selectedTower,
        isActing,
        errorMessage,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class ErpStructureBloc extends Bloc<ErpStructureEvent, ErpStructureState> {
  ErpStructureBloc({required ProjectRepository projectRepository})
      : _projectRepository = projectRepository,
        super(const ErpStructureState()) {
    on<ErpStructureTowersRequested>(_onTowersRequested);
    on<ErpStructureTowerDetailRequested>(_onTowerDetailRequested);
    on<ErpStructureTowerSelected>(_onTowerSelected);
    on<ErpStructureTowerCreated>(_onTowerCreated);
    on<ErpStructureTowerUpdated>(_onTowerUpdated);
    on<ErpStructureTowerDeleted>(_onTowerDeleted);
    on<ErpStructureUnitsRegenerated>(_onUnitsRegenerated);
    on<ErpStructureUnitUpdated>(_onUnitUpdated);
  }

  final ProjectRepository _projectRepository;

  Future<void> _onTowerDetailRequested(
    ErpStructureTowerDetailRequested event,
    Emitter<ErpStructureState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, projectId: event.projectId));
    try {
      final tower = await _projectRepository.getTower(event.projectId, event.towerId);
      emit(state.copyWith(
        status: LoadStatus.success,
        selectedTower: tower,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onTowersRequested(
    ErpStructureTowersRequested event,
    Emitter<ErpStructureState> emit,
  ) async {
    emit(state.copyWith(
      status: LoadStatus.loading,
      projectId: event.projectId,
    ));
    try {
      final towers = await _projectRepository.listTowers(event.projectId);
      ErpProject? project;
      try {
        project = await _projectRepository.getById(event.projectId);
      } catch (_) {}
      emit(state.copyWith(
        status: LoadStatus.success,
        towers: towers,
        project: project,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onTowerSelected(
    ErpStructureTowerSelected event,
    Emitter<ErpStructureState> emit,
  ) {
    emit(state.copyWith(
      selectedTower: event.tower,
      clearSelectedTower: event.tower == null,
    ));
  }

  Future<void> _onTowerCreated(
    ErpStructureTowerCreated event,
    Emitter<ErpStructureState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final tower = await _projectRepository.createTower(event.projectId, event.body);
      final updatedList = [...state.towers, tower];
      emit(state.copyWith(
        isActing: false,
        towers: updatedList,
        actionMessage: 'Tower created successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onTowerUpdated(
    ErpStructureTowerUpdated event,
    Emitter<ErpStructureState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final tower = await _projectRepository.updateTower(
        event.projectId,
        event.towerId,
        event.body,
      );
      final updatedList = state.towers.map((t) => t.id == tower.id ? tower : t).toList();
      emit(state.copyWith(
        isActing: false,
        towers: updatedList,
        selectedTower: state.selectedTower?.id == tower.id ? tower : state.selectedTower,
        actionMessage: 'Tower updated successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onTowerDeleted(
    ErpStructureTowerDeleted event,
    Emitter<ErpStructureState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _projectRepository.deleteTower(event.projectId, event.towerId);
      final updatedList = state.towers.where((t) => t.id != event.towerId).toList();
      emit(state.copyWith(
        isActing: false,
        towers: updatedList,
        clearSelectedTower: state.selectedTower?.id == event.towerId,
        actionMessage: 'Tower deleted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onUnitsRegenerated(
    ErpStructureUnitsRegenerated event,
    Emitter<ErpStructureState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final tower = await _projectRepository.regenerateUnits(event.projectId, event.towerId);
      final updatedList = state.towers.map((t) => t.id == tower.id ? tower : t).toList();
      emit(state.copyWith(
        isActing: false,
        towers: updatedList,
        selectedTower: tower,
        actionMessage: 'Units regenerated successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onUnitUpdated(
    ErpStructureUnitUpdated event,
    Emitter<ErpStructureState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _projectRepository.updateUnit(
        projectId: event.projectId,
        towerId: event.towerId,
        unitId: event.unitId,
        body: event.body,
      );
      // Reload tower
      final tower = await _projectRepository.getTower(event.projectId, event.towerId);
      final updatedList = state.towers.map((t) => t.id == tower.id ? tower : t).toList();
      emit(state.copyWith(
        isActing: false,
        towers: updatedList,
        selectedTower: tower,
        actionMessage: 'Unit updated successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
