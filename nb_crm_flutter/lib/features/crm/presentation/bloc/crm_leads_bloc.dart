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

class CrmLeadsLeadFlowFilterChanged extends CrmLeadsEvent {
  const CrmLeadsLeadFlowFilterChanged(this.leadFlow);
  final String leadFlow;

  @override
  List<Object?> get props => [leadFlow];
}

class CrmLeadsSearchChanged extends CrmLeadsEvent {
  const CrmLeadsSearchChanged(this.search);
  final String search;

  @override
  List<Object?> get props => [search];
}

class CrmLeadsDateFilterChanged extends CrmLeadsEvent {
  const CrmLeadsDateFilterChanged({
    this.fromDate,
    this.toDate,
    this.datePreset = 'all',
  });
  final DateTime? fromDate;
  final DateTime? toDate;
  final String datePreset;

  @override
  List<Object?> get props => [fromDate, toDate, datePreset];
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
    this.scheduledVisitAt,
    this.remarks,
    this.assignedToId,
    this.notInterestedReason,
    this.notInterestedRemark,
  });

  final String leadId;
  final String status;
  final String? scheduledDate;
  final String? scheduledTime;
  final String? scheduledVisitAt;
  final String? remarks;
  final int? assignedToId;
  final String? notInterestedReason;
  final String? notInterestedRemark;

  @override
  List<Object?> get props => [
        leadId,
        status,
        scheduledDate,
        scheduledTime,
        scheduledVisitAt,
        remarks,
        assignedToId,
        notInterestedReason,
        notInterestedRemark,
      ];
}

class CrmLeadsLeadMovedToBin extends CrmLeadsEvent {
  const CrmLeadsLeadMovedToBin(this.leadId);
  final String leadId;

  @override
  List<Object?> get props => [leadId];
}

class CrmLeadsExcelImported extends CrmLeadsEvent {
  const CrmLeadsExcelImported(
    this.fileBytes,
    this.fileName, {
    this.campaignId,
    this.assignmentMode,
    this.telecallerId,
    this.assignedTelecallerIds,
    this.skipDuplicates = true,
  });
  final Uint8List fileBytes;
  final String fileName;
  final String? campaignId;
  final String? assignmentMode;
  final int? telecallerId;
  final List<int>? assignedTelecallerIds;
  final bool skipDuplicates;

  @override
  List<Object?> get props => [
        fileBytes,
        fileName,
        campaignId,
        assignmentMode,
        telecallerId,
        assignedTelecallerIds,
        skipDuplicates,
      ];
}

class CrmLeadsMergeRequested extends CrmLeadsEvent {
  const CrmLeadsMergeRequested({
    required this.primaryLeadId,
    required this.duplicateLeadId,
    this.remarks,
  });
  final String primaryLeadId;
  final String duplicateLeadId;
  final String? remarks;

  @override
  List<Object?> get props => [primaryLeadId, duplicateLeadId, remarks];
}

class CrmLeadTransferRequested extends CrmLeadsEvent {
  const CrmLeadTransferRequested({
    required this.leadId,
    required this.targetTelecallerId,
    this.remarks,
  });
  final String leadId;
  final int targetTelecallerId;
  final String? remarks;

  @override
  List<Object?> get props => [leadId, targetTelecallerId, remarks];
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

class CrmLeadsVisitorCheckinSubmitted extends CrmLeadsEvent {
  const CrmLeadsVisitorCheckinSubmitted(this.payload);
  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [payload];
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

class CrmLeadsSilentRefreshRequested extends CrmLeadsEvent {
  const CrmLeadsSilentRefreshRequested();
  @override
  List<Object?> get props => [];
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
    this.leadFlowFilter = 'ALL',
    this.search = '',
    this.fromDate,
    this.toDate,
    this.datePreset = 'all',
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
    this.settings,
  });

