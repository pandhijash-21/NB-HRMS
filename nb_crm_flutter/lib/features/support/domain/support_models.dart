enum SupportTicketStatus {
  open,
  inReview,
  resolved,
  closed;

  String get api {
    switch (this) {
      case SupportTicketStatus.open:
        return 'OPEN';
      case SupportTicketStatus.inReview:
        return 'IN_REVIEW';
      case SupportTicketStatus.resolved:
        return 'RESOLVED';
      case SupportTicketStatus.closed:
        return 'CLOSED';
    }
  }

  String get label {
    switch (this) {
      case SupportTicketStatus.open:
        return 'Open';
      case SupportTicketStatus.inReview:
        return 'In review';
      case SupportTicketStatus.resolved:
        return 'Resolved';
      case SupportTicketStatus.closed:
        return 'Closed';
    }
  }

  static SupportTicketStatus fromString(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'IN_REVIEW':
        return SupportTicketStatus.inReview;
      case 'RESOLVED':
        return SupportTicketStatus.resolved;
      case 'CLOSED':
        return SupportTicketStatus.closed;
      default:
        return SupportTicketStatus.open;
    }
  }
}

class SupportTicketEvent {
  const SupportTicketEvent({
    required this.id,
    required this.actorId,
    this.fromStatus,
    required this.toStatus,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String actorId;
  final SupportTicketStatus? fromStatus;
  final SupportTicketStatus toStatus;
  final String? note;
  final DateTime createdAt;

  factory SupportTicketEvent.fromJson(Map<String, dynamic> json) {
    return SupportTicketEvent(
      id: json['id']?.toString() ?? '',
      actorId: json['actorId']?.toString() ?? '',
      fromStatus: json['fromStatus'] != null
          ? SupportTicketStatus.fromString(json['fromStatus']?.toString())
          : null,
      toStatus: SupportTicketStatus.fromString(json['toStatus']?.toString()),
      note: json['note']?.toString(),
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    );
  }
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.ticketNo,
    required this.employeeId,
    required this.title,
    required this.description,
    this.photoUrl,
    required this.status,
    this.etaAt,
    this.resolveRemarks,
    this.denyRemarks,
    this.forceClosed = false,
    required this.createdBy,
    this.closedAt,
    required this.createdAt,
    this.employeeName,
    this.employeeCode,
    this.designation,
    this.department,
    this.events = const [],
  });

  final String id;
  final String ticketNo;
  final int employeeId;
  final String title;
  final String description;
  final String? photoUrl;
  final SupportTicketStatus status;
  final DateTime? etaAt;
  final String? resolveRemarks;
  final String? denyRemarks;
  final bool forceClosed;
  final String createdBy;
  final DateTime? closedAt;
  final DateTime createdAt;
  final String? employeeName;
  final String? employeeCode;
  final String? designation;
  final String? department;
  final List<SupportTicketEvent> events;

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'];
    Map<String, dynamic>? general;
    if (emp is Map) {
      final g = emp['generalInfo'];
      if (g is Map) general = Map<String, dynamic>.from(g);
    }
    final eventsRaw = json['events'];
    return SupportTicket(
      id: json['id']?.toString() ?? '',
      ticketNo: json['ticketNo']?.toString() ?? '',
      employeeId: (json['employeeId'] is num)
          ? (json['employeeId'] as num).toInt()
          : int.tryParse('${json['employeeId']}') ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString(),
      status: SupportTicketStatus.fromString(json['status']?.toString()),
      etaAt: json['etaAt'] != null ? DateTime.tryParse('${json['etaAt']}') : null,
      resolveRemarks: json['resolveRemarks']?.toString(),
      denyRemarks: json['denyRemarks']?.toString(),
      forceClosed: json['forceClosed'] == true,
      createdBy: json['createdBy']?.toString() ?? '',
      closedAt: json['closedAt'] != null ? DateTime.tryParse('${json['closedAt']}') : null,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      employeeName: general?['fullName']?.toString(),
      employeeCode: general?['employeeCode']?.toString(),
      designation: general?['designation']?.toString(),
      department: general?['department']?.toString(),
      events: eventsRaw is List
          ? eventsRaw
              .whereType<Map>()
              .map((e) => SupportTicketEvent.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class SupportCapabilities {
  const SupportCapabilities({
    required this.isIt,
    required this.canManageHandlers,
    required this.handlersConfigured,
    required this.isAssignedHandler,
  });

  final bool isIt;
  final bool canManageHandlers;
  final bool handlersConfigured;
  final bool isAssignedHandler;

  factory SupportCapabilities.fromJson(Map<String, dynamic> json) {
    return SupportCapabilities(
      isIt: json['isIt'] == true,
      canManageHandlers: json['canManageHandlers'] == true,
      handlersConfigured: json['handlersConfigured'] == true,
      isAssignedHandler: json['isAssignedHandler'] == true,
    );
  }

  static const empty = SupportCapabilities(
    isIt: false,
    canManageHandlers: false,
    handlersConfigured: false,
    isAssignedHandler: false,
  );
}

class SupportHandler {
  const SupportHandler({
    required this.id,
    required this.employeeId,
    this.fullName,
    this.employeeCode,
    this.designation,
    this.department,
    this.userId,
  });

  final String id;
  final int employeeId;
  final String? fullName;
  final String? employeeCode;
  final String? designation;
  final String? department;
  final String? userId;

  factory SupportHandler.fromJson(Map<String, dynamic> json) {
    return SupportHandler(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId'] is int
          ? json['employeeId'] as int
          : int.tryParse('${json['employeeId']}') ?? 0,
      fullName: json['fullName']?.toString(),
      employeeCode: json['employeeCode']?.toString(),
      designation: json['designation']?.toString(),
      department: json['department']?.toString(),
      userId: json['userId']?.toString(),
    );
  }

  String get displayLabel {
    final name = fullName?.trim();
    final code = employeeCode?.trim();
    if (name != null && name.isNotEmpty && code != null && code.isNotEmpty) {
      return '$name ($code)';
    }
    if (name != null && name.isNotEmpty) return name;
    return 'Employee #$employeeId';
  }
}
