import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/crm_repository.dart';
import '../domain/crm_models.dart';

final crmRepositoryProvider = Provider<CrmRepository>((ref) {
  return CrmRepository(dioClient: ref.watch(dioClientProvider));
});

// -----------------------------------------------------------------------------
// Projects
// -----------------------------------------------------------------------------
class CrmProjectsNotifier extends AsyncNotifier<List<CrmProject>> {
  @override
  FutureOr<List<CrmProject>> build() {
    return ref.watch(crmRepositoryProvider).getProjects();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(crmRepositoryProvider).getProjects(),
    );
  }

  Future<CrmProject> createProject(Map<String, dynamic> data) async {
    final created = await ref.read(crmRepositoryProvider).createProject(data);
    await refresh();
    return created;
  }

  Future<CrmProject> updateProject(String id, Map<String, dynamic> data) async {
    final updated = await ref.read(crmRepositoryProvider).updateProject(id, data);
    await refresh();
    return updated;
  }

  Future<void> deleteProject(String id) async {
    await ref.read(crmRepositoryProvider).deleteProject(id);
    await refresh();
  }
}

final crmProjectsProvider =
    AsyncNotifierProvider<CrmProjectsNotifier, List<CrmProject>>(
  CrmProjectsNotifier.new,
);

class SelectedProjectIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setProjectId(String? id) => state = id;
}

final selectedProjectIdProvider =
    NotifierProvider<SelectedProjectIdNotifier, String?>(
  SelectedProjectIdNotifier.new,
);

// -----------------------------------------------------------------------------
// Campaigns
// -----------------------------------------------------------------------------
class CrmCampaignsNotifier extends AsyncNotifier<List<CrmCampaign>> {
  @override
  FutureOr<List<CrmCampaign>> build() {
    final projectId = ref.watch(selectedProjectIdProvider);
    return ref.watch(crmRepositoryProvider).getCampaigns(
          module: 'PRE_SALES',
          projectId: projectId,
        );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final projectId = ref.read(selectedProjectIdProvider);
    state = await AsyncValue.guard(
      () => ref.read(crmRepositoryProvider).getCampaigns(
            module: 'PRE_SALES',
            projectId: projectId,
          ),
    );
  }

  Future<CrmCampaign> createCampaign(Map<String, dynamic> data) async {
    final created = await ref.read(crmRepositoryProvider).createCampaign(data);
    await refresh();
    ref.invalidate(crmProjectsProvider);
    return created;
  }

  Future<CrmCampaign> updateCampaign(String id, Map<String, dynamic> data) async {
    final updated = await ref.read(crmRepositoryProvider).updateCampaign(id, data);
    await refresh();
    ref.invalidate(crmProjectsProvider);
    return updated;
  }

  Future<void> deleteCampaign(String id) async {
    await ref.read(crmRepositoryProvider).deleteCampaign(id);
    await refresh();
    ref.invalidate(crmProjectsProvider);
  }
}

final crmCampaignsProvider =
    AsyncNotifierProvider<CrmCampaignsNotifier, List<CrmCampaign>>(
  CrmCampaignsNotifier.new,
);

class SelectedCampaignIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.listen(crmCampaignsProvider, (previous, next) {
      next.whenData((list) {
        final current = state;
        if (current != null && list.any((c) => c.id == current)) return;
        // Keep "All Campaigns" (null) so leads for the whole project stay visible.
        state = null;
      });
    });
    return null;
  }

  void setCampaignId(String? id) => state = id;
}

final selectedCampaignIdProvider =
    NotifierProvider<SelectedCampaignIdNotifier, String?>(
  SelectedCampaignIdNotifier.new,
);

// -----------------------------------------------------------------------------
// Dynamic Column Configs (Scoped to Selected Campaign)
// -----------------------------------------------------------------------------
class CrmColumnsNotifier extends AsyncNotifier<List<CrmColumnConfig>> {
  @override
  FutureOr<List<CrmColumnConfig>> build() {
    final campaignId = ref.watch(selectedCampaignIdProvider);
    final campaigns = ref.watch(crmCampaignsProvider).value ?? [];
    final columnCampaignId =
        campaignId ?? (campaigns.isNotEmpty ? campaigns.first.id : null);
    return ref.watch(crmRepositoryProvider).getColumns(
          module: 'PRE_SALES',
          campaignId: columnCampaignId,
        );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final campaignId = ref.read(selectedCampaignIdProvider);
    final campaigns = ref.read(crmCampaignsProvider).value ?? [];
    final columnCampaignId =
        campaignId ?? (campaigns.isNotEmpty ? campaigns.first.id : null);
    state = await AsyncValue.guard(
      () => ref.read(crmRepositoryProvider).getColumns(
            module: 'PRE_SALES',
            campaignId: columnCampaignId,
          ),
    );
  }

