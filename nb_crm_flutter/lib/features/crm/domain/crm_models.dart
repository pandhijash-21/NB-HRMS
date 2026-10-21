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
  final List<int> assignedTelecallerIds;
  final String assignmentMode;

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
    this.assignedTelecallerIds = const [],
    this.assignmentMode = 'ROUND_ROBIN',
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
      assignedTelecallerIds: (json['assignedTelecallerIds'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      assignmentMode: json['assignmentMode'] as String? ?? 'ROUND_ROBIN',
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
        'assignedTelecallerIds': assignedTelecallerIds,
        'assignmentMode': assignmentMode,
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
  assigned,
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
      case CrmStatus.assigned:
        return 'ASSIGNED';
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
      case CrmStatus.assigned:
        return 'Assigned';
      case CrmStatus.cnr:
        return 'CNR (Call Not received)';
      case CrmStatus.scheduledVisit:
        return 'Visit Scheduled';
      case CrmStatus.notInterested:
        return 'Not Interested';
      case CrmStatus.siteVisitDone:
        return 'Visit Done';
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
      case 'ASSIGNED':
        return CrmStatus.assigned;
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
  final String scope;
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
    this.scope = 'NB_DEVELOPER',
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

  bool get isWaitingList => (telecallerId == null && assignedToId == null) || (status == CrmStatus.notStarted && telecallerId == null);

  String get allocatedAgentName {
    if (telecallerName != null && telecallerName!.trim().isNotEmpty) {
      return telecallerName!;
    }
    if (assignedToName != null && assignedToName!.trim().isNotEmpty) {
      return assignedToName!;
    }
    return isWaitingList ? 'Waiting List (WL)' : 'Unassigned';
  }

  factory CrmLead.fromJson(Map<String, dynamic> json) {
    String? assignedName;
    if (json['assignedTo'] is Map && (json['assignedTo'] as Map)['generalInfo'] is Map) {
      assignedName = (json['assignedTo'] as Map)['generalInfo']['fullName']?.toString();
    }

    String? teleName;
    if (json['telecaller'] is Map && (json['telecaller'] as Map)['generalInfo'] is Map) {
      teleName = (json['telecaller'] as Map)['generalInfo']['fullName']?.toString();
    }

    String? campName;
    if (json['campaign'] is Map) {
      campName = (json['campaign'] as Map)['name']?.toString();
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
      id: json['id']?.toString() ?? '',
      scope: json['scope']?.toString().toUpperCase() ?? 'NB_DEVELOPER',
      campaignId: json['campaignId']?.toString(),
      campaignName: campName,
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: CrmStatus.fromString(json['status']?.toString()),
      customFields: json['customFields'] is Map ? Map<String, dynamic>.from(json['customFields'] as Map) : {},
      assignedToId: (json['assignedToId'] as num?)?.toInt(),
      assignedToName: assignedName,
      telecallerId: (json['telecallerId'] as num?)?.toInt(),
      telecallerName: teleName,
      lastCallAt: json['lastCallAt'] != null ? DateTime.tryParse(json['lastCallAt'].toString()) : null,
      notInterestedAt: json['notInterestedAt'] != null ? DateTime.tryParse(json['notInterestedAt'].toString()) : null,
      notInterestedReason: json['notInterestedReason']?.toString(),
      notInterestedRemark: json['notInterestedRemark']?.toString(),
      scheduledVisitAt: json['scheduledVisitAt'] != null ? DateTime.tryParse(json['scheduledVisitAt'].toString())?.toLocal() : null,
      visitedAt: json['visitedAt'] != null ? DateTime.tryParse(json['visitedAt'].toString())?.toLocal() : null,
      leadSource: json['leadSource']?.toString(),
      channelPartnerName: json['channelPartnerName']?.toString(),
      referenceType: json['referenceType']?.toString(),
      referenceName: json['referenceName']?.toString(),
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
      name = (json['lead'] as Map)['name']?.toString();
      phone = (json['lead'] as Map)['phone']?.toString();
    }

    String? assignedName;
    if (json['assignedTo'] is Map && (json['assignedTo'] as Map)['generalInfo'] is Map) {
      assignedName = (json['assignedTo'] as Map)['generalInfo']['fullName']?.toString();
    }

    return CrmFollowUp(
      id: json['id']?.toString() ?? '',
      leadId: json['leadId']?.toString() ?? '',
      leadName: name,
      leadPhone: phone,
      scheduledDate: DateTime.tryParse(json['scheduledDate']?.toString() ?? '') ?? DateTime.now(),
      scheduledTime: json['scheduledTime']?.toString() ?? '10:00 AM',
      remarks: json['remarks']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
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
  final String? role;

  const CrmSalesUser({
    required this.employeeId,
    required this.fullName,
    this.designation,
    this.department,
    this.role,
  });

  bool get isTelecaller {
    final r = (role ?? '').toLowerCase();
    final d = (designation ?? '').toLowerCase();
    if (r.contains('admin') || r.contains('superadmin') || r.contains('itadmin')) return false;
    return r.contains('telecall') || d.contains('telecall');
  }

  factory CrmSalesUser.fromJson(Map<String, dynamic> json) {
    final empId = (json['employeeId'] as num?)?.toInt() ??
        (json['id'] as num?)?.toInt() ??
        0;
    String name = json['fullName']?.toString() ??
        json['name']?.toString() ??
        'Sales User';
    String? desig = json['designation']?.toString();
    String? dept = json['department']?.toString();
    String? role = json['role']?.toString();

    if (json['generalInfo'] is Map) {
      final gi = json['generalInfo'] as Map;
      if (gi['fullName'] != null && gi['fullName'].toString().trim().isNotEmpty) {
        name = gi['fullName'].toString().trim();
      }
      if (gi['designation'] != null) desig = gi['designation'].toString().trim();
      if (gi['department'] != null) dept = gi['department'].toString().trim();
    }

    if (json['user'] is Map && (json['user'] as Map)['role'] is Map) {
      final roleMap = (json['user'] as Map)['role'] as Map;
      if (roleMap['name'] != null) {
        role = roleMap['name'].toString();
      }
    }

    return CrmSalesUser(
      employeeId: empId,
      fullName: name,
      designation: desig,
      department: dept,
      role: role,
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

  // Dual-Flow Lead Routing & Assignment
  final List<int> excelAssignedTelecallerIds;
  final List<int> webhookAssignedTelecallerIds;

  // Waiting Queue, Inactivity & Workload Management
  final int maxTelecallerActiveWorkload;
  final Map<String, int> telecallerMaxWorkloadMap;
  final int untouchedLeadTimeoutMinutes;
  final int idleTimeoutMinutes;

  // Loan Types & Document Configs (Finserve CRM)
  final List<String> loanTypes;
  final List<CrmLoanDocType> loanDocTypes;
  final Map<String, List<String>> loanTypeDocsMap;
  final List<FinserveApplicationField> finserveApplicationFields;

  static const List<CrmLoanDocType> defaultLoanDocTypes = [
    CrmLoanDocType(id: 'pan_card', name: 'PAN Card', maxFileSizeMb: 5),
    CrmLoanDocType(id: 'aadhaar_card', name: 'Aadhaar Card', maxFileSizeMb: 5),
    CrmLoanDocType(id: 'salary_slips', name: 'Salary Slips (Last 3 Months)', maxFileSizeMb: 10),
    CrmLoanDocType(id: 'bank_statement', name: 'Bank Statement (Last 6 Months)', maxFileSizeMb: 15),
    CrmLoanDocType(id: 'itr_docs', name: 'ITR / Form 16 (Last 2 Years)', maxFileSizeMb: 10),
    CrmLoanDocType(id: 'property_docs', name: 'Property Chain Deeds / Title / Registry', maxFileSizeMb: 25),
    CrmLoanDocType(id: 'business_proof', name: 'Business Registration / GST Certificate', maxFileSizeMb: 10),
    CrmLoanDocType(id: 'utility_bill', name: 'Utility Bill / Residence Proof', maxFileSizeMb: 5),
  ];

  static const Map<String, List<String>> defaultLoanTypeDocsMap = {
    'Home Loan': ['pan_card', 'aadhaar_card', 'salary_slips', 'bank_statement', 'property_docs'],
    'Personal Loan': ['pan_card', 'aadhaar_card', 'salary_slips', 'bank_statement'],
    'Business Loan': ['pan_card', 'aadhaar_card', 'bank_statement', 'itr_docs', 'business_proof'],
    'Mortgage / LAP': ['pan_card', 'aadhaar_card', 'bank_statement', 'property_docs', 'itr_docs'],
    'Auto Loan': ['pan_card', 'aadhaar_card', 'salary_slips', 'bank_statement'],
    'Education Loan': ['pan_card', 'aadhaar_card', 'bank_statement', 'salary_slips'],
  };

  static const List<FinserveApplicationField> defaultFinserveApplicationFields = [
    FinserveApplicationField(key: 'mobileNo', label: 'Mobile No', section: 'PERSONAL', type: 'phone', required: true, enabled: true),
    FinserveApplicationField(key: 'alternateNo', label: 'Alternate No', section: 'PERSONAL', type: 'phone', required: false, enabled: true),
    FinserveApplicationField(key: 'personalEmail', label: 'Personal Mail ID', section: 'PERSONAL', type: 'email', required: true, enabled: true),
    FinserveApplicationField(key: 'maritalStatus', label: 'Marital Status', section: 'PERSONAL', type: 'select', options: ['Single', 'Married', 'Divorced', 'Widowed'], required: true, enabled: true),
    FinserveApplicationField(key: 'motherName', label: 'Mother Name', section: 'PERSONAL', type: 'text', required: true, enabled: true),
    FinserveApplicationField(key: 'spouseName', label: 'Spouse Name', section: 'PERSONAL', type: 'text', required: false, enabled: true),
    FinserveApplicationField(key: 'education', label: 'Education', section: 'PERSONAL', type: 'select', options: ['High School', 'Graduate', 'Post Graduate', 'Doctorate', 'Professional', 'Other'], required: true, enabled: true),
    FinserveApplicationField(key: 'currentAddress', label: 'Current Address', section: 'PERSONAL', type: 'textarea', required: true, enabled: true),
    FinserveApplicationField(key: 'currentAddressType', label: 'Current Address (Rent/Owned)', section: 'PERSONAL', type: 'select', options: ['Owned', 'Rented', 'Parental', 'Company Provided'], required: true, enabled: true),
    FinserveApplicationField(key: 'permanentAddress', label: 'Permanent Address', section: 'PERSONAL', type: 'textarea', required: true, enabled: true),
    FinserveApplicationField(key: 'permanentAddressType', label: 'Permanent Address (Rent/Owned)', section: 'PERSONAL', type: 'select', options: ['Owned', 'Rented', 'Parental'], required: true, enabled: true),
    FinserveApplicationField(key: 'requiredLoanAmount', label: 'Require Loan Amount', section: 'PERSONAL', type: 'number', required: true, enabled: true),
    FinserveApplicationField(key: 'loanPurpose', label: 'Loan Purpose', section: 'PERSONAL', type: 'text', required: true, enabled: true),

    FinserveApplicationField(key: 'companyName', label: 'Company Name', section: 'COMPANY', type: 'text', required: true, enabled: true),
    FinserveApplicationField(key: 'companyAddress', label: 'Company Address', section: 'COMPANY', type: 'textarea', required: true, enabled: true),
    FinserveApplicationField(key: 'currentWorkExp', label: 'Current Work Exp', section: 'COMPANY', type: 'text', required: true, enabled: true),
    FinserveApplicationField(key: 'totalWorkExp', label: 'Total Work Exp', section: 'COMPANY', type: 'text', required: true, enabled: true),
    FinserveApplicationField(key: 'officialEmail', label: 'Official Mail ID', section: 'COMPANY', type: 'email', required: false, enabled: true),
    FinserveApplicationField(key: 'officeLandlineNo', label: 'Office Landline No', section: 'COMPANY', type: 'phone', required: false, enabled: true),

    FinserveApplicationField(key: 'ref1Name', label: '1. Name', section: 'REFERENCE', type: 'text', required: true, enabled: true),
    FinserveApplicationField(key: 'ref1Mobile', label: '1. Mobile No', section: 'REFERENCE', type: 'phone', required: true, enabled: true),
    FinserveApplicationField(key: 'ref1Relation', label: '1. Relation', section: 'REFERENCE', type: 'text', required: true, enabled: true),
    FinserveApplicationField(key: 'ref1Address', label: '1. Address', section: 'REFERENCE', type: 'textarea', required: true, enabled: true),

    FinserveApplicationField(key: 'ref2Name', label: '2. Name', section: 'REFERENCE', type: 'text', required: true, enabled: true),
    FinserveApplicationField(key: 'ref2Mobile', label: '2. Mobile No', section: 'REFERENCE', type: 'phone', required: true, enabled: true),
    FinserveApplicationField(key: 'ref2Relation', label: '2. Relation', section: 'REFERENCE', type: 'text', required: true, enabled: true),
    FinserveApplicationField(key: 'ref2Address', label: '2. Address', section: 'REFERENCE', type: 'textarea', required: true, enabled: true),
  ];

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
    this.excelAssignedTelecallerIds = const [],
    this.webhookAssignedTelecallerIds = const [],
    this.maxTelecallerActiveWorkload = 20,
    this.telecallerMaxWorkloadMap = const {},
    this.untouchedLeadTimeoutMinutes = 30,
    this.idleTimeoutMinutes = 5,
    this.loanTypes = const [
      'Home Loan',
      'Personal Loan',
      'Business Loan',
      'Mortgage / LAP',
      'Auto Loan',
      'Education Loan',
    ],
    this.loanDocTypes = defaultLoanDocTypes,
    this.loanTypeDocsMap = defaultLoanTypeDocsMap,
    this.finserveApplicationFields = defaultFinserveApplicationFields,
  });

  static List<int> _parseIntList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => int.tryParse(e.toString())).whereType<int>().toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => int.tryParse(e.toString())).whereType<int>().toList();
        }
      } catch (_) {
        return raw.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();
      }
    }
    return const [];
  }

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

  static List<CrmLoanDocType> _parseLoanDocTypes(dynamic raw) {
    if (raw == null) return defaultLoanDocTypes;
    List list = [];
    if (raw is List) {
      list = raw;
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) list = decoded;
      } catch (_) {}
    }
    if (list.isNotEmpty) {
      return list.map((e) {
        if (e is Map<String, dynamic>) return CrmLoanDocType.fromJson(e);
        if (e is Map) return CrmLoanDocType.fromJson(Map<String, dynamic>.from(e));
        return CrmLoanDocType(id: e.toString(), name: e.toString());
      }).toList();
    }
    return defaultLoanDocTypes;
  }

  static Map<String, List<String>> _parseLoanTypeDocsMap(dynamic raw) {
    if (raw == null) return defaultLoanTypeDocsMap;
    Map map = {};
    if (raw is Map) {
      map = raw;
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) map = decoded;
      } catch (_) {}
    }
    if (map.isNotEmpty) {
      final res = <String, List<String>>{};
      map.forEach((k, v) {
        if (v is List) {
          res[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
      return res;
    }
    return defaultLoanTypeDocsMap;
  }

  factory CrmSettings.fromJson(Map<String, dynamic> json) {
    return CrmSettings(
      elisionApiUrl: json['elision_api_url']?.toString() ?? 'https://greeter.co.in/api/click2call',
      elisionUserId: json['elision_user_id']?.toString() ?? '634550',
      elisionDid: json['elision_did']?.toString() ?? '9484700070',
      elisionRouteNumber: json['elision_route_number']?.toString() ?? '98',
      elisionDefaultAgentNumber: json['elision_default_agent_number']?.toString() ?? '8511139384',
      elisionApiKey: json['elision_api_key']?.toString() ?? '',
      elisionCampaignId: json['elision_campaign_id']?.toString() ?? '',
      elisionAgentId: json['elision_agent_id']?.toString() ?? '',
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
      excelAssignedTelecallerIds: _parseIntList(json['excel_assigned_telecaller_ids']),
      webhookAssignedTelecallerIds: _parseIntList(json['webhook_assigned_telecaller_ids']),
      maxTelecallerActiveWorkload: int.tryParse(json['max_telecaller_active_workload']?.toString() ?? '20') ?? 20,
      telecallerMaxWorkloadMap: _parseWorkloadMap(json['telecaller_max_workload_map']),
      untouchedLeadTimeoutMinutes: int.tryParse(json['untouched_lead_timeout_minutes']?.toString() ?? '30') ?? 30,
      idleTimeoutMinutes: int.tryParse(json['idle_timeout_minutes']?.toString() ?? '5') ?? 5,
      loanTypes: _parseList(json['loan_types'], const [
        'Home Loan',
        'Personal Loan',
        'Business Loan',
        'Mortgage / LAP',
        'Auto Loan',
        'Education Loan',
      ]),
      loanDocTypes: _parseLoanDocTypes(json['loan_doc_types']),
      loanTypeDocsMap: _parseLoanTypeDocsMap(json['loan_type_docs_map']),
      finserveApplicationFields: _parseFinserveAppFields(json['finserve_application_fields'] ?? json['application_fields']),
    );
  }

  static List<FinserveApplicationField> _parseFinserveAppFields(dynamic raw) {
    if (raw == null) return defaultFinserveApplicationFields;
    List list = [];
    if (raw is List) {
      list = raw;
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) list = decoded;
      } catch (_) {}
    }
    if (list.isNotEmpty) {
      return list.map((e) {
        if (e is Map<String, dynamic>) return FinserveApplicationField.fromJson(e);
        if (e is Map) return FinserveApplicationField.fromJson(Map<String, dynamic>.from(e));
        return FinserveApplicationField(key: e.toString(), label: e.toString());
      }).toList();
    }
    return defaultFinserveApplicationFields;
  }

  static Map<String, int> _parseWorkloadMap(dynamic raw) {
    if (raw == null) return const {};
    Map map = {};
    if (raw is Map) {
      map = raw;
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) map = decoded;
      } catch (_) {}
    }
    if (map.isNotEmpty) {
      final res = <String, int>{};
      map.forEach((k, v) {
        final val = int.tryParse(v.toString());
        if (val != null && val > 0) {
          res[k.toString()] = val;
        }
      });
      return res;
    }
    return const {};
  }
}