  final LoadStatus status;
  final List<CrmProject> projects;
  final String? selectedProjectId;
  final List<CrmCampaign> campaigns;
  final String? selectedCampaignId;
  final List<CrmColumnConfig> columns;
  final List<CrmLead> leads;
  final String statusFilter;
  final String leadFlowFilter;
  final String search;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String datePreset;
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
  final CrmSettings? settings;

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
    String? leadFlowFilter,
    String? search,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
    String? datePreset,
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
    CrmSettings? settings,
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
      leadFlowFilter: leadFlowFilter ?? this.leadFlowFilter,
      search: search ?? this.search,
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      datePreset: datePreset ?? this.datePreset,
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
      settings: settings ?? this.settings,
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
        leadFlowFilter,
        search,
        fromDate,
        toDate,
        datePreset,
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
        settings,
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
    on<CrmLeadsLeadFlowFilterChanged>(_onLeadFlowFilterChanged);
    on<CrmLeadsSearchChanged>(_onSearchChanged);
    on<CrmLeadsDateFilterChanged>(_onDateFilterChanged);
    on<CrmLeadsLeadCreated>(_onLeadCreated);
    on<CrmLeadsLeadUpdated>(_onLeadUpdated);
    on<CrmLeadsLeadStatusUpdated>(_onLeadStatusUpdated);
    on<CrmLeadsLeadMovedToBin>(_onLeadMovedToBin);
    on<CrmLeadsExcelImported>(_onExcelImported);
    on<CrmLeadsMergeRequested>(_onMergeRequested);
    on<CrmLeadTransferRequested>(_onLeadTransferRequested);
    on<CrmLeadsFollowUpFilterChanged>(_onFollowUpFilterChanged);
    on<CrmLeadsFollowUpScheduled>(_onFollowUpScheduled);
    on<CrmLeadsFollowUpCompleted>(_onFollowUpCompleted);
    on<CrmLeadsVisitorCheckinSubmitted>(_onVisitorCheckinSubmitted);
    on<CrmLeadsCallLogsFilterChanged>(_onCallLogsFilterChanged);
    on<CrmLeadsClickToCallRequested>(_onClickToCallRequested);
    on<CrmLeadsColumnVisibilityToggled>(_onColumnVisibilityToggled);
    on<CrmLeadsColumnsMerged>(_onColumnsMerged);
    on<CrmLeadsSilentRefreshRequested>(_onSilentRefresh);

