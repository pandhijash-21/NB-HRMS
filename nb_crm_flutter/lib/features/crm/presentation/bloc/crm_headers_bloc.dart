import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class CrmHeadersEvent extends Equatable {
  const CrmHeadersEvent();

  @override
  List<Object?> get props => [];
}

class CrmHeadersLoadRequested extends CrmHeadersEvent {
  const CrmHeadersLoadRequested();
}

class CrmHeadersProjectSelected extends CrmHeadersEvent {
  const CrmHeadersProjectSelected(this.project);
  final CrmProject? project;

  @override
  List<Object?> get props => [project];
}

class CrmHeadersCampaignSelected extends CrmHeadersEvent {
  const CrmHeadersCampaignSelected(this.campaignId);
  final String? campaignId;

  @override
  List<Object?> get props => [campaignId];
}

class CrmHeadersProjectCreated extends CrmHeadersEvent {
  const CrmHeadersProjectCreated(this.data);
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}

class CrmHeadersProjectUpdated extends CrmHeadersEvent {
  const CrmHeadersProjectUpdated(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [id, data];
}

class CrmHeadersProjectDeleted extends CrmHeadersEvent {
  const CrmHeadersProjectDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class CrmHeadersCampaignCreated extends CrmHeadersEvent {
  const CrmHeadersCampaignCreated(this.data);
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}

class CrmHeadersCampaignUpdated extends CrmHeadersEvent {
  const CrmHeadersCampaignUpdated(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [id, data];
}

class CrmHeadersCampaignDeleted extends CrmHeadersEvent {
  const CrmHeadersCampaignDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class CrmHeadersColumnCreated extends CrmHeadersEvent {
  const CrmHeadersColumnCreated(this.data);
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}

class CrmHeadersColumnDeleted extends CrmHeadersEvent {
  const CrmHeadersColumnDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class CrmHeadersColumnVisibilityToggled extends CrmHeadersEvent {
  const CrmHeadersColumnVisibilityToggled(this.id, this.isVisible);
  final String id;
  final bool isVisible;

  @override
  List<Object?> get props => [id, isVisible];
}

class CrmHeadersColumnsMerged extends CrmHeadersEvent {
  const CrmHeadersColumnsMerged({
    required this.sourceKey,
    required this.targetKey,
    this.targetLabel,
  });

  final String sourceKey;
  final String targetKey;
  final String? targetLabel;

