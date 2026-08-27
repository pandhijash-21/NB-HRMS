DateTime? parseTaskDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

class TaskPerson {
  const TaskPerson({required this.id, this.employeeId, required this.name});

  final String id;
  final int? employeeId;
  final String name;

  factory TaskPerson.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TaskPerson(id: '', name: 'Unknown');
    }
    return TaskPerson(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId'] is int
          ? json['employeeId'] as int
          : int.tryParse('${json['employeeId'] ?? ''}'),
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

class WorkTaskSubtask {
  const WorkTaskSubtask({
    required this.id,
    required this.title,
    required this.sortOrder,
    required this.isDone,
    this.completedAt,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMime,
  });

  final String id;
  final String title;
  final int sortOrder;
  final bool isDone;
  final DateTime? completedAt;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMime;

  factory WorkTaskSubtask.fromJson(Map<String, dynamic> json) {
    return WorkTaskSubtask(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      sortOrder: json['sortOrder'] as int? ?? 0,
      isDone: json['isDone'] == true,
      completedAt: parseTaskDate(json['completedAt']),
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentName: json['attachmentName'] as String?,
      attachmentMime: json['attachmentMime'] as String?,
    );
  }
}

class TaskEvent {
  const TaskEvent({
    required this.id,
    required this.type,
    this.fromStatus,
    this.toStatus,
    this.remarks,
    this.newDeadline,
    required this.createdAt,
    required this.actor,
  });

  final String id;
  final String type;
  final String? fromStatus;
  final String? toStatus;
  final String? remarks;
  final DateTime? newDeadline;
  final DateTime createdAt;
  final TaskPerson actor;

  factory TaskEvent.fromJson(Map<String, dynamic> json) {
    return TaskEvent(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? '',
      fromStatus: json['fromStatus'] as String?,
      toStatus: json['toStatus'] as String?,
      remarks: json['remarks'] as String?,
      newDeadline: parseTaskDate(json['newDeadline']),
      createdAt: parseTaskDate(json['createdAt']) ?? DateTime.now(),
      actor: TaskPerson.fromJson(
        json['actor'] is Map ? Map<String, dynamic>.from(json['actor'] as Map) : null,
      ),
    );
  }
}

class WorkTask {
  const WorkTask({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.deadline,
    this.startedAt,
    this.completedAt,
    this.reviewedAt,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMime,
    this.extraApproverUserId,
    this.extraApprovalStatus,
    this.extraApprovalRemarks,
    this.extraApprovalDecidedAt,
    this.reviewRemarks,
    required this.createdAt,
    required this.updatedAt,
    required this.assigner,
    required this.assignee,
    this.extraApprover,
    this.events = const [],
    this.subtasks = const [],
  });

  final String id;
  final String title;
  final String? description;
  final String status;
  final DateTime deadline;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? reviewedAt;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMime;
  final String? extraApproverUserId;
  final String? extraApprovalStatus;
  final String? extraApprovalRemarks;
  final DateTime? extraApprovalDecidedAt;
  final String? reviewRemarks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TaskPerson assigner;
  final TaskPerson assignee;
  final TaskPerson? extraApprover;
  final List<TaskEvent> events;
  final List<WorkTaskSubtask> subtasks;

  bool get isClosed => status == 'APPROVED' || status == 'REJECTED';

  int get subtasksDone => subtasks.where((s) => s.isDone).length;

  double get subtaskProgress => subtasks.isEmpty ? 0 : subtasksDone / subtasks.length;

  factory WorkTask.fromJson(Map<String, dynamic> json) {
    return WorkTask(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'ASSIGNED',
      deadline: parseTaskDate(json['deadline']) ?? DateTime.now(),
      startedAt: parseTaskDate(json['startedAt']),
      completedAt: parseTaskDate(json['completedAt']),
      reviewedAt: parseTaskDate(json['reviewedAt']),
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentName: json['attachmentName'] as String?,
      attachmentMime: json['attachmentMime'] as String?,
      extraApproverUserId: json['extraApproverUserId'] as String?,
      extraApprovalStatus: json['extraApprovalStatus'] as String?,
      extraApprovalRemarks: json['extraApprovalRemarks'] as String?,
      extraApprovalDecidedAt: parseTaskDate(json['extraApprovalDecidedAt']),
      reviewRemarks: json['reviewRemarks'] as String?,
      createdAt: parseTaskDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseTaskDate(json['updatedAt']) ?? DateTime.now(),
      assigner: TaskPerson.fromJson(
        json['assigner'] is Map ? Map<String, dynamic>.from(json['assigner'] as Map) : null,
      ),
      assignee: TaskPerson.fromJson(
        json['assignee'] is Map ? Map<String, dynamic>.from(json['assignee'] as Map) : null,
      ),
      extraApprover: json['extraApprover'] is Map
          ? TaskPerson.fromJson(Map<String, dynamic>.from(json['extraApprover'] as Map))
          : null,
      events: (json['events'] as List? ?? [])
          .whereType<Map>()
          .map((e) => TaskEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      subtasks: (json['subtasks'] as List? ?? [])
          .whereType<Map>()
          .map((e) => WorkTaskSubtask.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class TaskReportee {
  const TaskReportee({
    required this.userId,
    required this.employeeId,
    required this.fullName,
    this.designation,
    this.employeeCode,
    this.photoUrl,
    required this.reportingLayer,
  });

  final String userId;
  final int employeeId;
  final String fullName;
  final String? designation;
  final String? employeeCode;
  final String? photoUrl;
  final int reportingLayer;

  String get displayLabel {
    final parts = <String>[fullName];
    if (employeeCode != null && employeeCode!.isNotEmpty) parts.add(employeeCode!);
    if (designation != null && designation!.isNotEmpty) parts.add(designation!);
    return parts.join(' • ');
  }

  factory TaskReportee.fromJson(Map<String, dynamic> json) {
    return TaskReportee(
      userId: json['userId']?.toString() ?? '',
      employeeId: json['employeeId'] is int
          ? json['employeeId'] as int
          : int.tryParse('${json['employeeId'] ?? ''}') ?? 0,
      fullName: json['fullName'] as String? ?? '',
      designation: json['designation'] as String?,
      employeeCode: json['employeeCode'] as String?,
      photoUrl: json['photoUrl'] as String?,
      reportingLayer: json['reportingLayer'] is int
          ? json['reportingLayer'] as int
          : int.tryParse('${json['reportingLayer'] ?? ''}') ?? 1,
    );
  }
}

class TaskSummary {
  const TaskSummary({
    required this.inbox,
    required this.review,
    required this.extra,
    required this.changes,
  });

  final int inbox;
  final int review;
  final int extra;
  final int changes;

  factory TaskSummary.fromJson(Map<String, dynamic> json) {
    return TaskSummary(
      inbox: json['inbox'] as int? ?? 0,
      review: json['review'] as int? ?? 0,
      extra: json['extra'] as int? ?? 0,
      changes: json['changes'] as int? ?? 0,
    );
  }
}

String taskStatusLabel(String status) {
  switch (status) {
    case 'ASSIGNED':
      return 'Assigned';
    case 'ONGOING':
      return 'Ongoing';
    case 'COMPLETED':
      return 'Completed';
    case 'CHANGES_REQUESTED':
      return 'Changes requested';
    case 'APPROVED':
      return 'Approved';
    case 'REJECTED':
      return 'Rejected';
    default:
      return status;
  }
}

String taskPersonInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final s = parts.first;
    return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String taskEventSummary(TaskEvent event) {
  switch (event.type) {
    case 'CREATED':
      return 'Task created'
          '${event.toStatus == null ? '' : ' · status set to ${taskStatusLabel(event.toStatus!)}'}';
    case 'STATUS_CHANGED':
      if (event.fromStatus != null && event.toStatus != null) {
        return 'Status changed from ${taskStatusLabel(event.fromStatus!)} to ${taskStatusLabel(event.toStatus!)}';
      }
      if (event.toStatus != null) {
        return 'Status changed to ${taskStatusLabel(event.toStatus!)}';
      }
      return 'Status changed';
    case 'REVIEWED':
      if (event.toStatus != null) {
        return 'Reviewed · status set to ${taskStatusLabel(event.toStatus!)}';
      }
      return 'Reviewed';
    case 'EXTRA_APPROVAL_REQUESTED':
      return 'Extra approval requested';
    case 'EXTRA_APPROVAL_DECIDED':
      return 'Extra approval decided';
    case 'SUBTASK_UPDATED':
      return event.remarks ?? 'Subtask updated';
    default:
      return event.type.replaceAll('_', ' ').toLowerCase();
  }
}
