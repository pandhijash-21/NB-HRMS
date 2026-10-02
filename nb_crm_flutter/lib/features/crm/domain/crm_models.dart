import 'dart:convert';
import 'package:intl/intl.dart';

class CrmProject {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String? location;
  final DateTime? startDate;
  final bool isActive;
  final int campaignCount;
  final List<CrmCampaign> campaigns;

  const CrmProject({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.location,
    this.startDate,
    this.isActive = true,
    this.campaignCount = 0,
    this.campaigns = const [],
  });

  factory CrmProject.fromJson(Map<String, dynamic> json) {
    var rawCampaigns = json['campaigns'] as List<dynamic>?;
    return CrmProject(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String?,
      location: json['location'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())?.toLocal()
          : null,
      isActive: json['isActive'] as bool? ?? true,
      campaignCount: (json['_count']?['campaigns'] as num?)?.toInt() ?? (rawCampaigns?.length ?? 0),
      campaigns: rawCampaigns != null
          ? rawCampaigns.map((c) => CrmCampaign.fromJson(Map<String, dynamic>.from(c as Map))).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'description': description,
        'location': location,
        'startDate': startDate?.toIso8601String(),
        'isActive': isActive,
      };
}

class CrmCampaign {
  final String id;
  final String? projectId;
  final String? projectName;
  final String name;
  final String code;
  final String? adId;
  final String? webhookToken;
  final String? description;
  final DateTime? startDate;
  final String module;
  final bool isActive;
  final int columnsCount;
  final int leadsCount;

  const CrmCampaign({
    required this.id,
    this.projectId,
    this.projectName,
    required this.name,
    required this.code,
    this.adId,
    this.webhookToken,
    this.description,
    this.startDate,
    this.module = 'PRE_SALES',
    this.isActive = true,
    this.columnsCount = 0,
    this.leadsCount = 0,
  });

  String get webhookUrl {
    if (webhookToken == null || webhookToken!.isEmpty) return '';
    return 'https://crm.nbdeveloper.co.in/api/crm/campaigns/$webhookToken/webhook';
  }

