import 'dart:typed_data';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class CrmLeadsEvent extends Equatable {
  const CrmLeadsEvent();

  @override
  List<Object?> get props => [];
}

class CrmLeadsLoadRequested extends CrmLeadsEvent {
  const CrmLeadsLoadRequested();
}

class CrmLeadsRefreshRequested extends CrmLeadsEvent {
  const CrmLeadsRefreshRequested();
}

class CrmLeadsProjectSelected extends CrmLeadsEvent {
  const CrmLeadsProjectSelected(this.projectId);
  final String? projectId;

  @override
  List<Object?> get props => [projectId];
}

class CrmLeadsCampaignSelected extends CrmLeadsEvent {
  const CrmLeadsCampaignSelected(this.campaignId);
  final String? campaignId;

  @override
  List<Object?> get props => [campaignId];
}

class CrmLeadsStatusFilterChanged extends CrmLeadsEvent {
  const CrmLeadsStatusFilterChanged(this.status);
  final String status;

  @override
  List<Object?> get props => [status];
}

class CrmLeadsSearchChanged extends CrmLeadsEvent {
  const CrmLeadsSearchChanged(this.search);
  final String search;

  @override
  List<Object?> get props => [search];
}

class CrmLeadsLeadCreated extends CrmLeadsEvent {
  const CrmLeadsLeadCreated(this.data);
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}

class CrmLeadsLeadUpdated extends CrmLeadsEvent {
  const CrmLeadsLeadUpdated(this.leadId, this.data);
  final String leadId;
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [leadId, data];
}

class CrmLeadsLeadStatusUpdated extends CrmLeadsEvent {
  const CrmLeadsLeadStatusUpdated(
    this.leadId, {
    required this.status,
    this.scheduledDate,
    this.scheduledTime,
    this.remarks,
    this.assignedToId,
  });

  final String leadId;
  final String status;
  final String? scheduledDate;
  final String? scheduledTime;
  final String? remarks;
  final int? assignedToId;

  @override
  List<Object?> get props => [
        leadId,
        status,
        scheduledDate,
        scheduledTime,
        remarks,
        assignedToId,
      ];
}

class CrmLeadsLeadMovedToBin extends CrmLeadsEvent {
  const CrmLeadsLeadMovedToBin(this.leadId);
  final String leadId;

  @override
  List<Object?> get props => [leadId];
}

class CrmLeadsExcelImported extends CrmLeadsEvent {
  const CrmLeadsExcelImported(this.fileBytes, this.fileName);
  final Uint8List fileBytes;
  final String fileName;

  @override
  List<Object?> get props => [fileBytes, fileName];
}

class CrmLeadsFollowUpFilterChanged extends CrmLeadsEvent {
  const CrmLeadsFollowUpFilterChanged(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
}

class CrmLeadsFollowUpScheduled extends CrmLeadsEvent {
  const CrmLeadsFollowUpScheduled(this.data);
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [data];
}

class CrmLeadsFollowUpCompleted extends CrmLeadsEvent {
  const CrmLeadsFollowUpCompleted(this.id, {this.remarks});
  final String id;
  final String? remarks;

  @override
  List<Object?> get props => [id, remarks];
}

class CrmLeadsCallLogsFilterChanged extends CrmLeadsEvent {
  const CrmLeadsCallLogsFilterChanged({
    this.search,
    this.dateFilter,
    this.callStatus,
    this.hasRecording,
  });

  final String? search;
  final String? dateFilter;
  final String? callStatus;
  final bool? hasRecording;

  @override
  List<Object?> get props => [search, dateFilter, callStatus, hasRecording];
}

class CrmLeadsClickToCallRequested extends CrmLeadsEvent {
  const CrmLeadsClickToCallRequested(this.leadId, {this.agentId});
  final String leadId;
  final String? agentId;

  @override
  List<Object?> get props => [leadId, agentId];
}

class CrmLeadsColumnVisibilityToggled extends CrmLeadsEvent {
  const CrmLeadsColumnVisibilityToggled(this.columnId, this.isVisible);
  final String columnId;
  final bool isVisible;