    CrmRepository.leadMutationNotifier.addListener(_onLeadMutationNotified);
  }

  final CrmRepository _crmRepository;

  void _onLeadMutationNotified() {
    add(const CrmLeadsSilentRefreshRequested());
  }

  @override
  Future<void> close() {
    CrmRepository.leadMutationNotifier.removeListener(_onLeadMutationNotified);
    return super.close();
  }

  Future<void> _onSilentRefresh(
    CrmLeadsSilentRefreshRequested event,
    Emitter<CrmLeadsState> emit,
  ) async {
    await _refreshLeadsOnly(emit);
  }

  Future<void> _onDateFilterChanged(
    CrmLeadsDateFilterChanged event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(
      fromDate: event.fromDate,
      clearFromDate: event.fromDate == null,
      toDate: event.toDate,
      clearToDate: event.toDate == null,
      datePreset: event.datePreset,
    ));
    await _refreshLeadsOnly(emit);
  }

  Future<void> _refreshLeadsOnly(Emitter<CrmLeadsState> emit) async {
    try {
      final effectiveStatus = state.statusFilter;
      final effectiveLeadFlow = state.leadFlowFilter;
      final effectiveSearch = state.search;

      final updatedLeads = await _crmRepository.getLeads(
        projectId: state.selectedProjectId,
        campaignId: state.selectedCampaignId,
        status: effectiveStatus == 'ALL' ? null : effectiveStatus,
        leadFlow: effectiveLeadFlow == 'ALL' ? null : effectiveLeadFlow,
        search: effectiveSearch.isEmpty ? null : effectiveSearch,
        fromDate: state.fromDate,
        toDate: state.toDate,
      );
      emit(state.copyWith(leads: updatedLeads));
    } catch (_) {
      // Retain optimistic local state on network error
    }
  }

  Future<void> _fetchData(
    Emitter<CrmLeadsState> emit, {
    String? projectId,
    String? campaignId,
    String? statusFilter,
    String? leadFlowFilter,
    String? search,
    String? followUpFilter,
  }) async {
    try {
      final effectiveStatus = statusFilter ?? state.statusFilter;
      final effectiveLeadFlow = leadFlowFilter ?? state.leadFlowFilter;
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
          leadFlow: effectiveLeadFlow == 'ALL' ? null : effectiveLeadFlow,
          search: effectiveSearch.isEmpty ? null : effectiveSearch,
          fromDate: state.fromDate,
          toDate: state.toDate,
        ),
        _crmRepository.getHrmsEmployees(),
        _crmRepository.getFollowUps(filter: effectiveFollowUp),
        _crmRepository.getCallLogs(
          search: state.callRecordingSearch.isEmpty ? null : state.callRecordingSearch,
          dateFilter: state.callRecordingFilterDate == 'all' ? null : state.callRecordingFilterDate,
          callStatus: state.callRecordingFilterStatus == 'ALL' ? null : state.callRecordingFilterStatus,
          hasRecording: state.callRecordingsOnlyWithAudio ? true : null,
        ),
        _crmRepository.getSettings(),
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
        settings: results[7] as CrmSettings,
      ));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onLeadFlowFilterChanged(
    CrmLeadsLeadFlowFilterChanged event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(leadFlowFilter: event.leadFlow));
    await _fetchData(
      emit,
      projectId: state.selectedProjectId,
      campaignId: state.selectedCampaignId,
      leadFlowFilter: event.leadFlow,
    );
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
    // 1. Instant Optimistic Update in State
    final assignedId = event.data['assignedToId'] as int?;
    final targetUser = assignedId != null
        ? state.salesUsers.firstWhere(
            (u) => u.employeeId == assignedId,
            orElse: () => CrmSalesUser(
              employeeId: assignedId,
              fullName: 'Sales Manager #$assignedId',
            ),
          )
        : null;
    final statusStr = event.data['status']?.toString();
    final newStatus = statusStr != null ? CrmStatus.fromString(statusStr) : null;

    final optimisticallyUpdated = state.leads.map((l) {
      if (l.id == event.leadId) {
        return l.copyWith(
          assignedToId: event.data.containsKey('assignedToId') ? assignedId : l.assignedToId,
          clearAssignedTo: event.data.containsKey('assignedToId') && assignedId == null,
          assignedToName: event.data.containsKey('assignedToId') ? targetUser?.fullName : l.assignedToName,
          status: newStatus ?? l.status,
          name: event.data['name']?.toString() ?? l.name,
          phone: event.data['phone']?.toString() ?? l.phone,
          customFields: event.data['customFields'] is Map
              ? Map<String, dynamic>.from(event.data['customFields'] as Map)
              : l.customFields,
        );
      }
      return l;
    }).toList();

    emit(state.copyWith(
      leads: optimisticallyUpdated,
      actionSuccessMessage: assignedId != null
          ? 'Lead assigned to ${targetUser?.fullName ?? "Sales Manager"}'
          : 'Lead updated',
    ));

    // 2. Perform background update & silent refresh
    try {
      await _crmRepository.updateLead(event.leadId, event.data);
      await _refreshLeadsOnly(emit);
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Update failed: $e'));
    }
  }

  Future<void> _onLeadStatusUpdated(
    CrmLeadsLeadStatusUpdated event,
    Emitter<CrmLeadsState> emit,
  ) async {
    // 1. Instant Optimistic Update
    final newStatus = CrmStatus.fromString(event.status);
    final optimisticallyUpdated = state.leads.map((l) {
      if (l.id == event.leadId) {
        CrmFollowUp? updatedFollowUp = l.latestFollowUp;
        if (event.scheduledDate != null && event.scheduledTime != null) {
          updatedFollowUp = CrmFollowUp(
            id: l.latestFollowUp?.id ?? 'optimistic-${DateTime.now().millisecondsSinceEpoch}',
            leadId: l.id,
            leadName: l.name,
            leadPhone: l.phone,
            scheduledDate: DateTime.tryParse(event.scheduledDate!) ?? DateTime.now(),
            scheduledTime: event.scheduledTime!,
            remarks: event.remarks,
            status: 'PENDING',
            createdAt: DateTime.now(),
          );
        }
        return l.copyWith(
          status: newStatus,
          latestFollowUp: updatedFollowUp,
        );
      }
      return l;
    }).toList();

    emit(state.copyWith(
      leads: optimisticallyUpdated,
      actionSuccessMessage: 'Status updated to ${event.status}',
    ));

    // 2. Background update & silent refresh
    try {
      await _crmRepository.updateLeadStatus(
        event.leadId,
        status: event.status,
        scheduledDate: event.scheduledDate,
        scheduledTime: event.scheduledTime,
        scheduledVisitAt: event.scheduledVisitAt,
        remarks: event.remarks,
        assignedToId: event.assignedToId,
        notInterestedReason: event.notInterestedReason,
        notInterestedRemark: event.notInterestedRemark,
      );
      await _refreshLeadsOnly(emit);
      if (event.scheduledDate != null || event.status == 'FOLLOW_UP') {
        try {
          final updatedFollowUps = await _crmRepository.getFollowUps(filter: state.followUpFilter);
          emit(state.copyWith(followUps: updatedFollowUps));
        } catch (_) {}
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Status update failed: $e'));
    }
  }

  Future<void> _onLeadMovedToBin(
    CrmLeadsLeadMovedToBin event,
    Emitter<CrmLeadsState> emit,
  ) async {
    final updatedLeads = state.leads.where((l) => l.id != event.leadId).toList();
    emit(state.copyWith(
      leads: updatedLeads,
      actionSuccessMessage: 'Lead moved to bin',
    ));
    try {
      await _crmRepository.moveToBin(event.leadId);
      await _refreshLeadsOnly(emit);
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
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
        campaignId: event.campaignId ?? state.selectedCampaignId,
        assignmentMode: event.assignmentMode,
        telecallerId: event.telecallerId,
        assignedTelecallerIds: event.assignedTelecallerIds,
        skipDuplicates: event.skipDuplicates,
      );
      final count = res['count'] ?? 0;
      final msg = res['message'] ?? 'Imported $count leads';
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: msg,
      ));
      await _fetchData(
        emit,
        projectId: state.selectedProjectId,
        campaignId: event.campaignId ?? state.selectedCampaignId,
      );
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onMergeRequested(
    CrmLeadsMergeRequested event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _crmRepository.mergeLeads(
        primaryLeadId: event.primaryLeadId,
        duplicateLeadId: event.duplicateLeadId,
        remarks: event.remarks,
      );
      emit(state.copyWith(
        isActing: false,
        actionSuccessMessage: 'Leads merged successfully',
      ));
      await _fetchData(
        emit,
        projectId: state.selectedProjectId,
        campaignId: state.selectedCampaignId,
      );
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: 'Merge failed: $e'));
    }
  }

  Future<void> _onLeadTransferRequested(
    CrmLeadTransferRequested event,
    Emitter<CrmLeadsState> emit,
  ) async {
    // 1. Instant Optimistic Update in State
    final targetUser = state.salesUsers.firstWhere(
      (u) => u.employeeId == event.targetTelecallerId,
      orElse: () => CrmSalesUser(
        employeeId: event.targetTelecallerId,
        fullName: 'Telecaller #${event.targetTelecallerId}',
      ),
    );

    final optimisticallyUpdated = state.leads.map((l) {
      if (l.id == event.leadId) {
        return l.copyWith(
          telecallerId: event.targetTelecallerId,
          telecallerName: targetUser.fullName,
        );
      }
      return l;
    }).toList();

    emit(state.copyWith(
      leads: optimisticallyUpdated,
      actionSuccessMessage: 'Lead transferred to ${targetUser.fullName}',
    ));

    // 2. Background transfer & silent refresh
    try {
      await _crmRepository.transferLead(
        event.leadId,
        targetTelecallerId: event.targetTelecallerId,
        remarks: event.remarks,
      );
      await _refreshLeadsOnly(emit);
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Transfer failed: $e'));
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

  Future<void> _onVisitorCheckinSubmitted(
    CrmLeadsVisitorCheckinSubmitted event,
    Emitter<CrmLeadsState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final checkedIn = await _crmRepository.visitorCheckin(event.payload);
      final existingIndex = state.leads.indexWhere((l) => l.id == checkedIn.id);
      final updatedLeads = List<CrmLead>.from(state.leads);
      if (existingIndex >= 0) {
        updatedLeads[existingIndex] = checkedIn;
      } else {
        updatedLeads.insert(0, checkedIn);
      }

      emit(state.copyWith(
        isActing: false,
        leads: updatedLeads,
        actionSuccessMessage: 'Visitor check-in completed & status updated to Site Done!',
      ));
      await _refreshLeadsOnly(emit);
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