  factory CrmCampaign.fromJson(Map<String, dynamic> json) {
    return CrmCampaign(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String?,
      projectName: json['projectName'] as String?,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      adId: json['adId'] as String?,
      webhookToken: json['webhookToken'] as String?,
      description: json['description'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())?.toLocal()
          : null,
      module: json['module'] as String? ?? 'PRE_SALES',
      isActive: json['isActive'] as bool? ?? true,
      columnsCount: (json['columnsCount'] as num?)?.toInt() ??
          ((json['_count'] is Map ? (json['_count'] as Map)['columns'] : null) as num?)?.toInt() ??
          0,
      leadsCount: (json['leadsCount'] as num?)?.toInt() ??
          ((json['_count'] is Map ? (json['_count'] as Map)['leads'] : null) as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'name': name,
        'code': code,
        'adId': adId,
        'webhookToken': webhookToken,
        'description': description,
        'startDate': startDate?.toIso8601String(),
        'module': module,
        'isActive': isActive,
      };
}

class CrmColumnConfig {
  final String id;
  final String module;
  final String? campaignId;
  final String columnKey;
  final String label;
  final String dataType;
  final List<String> options;
  final bool isRequired;
  final bool isSystem;
  final bool isVisibleInTable;
  final int displayOrder;
  final bool isActive;

  const CrmColumnConfig({
    required this.id,
    required this.module,
    this.campaignId,
    required this.columnKey,
    required this.label,
    required this.dataType,
    required this.options,
    required this.isRequired,
    required this.isSystem,
    this.isVisibleInTable = true,
    required this.displayOrder,
    required this.isActive,
  });

  factory CrmColumnConfig.fromJson(Map<String, dynamic> json) {
    return CrmColumnConfig(
      id: json['id'] as String? ?? '',
      module: json['module'] as String? ?? 'PRE_SALES',
      campaignId: json['campaignId'] as String?,
      columnKey: json['columnKey'] as String? ?? '',
      label: json['label'] as String? ?? '',
      dataType: json['dataType'] as String? ?? 'TEXT',
      options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isRequired: json['isRequired'] as bool? ?? false,
      isSystem: json['isSystem'] as bool? ?? false,
      isVisibleInTable: json['isVisibleInTable'] as bool? ?? true,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'module': module,
        'campaignId': campaignId,
        'columnKey': columnKey,
        'label': label,
        'dataType': dataType,
        'options': options,
        'isRequired': isRequired,
        'isSystem': isSystem,
        'isVisibleInTable': isVisibleInTable,
        'displayOrder': displayOrder,
        'isActive': isActive,
      };
}

enum CrmStatus {
  notStarted,
  cnr,
  scheduledVisit,
  notInterested,
  siteVisitDone,
  followUp,
  interested,
  proposalSent,
  bookingConfirmed,
  rejected;

  String get backendValue {
    switch (this) {
      case CrmStatus.notStarted:
        return 'NOT_STARTED';
      case CrmStatus.cnr:
        return 'CNR';
      case CrmStatus.scheduledVisit:
        return 'SCHEDULED_VISIT';
      case CrmStatus.notInterested:
        return 'NOT_INTERESTED';
      case CrmStatus.siteVisitDone:
        return 'SITE_VISIT_DONE';
      case CrmStatus.followUp:
        return 'FOLLOW_UP';
      case CrmStatus.interested:
        return 'INTERESTED';
      case CrmStatus.proposalSent:
        return 'PROPOSAL_SENT';
      case CrmStatus.bookingConfirmed:
        return 'BOOKING_CONFIRMED';
      case CrmStatus.rejected:
        return 'REJECTED';
    }
  }

  String get displayName {
    switch (this) {
      case CrmStatus.notStarted:
        return 'Not started';
      case CrmStatus.cnr:
        return 'CNR (Call Not received)';
      case CrmStatus.scheduledVisit:
        return 'Schedule A Visit';
      case CrmStatus.notInterested:
        return 'Not Interested';
      case CrmStatus.siteVisitDone:
        return 'Site Visit Done';
      case CrmStatus.followUp:
        return 'Follow up';
      case CrmStatus.interested:
        return 'Interested';
      case CrmStatus.proposalSent:
        return 'Proposal Sent';
      case CrmStatus.bookingConfirmed:
        return 'Booking Confirmed';
      case CrmStatus.rejected:
        return 'Rejected';
    }
  }

  static CrmStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'CNR':
        return CrmStatus.cnr;
      case 'SCHEDULED_VISIT':
        return CrmStatus.scheduledVisit;
      case 'SITE_VISIT_DONE':
        return CrmStatus.siteVisitDone;
      case 'FOLLOW_UP':
        return CrmStatus.followUp;
      case 'INTERESTED':
        return CrmStatus.interested;
      case 'PROPOSAL_SENT':
        return CrmStatus.proposalSent;
      case 'BOOKING_CONFIRMED':
        return CrmStatus.bookingConfirmed;
      case 'REJECTED':
        return CrmStatus.rejected;
      case 'NOT_INTERESTED':
        return CrmStatus.notInterested;
      case 'NOT_STARTED':
      default:
        return CrmStatus.notStarted;
    }
  }
}

class CrmLead {
  final String id;
  final String? campaignId;
  final String? campaignName;
  final String phone;
  final String name;
  final CrmStatus status;
  final Map<String, dynamic> customFields;
  final int? assignedToId;
  final String? assignedToName;
  final int? telecallerId;
  final String? telecallerName;
  final DateTime? lastCallAt;
  final DateTime? notInterestedAt;
  final String? notInterestedReason;
  final String? notInterestedRemark;
  final DateTime? scheduledVisitAt;
  final DateTime? visitedAt;
  final String? leadSource;
  final String? channelPartnerName;
  final String? referenceType;
  final String? referenceName;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CrmFollowUp? latestFollowUp;

  const CrmLead({
    required this.id,
    this.campaignId,
    this.campaignName,
    required this.phone,
    required this.name,
    required this.status,
    required this.customFields,
    this.assignedToId,
    this.assignedToName,
    this.telecallerId,
    this.telecallerName,
    this.lastCallAt,
    this.notInterestedAt,
    this.notInterestedReason,
    this.notInterestedRemark,
    this.scheduledVisitAt,
    this.visitedAt,
    this.leadSource,
    this.channelPartnerName,
    this.referenceType,
    this.referenceName,
    required this.isDeleted,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.latestFollowUp,
  });

