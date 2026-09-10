import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class CrmSettingsEvent extends Equatable {
  const CrmSettingsEvent();

  @override
  List<Object?> get props => [];
}

class CrmSettingsLoadRequested extends CrmSettingsEvent {
  const CrmSettingsLoadRequested();
}

class CrmSettingsSaved extends CrmSettingsEvent {
  const CrmSettingsSaved(this.data);
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class CrmSettingsState extends Equatable {
  const CrmSettingsState({
    this.status = LoadStatus.initial,
    this.errorMessage,
    this.settings,
    this.kpiMetrics,
    this.isSaving = false,
    this.successMessage,
  });

  final LoadStatus status;
  final String? errorMessage;
  final CrmSettings? settings;
  final CrmKpiMetrics? kpiMetrics;
  final bool isSaving;
  final String? successMessage;

  CrmSettingsState copyWith({
    LoadStatus? status,
    String? errorMessage,
    CrmSettings? settings,
    CrmKpiMetrics? kpiMetrics,
    bool? isSaving,
    String? successMessage,
  }) {
    return CrmSettingsState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      settings: settings ?? this.settings,
      kpiMetrics: kpiMetrics ?? this.kpiMetrics,
      isSaving: isSaving ?? this.isSaving,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        errorMessage,
        settings,
        kpiMetrics,
        isSaving,
        successMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class CrmSettingsBloc extends Bloc<CrmSettingsEvent, CrmSettingsState> {
  CrmSettingsBloc({required CrmRepository crmRepository})
      : _crmRepository = crmRepository,
        super(const CrmSettingsState()) {
    on<CrmSettingsLoadRequested>(_onLoadRequested);
    on<CrmSettingsSaved>(_onSettingsSaved);
  }

  final CrmRepository _crmRepository;

  Future<void> _onLoadRequested(
    CrmSettingsLoadRequested event,
    Emitter<CrmSettingsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final results = await Future.wait([
        _crmRepository.getSettings(),
        _crmRepository.getKpiMetrics(),
      ]);
      final settings = results[0] as CrmSettings;
      final kpiMetrics = results[1] as CrmKpiMetrics;

      emit(state.copyWith(
        status: LoadStatus.success,
        settings: settings,
        kpiMetrics: kpiMetrics,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSettingsSaved(
    CrmSettingsSaved event,
    Emitter<CrmSettingsState> emit,
  ) async {
    emit(state.copyWith(isSaving: true));
    try {
      final updated = await _crmRepository.updateSettings(event.data);
      final kpiMetrics = await _crmRepository.getKpiMetrics();
      emit(state.copyWith(
        isSaving: false,
        settings: updated,
        kpiMetrics: kpiMetrics,
        successMessage: 'Settings updated successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      ));
    }
  }
}
