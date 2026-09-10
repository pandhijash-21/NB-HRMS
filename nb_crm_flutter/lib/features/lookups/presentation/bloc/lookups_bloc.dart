import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/lookup_repository.dart';
import '../../domain/lookup_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class LookupsEvent extends Equatable {
  const LookupsEvent();

  @override
  List<Object?> get props => [];
}

class LookupsLoadRequested extends LookupsEvent {
  const LookupsLoadRequested({this.includeInactive = true});
  final bool includeInactive;

  @override
  List<Object?> get props => [includeInactive];
}

class LookupOptionCreated extends LookupsEvent {
  const LookupOptionCreated({
    required this.category,
    required this.code,
    required this.label,
  });

  final String category;
  final String code;
  final String label;

  @override
  List<Object?> get props => [category, code, label];
}

class LookupOptionUpdated extends LookupsEvent {
  const LookupOptionUpdated({
    required this.id,
    required this.category,
    this.label,
    this.isActive,
    this.sortOrder,
  });

  final String id;
  final String category;
  final String? label;
  final bool? isActive;
  final int? sortOrder;

  @override
  List<Object?> get props => [id, category, label, isActive, sortOrder];
}

class LookupOptionDeleted extends LookupsEvent {
  const LookupOptionDeleted({
    required this.id,
    required this.category,
  });

  final String id;
  final String category;

  @override
  List<Object?> get props => [id, category];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class LookupsState extends Equatable {
  const LookupsState({
    this.status = LoadStatus.initial,
    this.groups = const [],
    this.isActing = false,
    this.errorMessage,
    this.actionMessage,
  });

  final LoadStatus status;
  final List<LookupCategoryGroup> groups;
  final bool isActing;
  final String? errorMessage;
  final String? actionMessage;

  LookupsState copyWith({
    LoadStatus? status,
    List<LookupCategoryGroup>? groups,
    bool? isActing,
    String? errorMessage,
    String? actionMessage,
  }) {
    return LookupsState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  LookupCategoryGroup? groupForCategory(String category) {
    for (final g in groups) {
      if (g.key == category) return g;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        status,
        groups,
        isActing,
        errorMessage,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class LookupsBloc extends Bloc<LookupsEvent, LookupsState> {
  LookupsBloc({required LookupRepository lookupRepository})
      : _lookupRepository = lookupRepository,
        super(const LookupsState()) {
    on<LookupsLoadRequested>(_onLoadRequested);
    on<LookupOptionCreated>(_onOptionCreated);
    on<LookupOptionUpdated>(_onOptionUpdated);
    on<LookupOptionDeleted>(_onOptionDeleted);
  }

  final LookupRepository _lookupRepository;

  Future<void> _onLoadRequested(
    LookupsLoadRequested event,
    Emitter<LookupsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, errorMessage: null));
    try {
      final groups = await _lookupRepository.listGrouped(
        includeInactive: event.includeInactive,
      );
      emit(state.copyWith(
        status: LoadStatus.success,
        groups: groups,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onOptionCreated(
    LookupOptionCreated event,
    Emitter<LookupsState> emit,
  ) async {
    emit(state.copyWith(isActing: true, errorMessage: null, actionMessage: null));
    try {
      await _lookupRepository.create(
        category: event.category,
        code: event.code,
        label: event.label,
      );
      final groups = await _lookupRepository.listGrouped(includeInactive: true);
      emit(state.copyWith(
        isActing: false,
        groups: groups,
        actionMessage: 'Option added',
      ));
    } catch (e) {
      emit(state.copyWith(
        isActing: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onOptionUpdated(
    LookupOptionUpdated event,
    Emitter<LookupsState> emit,
  ) async {
    emit(state.copyWith(isActing: true, errorMessage: null, actionMessage: null));
    try {
      await _lookupRepository.update(
        event.id,
        label: event.label,
        isActive: event.isActive,
        sortOrder: event.sortOrder,
      );
      final groups = await _lookupRepository.listGrouped(includeInactive: true);
      emit(state.copyWith(
        isActing: false,
        groups: groups,
        actionMessage: 'Option updated',
      ));
    } catch (e) {
      emit(state.copyWith(
        isActing: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onOptionDeleted(
    LookupOptionDeleted event,
    Emitter<LookupsState> emit,
  ) async {
    emit(state.copyWith(isActing: true, errorMessage: null, actionMessage: null));
    try {
      await _lookupRepository.delete(event.id);
      final groups = await _lookupRepository.listGrouped(includeInactive: true);
      emit(state.copyWith(
        isActing: false,
        groups: groups,
        actionMessage: 'Option deleted',
      ));
    } catch (e) {
      emit(state.copyWith(
        isActing: false,
        errorMessage: e.toString(),
      ));
    }
  }
}