class TelecallerPresenceInfo {
  final int employeeId;
  final String fullName;
  final String? subOrganization;
  final String? department;
  final String? designation;
  final bool isPunchedIn;
  final String presenceStatus; // 'ACTIVE' | 'ON_BREAK'
  final DateTime? lastActiveAt;
  final bool isActiveOnScreen;
  final int maxCapacity;
  final int currentWorkload;
  final int availableCapacity;
  final bool isEligibleForDispatch;
  final int inactiveSeconds;
  final String? ineligibleReason;

  const TelecallerPresenceInfo({
    required this.employeeId,
    required this.fullName,
    this.subOrganization,
    this.department,
    this.designation,
    this.isPunchedIn = false,
    this.presenceStatus = 'ON_BREAK',
    this.lastActiveAt,
    this.isActiveOnScreen = false,
    this.maxCapacity = 20,
    this.currentWorkload = 0,
    this.availableCapacity = 20,
    this.isEligibleForDispatch = false,
    this.inactiveSeconds = 0,
    this.ineligibleReason,
  });

  String get inactiveDurationFormatted {
    if (inactiveSeconds <= 0) return '0s';
    final mins = inactiveSeconds ~/ 60;
    final secs = inactiveSeconds % 60;
    if (mins == 0) return '${secs}s';
    if (mins < 60) return '${mins}m ${secs}s';
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    return '${hours}h ${remMins}m';
  }