  Future<CrmColumnConfig> createColumn(Map<String, dynamic> data) async {
    final campaignId = ref.read(selectedCampaignIdProvider);
    final payload = Map<String, dynamic>.from(data);
    if (campaignId != null && !payload.containsKey('campaignId')) {
      payload['campaignId'] = campaignId;
    }
    final created = await ref.read(crmRepositoryProvider).createColumn(payload);
    ref.invalidateSelf();
    ref.invalidate(crmCampaignsProvider);
    return created;
  }

  Future<CrmColumnConfig> toggleVisibility(String id, bool isVisible) async {
    final updated = await ref.read(crmRepositoryProvider).toggleColumnVisibility(id, isVisible);
    ref.invalidateSelf();
    return updated;
  }

  Future<Map<String, dynamic>> mergeColumns({
    String? campaignId,
    required String sourceKey,
    required String targetKey,
    String? targetLabel,
  }) async {
    final activeCampaignId = campaignId ?? ref.read(selectedCampaignIdProvider);
    final res = await ref.read(crmRepositoryProvider).mergeColumns(
      campaignId: activeCampaignId,
      sourceKey: sourceKey,
      targetKey: targetKey,
      targetLabel: targetLabel,
    );
    ref.invalidateSelf();
    ref.invalidate(crmLeadsProvider);
    return res;
  }

  Future<CrmColumnConfig> updateColumn(String id, Map<String, dynamic> data) async {
    final updated = await ref.read(crmRepositoryProvider).updateColumn(id, data);
    ref.invalidateSelf();
    return updated;
  }

  Future<void> deleteColumn(String id) async {
    await ref.read(crmRepositoryProvider).deleteColumn(id);
    ref.invalidateSelf();
    ref.invalidate(crmCampaignsProvider);
  }
}

final crmColumnsProvider =
    AsyncNotifierProvider<CrmColumnsNotifier, List<CrmColumnConfig>>(
  CrmColumnsNotifier.new,
);

// -----------------------------------------------------------------------------
// Leads List & Filters (Scoped to Selected Campaign)
// -----------------------------------------------------------------------------
class CrmLeadsFilter {
  final String status;
  final String search;
  final String? campaignId;

  const CrmLeadsFilter({
    this.status = 'ALL',
    this.search = '',
    this.campaignId,
  });

  CrmLeadsFilter copyWith({
    String? status,
    String? search,
    String? campaignId,
  }) {
    return CrmLeadsFilter(
      status: status ?? this.status,
      search: search ?? this.search,
      campaignId: campaignId ?? this.campaignId,
    );
  }
}

class CrmLeadsFilterNotifier extends Notifier<CrmLeadsFilter> {
  @override
  CrmLeadsFilter build() => const CrmLeadsFilter();

  void setStatus(String status) => state = state.copyWith(status: status);
  void setSearch(String search) => state = state.copyWith(search: search);
  void setCampaignId(String? campaignId) => state = state.copyWith(campaignId: campaignId);
}

final crmLeadsFilterProvider =
    NotifierProvider<CrmLeadsFilterNotifier, CrmLeadsFilter>(
  CrmLeadsFilterNotifier.new,
);

class CrmLeadsNotifier extends AsyncNotifier<List<CrmLead>> {
  @override
  FutureOr<List<CrmLead>> build() {
    final filter = ref.watch(crmLeadsFilterProvider);
    final activeProjectId = ref.watch(selectedProjectIdProvider);
    final activeCampaignId = ref.watch(selectedCampaignIdProvider);
    final effectiveCampaignId = filter.campaignId ?? activeCampaignId;

    return ref.watch(crmRepositoryProvider).getLeads(
          projectId: activeProjectId,
          campaignId: effectiveCampaignId,
          status: filter.status == 'ALL' ? null : filter.status,
          search: filter.search.isEmpty ? null : filter.search,
        );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final filter = ref.read(crmLeadsFilterProvider);
      final activeProjectId = ref.read(selectedProjectIdProvider);
      final activeCampaignId = ref.read(selectedCampaignIdProvider);
      final effectiveCampaignId = filter.campaignId ?? activeCampaignId;

      return ref.read(crmRepositoryProvider).getLeads(
            projectId: activeProjectId,
            campaignId: effectiveCampaignId,
            status: filter.status == 'ALL' ? null : filter.status,
            search: filter.search.isEmpty ? null : filter.search,
          );
    });
    ref.invalidate(crmKpiProvider);
    ref.invalidate(crmFollowUpsProvider);
    ref.invalidate(crmCampaignsProvider);
  }

  Future<CrmLead> createLead(Map<String, dynamic> data) async {
    final activeCampaignId = ref.read(selectedCampaignIdProvider);
    final campaigns = ref.read(crmCampaignsProvider).value ?? [];
    final payload = Map<String, dynamic>.from(data);
    if (!payload.containsKey('campaignId')) {
      payload['campaignId'] =
          activeCampaignId ?? (campaigns.isNotEmpty ? campaigns.first.id : null);
    }
    final created = await ref.read(crmRepositoryProvider).createLead(payload);
    await refresh();
    return created;
  }

  Future<Map<String, dynamic>> importExcel(
    Uint8List bytes,
    String fileName, {
    String? campaignId,
  }) async {
    final effectiveCampaignId = campaignId ?? ref.read(selectedCampaignIdProvider);
    final res = await ref.read(crmRepositoryProvider).importExcel(
          bytes,
          fileName,
          campaignId: effectiveCampaignId,
        );
    await refresh();
    return res;
  }

  Future<CrmLead> updateLeadStatus(
    String leadId, {
    required String status,
    String? scheduledDate,
    String? scheduledTime,
    String? remarks,
    int? assignedToId,
  }) async {
    final updated = await ref.read(crmRepositoryProvider).updateLeadStatus(
          leadId,
          status: status,
          scheduledDate: scheduledDate,
          scheduledTime: scheduledTime,
          remarks: remarks,
          assignedToId: assignedToId,
        );
    await refresh();
    return updated;
  }

  Future<CrmLead> updateLead(String leadId, Map<String, dynamic> data) async {
    final updated = await ref.read(crmRepositoryProvider).updateLead(leadId, data);
    await refresh();
    return updated;
  }

  Future<void> moveToBin(String leadId) async {
    await ref.read(crmRepositoryProvider).moveToBin(leadId);
    await refresh();
    ref.invalidate(crmBinLeadsProvider);
  }

  Future<void> restoreFromBin(String leadId) async {
    await ref.read(crmRepositoryProvider).restoreFromBin(leadId);
    await refresh();
    ref.invalidate(crmBinLeadsProvider);
  }
}