  @override
  List<Object?> get props => [columnId, isVisible];
}

class CrmLeadsColumnsMerged extends CrmLeadsEvent {
  const CrmLeadsColumnsMerged({
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
class CrmLeadsState extends Equatable {
  const CrmLeadsState({
    this.status = LoadStatus.initial,
    this.projects = const [],
    this.selectedProjectId,
    this.campaigns = const [],
    this.selectedCampaignId,
    this.columns = const [],
    this.leads = const [],
    this.statusFilter = 'ALL',
    this.search = '',
    this.salesUsers = const [],
    this.followUps = const [],
    this.followUpFilter = 'today',
    this.callLogs = const [],
    this.callRecordingFilterDate = 'all',
    this.callRecordingFilterStatus = 'ALL',
    this.callRecordingSearch = '',
    this.callRecordingsOnlyWithAudio = false,
    this.isActing = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  final LoadStatus status;
  final List<CrmProject> projects;
  final String? selectedProjectId;
  final List<CrmCampaign> campaigns;
  final String? selectedCampaignId;
  final List<CrmColumnConfig> columns;
  final List<CrmLead> leads;
  final String statusFilter;
  final String search;
  final List<CrmSalesUser> salesUsers;
  final List<CrmFollowUp> followUps;
  final String followUpFilter;
  final List<CrmCallLog> callLogs;
  final String callRecordingFilterDate;
  final String callRecordingFilterStatus;
  final String callRecordingSearch;
  final bool callRecordingsOnlyWithAudio;
  final bool isActing;
  final String? errorMessage;
  final String? actionSuccessMessage;

  CrmLeadsState copyWith({
    LoadStatus? status,
    List<CrmProject>? projects,
    String? selectedProjectId,
    bool clearSelectedProject = false,
    List<CrmCampaign>? campaigns,
    String? selectedCampaignId,
    bool clearSelectedCampaign = false,
    List<CrmColumnConfig>? columns,
    List<CrmLead>? leads,
    String? statusFilter,
    String? search,
    List<CrmSalesUser>? salesUsers,
    List<CrmFollowUp>? followUps,
    String? followUpFilter,
    List<CrmCallLog>? callLogs,
    String? callRecordingFilterDate,
    String? callRecordingFilterStatus,
    String? callRecordingSearch,
    bool? callRecordingsOnlyWithAudio,
    bool? isActing,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return CrmLeadsState(
      status: status ?? this.status,
      projects: projects ?? this.projects,
      selectedProjectId: clearSelectedProject
          ? null
          : (selectedProjectId ?? this.selectedProjectId),
      campaigns: campaigns ?? this.campaigns,
      selectedCampaignId: clearSelectedCampaign
          ? null
          : (selectedCampaignId ?? this.selectedCampaignId),
      columns: columns ?? this.columns,
      leads: leads ?? this.leads,
      statusFilter: statusFilter ?? this.statusFilter,
      search: search ?? this.search,
      salesUsers: salesUsers ?? this.salesUsers,
      followUps: followUps ?? this.followUps,
      followUpFilter: followUpFilter ?? this.followUpFilter,
      callLogs: callLogs ?? this.callLogs,
      callRecordingFilterDate:
          callRecordingFilterDate ?? this.callRecordingFilterDate,
      callRecordingFilterStatus:
          callRecordingFilterStatus ?? this.callRecordingFilterStatus,
      callRecordingSearch: callRecordingSearch ?? this.callRecordingSearch,
      callRecordingsOnlyWithAudio:
          callRecordingsOnlyWithAudio ?? this.callRecordingsOnlyWithAudio,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        projects,
        selectedProjectId,
        campaigns,
        selectedCampaignId,
        columns,
        leads,
        statusFilter,
        search,
        salesUsers,
        followUps,
        followUpFilter,
        callLogs,
        callRecordingFilterDate,
        callRecordingFilterStatus,
        callRecordingSearch,
        callRecordingsOnlyWithAudio,
        isActing,
        errorMessage,
        actionSuccessMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class CrmLeadsBloc extends Bloc<CrmLeadsEvent, CrmLeadsState> {
  CrmLeadsBloc({required CrmRepository crmRepository})
      : _crmRepository = crmRepository,
        super(const CrmLeadsState()) {
    on<CrmLeadsLoadRequested>(_onLoad);
    on<CrmLeadsRefreshRequested>(_onRefresh);
    on<CrmLeadsProjectSelected>(_onProjectSelected);
    on<CrmLeadsCampaignSelected>(_onCampaignSelected);
    on<CrmLeadsStatusFilterChanged>(_onStatusFilterChanged);
    on<CrmLeadsSearchChanged>(_onSearchChanged);
    on<CrmLeadsLeadCreated>(_onLeadCreated);
    on<CrmLeadsLeadUpdated>(_onLeadUpdated);
    on<CrmLeadsLeadStatusUpdated>(_onLeadStatusUpdated);
    on<CrmLeadsLeadMovedToBin>(_onLeadMovedToBin);
    on<CrmLeadsExcelImported>(_onExcelImported);
    on<CrmLeadsFollowUpFilterChanged>(_onFollowUpFilterChanged);
    on<CrmLeadsFollowUpScheduled>(_onFollowUpScheduled);
    on<CrmLeadsFollowUpCompleted>(_onFollowUpCompleted);
    on<CrmLeadsCallLogsFilterChanged>(_onCallLogsFilterChanged);
    on<CrmLeadsClickToCallRequested>(_onClickToCallRequested);
    on<CrmLeadsColumnVisibilityToggled>(_onColumnVisibilityToggled);
    on<CrmLeadsColumnsMerged>(_onColumnsMerged);
  }

  final CrmRepository _crmRepository;

  Future<void> _fetchData(
    Emitter<CrmLeadsState> emit, {
    String? projectId,
    String? campaignId,
    String? statusFilter,
    String? search,
    String? followUpFilter,
  }) async {
    try {
      final effectiveStatus = statusFilter ?? state.statusFilter;
      final effectiveSearch = search ?? state.search;
      final effectiveFollowUp = followUpFilter ?? state.followUpFilter;

      final results = await Future.wait([
        _crmRepository.getProjects(),
        _crmRepository.getCampaigns(module: 'PRE_SALES', projectId: projectId),
        _crmRepository.getColumns(module: 'PRE_SALES', campaignId: campaignId),
        _crmRepository.getLeads(
          projectId: projectId,
          campaignId: campaignId,
          status: effectiveStatus == 'ALL' ? null : effectiveStatus,
          search: effectiveSearch.isEmpty ? null : effectiveSearch,
        ),
        _crmRepository.getHrmsEmployees(),
        _crmRepository.getFollowUps(filter: effectiveFollowUp),
        _crmRepository.getCallLogs(
          search: state.callRecordingSearch.isEmpty ? null : state.callRecordingSearch,
          dateFilter: state.callRecordingFilterDate == 'all' ? null : state.callRecordingFilterDate,
          callStatus: state.callRecordingFilterStatus == 'ALL' ? null : state.callRecordingFilterStatus,
          hasRecording: state.callRecordingsOnlyWithAudio ? true : null,
        ),
      ]);

      emit(state.copyWith(
        status: LoadStatus.success,
        projects: results[0] as List<CrmProject>,
        campaigns: results[1] as List<CrmCampaign>,
        columns: results[2] as List<CrmColumnConfig>,
        leads: results[3] as List<CrmLead>,
        salesUsers: results[4] as List<CrmSalesUser>,
        followUps: results[5] as List<CrmFollowUp>,
        callLogs: results[6] as List<CrmCallLog>,
      ));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoad(
    CrmLeadsLoadRequested event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetchData(
      emit,
      projectId: state.selectedProjectId,
      campaignId: state.selectedCampaignId,
    );
  }

  Future<void> _onRefresh(
    CrmLeadsRefreshRequested event,
    Emitter<CrmLeadsState> emit,
  ) async {
    await _fetchData(
      emit,
      projectId: state.selectedProjectId,
      campaignId: state.selectedCampaignId,
    );
  }

  Future<void> _onProjectSelected(
    CrmLeadsProjectSelected event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(
      status: LoadStatus.loading,
      selectedProjectId: event.projectId,
      clearSelectedProject: event.projectId == null,
      clearSelectedCampaign: true,
    ));
    await _fetchData(emit, projectId: event.projectId, campaignId: null);
  }

  Future<void> _onCampaignSelected(
    CrmLeadsCampaignSelected event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(
      status: LoadStatus.loading,
      selectedCampaignId: event.campaignId,
      clearSelectedCampaign: event.campaignId == null,
    ));
    await _fetchData(
      emit,
      projectId: state.selectedProjectId,
      campaignId: event.campaignId,
    );
  }

  Future<void> _onStatusFilterChanged(
    CrmLeadsStatusFilterChanged event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, statusFilter: event.status));
    await _fetchData(
      emit,
      projectId: state.selectedProjectId,
      campaignId: state.selectedCampaignId,
      statusFilter: event.status,
    );
  }

  Future<void> _onSearchChanged(
    CrmLeadsSearchChanged event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, search: event.search));
    await _fetchData(
      emit,
      projectId: state.selectedProjectId,
      campaignId: state.selectedCampaignId,
      search: event.search,
    );
  }

  Future<void> _onLeadCreated(
    CrmLeadsLeadCreated event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final payload = Map<String, dynamic>.from(event.data);
      if (state.selectedCampaignId != null && !payload.containsKey('campaignId')) {
        payload['campaignId'] = state.selectedCampaignId;
      }
      await _crmRepository.createLead(payload);
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Lead created successfully',
      ));
      await _fetchData(
        emit,
        projectId: state.selectedProjectId,
        campaignId: state.selectedCampaignId,
      );
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onLeadUpdated(
    CrmLeadsLeadUpdated event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.updateLead(event.leadId, event.data);
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Lead updated',
      ));
      await _fetchData(
        emit,
        projectId: state.selectedProjectId,
        campaignId: state.selectedCampaignId,
      );
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onLeadStatusUpdated(
    CrmLeadsLeadStatusUpdated event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.updateLeadStatus(
        event.leadId,
        status: event.status,
        scheduledDate: event.scheduledDate,
        scheduledTime: event.scheduledTime,
        remarks: event.remarks,
        assignedToId: event.assignedToId,
      );
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Status updated to ${event.status}',
      ));
      await _fetchData(
        emit,
        projectId: state.selectedProjectId,
        campaignId: state.selectedCampaignId,
      );
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onLeadMovedToBin(
    CrmLeadsLeadMovedToBin event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.moveToBin(event.leadId);
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Lead moved to bin',
      ));
      await _fetchData(
        emit,
        projectId: state.selectedProjectId,
        campaignId: state.selectedCampaignId,
      );
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onExcelImported(
    CrmLeadsExcelImported event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final res = await _crmRepository.importExcel(
        event.fileBytes,
        event.fileName,
        campaignId: state.selectedCampaignId,
      );
      final count = res['count'] ?? 0;
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Imported $count leads',
      ));
      await _fetchData(
        emit,
        projectId: state.selectedProjectId,
        campaignId: state.selectedCampaignId,
      );
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onFollowUpFilterChanged(
    CrmLeadsFollowUpFilterChanged event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(followUpFilter: event.filter));
    try {
      final list = await _crmRepository.getFollowUps(filter: event.filter);
      emit(state.copyWith(followUps: list));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onFollowUpScheduled(
    CrmLeadsFollowUpScheduled event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.scheduleFollowUp(event.data);
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Follow-up scheduled',
      ));
      final list = await _crmRepository.getFollowUps(filter: state.followUpFilter);
      emit(state.copyWith(followUps: list));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onFollowUpCompleted(
    CrmLeadsFollowUpCompleted event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.completeFollowUp(event.id, remarks: event.remarks);
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Follow-up marked complete',
      ));
      final list = await _crmRepository.getFollowUps(filter: state.followUpFilter);
      emit(state.copyWith(followUps: list));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onCallLogsFilterChanged(
    CrmLeadsCallLogsFilterChanged event,
    Emitter<CrmLeadsState> emit,
  ) async {
    final search = event.search ?? state.callRecordingSearch;
    final dateFilter = event.dateFilter ?? state.callRecordingFilterDate;
    final callStatus = event.callStatus ?? state.callRecordingFilterStatus;
    final hasRec = event.hasRecording ?? state.callRecordingsOnlyWithAudio;

    emit(state.copyWith(
      callRecordingSearch: search,
      callRecordingFilterDate: dateFilter,
      callRecordingFilterStatus: callStatus,
      callRecordingsOnlyWithAudio: hasRec,
    ));

    try {
      final logs = await _crmRepository.getCallLogs(
        search: search.isEmpty ? null : search,
        dateFilter: dateFilter == 'all' ? null : dateFilter,
        callStatus: callStatus == 'ALL' ? null : callStatus,
        hasRecording: hasRec ? true : null,
      );
      emit(state.copyWith(callLogs: logs));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onClickToCallRequested(
    CrmLeadsClickToCallRequested event,
    Emitter<CrmLeadsState> emit,
  ) async {
    try {
      await _crmRepository.clickToCall(event.leadId, agentId: event.agentId);
      emit(state.copyWith(actionSuccessMessage: 'Calling lead...'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onColumnVisibilityToggled(
    CrmLeadsColumnVisibilityToggled event,
    Emitter<CrmLeadsState> emit,
  ) async {
    try {
      await _crmRepository.toggleColumnVisibility(event.columnId, event.isVisible);
      final cols = await _crmRepository.getColumns(
        module: 'PRE_SALES',
        campaignId: state.selectedCampaignId,
      );
      emit(state.copyWith(columns: cols));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onColumnsMerged(
    CrmLeadsColumnsMerged event,
    Emitter<CrmLeadsState> emit,
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
        actionSuccessMessage: res['message']?.toString() ?? 'Columns merged successfully!',
      ));
      await _fetchData(
        emit,
        projectId: state.selectedProjectId,
        campaignId: state.selectedCampaignId,
      );
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
