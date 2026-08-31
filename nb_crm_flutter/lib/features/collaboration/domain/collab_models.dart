class CollabProfile {
  const CollabProfile({
    required this.userId,
    required this.name,
    this.photoUrl,
    this.email,
    this.role,
    this.department,
    this.employeeId,
    this.online = false,
    this.lastReadAt,
  });

  final String userId;
  final String name;
  final String? photoUrl;
  final String? email;
  final String? role;
  final String? department;
  final int? employeeId;
  final bool online;
  final DateTime? lastReadAt;

  factory CollabProfile.fromJson(Map<String, dynamic> json) {
    return CollabProfile(
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'User',
      photoUrl: json['photoUrl'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String?,
      department: json['department'] as String?,
      employeeId: json['employeeId'] is int ? json['employeeId'] as int : int.tryParse('${json['employeeId'] ?? ''}'),
      online: json['online'] == true,
      lastReadAt: DateTime.tryParse('${json['lastReadAt'] ?? ''}'),
    );
  }

  CollabProfile copyWith({DateTime? lastReadAt, bool? online}) {
    return CollabProfile(
      userId: userId,
      name: name,
      photoUrl: photoUrl,
      email: email,
      role: role,
      department: department,
      employeeId: employeeId,
      online: online ?? this.online,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}

class ChatChannel {
  const ChatChannel({
    required this.id,
    required this.type,
    this.name,
    this.topic,
    this.avatarUrl,
    this.createdById,
    this.unread = 0,
    this.members = const [],
    this.lastPreview,
    this.lastAt,
  });

  final String id;
  final String type;
  final String? name;
  final String? topic;
  final String? avatarUrl;
  final String? createdById;
  final int unread;
  final List<CollabProfile> members;
  final String? lastPreview;
  final DateTime? lastAt;

  bool get isGroup => type == 'GROUP';

  List<CollabProfile> others(String? me) => members.where((m) => m.userId != me).toList();

  bool anyOtherOnline(String? me) => members.any((m) => m.online && m.userId != me);

  String presenceSubtitle(String? me) {
    if (!isGroup) {
      final other = others(me).firstOrNull;
      if (other == null) return 'Saved messages';
      return other.online ? 'Available' : 'Away';
    }
    final peers = others(me);
    final online = peers.where((m) => m.online).toList();
    if (online.isEmpty) return '${members.length} members';
    String first(CollabProfile p) {
      final t = p.name.trim();
      if (t.isEmpty) return 'Someone';
      return t.split(RegExp(r'\s+')).first;
    }
    if (online.length == 1) return '${first(online.first)} available';
    if (online.length == 2) return '${first(online[0])} and ${first(online[1])} available';
    return '${online.length} of ${peers.length} available';
  }

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];
    return ChatChannel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'DIRECT',
      name: json['name'] as String?,
      topic: json['topic'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdById: json['createdById']?.toString(),
      unread: json['unread'] is int ? json['unread'] as int : 0,
      members: (json['members'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CollabProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      lastPreview: last is Map
          ? (last['content'] as String? ??
              ((last['hasAttachment'] == true) ? 'Attachment' : ''))
          : null,
      lastAt: last is Map ? DateTime.tryParse('${last['createdAt'] ?? ''}') : null,
    );
  }

  ChatChannel copyWith({
    int? unread,
    List<CollabProfile>? members,
    String? lastPreview,
    DateTime? lastAt,
    String? name,
    String? topic,
    String? avatarUrl,
    bool clearAvatar = false,
  }) {
    return ChatChannel(
      id: id,
      type: type,
      name: name ?? this.name,
      topic: topic ?? this.topic,
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      createdById: createdById,
      unread: unread ?? this.unread,
      members: members ?? this.members,
      lastPreview: lastPreview ?? this.lastPreview,
      lastAt: lastAt ?? this.lastAt,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    this.senderName,
    this.senderPhoto,
    this.content,
    this.deleted = false,
    this.attachments = const [],
    this.reactions = const [],
    this.replyToId,
    this.replyTo,
    this.seenBy = const [],
    this.unseenBy = const [],
    this.createdAt,
    this.editedAt,
  });

  final String id;
  final String channelId;
  final String senderId;
  final String? senderName;
  final String? senderPhoto;
  final String? content;
  final bool deleted;
  final String? replyToId;
  final ChatReplyPreview? replyTo;
  final List<ChatAttachment> attachments;
  final List<ChatReaction> reactions;
  final List<CollabProfile> seenBy;
  final List<CollabProfile> unseenBy;
  final DateTime? createdAt;
  final DateTime? editedAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      channelId: json['channelId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: sender is Map ? sender['name'] as String? : null,
      senderPhoto: sender is Map ? sender['photoUrl'] as String? : null,
      content: json['content'] as String?,
      deleted: json['deletedAt'] != null,
      replyToId: json['replyToId']?.toString(),
      replyTo: json['replyTo'] is Map
          ? ChatReplyPreview.fromJson(Map<String, dynamic>.from(json['replyTo'] as Map))
          : null,
      attachments: (json['attachments'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ChatAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      reactions: (json['reactions'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ChatReaction.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      seenBy: (json['seenBy'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CollabProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      unseenBy: (json['unseenBy'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CollabProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      editedAt: DateTime.tryParse('${json['editedAt'] ?? ''}'),
    );
  }
}

class ChatReplyPreview {
  const ChatReplyPreview({
    required this.id,
    required this.senderName,
    this.content,
    this.senderId,
  });
  final String id;
  final String senderName;
  final String? content;
  final String? senderId;

  factory ChatReplyPreview.fromJson(Map<String, dynamic> json) => ChatReplyPreview(
        id: json['id']?.toString() ?? '',
        senderName: json['senderName']?.toString() ?? 'Member',
        content: json['content'] as String?,
        senderId: json['senderId']?.toString(),
      );
}

class ChatAttachment {
  const ChatAttachment({required this.fileName, this.id, this.fileUrl, this.mimeType});
  final String? id;
  final String fileName;
  final String? fileUrl;
  final String? mimeType;

  bool get isImage {
    final n = fileName.toLowerCase();
    final mime = (mimeType ?? '').toLowerCase();
    return mime.startsWith('image/') ||
        n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.gif') ||
        n.endsWith('.webp') ||
        n.endsWith('.bmp');
  }

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
        id: json['id']?.toString(),
        fileName: json['fileName']?.toString() ?? 'file',
        fileUrl: json['fileUrl'] as String?,
        mimeType: json['mimeType'] as String?,
      );
}

class ChatReaction {
  const ChatReaction({required this.emoji, required this.count, required this.mine});
  final String emoji;
  final int count;
  final bool mine;
  factory ChatReaction.fromJson(Map<String, dynamic> json) => ChatReaction(
        emoji: json['emoji']?.toString() ?? '',
        count: json['count'] is int ? json['count'] as int : 0,
        mine: json['mine'] == true,
      );
}

class MeetingItem {
  const MeetingItem({
    required this.id,
    required this.code,
    required this.title,
    required this.status,
    this.agenda,
    this.scheduledStart,
    this.scheduledEnd,
    this.startedAt,
    this.endedAt,
    this.summaryText,
    this.recordingUrl,
    this.hasRecording = false,
    this.isHost = false,
    this.waitingRoom = false,
    this.recordEnabled = false,
    this.joinUrl,
    this.hostName,
    this.attendeeCount,
    this.participants = const [],
    this.waitingParticipants = const [],
  });

  final String id;
  final String code;
  final String title;
  final String status;
  final String? agenda;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? summaryText;
  final String? recordingUrl;
  final bool hasRecording;
  final bool isHost;
  final bool waitingRoom;
  final bool recordEnabled;
  final String? joinUrl;
  final String? hostName;
  final int? attendeeCount;
  final List<MeetingPerson> participants;
  final List<MeetingPerson> waitingParticipants;

  factory MeetingItem.fromJson(Map<String, dynamic> json) {
    return MeetingItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Meeting',
      status: json['status']?.toString() ?? 'SCHEDULED',
      agenda: json['agenda'] as String?,
      scheduledStart: DateTime.tryParse('${json['scheduledStart'] ?? ''}'),
      scheduledEnd: DateTime.tryParse('${json['scheduledEnd'] ?? ''}'),
      startedAt: DateTime.tryParse('${json['startedAt'] ?? ''}'),
      endedAt: DateTime.tryParse('${json['endedAt'] ?? ''}'),
      summaryText: json['summaryText'] as String?,
      recordingUrl: json['recordingUrl'] as String?,
      hasRecording: json['hasRecording'] == true ||
          ((json['recordingUrl'] as String?)?.trim().isNotEmpty ?? false),
      isHost: json['isHost'] == true,
      waitingRoom: json['waitingRoom'] == true,
      recordEnabled: json['recordEnabled'] == true,
      joinUrl: json['joinUrl'] as String?,
      hostName: json['hostName'] as String? ??
          (json['host'] is Map ? (json['host'] as Map)['name'] as String? : null),
      attendeeCount: json['attendeeCount'] is int
          ? json['attendeeCount'] as int
          : (json['participants'] is List ? (json['participants'] as List).length : null),
      participants: (json['participants'] as List? ?? [])
          .whereType<Map>()
          .map((e) => MeetingPerson.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      waitingParticipants: (json['waitingParticipants'] as List? ?? [])
          .whereType<Map>()
          .map((e) => MeetingPerson.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class MeetingPerson {
  const MeetingPerson({
    required this.name,
    this.id,
    this.userId,
    this.photoUrl,
    this.role,
    this.email,
    this.isGuest = false,
    this.admission,
    this.joinedAt,
    this.leftAt,
  });
  final String name;
  final String? id;
  final String? userId;
  final String? photoUrl;
  final String? role;
  final String? email;
  final bool isGuest;
  final String? admission;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  factory MeetingPerson.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final userId = json['userId']?.toString();
    return MeetingPerson(
      name: json['name']?.toString() ?? 'Guest',
      id: (id == null || id.isEmpty) ? null : id,
      userId: (userId == null || userId.isEmpty) ? null : userId,
      photoUrl: json['photoUrl']?.toString(),
      role: json['role']?.toString(),
      email: json['email']?.toString(),
      isGuest: json['isGuest'] == true || userId == null || userId.isEmpty,
      admission: json['admission']?.toString(),
      joinedAt: DateTime.tryParse('${json['joinedAt'] ?? ''}'),
      leftAt: DateTime.tryParse('${json['leftAt'] ?? ''}'),
    );
  }
}

class MeetingRecording {
  const MeetingRecording({
    required this.url,
    required this.title,
    required this.code,
    this.ready = false,
    this.canDelete = false,
    this.agenda,
    this.hostName,
    this.summaryText,
    this.startedAt,
    this.endedAt,
    this.attendees = const [],
  });

  final String url;
  final String title;
  final String code;
  final bool ready;
  final bool canDelete;
  final String? agenda;
  final String? hostName;
  final String? summaryText;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<MeetingPerson> attendees;

  factory MeetingRecording.fromJson(Map<String, dynamic> json) {
    return MeetingRecording(
      url: json['url']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Recording',
      code: json['code']?.toString() ?? '',
      ready: json['ready'] != false && (json['url']?.toString().trim().isNotEmpty ?? false),
      canDelete: json['canDelete'] == true,
      agenda: json['agenda'] as String?,
      hostName: json['hostName'] as String?,
      summaryText: json['summaryText'] as String?,
      startedAt: DateTime.tryParse('${json['startedAt'] ?? ''}'),
      endedAt: DateTime.tryParse('${json['endedAt'] ?? ''}'),
      attendees: (json['attendees'] as List? ?? [])
          .whereType<Map>()
          .map((e) => MeetingPerson.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class MeetJoinPayload {
  const MeetJoinPayload({
    required this.meeting,
    required this.livekitUrl,
    required this.livekitToken,
    this.guestToken,
    this.waiting = false,
    this.participant,
  });
  final MeetingItem meeting;
  final String livekitUrl;
  final String livekitToken;
  final String? guestToken;
  final bool waiting;
  final MeetingPerson? participant;

  factory MeetJoinPayload.fromJson(Map<String, dynamic> json) {
    final lk = json['livekit'] is Map ? Map<String, dynamic>.from(json['livekit'] as Map) : <String, dynamic>{};
    return MeetJoinPayload(
      meeting: MeetingItem.fromJson(Map<String, dynamic>.from(json['meeting'] as Map)),
      livekitUrl: lk['url']?.toString() ?? '',
      livekitToken: lk['token']?.toString() ?? '',
      guestToken: json['guestToken'] as String?,
      waiting: json['waiting'] == true,
      participant: json['participant'] is Map
          ? MeetingPerson.fromJson(Map<String, dynamic>.from(json['participant'] as Map))
          : null,
    );
  }
}