final crmLeadsProvider =
    AsyncNotifierProvider<CrmLeadsNotifier, List<CrmLead>>(
  CrmLeadsNotifier.new,
);

// -----------------------------------------------------------------------------
// Follow-ups Provider
// -----------------------------------------------------------------------------
final crmFollowUpsProvider =
    FutureProvider.autoDispose.family<List<CrmFollowUp>, String?>((ref, filter) async {
  return ref.watch(crmRepositoryProvider).getFollowUps(filter: filter);
});

// -----------------------------------------------------------------------------
// Bin Leads Provider
// -----------------------------------------------------------------------------
final crmBinLeadsProvider = FutureProvider.autoDispose<List<CrmLead>>((ref) async {
  return ref.watch(crmRepositoryProvider).getBinLeads();
});

// -----------------------------------------------------------------------------
// Settings Provider
// -----------------------------------------------------------------------------
class CrmSettingsNotifier extends AsyncNotifier<CrmSettings> {
  @override
  FutureOr<CrmSettings> build() {
    return ref.watch(crmRepositoryProvider).getSettings();
  }

  Future<void> saveSettings(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(crmRepositoryProvider).updateSettings(data),
    );
  }
}

final crmSettingsProvider =
    AsyncNotifierProvider<CrmSettingsNotifier, CrmSettings>(
  CrmSettingsNotifier.new,
);

// -----------------------------------------------------------------------------
// KPI Metrics Provider
// -----------------------------------------------------------------------------
final crmKpiProvider = FutureProvider.autoDispose<CrmKpiMetrics>((ref) async {
  final projectId = ref.watch(selectedProjectIdProvider);
  final campaignId = ref.watch(selectedCampaignIdProvider);
  return ref.watch(crmRepositoryProvider).getKpiMetrics(
        projectId: projectId,
        campaignId: campaignId,
      );
});

// -----------------------------------------------------------------------------
// Call Recordings & Logs Provider
// -----------------------------------------------------------------------------
class CrmCallLogsFilter {
  final String dateFilter;
  final String callStatus;
  final String search;
  final String? did;
  final bool hasRecording;

  const CrmCallLogsFilter({
    this.dateFilter = 'all',
    this.callStatus = 'ALL',
    this.search = '',
    this.did,
    this.hasRecording = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrmCallLogsFilter &&
          runtimeType == other.runtimeType &&
          dateFilter == other.dateFilter &&
          callStatus == other.callStatus &&
          search == other.search &&
          did == other.did &&
          hasRecording == other.hasRecording;

  @override
  int get hashCode =>
      dateFilter.hashCode ^
      callStatus.hashCode ^
      search.hashCode ^
      did.hashCode ^
      hasRecording.hashCode;
}

final crmCallLogsProvider =
    FutureProvider.autoDispose.family<List<CrmCallLog>, CrmCallLogsFilter>((ref, filter) async {
  return ref.watch(crmRepositoryProvider).getCallLogs(
        dateFilter: filter.dateFilter == 'all' ? null : filter.dateFilter,
        callStatus: filter.callStatus,
        search: filter.search,
        did: filter.did,
        hasRecording: filter.hasRecording ? true : null,
      );
});

// -----------------------------------------------------------------------------
// Sales Reps Provider (from HRMS)
// -----------------------------------------------------------------------------
final crmSalesUsersProvider =
    FutureProvider.autoDispose<List<CrmSalesUser>>((ref) async {
  return ref.watch(crmRepositoryProvider).getHrmsEmployees();
});
