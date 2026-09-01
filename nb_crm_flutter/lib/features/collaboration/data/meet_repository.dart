import '../../../core/network/dio_client.dart';
import '../domain/collab_models.dart';

class MeetRepository {
  const MeetRepository({required DioClient dioClient}) : _dio = dioClient;
  final DioClient _dio;

  Future<List<MeetingItem>> mine() {
    return _dio.getEnvelope(
      'meetings',
      parse: (raw) => (raw as List? ?? [])
          .whereType<Map>()
          .map((e) => MeetingItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<List<MeetingItem>> adminAll() {
    return _dio.getEnvelope(
      'meetings/admin',
      parse: (raw) => (raw as List? ?? [])
          .whereType<Map>()
          .map((e) => MeetingItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<MeetingItem> getByCode(String code) {
    return _dio.getEnvelope(
      'meetings/code/${Uri.encodeComponent(code.trim().toLowerCase())}',
      parse: (raw) => MeetingItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<MeetingItem> getById(String id) {
    return _dio.getEnvelope(
      'meetings/$id',
      parse: (raw) => MeetingItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<MeetingItem> create({
    required String title,
    String? agenda,
    String? scheduledStart,
    String? scheduledEnd,
    bool instant = true,
    bool recordEnabled = false,
    bool waitingRoom = false,
    List<String>? inviteeIds,
  }) {
    return _dio.postEnvelope(
      'meetings',
      data: {
        'title': title,
        if (agenda != null) 'agenda': agenda,
        if (scheduledStart != null) 'scheduledStart': scheduledStart,
        if (scheduledEnd != null) 'scheduledEnd': scheduledEnd,
        'instant': instant,
        'recordEnabled': recordEnabled,
        'waitingRoom': waitingRoom,
        if (inviteeIds != null) 'inviteeIds': inviteeIds,
      },
      parse: (raw) => MeetingItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<MeetingItem> update(
    String id, {
    String? title,
    String? agenda,
    String? scheduledStart,
    String? scheduledEnd,
    bool? recordEnabled,
    bool? waitingRoom,
    List<String>? inviteeIds,
  }) {
    return _dio.patchEnvelope(
      'meetings/$id',
      data: {
        if (title != null) 'title': title,
        if (agenda != null) 'agenda': agenda,
        if (scheduledStart != null) 'scheduledStart': scheduledStart,
        if (scheduledEnd != null) 'scheduledEnd': scheduledEnd,
        if (recordEnabled != null) 'recordEnabled': recordEnabled,
        if (waitingRoom != null) 'waitingRoom': waitingRoom,
        if (inviteeIds != null) 'inviteeIds': inviteeIds,
      },
      parse: (raw) => MeetingItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<MeetingItem> cancel(String id) {
    return _dio.postEnvelope(
      'meetings/$id/cancel',
      data: {},
      parse: (raw) => MeetingItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<MeetJoinPayload> join(String code) {
    return _dio.postEnvelope(
      'meetings/join',
      data: {'code': code},
      parse: (raw) => MeetJoinPayload.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<MeetJoinPayload> guestJoin(String code, String displayName, {String? email}) {
    return _dio.postEnvelope(
      'meetings/guest-join',
      data: {
        'code': code,
        'displayName': displayName,
        if (email != null) 'email': email,
      },
      parse: (raw) => MeetJoinPayload.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<MeetJoinPayload> guestEnter(String guestToken) {
    return _dio.postEnvelope(
      'meetings/guest-enter',
      data: {},
      bearer: guestToken,
      parse: (raw) => MeetJoinPayload.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> admit(String meetingId, String participantId) async {
    await _dio.postEnvelope<Map<String, dynamic>>(
      'meetings/$meetingId/admit',
      data: {'participantId': participantId},
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<void> deny(String meetingId, String participantId) async {
    await _dio.postEnvelope<Map<String, dynamic>>(
      'meetings/$meetingId/deny',
      data: {'participantId': participantId},
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }

  Future<MeetingItem> end(String id) {
    return _dio.postEnvelope(
      'meetings/$id/end',
      data: {},
      receiveTimeout: const Duration(seconds: 180),
      parse: (raw) => MeetingItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<MeetingItem> startRecording(String id) {
    return _dio.postEnvelope(
      'meetings/$id/recording/start',
      data: {},
      parse: (raw) => MeetingItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<MeetingItem> stopRecording(String id) {
    return _dio.postEnvelope(
      'meetings/$id/recording/stop',
      data: {},
      receiveTimeout: const Duration(seconds: 90),
      parse: (raw) => MeetingItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<MeetingRecording> recordingPlayback(String id) {
    return _dio.getEnvelope(
      'meetings/$id/recording',
      parse: (raw) => MeetingRecording.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<MeetingItem> deleteRecording(String id) {
    return _dio.deleteEnvelope(
      'meetings/$id/recording',
      parse: (raw) => MeetingItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<void> ingestTranscriptChunk(
    String meetingId, {
    required String audioBase64,
    String audioFormat = 'wav',
    int samplingRate = 16000,
    String? language,
    DateTime? startedAt,
    DateTime? endedAt,
    String? bearer,
  }) async {
    await _dio.postEnvelope<Object?>(
      'meetings/$meetingId/transcript',
      data: {
        'audioBase64': audioBase64,
        'audioFormat': audioFormat,
        'samplingRate': samplingRate,
        if (language != null) 'language': language,
        if (startedAt != null) 'startedAt': startedAt.toUtc().toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt.toUtc().toIso8601String(),
      },
      bearer: bearer,
      receiveTimeout: const Duration(seconds: 45),
      parse: (_) => null,
    );
  }

  Future<({bool enabled, String language, String? conversationText, List<MeetingUtterance> utterances})>
      listTranscript(String meetingId, {String? bearer}) {
    return _dio.getEnvelope(
      'meetings/$meetingId/transcript',
      bearer: bearer,
      parse: (raw) {
        final map = Map<String, dynamic>.from(raw as Map? ?? {});
        return (
          enabled: map['enabled'] == true,
          language: map['language']?.toString() ?? 'en',
          conversationText: map['conversationText'] as String?,
          utterances: (map['utterances'] as List? ?? [])
              .whereType<Map>()
              .map((e) => MeetingUtterance.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      },
    );
  }

  Future<void> setTranscriptLanguage(String meetingId, String language) async {
    await _dio.postEnvelope<Object?>(
      'meetings/$meetingId/transcript-language',
      data: {'language': language},
      parse: (_) => null,
    );
  }

  Future<({bool enabled, bool online})> sttStatus({String? bearer}) {
    return _dio.getEnvelope(
      'meetings/stt-status',
      bearer: bearer,
      parse: (raw) {
        final map = Map<String, dynamic>.from(raw as Map? ?? {});
        return (
          enabled: map['enabled'] == true,
          online: map['online'] == true,
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> listChat(String meetingId, {String? bearer}) {
    return _dio.getEnvelope(
      'meetings/$meetingId/chat',
      bearer: bearer,
      parse: (raw) => (raw as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }

  Future<void> removeParticipant(String meetingId, String participantId) async {
    await _dio.postEnvelope<Map<String, dynamic>>(
      'meetings/$meetingId/remove',
      data: {'participantId': participantId},
      parse: (raw) => Map<String, dynamic>.from(raw as Map? ?? {}),
    );
  }
}
