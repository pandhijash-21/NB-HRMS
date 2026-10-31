import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/dio_client.dart';
import '../domain/crm_models.dart';
import '../domain/hub_partner_model.dart';


class CrmRepository {
  final DioClient _dio;
  static final ValueNotifier<String> crmScopeNotifier = ValueNotifier<String>('NB_DEVELOPER');
  static final ValueNotifier<int> leadMutationNotifier = ValueNotifier<int>(0);

  static void notifyLeadMutated() {
    leadMutationNotifier.value = leadMutationNotifier.value + 1;
  }

  CrmRepository({required DioClient dioClient}) : _dio = dioClient {
    _dio.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['x-crm-scope'] = crmScopeNotifier.value;
          handler.next(options);
        },
      ),
    );
  }

  ValueNotifier<String> get scopeNotifier => crmScopeNotifier;
  String get scope => crmScopeNotifier.value;

  void setScope(String newScope) {
    final s = (newScope.toUpperCase() == 'NB_FINSERVE') ? 'NB_FINSERVE' : 'NB_DEVELOPER';
    if (crmScopeNotifier.value != s) {
      crmScopeNotifier.value = s;
    }
  }

  // ---------------------------------------------------------------------------
  // Projects
  // ---------------------------------------------------------------------------
  Future<List<CrmProject>> getProjects() async {
    return _dio.getEnvelope<List<CrmProject>>(
      'crm/projects',
      queryParameters: {'scope': crmScopeNotifier.value},
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => CrmProject.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<CrmProject> createProject(Map<String, dynamic> data) async {
    return _dio.postEnvelope<CrmProject>(
      'crm/projects',
      data: data,
      parse: (raw) => CrmProject.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<CrmProject> updateProject(String id, Map<String, dynamic> data) async {
    return _dio.putEnvelope<CrmProject>(
      'crm/projects/$id',
      data: data,
      parse: (raw) => CrmProject.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> deleteProject(String id) async {
    await _dio.deleteEnvelope<void>(
      'crm/projects/$id',
      parse: (_) {},
    );
  }

  // ---------------------------------------------------------------------------
  // Campaigns
  // ---------------------------------------------------------------------------
  Future<List<CrmCampaign>> getCampaigns({
    String module = 'PRE_SALES',
    String? projectId,
  }) async {
    final query = <String, dynamic>{
      'module': module,
      'scope': crmScopeNotifier.value,
    };
    if (projectId != null && projectId.isNotEmpty) {
      query['projectId'] = projectId;
    }

    return _dio.getEnvelope<List<CrmCampaign>>(
      'crm/campaigns',
      queryParameters: query,
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => CrmCampaign.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<CrmCampaign> createCampaign(Map<String, dynamic> data) async {
    return _dio.postEnvelope<CrmCampaign>(
      'crm/campaigns',
      data: data,
      parse: (raw) => CrmCampaign.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<CrmCampaign> updateCampaign(String id, Map<String, dynamic> data) async {
    return _dio.putEnvelope<CrmCampaign>(
      'crm/campaigns/$id',
      data: data,
      parse: (raw) => CrmCampaign.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> deleteCampaign(String id) async {
    await _dio.deleteEnvelope<void>(
      'crm/campaigns/$id',
      parse: (_) {},
    );
  }

  // ---------------------------------------------------------------------------
  // Columns & Headers Management
  // ---------------------------------------------------------------------------
  Future<List<CrmColumnConfig>> getColumns({
    String module = 'PRE_SALES',
    String? campaignId,
  }) async {
    final query = <String, dynamic>{
      'module': module,
      'scope': crmScopeNotifier.value,
    };
    if (campaignId != null && campaignId.isNotEmpty) {
      query['campaignId'] = campaignId;
    }

    return _dio.getEnvelope<List<CrmColumnConfig>>(
      'crm/columns',
      queryParameters: query,
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => CrmColumnConfig.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<CrmColumnConfig> createColumn(Map<String, dynamic> data) async {
    return _dio.postEnvelope<CrmColumnConfig>(
      'crm/columns',
      data: data,
      parse: (raw) => CrmColumnConfig.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<CrmColumnConfig> toggleColumnVisibility(String id, bool isVisibleInTable) async {
    return _dio.patchEnvelope<CrmColumnConfig>(
      'crm/columns/$id/visibility',
      data: {'isVisibleInTable': isVisibleInTable},
      parse: (raw) => CrmColumnConfig.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<Map<String, dynamic>> mergeColumns({
    String? campaignId,
    String module = 'PRE_SALES',
    required String sourceKey,
    required String targetKey,
    String? targetLabel,
  }) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/columns/merge',
      data: {
        if (campaignId != null) 'campaignId': campaignId,
        'module': module,
        'sourceKey': sourceKey,
        'targetKey': targetKey,
        if (targetLabel != null) 'targetLabel': targetLabel,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<CrmColumnConfig> updateColumn(String id, Map<String, dynamic> data) async {
    return _dio.putEnvelope<CrmColumnConfig>(
      'crm/columns/$id',
      data: data,
      parse: (raw) => CrmColumnConfig.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> deleteColumn(String id) async {
    await _dio.deleteEnvelope<void>(
      'crm/columns/$id',
      parse: (_) {},
    );
  }

  // ---------------------------------------------------------------------------
  // Leads
  // ---------------------------------------------------------------------------
  Future<List<CrmLead>> getLeads({
    String? projectId,
    String? campaignId,
    String? status,
    String? search,
    String? leadFlow,
    int? assignedToId,
    DateTime? fromDate,
    DateTime? toDate,
    int page = 1,
    int limit = 100,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'scope': crmScopeNotifier.value,
    };
    if (projectId != null && projectId != 'ALL' && projectId.isNotEmpty) {
      query['projectId'] = projectId;
    }
    if (campaignId != null && campaignId != 'ALL' && campaignId.isNotEmpty) {
      query['campaignId'] = campaignId;
    }
    if (status != null && status != 'ALL') query['status'] = status;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (assignedToId != null) query['assignedToId'] = assignedToId;
    if (leadFlow != null && leadFlow != 'ALL') query['leadFlow'] = leadFlow;
    if (fromDate != null) query['fromDate'] = fromDate.toIso8601String();
    if (toDate != null) query['toDate'] = toDate.toIso8601String();

    return _dio.getEnvelope<List<CrmLead>>(
      'crm/leads',
      queryParameters: query,
      parse: (raw) {
        if (raw is! Map) return [];
        final items = raw['items'];
        if (items is! List) return [];
        return items
            .map((e) => CrmLead.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<Uint8List> exportLeadsExcel({
    String? projectId,
    String? campaignId,
    String? status,
    String? search,
    String? leadFlow,
    int? assignedToId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = <String, dynamic>{
      'scope': crmScopeNotifier.value,
    };
    if (projectId != null && projectId != 'ALL' && projectId.isNotEmpty) {
      query['projectId'] = projectId;
    }
    if (campaignId != null && campaignId != 'ALL' && campaignId.isNotEmpty) {
      query['campaignId'] = campaignId;
    }
    if (status != null && status != 'ALL') query['status'] = status;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (assignedToId != null) query['assignedToId'] = assignedToId;
    if (leadFlow != null && leadFlow != 'ALL') query['leadFlow'] = leadFlow;
    if (fromDate != null) query['fromDate'] = fromDate.toIso8601String();
    if (toDate != null) query['toDate'] = toDate.toIso8601String();

    final response = await _dio.dio.get<List<int>>(
      'crm/leads/export-excel',
      queryParameters: query,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? []);
  }

  Future<CrmLead> createLead(Map<String, dynamic> data) async {
    return _dio.postEnvelope<CrmLead>(
      'crm/leads',
      data: data,
      parse: (raw) => CrmLead.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<Map<String, dynamic>> importExcel(
    Uint8List fileBytes,
    String fileName, {
    String? campaignId,
    String? assignmentMode,
    int? telecallerId,
    List<int>? assignedTelecallerIds,
    bool skipDuplicates = true,
  }) async {
    final map = <String, dynamic>{
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      'skipDuplicates': skipDuplicates,
    };
    if (campaignId != null && campaignId.isNotEmpty) {
      map['campaignId'] = campaignId;
    }
    if (assignmentMode != null && assignmentMode.isNotEmpty) {
      map['assignmentMode'] = assignmentMode;
    }
    if (telecallerId != null && telecallerId > 0) {
      map['telecallerId'] = telecallerId;
    }
    if (assignedTelecallerIds != null && assignedTelecallerIds.isNotEmpty) {
      map['assignedTelecallerIds'] = jsonEncode(assignedTelecallerIds);
    }

    final formData = FormData.fromMap(map);

    final res = await _dio.dio.post<Map<String, dynamic>>(
      'crm/leads/import-excel',
      data: formData,
    );

    if (res.data != null && res.data!['data'] is Map) {
      return Map<String, dynamic>.from(res.data!['data'] as Map);
    }
    return {'count': 0, 'message': 'Upload completed'};
  }

  Future<Map<String, dynamic>> checkPhone(String phone, {String? scope}) async {
    try {
      final query = <String, dynamic>{
        'phone': phone,
        if (scope != null && scope.isNotEmpty) 'scope': scope,
      };
      final res = await _dio.dio.get<Map<String, dynamic>>(
        'crm/leads/check-phone',
        queryParameters: query,
      );
      if (res.data != null && res.data!['data'] is Map) {
        return Map<String, dynamic>.from(res.data!['data'] as Map);
      }
    } catch (_) {}
    return {'exists': false};
  }

  Future<Map<String, dynamic>> mergeLeads({
    required String primaryLeadId,
    required String duplicateLeadId,
    String? remarks,
  }) async {
    final res = await _dio.dio.post<Map<String, dynamic>>(
      'crm/leads/merge',
      data: {
        'primaryLeadId': primaryLeadId,
        'duplicateLeadId': duplicateLeadId,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
    );
    notifyLeadMutated();
    if (res.data != null && res.data!['data'] is Map) {
      return Map<String, dynamic>.from(res.data!['data'] as Map);
    }
    return {'status': 'success'};
  }

  Future<Map<String, dynamic>> transferLead(
    String leadId, {
    required int targetTelecallerId,
    String? remarks,
  }) async {
    final res = await _dio.dio.post<Map<String, dynamic>>(
      'crm/leads/$leadId/transfer',
      data: {
        'targetTelecallerId': targetTelecallerId,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
    );
    notifyLeadMutated();
    if (res.data != null && res.data!['data'] is Map) {
      return Map<String, dynamic>.from(res.data!['data'] as Map);
    }
    return {'status': 'success'};
  }

  /// Admin-only: transfer many leads to one telecaller.
  Future<Map<String, dynamic>> bulkTransferLeads({
    required List<String> leadIds,
    required int targetTelecallerId,
    String? remarks,
  }) async {
    final res = await _dio.dio.post<Map<String, dynamic>>(
      'crm/leads/bulk-transfer',
      data: {
        'leadIds': leadIds,
        'targetTelecallerId': targetTelecallerId,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
    );
    notifyLeadMutated();
    if (res.data != null && res.data!['data'] is Map) {
      return Map<String, dynamic>.from(res.data!['data'] as Map);
    }
    return {'status': 'success'};
  }

  Future<CrmLead> updateLeadStatus(
    String leadId, {
    required String status,
    String? scheduledDate,
    String? scheduledTime,
    String? scheduledVisitAt,
    String? remarks,
    int? assignedToId,
    String? notInterestedReason,
    String? notInterestedRemark,
  }) async {
    final updated = await _dio.patchEnvelope<CrmLead>(
      'crm/leads/$leadId/status',
      data: {
        'status': status,
        if (scheduledDate != null) 'scheduledDate': scheduledDate,
        if (scheduledTime != null) 'scheduledTime': scheduledTime,
        if (scheduledVisitAt != null) 'scheduledVisitAt': scheduledVisitAt,
        if (remarks != null) 'remarks': remarks,
        if (assignedToId != null) 'assignedToId': assignedToId,
        if (notInterestedReason != null) 'notInterestedReason': notInterestedReason,
        if (notInterestedRemark != null) 'notInterestedRemark': notInterestedRemark,
      },
      parse: (raw) => CrmLead.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    notifyLeadMutated();
    return updated;
  }

  Future<Map<String, dynamic>> visitorLookup(String phone) async {
    return _dio.getEnvelope<Map<String, dynamic>>(
      'crm/visitor-lookup',
      queryParameters: {'phone': phone},
      parse: (raw) => raw is Map ? Map<String, dynamic>.from(raw) : {'exists': false},
    );
  }

  Future<CrmLead> visitorCheckin(Map<String, dynamic> data) async {
    final res = await _dio.postEnvelope<CrmLead>(
      'crm/visitor-checkin',
      data: data,
      parse: (raw) => CrmLead.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    notifyLeadMutated();
    return res;
  }

  Future<CrmLead> updateLead(String leadId, Map<String, dynamic> data) async {
    final res = await _dio.patchEnvelope<CrmLead>(
      'crm/leads/$leadId',
      data: data,
      parse: (raw) => CrmLead.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    notifyLeadMutated();
    return res;
  }

  Future<void> moveToBin(String leadId) async {
    await _dio.deleteEnvelope<void>(
      'crm/leads/$leadId',
      parse: (_) {},
    );
    notifyLeadMutated();
  }

  Future<void> restoreFromBin(String leadId) async {
    await _dio.patchEnvelope<void>(
      'crm/leads/$leadId/restore',
      data: {},
      parse: (_) {},
    );
  }

  Future<List<CrmLead>> getBinLeads({String module = 'PRE_SALES'}) async {
    return _dio.getEnvelope<List<CrmLead>>(
      'crm/bin',
      queryParameters: {'module': module},
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => CrmLead.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Follow-ups
  // ---------------------------------------------------------------------------
  Future<List<CrmFollowUp>> getFollowUps({String? filter, String? leadId}) async {
    final now = DateTime.now();
    final localDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final query = <String, dynamic>{
      'scope': crmScopeNotifier.value,
      'date': localDate,
    };
    if (filter != null) query['filter'] = filter;
    if (leadId != null) query['leadId'] = leadId;

    return _dio.getEnvelope<List<CrmFollowUp>>(
      'crm/follow-ups',
      queryParameters: query.isEmpty ? null : query,
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => CrmFollowUp.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<CrmFollowUp> scheduleFollowUp(Map<String, dynamic> data) async {
    return _dio.postEnvelope<CrmFollowUp>(
      'crm/follow-ups',
      data: data,
      parse: (raw) => CrmFollowUp.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> completeFollowUp(String id, {String? remarks}) async {
    await _dio.patchEnvelope<void>(
      'crm/follow-ups/$id/complete',
      data: {'remarks': remarks},
      parse: (_) {},
    );
  }

  // ---------------------------------------------------------------------------
  // Settings & Elision Telephony
  // ---------------------------------------------------------------------------
  Future<CrmSettings> getSettings() async {
    return _dio.getEnvelope<CrmSettings>(
      'crm/settings',
      queryParameters: {'scope': crmScopeNotifier.value},
      parse: (raw) => CrmSettings.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<CrmSettings> updateSettings(Map<String, dynamic> data) async {
    return _dio.putEnvelope<CrmSettings>(
      'crm/settings',
      data: data,
      parse: (raw) => CrmSettings.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<Map<String, dynamic>> reportTelecallerActivity(String status) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telecallers/activity?scope=${crmScopeNotifier.value}',
      data: {'status': status, 'scope': crmScopeNotifier.value},
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<WaitingQueueStatus> getWaitingQueueStatus() async {
    return _dio.getEnvelope<WaitingQueueStatus>(
      'crm/waiting-queue/status',
      queryParameters: {'scope': crmScopeNotifier.value},
      parse: (raw) => WaitingQueueStatus.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<Map<String, dynamic>> dispatchWaitingQueue() async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/waiting-queue/dispatch?scope=${crmScopeNotifier.value}',
      data: {'scope': crmScopeNotifier.value},
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<CrmTelecallerTelephonyList> listTelecallerTelephony() async {
    return _dio.getEnvelope<CrmTelecallerTelephonyList>(
      'crm/telephony/telecallers',
      parse: (raw) => CrmTelecallerTelephonyList.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<CrmTelecallerTelephony> saveTelecallerTelephony(
    int employeeId,
    Map<String, dynamic> config,
  ) async {
    return _dio.putEnvelope<CrmTelecallerTelephony>(
      'crm/telephony/telecallers/$employeeId',
      data: config,
      parse: (raw) => CrmTelecallerTelephony.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<Map<String, dynamic>> clickToCall(String leadId, {String? agentId}) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/click-to-call',
      data: {'leadId': leadId, if (agentId != null) 'agentId': agentId},
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> testNineanceConnection() async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/test-connection',
      data: {},
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> activateNineance([Map<String, dynamic>? body]) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/activate',
      data: body ?? {},
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<List<Map<String, dynamic>>> listNineanceAgents() async {
    return _dio.getEnvelope<List<Map<String, dynamic>>>(
      'crm/telephony/agents',
      parse: (raw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final list = map['agents'] ?? raw;
        if (list is! List) return [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      },
    );
  }

  Future<Map<String, dynamic>> createNineanceAgent({
    required String name,
    required String phone,
    String access = '2',
    String? sipPassword,
  }) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/agents',
      data: {
        'name': name,
        'phone': phone,
        'access': access,
        if (sipPassword != null && sipPassword.isNotEmpty) 'sip_password': sipPassword,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<void> deleteNineanceAgent(String agentId) async {
    await _dio.deleteEnvelope<void>(
      'crm/telephony/agents/$agentId',
      parse: (_) {},
    );
  }

  Future<List<Map<String, dynamic>>> syncNineanceAgents() async {
    return _dio.postEnvelope<List<Map<String, dynamic>>>(
      'crm/telephony/agents/sync',
      data: {},
      parse: (raw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final list = map['agents'] ?? raw;
        if (list is! List) return [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      },
    );
  }

  Future<Map<String, dynamic>> assignNineanceAgent(
    String agentId, {
    int? employeeId,
    String? userId,
  }) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/agents/$agentId/assign',
      data: {
        if (employeeId != null) 'employee_id': employeeId,
        if (userId != null) 'user_id': userId,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> setNineanceAgentStatus(
    String agentId,
    String status, {
    String? breakType,
  }) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/agents/$agentId/status',
      data: {
        'status': status,
        if (breakType != null) 'break_type': breakType,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<List<Map<String, dynamic>>> listNineanceDids() async {
    return _dio.getEnvelope<List<Map<String, dynamic>>>(
      'crm/telephony/dids',
      parse: (raw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final list = map['dids'] ?? raw;
        if (list is! List) return [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      },
    );
  }

  Future<List<Map<String, dynamic>>> syncNineanceDids() async {
    return _dio.postEnvelope<List<Map<String, dynamic>>>(
      'crm/telephony/dids/sync',
      data: {},
      parse: (raw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final list = map['dids'] ?? raw;
        if (list is! List) return [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      },
    );
  }

  Future<Map<String, dynamic>> setNineanceDefaultDid(String didId) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/dids/$didId/set-default',
      data: {},
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> syncNineanceCalls() async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/calls/sync',
      data: {},
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> getNineanceDialerConfig() async {
    return _dio.getEnvelope<Map<String, dynamic>>(
      'crm/telephony/dialer-config',
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> getNineanceWsToken() async {
    return _dio.getEnvelope<Map<String, dynamic>>(
      'crm/telephony/ws-token',
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<dynamic> listNineanceLiveCalls() async {
    return _dio.getEnvelope<dynamic>(
      'crm/telephony/live-calls',
      parse: (raw) => raw,
    );
  }

  Future<Map<String, dynamic>> matchNineancePhone(String phone) async {
    return _dio.getEnvelope<Map<String, dynamic>>(
      'crm/telephony/match-phone',
      queryParameters: {'phone': phone},
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> dispositionNineanceCall(
    String callId, {
    required String disposition,
    String? notes,
    String? followUpAt,
  }) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/calls/$callId/disposition',
      data: {
        'disposition': disposition,
        if (notes != null) 'notes': notes,
        if (followUpAt != null) 'follow_up_at': followUpAt,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<dynamic> listNineanceCampaigns() async {
    return _dio.getEnvelope<dynamic>(
      'crm/telephony/campaigns',
      parse: (raw) => raw,
    );
  }

  Future<Map<String, dynamic>> createNineanceCampaign(Map<String, dynamic> body) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/campaigns',
      data: body,
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> startNineanceCampaign(String id) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/campaigns/$id/start',
      data: {},
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> stopNineanceCampaign(String id) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/campaigns/$id/stop',
      data: {},
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<Map<String, dynamic>> nineanceCampaignReport(String id) async {
    return _dio.getEnvelope<Map<String, dynamic>>(
      'crm/telephony/campaigns/$id/report',
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<CrmKpiMetrics> getKpiMetrics({
    String? projectId,
    String? campaignId,
  }) async {
    final now = DateTime.now();
    final localDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final query = <String, dynamic>{
      'date': localDate,
    };
    if (projectId != null && projectId.isNotEmpty && projectId != 'ALL') {
      query['projectId'] = projectId;
    }
    if (campaignId != null && campaignId.isNotEmpty && campaignId != 'ALL') {
      query['campaignId'] = campaignId;
    }
    return _dio.getEnvelope<CrmKpiMetrics>(
      'crm/kpi',
      queryParameters: query.isEmpty ? null : query,
      parse: (raw) => CrmKpiMetrics.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<List<CrmCallLog>> getCallLogs({
    String? leadId,
    bool? hasRecording,
    String? search,
    String? dateFilter,
    String? startDate,
    String? endDate,
    String? callStatus,
    String? did,
    int? limit,
  }) async {
    final query = <String, dynamic>{
      'scope': crmScopeNotifier.value,
    };
    if (leadId != null) query['leadId'] = leadId;
    if (hasRecording != null) query['hasRecording'] = hasRecording.toString();
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (dateFilter != null && dateFilter.isNotEmpty) query['dateFilter'] = dateFilter;
    if (startDate != null) query['startDate'] = startDate;
    if (endDate != null) query['endDate'] = endDate;
    if (callStatus != null && callStatus != 'ALL') query['callStatus'] = callStatus;
    if (did != null && did != 'ALL') query['did'] = did;
    if (limit != null) query['limit'] = limit.toString();

    return _dio.getEnvelope<List<CrmCallLog>>(
      'crm/telephony/call-logs',
      queryParameters: query.isEmpty ? null : query,
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => CrmCallLog.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<CrmCallLog> updateCallLog(
    String id, {
    String? recordingUrl,
    int? duration,
    String? callStatus,
  }) async {
    final body = <String, dynamic>{};
    if (recordingUrl != null) body['recordingUrl'] = recordingUrl;
    if (duration != null) body['duration'] = duration;
    if (callStatus != null) body['callStatus'] = callStatus;

    return _dio.patchEnvelope<CrmCallLog>(
      'crm/telephony/call-logs/$id',
      data: body,
      parse: (raw) => CrmCallLog.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  // ---------------------------------------------------------------------------
  // HRMS Employee Lookup for Sales Assignment
  // ---------------------------------------------------------------------------
  Future<List<CrmSalesUser>> getHrmsEmployees() async {
    return _dio.getEnvelope<List<CrmSalesUser>>(
      'crm/sales-users',
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => CrmSalesUser.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // WhatsApp Automation API
  // ---------------------------------------------------------------------------
  Future<CrmWhatsappConfig> getWhatsappConfig() async {
    return _dio.getEnvelope<CrmWhatsappConfig>(
      'crm/whatsapp/config',
      parse: (raw) => CrmWhatsappConfig.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<CrmWhatsappConfig> updateWhatsappConfig(Map<String, dynamic> config) async {
    return _dio.putEnvelope<CrmWhatsappConfig>(
      'crm/whatsapp/config',
      data: config,
      parse: (raw) => CrmWhatsappConfig.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<Map<String, dynamic>> testWhatsappConnection() async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/whatsapp/test-connection',
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> syncWhatsappTemplates() async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/whatsapp/sync-templates',
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<List<BotbizTemplateModel>> getWhatsappTemplates() async {
    return _dio.getEnvelope<List<BotbizTemplateModel>>(
      'crm/whatsapp/templates',
      parse: (raw) {
        if (raw is! Map) return [];
        final list = raw['templates'];
        if (list is! List) return [];
        return list
            .map((e) => BotbizTemplateModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<Map<String, dynamic>> checkWhatsappTemplateStatus(String templateId) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/whatsapp/template-status/$templateId',
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> retryWhatsappLog(String logId) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/whatsapp/retry/$logId',
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> testWhatsapp(String phone, [String? message, String? templateId]) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/whatsapp/test',
      data: {
        'phone': phone,
        if (message != null) 'message': message,
        if (templateId != null) 'templateId': templateId,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<List<CrmWhatsappLogItem>> getWhatsappLogs([int limit = 50]) async {
    return _dio.getEnvelope<List<CrmWhatsappLogItem>>(
      'crm/whatsapp/logs',
      queryParameters: {'limit': limit},
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => CrmWhatsappLogItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<Map<String, dynamic>> sendLeadWhatsapp(
    String leadId, {
    String? phone,
    String? event,
    String? message,
    String? mediaUrl,
    String? headerMediaUrl,
    String? headerText,
    String? templateId,
    String? templateName,
    String? templateEndpoint,
    Map<String, String>? variables,
  }) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/leads/$leadId/whatsapp',
      data: {
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (event != null) 'event': event,
        if (message != null) 'message': message,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (headerMediaUrl != null) 'headerMediaUrl': headerMediaUrl,
        if (headerText != null) 'headerText': headerText,
        if (templateId != null) 'templateId': templateId,
        if (templateName != null) 'templateName': templateName,
        if (templateEndpoint != null) 'templateEndpoint': templateEndpoint,
        if (variables != null) 'variables': variables,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  // ---------------------------------------------------------------------------
  // Virtual Building Elevation & Inventory
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getVirtualBuilding({
    required String projectId,
    required String towerId,
  }) async {
    return _dio.getEnvelope<Map<String, dynamic>>(
      'crm/virtual-building',
      queryParameters: {
        'projectId': projectId,
        'towerId': towerId,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> updateVirtualBuildingUnit(Map<String, dynamic> data) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/virtual-building/unit-action',
      data: data,
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  // ---------------------------------------------------------------------------
  // Finserve Application Form & Client Portal
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> updateLeadApplicationDetails(
    String leadId,
    Map<String, dynamic> data,
  ) async {
    return _dio.putEnvelope<Map<String, dynamic>>(
      'crm/leads/$leadId/application-details',
      data: data,
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> generateClientPortalLink(String leadId) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/leads/$leadId/portal-link',
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> uploadLeadDoc(
    String leadId, {
    required String docTypeId,
    required String docName,
    required List<int> bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'docTypeId': docTypeId,
      'docName': docName,
      'document': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/leads/$leadId/upload-doc',
      data: formData,
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  // ---------------------------------------------------------------------------
  // Finserve Bank Processing, Post-Sanction & Disbursement Pipeline
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> updateFinservePipeline(
    String leadId,
    Map<String, dynamic> data,
  ) async {
    return _dio.putEnvelope<Map<String, dynamic>>(
      'crm/leads/$leadId/finserve-pipeline',
      data: data,
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> addBankQuery(
    String leadId, {
    required String query,
    required String required,
    String? stage,
  }) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/leads/$leadId/bank-queries',
      data: {
        'query': query,
        'required': required,
        if (stage != null) 'stage': stage,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> resolveBankQuery(
    String leadId,
    String queryId, {
    String? resolutionNotes,
  }) async {
    return _dio.patchEnvelope<Map<String, dynamic>>(
      'crm/leads/$leadId/bank-queries/$queryId/resolve',
      data: {
        if (resolutionNotes != null) 'resolutionNotes': resolutionNotes,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<Map<String, dynamic>> wipeRealEstatePreSalesData() async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/admin/wipe-real-estate-presales',
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  // ---------------------------------------------------------------------------
  // NB Hub Partners Integration
  // ---------------------------------------------------------------------------
  Future<List<HubPartner>> getHubPartners({String? role, String? status, String? search}) async {
    return _dio.getEnvelope<List<HubPartner>>(
      'crm/partners',
      queryParameters: {
        if (role != null && role.isNotEmpty && role != 'ALL') 'role': role,
        if (status != null && status.isNotEmpty && status != 'ALL') 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
      parse: (raw) {
        if (raw is! List) return [];
        return raw
            .map((e) => HubPartner.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
    );
  }

  Future<HubPartner?> getHubPartnerProfile(String identifier) async {
    return _dio.getEnvelope<HubPartner?>(
      'crm/partners/profile/${Uri.encodeComponent(identifier)}',
      parse: (raw) {
        if (raw == null) return null;
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          return HubPartner.fromJson(m);
        }
        return null;
      },
    );
  }

  Future<HubPartner> createHubPartner(Map<String, dynamic> data) async {
    return _dio.postEnvelope<HubPartner>(
      'crm/partners',
      data: data,
      parse: (raw) => HubPartner.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<HubPartner> updateHubPartner(String id, Map<String, dynamic> data) async {
    return _dio.putEnvelope<HubPartner>(
      'crm/partners/${Uri.encodeComponent(id)}',
      data: data,
      parse: (raw) => HubPartner.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<bool> deleteHubPartner(String id) async {
    return _dio.deleteEnvelope<bool>(
      'crm/partners/${Uri.encodeComponent(id)}',
      parse: (raw) {
        if (raw is Map && raw['success'] == true) return true;
        return true;
      },
    );
  }

  Future<List<Map<String, dynamic>>> getHubTrash() async {
    return _dio.getEnvelope<List<Map<String, dynamic>>>(
      'crm/partners/trash',
      parse: (raw) {
        if (raw is! List) return [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      },
    );
  }
}


