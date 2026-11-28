enum SupportTicketStatus {
  queued,
  open,
  inReview,
  resolved,
  closed;

  String get api {
    switch (this) {
      case SupportTicketStatus.queued:
        return 'QUEUED';
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
      case SupportTicketStatus.queued:
        return 'In Queue';
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
      case 'QUEUED':
        return SupportTicketStatus.queued;
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

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderRole,
    this.senderName,
    required this.message,
    this.attachmentUrl,
    this.attachmentName,
    required this.createdAt,
  });

  final String id;
  final String ticketId;
  final String senderId;
  final String senderRole;
  final String? senderName;
  final String message;
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime createdAt;

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) {
    return SupportTicketMessage(
      id: json['id']?.toString() ?? '',
      ticketId: json['ticketId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderRole: json['senderRole']?.toString() ?? 'EMPLOYEE',
      senderName: json['senderName']?.toString(),
      message: json['message']?.toString() ?? '',
      attachmentUrl: json['attachmentUrl']?.toString(),
      attachmentName: json['attachmentName']?.toString(),
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    );
  }
}

class SupportRemoteSession {
  const SupportRemoteSession({
    required this.id,
    required this.ticketId,
    required this.roomName,
    required this.handlerUserId,
    required this.employeeUserId,
    required this.status,
    this.accessLevel = 'FULL_CONTROL',
    this.uacEnabled = true,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String ticketId;
  final String roomName;
  final String handlerUserId;
  final String employeeUserId;
  final String status;
  final String accessLevel;
  final bool uacEnabled;
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isActive => status == 'ACCEPTED' || status == 'ACTIVE';
  bool get isRequested => status == 'REQUESTED';

  factory SupportRemoteSession.fromJson(Map<String, dynamic> json) {
    return SupportRemoteSession(
      id: json['id']?.toString() ?? '',
      ticketId: json['ticketId']?.toString() ?? '',
      roomName: json['roomName']?.toString() ?? '',
      handlerUserId: json['handlerUserId']?.toString() ?? '',
      employeeUserId: json['employeeUserId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'REQUESTED',
      accessLevel: json['accessLevel']?.toString() ?? 'FULL_CONTROL',
      uacEnabled: json['uacEnabled'] != false,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse('${json['startedAt']}')
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse('${json['endedAt']}')
          : null,
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
    this.assignedHandlerId,
    this.assignedAt,
    this.queuePosition,
    this.transferStatus,
    this.transferTargetHandlerId,
    this.transferReason,
    this.transferRequestedBy,
    required this.createdBy,
    this.closedAt,
    required this.createdAt,
    this.employeeName,
    this.employeeCode,
    this.designation,
    this.department,
    this.events = const [],
    this.messages = const [],
    this.activeRemoteSession,
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
  final int? assignedHandlerId;
  final DateTime? assignedAt;
  final int? queuePosition;
  final String? transferStatus;
  final int? transferTargetHandlerId;
  final String? transferReason;
  final String? transferRequestedBy;
  final String createdBy;
  final DateTime? closedAt;
  final DateTime createdAt;
  final String? employeeName;
  final String? employeeCode;
  final String? designation;
  final String? department;
  final List<SupportTicketEvent> events;
  final List<SupportTicketMessage> messages;
  final SupportRemoteSession? activeRemoteSession;

  bool get isQueued => status == SupportTicketStatus.queued;
  bool get isTransferPending => transferStatus == 'PENDING';

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'];
    Map<String, dynamic>? general;
    if (emp is Map) {
      final g = emp['generalInfo'];
      if (g is Map) general = Map<String, dynamic>.from(g);
    }
    final eventsRaw = json['events'];
    final messagesRaw = json['messages'];
    final sessionsRaw = json['remoteSessions'];

    SupportRemoteSession? activeSession;
    if (sessionsRaw is List && sessionsRaw.isNotEmpty) {
      activeSession = SupportRemoteSession.fromJson(
        Map<String, dynamic>.from(sessionsRaw.first),
      );
    }

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
      assignedHandlerId: (json['assignedHandlerId'] is num)
          ? (json['assignedHandlerId'] as num).toInt()
          : int.tryParse('${json['assignedHandlerId']}'),
      assignedAt: json['assignedAt'] != null
          ? DateTime.tryParse('${json['assignedAt']}')
          : null,
      queuePosition: (json['queuePosition'] is num)
          ? (json['queuePosition'] as num).toInt()
          : int.tryParse('${json['queuePosition']}'),
      transferStatus: json['transferStatus']?.toString(),
      transferTargetHandlerId: (json['transferTargetHandlerId'] is num)
          ? (json['transferTargetHandlerId'] as num).toInt()
          : int.tryParse('${json['transferTargetHandlerId']}'),
      transferReason: json['transferReason']?.toString(),
      transferRequestedBy: json['transferRequestedBy']?.toString(),
      createdBy: json['createdBy']?.toString() ?? '',
      closedAt: json['closedAt'] != null
          ? DateTime.tryParse('${json['closedAt']}')
          : null,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      employeeName: general?['fullName']?.toString(),
      employeeCode: general?['employeeCode']?.toString(),
      designation: general?['designation']?.toString(),
      department: general?['department']?.toString(),
      events: eventsRaw is List
          ? eventsRaw
              .whereType<Map>()
              .map((e) =>
                  SupportTicketEvent.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      messages: messagesRaw is List
          ? messagesRaw
              .whereType<Map>()
              .map((e) =>
                  SupportTicketMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      activeRemoteSession: activeSession,
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
    this.createdAt,
    this.createdBy,
    this.fullName,
    this.employeeCode,
    this.designation,
    this.department,
    this.userId,
  });

  final String id;
  final int employeeId;
  final DateTime? createdAt;
  final String? createdBy;
  final String? fullName;
  final String? employeeCode;
  final String? designation;
  final String? department;
  final String? userId;

  String get displayName =>
      fullName ?? (employeeCode != null ? 'Employee ($employeeCode)' : 'Employee #$employeeId');

  String get displayLabel {
    final name = fullName?.trim();
    final code = employeeCode?.trim();
    if (name != null && name.isNotEmpty && code != null && code.isNotEmpty) {
      return '$name ($code)';
    }
    if (name != null && name.isNotEmpty) return name;
    return 'Employee #$employeeId';
  }

  factory SupportHandler.fromJson(Map<String, dynamic> json) {
    return SupportHandler(
      id: json['id']?.toString() ?? '',
      employeeId: (json['employeeId'] is num)
          ? (json['employeeId'] as num).toInt()
          : int.tryParse('${json['employeeId']}') ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse('${json['createdAt']}')
          : null,
      createdBy: json['createdBy']?.toString(),
      fullName: json['fullName']?.toString(),
      employeeCode: json['employeeCode']?.toString(),
      designation: json['designation']?.toString(),
      department: json['department']?.toString(),
      userId: json['userId']?.toString(),
    );
  }
}

typedef SupportItAssigneeItem = SupportHandler;