  factory TelecallerPresenceInfo.fromJson(Map<String, dynamic> json) {
    return TelecallerPresenceInfo(
      employeeId: int.tryParse(json['employeeId']?.toString() ?? '0') ?? 0,
      fullName: json['fullName']?.toString() ?? 'Unknown Telecaller',
      subOrganization: json['subOrganization']?.toString(),
      department: json['department']?.toString(),
      designation: json['designation']?.toString(),
      isPunchedIn: json['isPunchedIn'] == true,
      presenceStatus: json['presenceStatus']?.toString().toUpperCase() ?? 'ON_BREAK',
      lastActiveAt: json['lastActiveAt'] != null ? DateTime.tryParse(json['lastActiveAt'].toString()) : null,
      isActiveOnScreen: json['isActiveOnScreen'] == true,
      maxCapacity: int.tryParse(json['maxCapacity']?.toString() ?? '20') ?? 20,
      currentWorkload: int.tryParse(json['currentWorkload']?.toString() ?? '0') ?? 0,
      availableCapacity: int.tryParse(json['availableCapacity']?.toString() ?? '20') ?? 20,
      isEligibleForDispatch: json['isEligibleForDispatch'] == true,
      inactiveSeconds: int.tryParse(json['inactiveSeconds']?.toString() ?? '0') ?? 0,
      ineligibleReason: json['ineligibleReason']?.toString(),
    );
  }
}

