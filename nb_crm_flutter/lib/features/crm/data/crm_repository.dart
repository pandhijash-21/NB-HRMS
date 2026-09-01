import 'dart:typed_data';
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/crm_models.dart';

class CrmRepository {
  final DioClient _dio;

  const CrmRepository({required DioClient dioClient}) : _dio = dioClient;

  // ---------------------------------------------------------------------------
  // Projects
  // ---------------------------------------------------------------------------
  Future<List<CrmProject>> getProjects() async {
    return _dio.getEnvelope<List<CrmProject>>(
      'crm/projects',
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
    final query = <String, dynamic>{'module': module};
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
    final query = <String, dynamic>{'module': module};
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
    int? assignedToId,
    int page = 1,
    int limit = 100,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
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
  }) async {
    final map = <String, dynamic>{
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    };
    if (campaignId != null && campaignId.isNotEmpty) {
      map['campaignId'] = campaignId;
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

  Future<CrmLead> updateLeadStatus(
    String leadId, {
    required String status,
    String? scheduledDate,
    String? scheduledTime,
    String? remarks,
    int? assignedToId,
  }) async {
    return _dio.patchEnvelope<CrmLead>(
      'crm/leads/$leadId/status',
      data: {
        'status': status,
        if (scheduledDate != null) 'scheduledDate': scheduledDate,
        if (scheduledTime != null) 'scheduledTime': scheduledTime,
        if (remarks != null) 'remarks': remarks,
        if (assignedToId != null) 'assignedToId': assignedToId,
      },
      parse: (raw) => CrmLead.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<CrmLead> updateLead(String leadId, Map<String, dynamic> data) async {
    return _dio.patchEnvelope<CrmLead>(
      'crm/leads/$leadId',
      data: data,
      parse: (raw) => CrmLead.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> moveToBin(String leadId) async {
    await _dio.deleteEnvelope<void>(
      'crm/leads/$leadId',
      parse: (_) {},
    );
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
    final query = <String, dynamic>{};
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

  Future<Map<String, dynamic>> clickToCall(String leadId, {String? agentId}) async {
    return _dio.postEnvelope<Map<String, dynamic>>(
      'crm/telephony/click-to-call',
      data: {'leadId': leadId, if (agentId != null) 'agentId': agentId},
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<CrmKpiMetrics> getKpiMetrics({
    String? projectId,
    String? campaignId,
  }) async {
    final query = <String, dynamic>{};
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
    final query = <String, dynamic>{};
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
}
