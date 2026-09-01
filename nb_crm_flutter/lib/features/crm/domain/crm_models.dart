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
  followUp,
  interested,
  notInterested;

  String get backendValue {
    switch (this) {
      case CrmStatus.notStarted:
        return 'NOT_STARTED';
      case CrmStatus.followUp:
        return 'FOLLOW_UP';
      case CrmStatus.interested:
        return 'INTERESTED';
      case CrmStatus.notInterested:
        return 'NOT_INTERESTED';
    }
  }

  String get displayName {
    switch (this) {
      case CrmStatus.notStarted:
        return 'Not started';
      case CrmStatus.followUp:
        return 'Follow up';
      case CrmStatus.interested:
        return 'Interested';
      case CrmStatus.notInterested:
        return 'Not interested';
    }
  }

  static CrmStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'FOLLOW_UP':
        return CrmStatus.followUp;
      case 'INTERESTED':
        return CrmStatus.interested;
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
        followUp = CrmFollowUp.fromJson(Map<String, dynamic>.from(first));
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
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'].toString()) : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      latestFollowUp: followUp,
    );
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