class WaitingQueueStatus {
  final int queuedLeadsCount;
  final int activeTelecallersCount;
  final int totalTelecallersCount;
  final int totalAvailableCapacity;
  final List<TelecallerPresenceInfo> telecallers;

  const WaitingQueueStatus({
    this.queuedLeadsCount = 0,
    this.activeTelecallersCount = 0,
    this.totalTelecallersCount = 0,
    this.totalAvailableCapacity = 0,
    this.telecallers = const [],
  });

  factory WaitingQueueStatus.fromJson(Map<String, dynamic> json) {
    return WaitingQueueStatus(
      queuedLeadsCount: int.tryParse(json['queuedLeadsCount']?.toString() ?? '0') ?? 0,
      activeTelecallersCount: int.tryParse(json['activeTelecallersCount']?.toString() ?? '0') ?? 0,
      totalTelecallersCount: int.tryParse(json['totalTelecallersCount']?.toString() ?? '0') ?? 0,
      totalAvailableCapacity: int.tryParse(json['totalAvailableCapacity']?.toString() ?? '0') ?? 0,
      telecallers: (json['telecallers'] as List? ?? [])
          .map((e) => TelecallerPresenceInfo.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class CrmLoanDocType {
  final String id;
  final String name;
  final int maxFileSizeMb;
  final List<String> allowedFormats;

  const CrmLoanDocType({
    required this.id,
    required this.name,
    this.maxFileSizeMb = 5,
    this.allowedFormats = const ['pdf', 'jpg', 'jpeg', 'png'],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'maxFileSizeMb': maxFileSizeMb,
    'allowedFormats': allowedFormats,
  };

  factory CrmLoanDocType.fromJson(Map<String, dynamic> json) {
    return CrmLoanDocType(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      maxFileSizeMb: int.tryParse(json['maxFileSizeMb']?.toString() ?? '5') ?? 5,
      allowedFormats: (json['allowedFormats'] as List?)
              ?.map((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const ['pdf', 'jpg', 'jpeg', 'png'],
    );
  }
}

class FinserveApplicationField {
  final String key;
  final String label;
  final String section; // PERSONAL, COMPANY, REFERENCE, CUSTOM
  final String type; // text, number, phone, email, select, textarea
  final List<String> options;
  final bool required;
  final bool enabled;

  const FinserveApplicationField({
    required this.key,
    required this.label,
    this.section = 'PERSONAL',
    this.type = 'text',
    this.options = const [],
    this.required = true,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'section': section,
    'type': type,
    'options': options,
    'required': required,
    'enabled': enabled,
  };

  factory FinserveApplicationField.fromJson(Map<String, dynamic> json) {
    return FinserveApplicationField(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      section: json['section']?.toString().toUpperCase() ?? 'PERSONAL',
      type: json['type']?.toString().toLowerCase() ?? 'text',
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      required: json['required'] == true,
      enabled: json['enabled'] != false,
    );
  }

  FinserveApplicationField copyWith({
    String? key,
    String? label,
    String? section,
    String? type,
    List<String>? options,
    bool? required,
    bool? enabled,
  }) {
    return FinserveApplicationField(
      key: key ?? this.key,
      label: label ?? this.label,
      section: section ?? this.section,
      type: type ?? this.type,
      options: options ?? this.options,
      required: required ?? this.required,
      enabled: enabled ?? this.enabled,
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
  final bool isPersonal;

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
    this.isPersonal = false,
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
      isPersonal: json['isPersonal'] == true,
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

// ---------------------------------------------------------------------------
// WhatsApp Automation Models
// ---------------------------------------------------------------------------

class CrmWhatsappTrigger {
  const CrmWhatsappTrigger({
    required this.id,
    required this.event,
    required this.name,
    required this.enabled,
    required this.messageTemplate,
    this.messageType = 'TEXT',
    this.templateId,
    this.templateName,
    this.templateEndpoint,
    this.language = 'en_US',
    this.mediaUrl = '',
    this.includeCalendarLink = false,
    this.locationUrl = '',
  });

  final String id;
  final String event;
  final String name;
  final bool enabled;
  final String messageTemplate;
  final String messageType; // 'TEXT' | 'TEMPLATE'
  final String? templateId;
  final String? templateName;
  final String? templateEndpoint;
  final String language;
  final String mediaUrl;
  final bool includeCalendarLink;
  final String locationUrl;

  CrmWhatsappTrigger copyWith({
    String? id,
    String? event,
    String? name,
    bool? enabled,
    String? messageTemplate,
    String? messageType,
    String? templateId,
    String? templateName,
    String? templateEndpoint,
    String? language,
    String? mediaUrl,
    bool? includeCalendarLink,
    String? locationUrl,
  }) {
    return CrmWhatsappTrigger(
      id: id ?? this.id,
      event: event ?? this.event,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      messageTemplate: messageTemplate ?? this.messageTemplate,
      messageType: messageType ?? this.messageType,
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName,
      templateEndpoint: templateEndpoint ?? this.templateEndpoint,
      language: language ?? this.language,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      includeCalendarLink: includeCalendarLink ?? this.includeCalendarLink,
      locationUrl: locationUrl ?? this.locationUrl,
    );
  }

  factory CrmWhatsappTrigger.fromJson(Map<String, dynamic> json) {
    return CrmWhatsappTrigger(
      id: json['id']?.toString() ?? '',
      event: json['event']?.toString() ?? 'LEAD_CREATED',
      name: json['name']?.toString() ?? '',
      enabled: json['enabled'] != false,
      messageTemplate: json['messageTemplate']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'TEXT',
      templateId: json['templateId']?.toString(),
      templateName: json['templateName']?.toString(),
      templateEndpoint: json['templateEndpoint']?.toString(),
      language: json['language']?.toString() ?? 'en_US',
      mediaUrl: json['mediaUrl']?.toString() ?? '',
      includeCalendarLink: json['includeCalendarLink'] == true,
      locationUrl: json['locationUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event': event,
        'name': name,
        'enabled': enabled,
        'messageTemplate': messageTemplate,
        'messageType': messageType,
        'templateId': templateId,
        'templateName': templateName,
        'templateEndpoint': templateEndpoint,
        'language': language,
        'mediaUrl': mediaUrl,
        'includeCalendarLink': includeCalendarLink,
        'locationUrl': locationUrl,
      };
}

class CrmWhatsappConfig {
  const CrmWhatsappConfig({
    required this.enabled,
    required this.provider,
    required this.apiBase,
    required this.apiUrl,
    required this.apiKey,
    this.hasApiKey = false,
    required this.senderId,
    required this.defaultBrochureUrl,
    this.defaultBrochureName = 'Legacy_Tower_Brochure.pdf',
    required this.defaultLocationUrl,
    required this.defaultProjectName,
    this.connectionStatus = 'NOT_CONFIGURED',
    this.lastVerifiedAt,
    this.lastVerificationResult,
    required this.triggers,
  });

  final bool enabled;
  final String provider;
  final String apiBase;
  final String apiUrl;
  final String apiKey;
  final bool hasApiKey;
  final String senderId;
  final String defaultBrochureUrl;
  final String defaultBrochureName;
  final String defaultLocationUrl;
  final String defaultProjectName;
  final String connectionStatus; // 'NOT_CONFIGURED' | 'CONFIGURED_UNVERIFIED' | 'CONNECTED_VERIFIED'
  final String? lastVerifiedAt;
  final String? lastVerificationResult;
  final List<CrmWhatsappTrigger> triggers;

  CrmWhatsappConfig copyWith({
    bool? enabled,
    String? provider,
    String? apiBase,
    String? apiUrl,
    String? apiKey,
    bool? hasApiKey,
    String? senderId,
    String? defaultBrochureUrl,
    String? defaultBrochureName,
    String? defaultLocationUrl,
    String? defaultProjectName,
    String? connectionStatus,
    String? lastVerifiedAt,
    String? lastVerificationResult,
    List<CrmWhatsappTrigger>? triggers,
  }) {
    return CrmWhatsappConfig(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      apiBase: apiBase ?? this.apiBase,
      apiUrl: apiUrl ?? this.apiUrl,
      apiKey: apiKey ?? this.apiKey,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      senderId: senderId ?? this.senderId,
      defaultBrochureUrl: defaultBrochureUrl ?? this.defaultBrochureUrl,
      defaultBrochureName: defaultBrochureName ?? this.defaultBrochureName,
      defaultLocationUrl: defaultLocationUrl ?? this.defaultLocationUrl,
      defaultProjectName: defaultProjectName ?? this.defaultProjectName,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      lastVerificationResult: lastVerificationResult ?? this.lastVerificationResult,
      triggers: triggers ?? this.triggers,
    );
  }

  factory CrmWhatsappConfig.fromJson(Map<String, dynamic> json) {
    final rawTriggers = json['triggers'];
    final list = <CrmWhatsappTrigger>[];
    if (rawTriggers is List) {
      for (final t in rawTriggers) {
        if (t is Map) {
          list.add(CrmWhatsappTrigger.fromJson(Map<String, dynamic>.from(t)));
        }
      }
    }
    return CrmWhatsappConfig(
      enabled: json['enabled'] != false,
      provider: json['provider']?.toString() ?? 'botbiz',
      apiBase: json['apiBase']?.toString() ?? 'https://dash.botbiz.io/api/v1',
      apiUrl: json['apiUrl']?.toString() ?? 'https://dash.botbiz.io/api/v1/whatsapp/send',
      apiKey: json['apiKey']?.toString() ?? '',
      hasApiKey: json['hasApiKey'] == true,
      senderId: json['senderId']?.toString() ?? '',
      defaultBrochureUrl: json['defaultBrochureUrl']?.toString() ?? '',
      defaultBrochureName: json['defaultBrochureName']?.toString() ?? 'Legacy_Tower_Brochure.pdf',
      defaultLocationUrl: json['defaultLocationUrl']?.toString() ?? '',
      defaultProjectName: json['defaultProjectName']?.toString() ?? 'Legacy Tower',
      connectionStatus: json['connectionStatus']?.toString() ?? 'NOT_CONFIGURED',
      lastVerifiedAt: json['lastVerifiedAt']?.toString(),
      lastVerificationResult: json['lastVerificationResult']?.toString(),
      triggers: list,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'provider': provider,
        'apiBase': apiBase,
        'apiUrl': apiUrl,
        'apiKey': apiKey,
        'senderId': senderId,
        'defaultBrochureUrl': defaultBrochureUrl,
        'defaultBrochureName': defaultBrochureName,
        'defaultLocationUrl': defaultLocationUrl,
        'defaultProjectName': defaultProjectName,
        'triggers': triggers.map((t) => t.toJson()).toList(),
      };
}

class BotbizTemplateModel {
  const BotbizTemplateModel({
    required this.id,
    required this.name,
    required this.language,
    this.category,
    required this.status,
    this.variableCount,
  });

  final String id;
  final String name;
  final String language;
  final String? category;
  final String status; // 'APPROVED' | 'PENDING' | 'REJECTED' | 'PAUSED' | 'DISABLED' | 'UNKNOWN'
  final int? variableCount;

  factory BotbizTemplateModel.fromJson(Map<String, dynamic> json) {
    return BotbizTemplateModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      language: json['language']?.toString() ?? 'en_US',
      category: json['category']?.toString(),
      status: json['status']?.toString() ?? 'UNKNOWN',
      variableCount: json['variableCount'] is num ? (json['variableCount'] as num).toInt() : null,
    );
  }
}

class CrmWhatsappLogItem {
  const CrmWhatsappLogItem({
    required this.id,
    required this.phone,
    required this.event,
    this.leadId,
    required this.message,
    this.messageType,
    this.templateId,
    this.waMessageId,
    this.mediaUrl,
    required this.status,
    this.error,
    required this.timestamp,
  });

  final String id;
  final String phone;
  final String event;
  final String? leadId;
  final String message;
  final String? messageType;
  final String? templateId;
  final String? waMessageId;
  final String? mediaUrl;
  final String status;
  final String? error;
  final String timestamp;

  factory CrmWhatsappLogItem.fromJson(Map<String, dynamic> json) {
    return CrmWhatsappLogItem(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      event: json['event']?.toString() ?? '',
      leadId: json['leadId']?.toString(),
      message: json['message']?.toString() ?? '',
      messageType: json['messageType']?.toString(),
      templateId: json['templateId']?.toString(),
      waMessageId: json['waMessageId']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      status: json['status']?.toString() ?? 'SENT',
      error: json['error']?.toString(),
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }
}