  factory CrmLead.fromJson(Map<String, dynamic> json) {
    String? assignedName;
    if (json['assignedTo'] != null && json['assignedTo']['generalInfo'] != null) {
      assignedName = json['assignedTo']['generalInfo']['fullName'] as String?;
    }

    String? teleName;
    if (json['telecaller'] != null && json['telecaller']['generalInfo'] != null) {
      teleName = json['telecaller']['generalInfo']['fullName'] as String?;
    }

    String? campName;
    if (json['campaign'] != null) {
      campName = json['campaign']['name'] as String?;
    }

    CrmFollowUp? followUp;
    if (json['followUps'] is List && (json['followUps'] as List).isNotEmpty) {
      final first = (json['followUps'] as List).first;
      if (first is Map) {
        final parsed = CrmFollowUp.fromJson(Map<String, dynamic>.from(first));
        if (parsed.status.toUpperCase() == 'PENDING') {
          followUp = parsed;
        }
      }
    }

    return CrmLead(
      id: json['id'] as String? ?? '',
      campaignId: json['campaignId'] as String?,
      campaignName: campName,
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: CrmStatus.fromString(json['status'] as String?),
      customFields: json['customFields'] is Map ? Map<String, dynamic>.from(json['customFields'] as Map) : {},
      assignedToId: (json['assignedToId'] as num?)?.toInt(),
      assignedToName: assignedName,
      telecallerId: (json['telecallerId'] as num?)?.toInt(),
      telecallerName: teleName,
      lastCallAt: json['lastCallAt'] != null ? DateTime.tryParse(json['lastCallAt'].toString()) : null,
      notInterestedAt: json['notInterestedAt'] != null ? DateTime.tryParse(json['notInterestedAt'].toString()) : null,
      notInterestedReason: json['notInterestedReason'] as String?,
      notInterestedRemark: json['notInterestedRemark'] as String?,
      scheduledVisitAt: json['scheduledVisitAt'] != null ? DateTime.tryParse(json['scheduledVisitAt'].toString())?.toLocal() : null,
      visitedAt: json['visitedAt'] != null ? DateTime.tryParse(json['visitedAt'].toString())?.toLocal() : null,
      leadSource: json['leadSource'] as String?,
      channelPartnerName: json['channelPartnerName'] as String?,
      referenceType: json['referenceType'] as String?,
      referenceName: json['referenceName'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'].toString()) : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      latestFollowUp: followUp,
    );
  }

  List<CrmProposal> get proposals {
    final raw = customFields['proposals'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => CrmProposal.fromJson(Map<String, dynamic>.from(m)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return const [];
  }

  Map<String, dynamic>? get unitShown {
    final raw = customFields['unitShown'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String? get email {
    final e = customFields['Email'] ?? customFields['email'] ?? customFields['client_email'];
    if (e != null && e.toString().trim().isNotEmpty) return e.toString().trim();
    return null;
  }

  String? get address {
    final a = customFields['Address'] ?? customFields['address'] ?? customFields['Location'] ?? customFields['location'];
    if (a != null && a.toString().trim().isNotEmpty) return a.toString().trim();
    return null;
  }

  List<CrmCustomerLog> get activityLogs {
    final raw = customFields['activityLogs'];
    final logs = <CrmCustomerLog>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            logs.add(CrmCustomerLog.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
    }
    return logs..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
}

class CrmFollowUp {
  final String id;
  final String leadId;
  final String? leadName;
  final String? leadPhone;
  final DateTime scheduledDate;
  final String scheduledTime;
  final String? remarks;
  final String status;
  final int? assignedToId;
  final String? assignedToName;
  final DateTime createdAt;

  const CrmFollowUp({
    required this.id,
    required this.leadId,
    this.leadName,
    this.leadPhone,
    required this.scheduledDate,
    required this.scheduledTime,
    this.remarks,
    required this.status,
    this.assignedToId,
    this.assignedToName,
    required this.createdAt,
  });

  factory CrmFollowUp.fromJson(Map<String, dynamic> json) {
    String? name;
    String? phone;
    if (json['lead'] is Map) {
      name = json['lead']['name'] as String?;
      phone = json['lead']['phone'] as String?;
    }

    String? assignedName;
    if (json['assignedTo'] != null && json['assignedTo']['generalInfo'] != null) {
      assignedName = json['assignedTo']['generalInfo']['fullName'] as String?;
    }

    return CrmFollowUp(
      id: json['id'] as String? ?? '',
      leadId: json['leadId'] as String? ?? '',
      leadName: name,
      leadPhone: phone,
      scheduledDate: DateTime.tryParse(json['scheduledDate']?.toString() ?? '') ?? DateTime.now(),
      scheduledTime: json['scheduledTime'] as String? ?? '10:00 AM',
      remarks: json['remarks'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      assignedToId: (json['assignedToId'] as num?)?.toInt(),
      assignedToName: assignedName,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class CrmSalesUser {
  final int employeeId;
  final String fullName;
  final String? designation;
  final String? department;

  const CrmSalesUser({
    required this.employeeId,
    required this.fullName,
    this.designation,
    this.department,
  });

  factory CrmSalesUser.fromJson(Map<String, dynamic> json) {
    final empId = (json['employeeId'] as num?)?.toInt() ??
        (json['id'] as num?)?.toInt() ??
        0;
    String name = (json['fullName'] as String?) ?? 'Sales User';
    String? desig = json['designation'] as String?;
    String? dept = json['department'] as String?;

    if (json['generalInfo'] is Map) {
      name = json['generalInfo']['fullName'] as String? ?? name;
      desig = json['generalInfo']['designation'] as String? ?? desig;
      dept = json['generalInfo']['department'] as String? ?? dept;
    } else if (json['name'] is String) {
      name = json['name'] as String;
    }

    return CrmSalesUser(
      employeeId: empId,
      fullName: name,
      designation: desig,
      department: dept,
    );
  }
}

class CrmSettings {
  final String elisionApiUrl;
  final String elisionUserId;
  final String elisionDid;
  final String elisionRouteNumber;
  final String elisionDefaultAgentNumber;
  final String elisionApiKey;
  final String elisionCampaignId;
  final String elisionAgentId;
  final int notInterestedRetentionDays;
  final int binRetentionDays;

  // Pre-Sales and Visitor Check-in Configurations
  final List<String> notInterestedReasons;
  final List<String> leadSources;
  final List<String> referenceTypes;
  final int? siteVisitDeskEmployeeId;

  // KPI Management Toggles
  final bool kpiShowActiveLeads;
  final bool kpiShowTodayFollowups;
  final bool kpiShowInterestedDeals;
  final bool kpiShowBinCount;
  final bool kpiShowTotalCalls;
  final bool kpiShowAnsweredCalls;
  final bool kpiShowMissedCalls;
  final bool kpiShowTalkTime;
  final bool kpiShowFreshLeads;
  final bool kpiShowConversionRate;

  const CrmSettings({
    required this.elisionApiUrl,
    required this.elisionUserId,
    required this.elisionDid,
    required this.elisionRouteNumber,
    required this.elisionDefaultAgentNumber,
    required this.elisionApiKey,
    required this.elisionCampaignId,
    required this.elisionAgentId,
    required this.notInterestedRetentionDays,
    required this.binRetentionDays,
    this.notInterestedReasons = const [
      'Budget mismatch',
      'Found somewhere else',
      'Locality mismatch',
      'Others',
    ],
    this.leadSources = const [
      'Walk IN',
      'Channel Partner',
      'Reference',
    ],
    this.referenceTypes = const [
      'B2B',
      'Employee',
      'Other Client',
    ],
    this.siteVisitDeskEmployeeId,
    this.kpiShowActiveLeads = true,
    this.kpiShowTodayFollowups = true,
    this.kpiShowInterestedDeals = true,
    this.kpiShowBinCount = true,
    this.kpiShowTotalCalls = true,
    this.kpiShowAnsweredCalls = true,
    this.kpiShowMissedCalls = true,
    this.kpiShowTalkTime = true,
    this.kpiShowFreshLeads = true,
    this.kpiShowConversionRate = true,
  });

  static List<String> _parseList(dynamic raw, List<String> fallback) {
    if (raw == null) return fallback;
    if (raw is List) return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }
      } catch (_) {
        return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }
    return fallback;
  }

  factory CrmSettings.fromJson(Map<String, dynamic> json) {
    return CrmSettings(
      elisionApiUrl: json['elision_api_url'] as String? ?? 'https://greeter.co.in/api/click2call',
      elisionUserId: json['elision_user_id'] as String? ?? '634550',
      elisionDid: json['elision_did'] as String? ?? '9484700070',
      elisionRouteNumber: json['elision_route_number'] as String? ?? '98',
      elisionDefaultAgentNumber: json['elision_default_agent_number'] as String? ?? '8511139384',
      elisionApiKey: json['elision_api_key'] as String? ?? '',
      elisionCampaignId: json['elision_campaign_id'] as String? ?? '',
      elisionAgentId: json['elision_agent_id'] as String? ?? '',
      notInterestedRetentionDays: int.tryParse(json['not_interested_retention_days']?.toString() ?? '30') ?? 30,
      binRetentionDays: int.tryParse(json['bin_retention_days']?.toString() ?? '30') ?? 30,
      notInterestedReasons: _parseList(json['not_interested_reasons'], const [
        'Budget mismatch',
        'Found somewhere else',
        'Locality mismatch',
        'Others',
      ]),
      leadSources: _parseList(json['lead_sources'], const [
        'Walk IN',
        'Channel Partner',
        'Reference',
      ]),
      referenceTypes: _parseList(json['reference_types'], const [
        'B2B',
        'Employee',
        'Other Client',
      ]),
      siteVisitDeskEmployeeId: int.tryParse(json['site_visit_desk_employee_id']?.toString() ?? ''),
      kpiShowActiveLeads: json['kpi_show_active_leads']?.toString() != 'false',
      kpiShowTodayFollowups: json['kpi_show_today_followups']?.toString() != 'false',
      kpiShowInterestedDeals: json['kpi_show_interested_deals']?.toString() != 'false',
      kpiShowBinCount: json['kpi_show_bin_count']?.toString() != 'false',
      kpiShowTotalCalls: json['kpi_show_total_calls']?.toString() != 'false',
      kpiShowAnsweredCalls: json['kpi_show_answered_calls']?.toString() != 'false',
      kpiShowMissedCalls: json['kpi_show_missed_calls']?.toString() != 'false',
      kpiShowTalkTime: json['kpi_show_talk_time']?.toString() != 'false',
      kpiShowFreshLeads: json['kpi_show_fresh_leads']?.toString() != 'false',
      kpiShowConversionRate: json['kpi_show_conversion_rate']?.toString() != 'false',
    );
  }
}

class CrmTelecallerTelephonyConfig {
  const CrmTelecallerTelephonyConfig({
    required this.apiUrl,
    required this.userId,
    required this.did,
    required this.routeNumber,
    required this.agentNumber,
  });

  final String apiUrl;
  final String userId;
  final String did;
  final String routeNumber;
  final String agentNumber;

  factory CrmTelecallerTelephonyConfig.fromJson(Map<String, dynamic> json) {
    return CrmTelecallerTelephonyConfig(
      apiUrl: json['api_url']?.toString() ?? 'https://greeter.co.in/api/click2call',
      userId: json['user_id']?.toString() ?? '',
      did: json['did']?.toString() ?? '',
      routeNumber: json['route_number']?.toString() ?? '',
      agentNumber: json['agent_number']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'api_url': apiUrl,
        'user_id': userId,
        'did': did,
        'route_number': routeNumber,
        'agent_number': agentNumber,
      };
}

class CrmTelecallerTelephony {
  const CrmTelecallerTelephony({
    required this.employeeId,
    required this.name,
    this.employeeCode,
    this.designation,
    this.configured = false,
    required this.config,
  });

  final int employeeId;
  final String name;
  final String? employeeCode;
  final String? designation;
  final bool configured;
  final CrmTelecallerTelephonyConfig config;

  factory CrmTelecallerTelephony.fromJson(Map<String, dynamic> json) {
    final cfg = json['config'];
    return CrmTelecallerTelephony(
      employeeId: (json['employeeId'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Telecaller',
      employeeCode: json['employeeCode']?.toString(),
      designation: json['designation']?.toString(),
      configured: json['configured'] == true,
      config: cfg is Map
          ? CrmTelecallerTelephonyConfig.fromJson(Map<String, dynamic>.from(cfg))
          : const CrmTelecallerTelephonyConfig(
              apiUrl: 'https://greeter.co.in/api/click2call',
              userId: '',
              did: '',
              routeNumber: '',
              agentNumber: '',
            ),
    );
  }
}

class CrmTelecallerTelephonyList {
  const CrmTelecallerTelephonyList({
    required this.telecallers,
    this.defaults,
  });

  final List<CrmTelecallerTelephony> telecallers;
  final CrmTelecallerTelephonyConfig? defaults;

  factory CrmTelecallerTelephonyList.fromJson(Map<String, dynamic> json) {
    final list = json['telecallers'];
    final defaults = json['defaults'];
    return CrmTelecallerTelephonyList(
      telecallers: list is List
          ? list
              .map((e) => CrmTelecallerTelephony.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
      defaults: defaults is Map
          ? CrmTelecallerTelephonyConfig.fromJson(Map<String, dynamic>.from(defaults))
          : null,
    );
  }
}

class CrmKpiMetrics {
  final int totalActiveLeads;
  final int todayFollowUps;
  final int interestedDeals;
  final int binCount;
  final int freshLeads;
  final int followUpLeads;
  final int totalCalls;
  final int answeredCalls;
  final int missedCalls;
  final int totalTalkTimeMinutes;
  final double conversionRate;

  const CrmKpiMetrics({
    required this.totalActiveLeads,
    required this.todayFollowUps,
    required this.interestedDeals,
    required this.binCount,
    this.freshLeads = 0,
    this.followUpLeads = 0,
    this.totalCalls = 0,
    this.answeredCalls = 0,
    this.missedCalls = 0,
    this.totalTalkTimeMinutes = 0,
    this.conversionRate = 0.0,
  });

  factory CrmKpiMetrics.fromJson(Map<String, dynamic> json) {
    return CrmKpiMetrics(
      totalActiveLeads: (json['totalActiveLeads'] as num?)?.toInt() ?? 0,
      todayFollowUps: (json['todayFollowUps'] as num?)?.toInt() ?? 0,
      interestedDeals: (json['interestedDeals'] as num?)?.toInt() ?? 0,
      binCount: (json['binCount'] as num?)?.toInt() ?? 0,
      freshLeads: (json['freshLeads'] as num?)?.toInt() ?? 0,
      followUpLeads: (json['followUpLeads'] as num?)?.toInt() ?? 0,
      totalCalls: (json['totalCalls'] as num?)?.toInt() ?? 0,
      answeredCalls: (json['answeredCalls'] as num?)?.toInt() ?? 0,
      missedCalls: (json['missedCalls'] as num?)?.toInt() ?? 0,
      totalTalkTimeMinutes: (json['totalTalkTimeMinutes'] as num?)?.toInt() ?? 0,
      conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CrmCallLog {
  final String id;
  final String? leadId;
  final String? customerNumber;
  final String? agentNumber;
  final String? did;
  final String callStatus;
  final int duration;
  final String? recordingUrl;
  final DateTime callTime;
  final String? callId;
  final String? leadName;
  final String? leadStatus;

  const CrmCallLog({
    required this.id,
    this.leadId,
    this.customerNumber,
    this.agentNumber,
    this.did,
    required this.callStatus,
    required this.duration,
    this.recordingUrl,
    required this.callTime,
    this.callId,
    this.leadName,
    this.leadStatus,
  });

  factory CrmCallLog.fromJson(Map<String, dynamic> json) {
    String? leadName;
    String? leadStatus;
    if (json['lead'] is Map) {
      leadName = json['lead']['name'] as String?;
      leadStatus = json['lead']['status'] as String?;
    }

    return CrmCallLog(
      id: json['id'] as String? ?? '',
      leadId: json['leadId'] as String?,
      customerNumber: json['customerNumber'] as String?,
      agentNumber: json['agentNumber'] as String?,
      did: json['did'] as String?,
      callStatus: json['callStatus'] as String? ?? 'UNKNOWN',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      recordingUrl: json['recordingUrl'] as String?,
      callTime: json['callTime'] != null
          ? (DateTime.tryParse(json['callTime'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      callId: json['callId'] as String?,
      leadName: leadName,
      leadStatus: leadStatus,
    );
  }
}

class CrmProposal {
  final String id;
  final String leadId;
  final int revision;
  final String status; // 'ACTIVE', 'REJECTED', 'BOOKED'
  final DateTime createdAt;
  final DateTime expiryDate;

  // Client details
  final String clientName;
  final String clientPhone;
  final String clientEmail;
  final String clientAddress;

  // Unit details
  final String projectId;
  final String projectName;
  final String towerId;
  final String towerName;
  final String unitId;
  final String unitNo;
  final String unitType;
  final int floorNo;
  final double carpetArea;
  final double superBuiltUp;
  final String areaUnit;

  // Financial details (every value can be changed by sales guy)
  final double baseRate;
  final double basePrice;
  final double plc;
  final double frc;
  final double developmentCharges;
  final double parkingCharges;
  final double maintenanceCharges;
  final double gstPercentage;
  final double gstAmount;
  final double stampDutyPercentage;
  final double stampDutyAmount;
  final double registrationCharges;
  final double otherChargesAmount;
  final double discountAmount;
  final double grandTotal;

  // Additional Payment Schedule (optional milestones)
  final List<Map<String, dynamic>> paymentSchedule;

  // Notes & Disclaimers
  final String description;
  final String disclaimer;

  // Sales guy metadata
  final int? createdById;
  final String? createdByName;

  const CrmProposal({
    required this.id,
    required this.leadId,
    this.revision = 1,
    this.status = 'ACTIVE',
    required this.createdAt,
    required this.expiryDate,
    required this.clientName,
    required this.clientPhone,
    this.clientEmail = '',
    this.clientAddress = '',
    this.projectId = '',
    this.projectName = '',
    this.towerId = '',
    this.towerName = '',
    this.unitId = '',
    required this.unitNo,
    this.unitType = '',
    this.floorNo = 0,
    this.carpetArea = 0.0,
    this.superBuiltUp = 0.0,
    this.areaUnit = 'sq.ft',
    this.baseRate = 0.0,
    this.basePrice = 0.0,
    this.plc = 0.0,
    this.frc = 0.0,
    this.developmentCharges = 0.0,
    this.parkingCharges = 0.0,
    this.maintenanceCharges = 0.0,
    this.gstPercentage = 5.0,
    this.gstAmount = 0.0,
    this.stampDutyPercentage = 6.0,
    this.stampDutyAmount = 0.0,
    this.registrationCharges = 0.0,
    this.otherChargesAmount = 0.0,
    this.discountAmount = 0.0,
    required this.grandTotal,
    this.paymentSchedule = const [],
    this.description = '',
    this.disclaimer = '',
    this.createdById,
    this.createdByName,
  });

  bool get isExpired {
    final now = DateTime.now();
    final endOfExpiryDay = DateTime(expiryDate.year, expiryDate.month, expiryDate.day, 23, 59, 59);
    return now.isAfter(endOfExpiryDay);
  }

  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isBooked => status.toUpperCase() == 'BOOKED' || status.toUpperCase() == 'BOOKING_CONFIRMED';

  String get displayStatus {
    if (isBooked) return 'BOOKING CONFIRMED';
    if (isRejected) return 'REJECTED';
    if (isExpired) return 'EXPIRED';
    return 'PROPOSAL SENT';
  }

  String get validityNotice =>
      'This proposal is valid till ${DateFormat('dd MMMM yyyy').format(expiryDate)}';

  factory CrmProposal.fromJson(Map<String, dynamic> json) {
    return CrmProposal(
      id: json['id']?.toString() ?? '',
      leadId: json['leadId']?.toString() ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? 'ACTIVE',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      expiryDate: json['expiryDate'] != null
          ? (DateTime.tryParse(json['expiryDate'].toString())?.toLocal() ??
              DateTime.now().add(const Duration(days: 7)))
          : DateTime.now().add(const Duration(days: 7)),
      clientName: json['clientName']?.toString() ?? '',
      clientPhone: json['clientPhone']?.toString() ?? '',
      clientEmail: json['clientEmail']?.toString() ?? '',
      clientAddress: json['clientAddress']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      projectName: json['projectName']?.toString() ?? '',
      towerId: json['towerId']?.toString() ?? '',
      towerName: json['towerName']?.toString() ?? '',
      unitId: json['unitId']?.toString() ?? '',
      unitNo: json['unitNo']?.toString() ?? '',
      unitType: json['unitType']?.toString() ?? '',
      floorNo: (json['floorNo'] as num?)?.toInt() ?? 0,
      carpetArea: (json['carpetArea'] as num?)?.toDouble() ?? 0.0,
      superBuiltUp: (json['superBuiltUp'] as num?)?.toDouble() ?? 0.0,
      areaUnit: json['areaUnit']?.toString() ?? 'sq.ft',
      baseRate: (json['baseRate'] as num?)?.toDouble() ?? 0.0,
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0.0,
      plc: (json['plc'] as num?)?.toDouble() ?? 0.0,
      frc: (json['frc'] as num?)?.toDouble() ?? 0.0,
      developmentCharges: (json['developmentCharges'] as num?)?.toDouble() ?? 0.0,
      parkingCharges: (json['parkingCharges'] as num?)?.toDouble() ?? 0.0,
      maintenanceCharges: (json['maintenanceCharges'] as num?)?.toDouble() ?? 0.0,
      gstPercentage: (json['gstPercentage'] as num?)?.toDouble() ?? 5.0,
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0.0,
      stampDutyPercentage: (json['stampDutyPercentage'] as num?)?.toDouble() ?? 6.0,
      stampDutyAmount: (json['stampDutyAmount'] as num?)?.toDouble() ?? 0.0,
      registrationCharges: (json['registrationCharges'] as num?)?.toDouble() ?? 0.0,
      otherChargesAmount: (json['otherChargesAmount'] as num?)?.toDouble() ??
          (json['otherCharges'] as num?)?.toDouble() ??
          0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      paymentSchedule: (json['paymentSchedule'] is List)
          ? (json['paymentSchedule'] as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
          : const [],
      description: json['description']?.toString() ?? '',
      disclaimer: json['disclaimer']?.toString() ?? '',
      createdById: (json['createdById'] as num?)?.toInt(),
      createdByName: json['createdByName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'leadId': leadId,
        'revision': revision,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
        'clientName': clientName,
        'clientPhone': clientPhone,
        'clientEmail': clientEmail,
        'clientAddress': clientAddress,
        'projectId': projectId,
        'projectName': projectName,
        'towerId': towerId,
        'towerName': towerName,
        'unitId': unitId,
        'unitNo': unitNo,
        'unitType': unitType,
        'floorNo': floorNo,
        'carpetArea': carpetArea,
        'superBuiltUp': superBuiltUp,
        'areaUnit': areaUnit,
        'baseRate': baseRate,
        'basePrice': basePrice,
        'plc': plc,
        'frc': frc,
        'developmentCharges': developmentCharges,
        'parkingCharges': parkingCharges,
        'maintenanceCharges': maintenanceCharges,
        'gstPercentage': gstPercentage,
        'gstAmount': gstAmount,
        'stampDutyPercentage': stampDutyPercentage,
        'stampDutyAmount': stampDutyAmount,
        'registrationCharges': registrationCharges,
        'otherChargesAmount': otherChargesAmount,
        'discountAmount': discountAmount,
        'grandTotal': grandTotal,
        'paymentSchedule': paymentSchedule,
        'description': description,
        'disclaimer': disclaimer,
        'createdById': createdById,
        'createdByName': createdByName,
      };
}

class CrmCustomerLog {
  final String id;
  final String title;
  final String description;
  final String type; // 'CALL', 'VISIT_SCHEDULED', 'VISIT_DONE', 'SALES_MANAGER_APPOINTED', 'FOLLOW_UP', 'UNIT_SHOWN', 'PROPOSAL_GENERATED', 'STATUS_CHANGE'
  final DateTime timestamp;
  final String? performedByName;
  final int? performedById;
  final Map<String, dynamic>? metadata;

  const CrmCustomerLog({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.timestamp,
    this.performedByName,
    this.performedById,
    this.metadata,
  });

  factory CrmCustomerLog.fromJson(Map<String, dynamic> json) {
    return CrmCustomerLog(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'NOTE',
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      performedByName: json['performedByName']?.toString(),
      performedById: (json['performedById'] as num?)?.toInt(),
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'performedByName': performedByName,
        'performedById': performedById,
        if (metadata != null) 'metadata': metadata,
      };
}