  @override
  List<Object?> get props => [sourceKey, targetKey, targetLabel];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class CrmHeadersState extends Equatable {
  const CrmHeadersState({
    this.status = LoadStatus.initial,
    this.errorMessage,
    this.projects = const [],
    this.selectedProject,
    this.campaigns = const [],
    this.selectedCampaignId,
    this.columns = const [],
    this.isActing = false,
    this.actionMessage,
  });

  final LoadStatus status;
  final String? errorMessage;
  final List<CrmProject> projects;
  final CrmProject? selectedProject;
  final List<CrmCampaign> campaigns;
  final String? selectedCampaignId;
  final List<CrmColumnConfig> columns;
  final bool isActing;
  final String? actionMessage;

  CrmHeadersState copyWith({
    LoadStatus? status,
    String? errorMessage,
    List<CrmProject>? projects,
    CrmProject? selectedProject,
    bool clearSelectedProject = false,
    List<CrmCampaign>? campaigns,
    String? selectedCampaignId,
    bool clearSelectedCampaignId = false,
    List<CrmColumnConfig>? columns,
    bool? isActing,
    String? actionMessage,
  }) {
    return CrmHeadersState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      projects: projects ?? this.projects,
      selectedProject: clearSelectedProject
          ? null
          : (selectedProject ?? this.selectedProject),
      campaigns: campaigns ?? this.campaigns,
      selectedCampaignId: clearSelectedCampaignId
          ? null
          : (selectedCampaignId ?? this.selectedCampaignId),
      columns: columns ?? this.columns,
      isActing: isActing ?? this.isActing,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        errorMessage,
        projects,
        selectedProject,
        campaigns,
        selectedCampaignId,
        columns,
        isActing,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class CrmHeadersBloc extends Bloc<CrmHeadersEvent, CrmHeadersState> {
  CrmHeadersBloc({required CrmRepository crmRepository})
      : _crmRepository = crmRepository,
        super(const CrmHeadersState()) {
    on<CrmHeadersLoadRequested>(_onLoadRequested);
    on<CrmHeadersProjectSelected>(_onProjectSelected);
    on<CrmHeadersCampaignSelected>(_onCampaignSelected);
    on<CrmHeadersProjectCreated>(_onProjectCreated);
    on<CrmHeadersProjectUpdated>(_onProjectUpdated);
    on<CrmHeadersProjectDeleted>(_onProjectDeleted);
    on<CrmHeadersCampaignCreated>(_onCampaignCreated);
    on<CrmHeadersCampaignUpdated>(_onCampaignUpdated);
    on<CrmHeadersCampaignDeleted>(_onCampaignDeleted);
    on<CrmHeadersColumnCreated>(_onColumnCreated);
    on<CrmHeadersColumnDeleted>(_onColumnDeleted);
    on<CrmHeadersColumnVisibilityToggled>(_onColumnVisibilityToggled);
    on<CrmHeadersColumnsMerged>(_onColumnsMerged);
  }

  final CrmRepository _crmRepository;

  Future<void> _onLoadRequested(
    CrmHeadersLoadRequested event,
    Emitter<CrmHeadersState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final projects = await _crmRepository.getProjects();
      List<CrmCampaign> campaigns = const [];
      List<CrmColumnConfig> columns = const [];

      if (state.selectedProject != null) {
        campaigns = await _crmRepository.getCampaigns(projectId: state.selectedProject!.id);
        final effCampId = state.selectedCampaignId ??
            (campaigns.isNotEmpty ? campaigns.first.id : null);
        if (effCampId != null) {
          columns = await _crmRepository.getColumns(campaignId: effCampId);
        }
      }

      emit(state.copyWith(
        status: LoadStatus.success,
        projects: projects,
        campaigns: campaigns,
        columns: columns,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onProjectSelected(
    CrmHeadersProjectSelected event,
    Emitter<CrmHeadersState> emit,
  ) async {
    if (event.project == null) {
      emit(state.copyWith(
        clearSelectedProject: true,
        clearSelectedCampaignId: true,
        campaigns: const [],
        columns: const [],
      ));
      return;
    }

    emit(state.copyWith(
      status: LoadStatus.loading,
      selectedProject: event.project,
    ));

    try {
      final campaigns = await _crmRepository.getCampaigns(projectId: event.project!.id);
      final effCampId = campaigns.isNotEmpty ? campaigns.first.id : null;
      List<CrmColumnConfig> columns = const [];
      if (effCampId != null) {
        columns = await _crmRepository.getColumns(campaignId: effCampId);
      }

      emit(state.copyWith(
        status: LoadStatus.success,
        campaigns: campaigns,
        selectedCampaignId: effCampId,
        columns: columns,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCampaignSelected(
    CrmHeadersCampaignSelected event,
    Emitter<CrmHeadersState> emit,
  ) async {
    emit(state.copyWith(
      selectedCampaignId: event.campaignId,
      status: LoadStatus.loading,
    ));
    try {
      final columns = await _crmRepository.getColumns(campaignId: event.campaignId);
      emit(state.copyWith(
        status: LoadStatus.success,
        columns: columns,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onProjectCreated(
    CrmHeadersProjectCreated event,
    Emitter<CrmHeadersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.createProject(event.data);
      emit(state.copyWith(isActing: false, actionMessage: 'Project created successfully'));
      final projects = await _crmRepository.getProjects();
      emit(state.copyWith(projects: projects));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onProjectUpdated(
    CrmHeadersProjectUpdated event,
    Emitter<CrmHeadersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.updateProject(event.id, event.data);
      emit(state.copyWith(isActing: false, actionMessage: 'Project updated successfully'));
      final projects = await _crmRepository.getProjects();
      emit(state.copyWith(projects: projects));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onProjectDeleted(
    CrmHeadersProjectDeleted event,
    Emitter<CrmHeadersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.deleteProject(event.id);
      emit(state.copyWith(isActing: false, actionMessage: 'Project deleted successfully'));
      final projects = await _crmRepository.getProjects();
      emit(state.copyWith(projects: projects));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onCampaignCreated(
    CrmHeadersCampaignCreated event,
    Emitter<CrmHeadersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final created = await _crmRepository.createCampaign(event.data);
      emit(state.copyWith(
        isActing: false,
        actionMessage: 'Campaign created successfully',
        selectedCampaignId: created.id,
      ));
      if (state.selectedProject != null) {
        final campaigns = await _crmRepository.getCampaigns(projectId: state.selectedProject!.id);
        final columns = await _crmRepository.getColumns(campaignId: created.id);
        emit(state.copyWith(campaigns: campaigns, columns: columns));
      }
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onCampaignUpdated(
    CrmHeadersCampaignUpdated event,
    Emitter<CrmHeadersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.updateCampaign(event.id, event.data);
      emit(state.copyWith(isActing: false, actionMessage: 'Campaign updated successfully'));
      if (state.selectedProject != null) {
        final campaigns = await _crmRepository.getCampaigns(projectId: state.selectedProject!.id);
        emit(state.copyWith(campaigns: campaigns));
      }
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onCampaignDeleted(
    CrmHeadersCampaignDeleted event,
    Emitter<CrmHeadersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.deleteCampaign(event.id);
      emit(state.copyWith(isActing: false, actionMessage: 'Campaign deleted successfully'));
      if (state.selectedProject != null) {
        final campaigns = await _crmRepository.getCampaigns(projectId: state.selectedProject!.id);
        final effCampId = campaigns.isNotEmpty ? campaigns.first.id : null;
        List<CrmColumnConfig> columns = const [];
        if (effCampId != null) {
          columns = await _crmRepository.getColumns(campaignId: effCampId);
        }
        emit(state.copyWith(
          campaigns: campaigns,
          selectedCampaignId: effCampId,
          clearSelectedCampaignId: effCampId == null,
          columns: columns,
        ));
      }
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onColumnCreated(
    CrmHeadersColumnCreated event,
    Emitter<CrmHeadersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.createColumn(event.data);
      emit(state.copyWith(isActing: false, actionMessage: 'Column created successfully'));
      if (state.selectedCampaignId != null) {
        final columns = await _crmRepository.getColumns(campaignId: state.selectedCampaignId);
        emit(state.copyWith(columns: columns));
      }
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onColumnDeleted(
    CrmHeadersColumnDeleted event,
    Emitter<CrmHeadersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.deleteColumn(event.id);
      emit(state.copyWith(isActing: false, actionMessage: 'Column deleted successfully'));
      if (state.selectedCampaignId != null) {
        final columns = await _crmRepository.getColumns(campaignId: state.selectedCampaignId);
        emit(state.copyWith(columns: columns));
      }
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onColumnVisibilityToggled(
    CrmHeadersColumnVisibilityToggled event,
    Emitter<CrmHeadersState> emit,
  ) async {
    try {
      await _crmRepository.toggleColumnVisibility(event.id, event.isVisible);
      if (state.selectedCampaignId != null) {
        final columns = await _crmRepository.getColumns(campaignId: state.selectedCampaignId);
        emit(state.copyWith(columns: columns));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onColumnsMerged(
    CrmHeadersColumnsMerged event,
    Emitter<CrmHeadersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final res = await _crmRepository.mergeColumns(
        campaignId: state.selectedCampaignId,
        sourceKey: event.sourceKey,
        targetKey: event.targetKey,
        targetLabel: event.targetLabel,
      );
      emit(state.copyWith(
        isActing: false,
        actionMessage: res['message']?.toString() ?? 'Columns merged successfully!',
      ));
      if (state.selectedCampaignId != null) {
        final columns = await _crmRepository.getColumns(campaignId: state.selectedCampaignId);
        emit(state.copyWith(columns: columns));
      }
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
