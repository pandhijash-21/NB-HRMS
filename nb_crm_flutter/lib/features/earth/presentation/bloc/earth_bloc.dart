import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/earth_repository.dart';
import '../../domain/earth_models.dart';

abstract class EarthEvent extends Equatable {
  const EarthEvent();
  @override
  List<Object?> get props => [];
}

class EarthLoadRequested extends EarthEvent {
  const EarthLoadRequested();
}

class EarthRefreshRequested extends EarthEvent {
  const EarthRefreshRequested();
}

class EarthFilterChanged extends EarthEvent {
  const EarthFilterChanged({this.kind, this.status, this.query});
  final String? kind;
  final String? status;
  final String? query;
  @override
  List<Object?> get props => [kind, status, query];
}

class EarthPropertySaved extends EarthEvent {
  const EarthPropertySaved(this.property);
  final EarthProperty property;
  @override
  List<Object?> get props => [property.id, property.updatedAt];
}

class EarthPropertyRemoved extends EarthEvent {
  const EarthPropertyRemoved(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class EarthSelectProperty extends EarthEvent {
  const EarthSelectProperty(this.id);
  final String? id;
  @override
  List<Object?> get props => [id];
}

class EarthState extends Equatable {
  const EarthState({
    this.status = LoadStatus.initial,
    this.properties = const [],
    this.selectedId,
    this.kindFilter,
    this.statusFilter,
    this.query,
    this.errorMessage,
  });

  final LoadStatus status;
  final List<EarthProperty> properties;
  final String? selectedId;
  final String? kindFilter;
  final String? statusFilter;
  final String? query;
  final String? errorMessage;

  EarthProperty? get selected {
    if (selectedId == null) return null;
    for (final p in properties) {
      if (p.id == selectedId) return p;
    }
    return null;
  }

  EarthState copyWith({
    LoadStatus? status,
    List<EarthProperty>? properties,
    String? selectedId,
    bool clearSelected = false,
    String? kindFilter,
    bool clearKind = false,
    String? statusFilter,
    bool clearStatus = false,
    String? query,
    bool clearQuery = false,
    String? errorMessage,
  }) {
    return EarthState(
      status: status ?? this.status,
      properties: properties ?? this.properties,
      selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
      kindFilter: clearKind ? null : (kindFilter ?? this.kindFilter),
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      query: clearQuery ? null : (query ?? this.query),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        properties,
        selectedId,
        kindFilter,
        statusFilter,
        query,
        errorMessage,
      ];
}

class EarthBloc extends Bloc<EarthEvent, EarthState> {
  EarthBloc({required EarthRepository repository})
      : _repo = repository,
        super(const EarthState()) {
    on<EarthLoadRequested>(_onLoad);
    on<EarthRefreshRequested>(_onLoad);
    on<EarthFilterChanged>(_onFilter);
    on<EarthPropertySaved>(_onSaved);
    on<EarthPropertyRemoved>(_onRemoved);
    on<EarthSelectProperty>(_onSelect);
  }

  final EarthRepository _repo;

  Future<void> _onLoad(EarthEvent event, Emitter<EarthState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, errorMessage: null));
    try {
      final list = await _repo.list(
        kind: state.kindFilter,
        status: state.statusFilter,
        q: state.query,
      );
      emit(state.copyWith(status: LoadStatus.success, properties: list));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onFilter(EarthFilterChanged event, Emitter<EarthState> emit) async {
    emit(state.copyWith(
      kindFilter: event.kind,
      clearKind: event.kind == null || event.kind!.isEmpty,
      statusFilter: event.status,
      clearStatus: event.status == null || event.status!.isEmpty,
      query: event.query,
      clearQuery: event.query == null || event.query!.isEmpty,
    ));
    add(const EarthLoadRequested());
  }

  void _onSaved(EarthPropertySaved event, Emitter<EarthState> emit) {
    final next = [...state.properties];
    final i = next.indexWhere((p) => p.id == event.property.id);
    if (i >= 0) {
      next[i] = event.property;
    } else {
      next.insert(0, event.property);
    }
    emit(state.copyWith(
      properties: next,
      selectedId: event.property.id,
      status: LoadStatus.success,
    ));
  }

  void _onRemoved(EarthPropertyRemoved event, Emitter<EarthState> emit) {
    emit(state.copyWith(
      properties: state.properties.where((p) => p.id != event.id).toList(),
      clearSelected: state.selectedId == event.id,
    ));
  }

  void _onSelect(EarthSelectProperty event, Emitter<EarthState> emit) {
    emit(state.copyWith(selectedId: event.id, clearSelected: event.id == null));
  }
}
