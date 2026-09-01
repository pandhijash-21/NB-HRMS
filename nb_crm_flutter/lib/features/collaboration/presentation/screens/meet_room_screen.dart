import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show DesktopCapturerSource;
import 'package:permission_handler/permission_handler.dart';

import '../../../auth/presentation/auth_notifier.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/zoomable_photo.dart';
import '../../domain/collab_models.dart';
import '../collab_providers.dart';
import '../end_meet_progress.dart';
import '../meet_helpers.dart';
import '../meet_local_recorder.dart';
import '../meet_stt_capture.dart';
import '../meet_android_share_stub.dart' if (dart.library.io) '../meet_android_share.dart';

class MeetRoomScreen extends ConsumerStatefulWidget {
  const MeetRoomScreen({
    super.key,
    required this.code,
    this.asGuest = false,
    this.voiceOnly = false,
    this.autoJoin = false,
  });

  final String code;
  final bool asGuest;
  final bool voiceOnly;
  final bool autoJoin;

  @override
  ConsumerState<MeetRoomScreen> createState() => _MeetRoomScreenState();
}

class _MeetRoomScreenState extends ConsumerState<MeetRoomScreen> {
  Room? _room;
  MeetJoinPayload? _join;
  bool _connecting = false;
  bool _waiting = false;
  bool _mic = true;
  bool _cam = true;
  bool _share = false;
  bool _recording = false;
  final _localRecorder = MeetLocalRecorder();
  bool _chatOpen = false;
  String _chatMode = 'ROOM';
  String? _dmTo;
  bool _dmPickerOpen = false;
  String? _guestToken;
  String? _myParticipantId;
  List<MeetingPerson> _waitingFor = [];
  final _busyAdmit = <String>{};
  final _name = TextEditingController();
  final _draft = TextEditingController();
  final _chat = <Map<String, dynamic>>[];
  final _chatToasts = <Map<String, dynamic>>[];
  final _toastTimers = <String, Timer>{};
  String? _summary;
  String? _conversation;
  bool _captionsOn = true;
  String _transcriptLang = 'en';
  bool _whisperOnline = false;
  Timer? _whisperPoll;
  final _captions = <MeetingUtterance>[];
  MeetBhashiniStt? _stt;
  EventsListener<RoomEvent>? _roomEvents;
  MeetingItem? _lobbyMeeting;
  LocalVideoTrack? _previewCam;
  Timer? _admitPoll;
  Timer? _hostWaitPoll;
  bool _didAutoJoin = false;
  bool _handRaised = false;
  bool _emojiOpen = false;
  bool _peopleOpen = false;
  int _presenterIndex = 0;
  bool _leaving = false;
  String? _busyLabel;
  bool _shareFullscreenOpen = false;
  final _hands = <String, String>{};
  final _floatReactions = <({String id, String emoji, String name})>[];
  final _reactionTimers = <String, Timer>{};

  static const _connectTimeouts = Timeouts(
    connection: Duration(seconds: 40),
    debounce: Duration(milliseconds: 20),
    publish: Duration(seconds: 15),
    subscribe: Duration(seconds: 15),
    peerConnection: Duration(seconds: 40),
    iceRestart: Duration(seconds: 15),
  );

  // Client ICE wins over the server list. A misconfigured LiveKit stun_servers
  // value (e.g. "stun:stun.l.google.com:19302") crashes RTCPeerConnection with
  // "Invalid port" before media can start.
  static const _rtcConfig = RTCConfiguration(
    iceServers: [
      RTCIceServer(urls: ['stun:stun.l.google.com:19302']),
    ],
  );

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      if (mounted) setState(() {});
    });
    _cam = !widget.voiceOnly;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _restoreGuestName();
      unawaited(_loadLobbyMeeting());
      if (widget.autoJoin) {
        unawaited(_tryAutoJoin());
      } else if (!widget.voiceOnly) {
        unawaited(_startLobbyPreview());
      }
    });
  }

  @override
  void dispose() {
    _admitPoll?.cancel();
    _hostWaitPoll?.cancel();
    _whisperPoll?.cancel();
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    _toastTimers.clear();
    for (final timer in _reactionTimers.values) {
      timer.cancel();
    }
    _reactionTimers.clear();
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    final room = _room;
    _room = null;
    room?.removeListener(_onRoom);
    room?.disconnect();
    _previewCam?.stop();
    _name.dispose();
    _draft.dispose();
    unawaited(_roomEvents?.dispose());
    unawaited(_stt?.dispose());
    super.dispose();
  }

  void _onRoom() {
    if (!mounted) return;
    final local = _room?.localParticipant;
    final sharing = local?.videoTrackPublications.any(
          (t) => t.source == TrackSource.screenShareVideo && !t.muted,
        ) ??
        false;
    setState(() => _share = sharing);
  }

  String get _code => sanitizeMeetCode(widget.code);

  bool _isHostViewer(AuthState auth) {
    final meeting = _join?.meeting ?? _lobbyMeeting;
    if (meeting == null) return false;
    if (meeting.isHost) return true;
    final uid = auth.user?.id;
    return uid != null && uid.isNotEmpty && meeting.hostUserId == uid;
  }

  Future<String?> _meetBearer({String? guestToken}) async {
    if (guestToken != null && guestToken.isNotEmpty) return guestToken;
    if (_guestToken != null && _guestToken!.isNotEmpty) return _guestToken;
    return ref.read(secureStorageProvider).readToken();
  }

  Future<void> _tryAutoJoin() async {
    if (_didAutoJoin || widget.asGuest) return;
    _didAutoJoin = true;
    for (var i = 0; i < 25; i++) {
      if (!mounted) return;
      if (ref.read(authNotifierProvider).status != AuthStatus.unknown) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted || _room != null || _connecting || _waiting) return;
    final auth = ref.read(authNotifierProvider);
    if (!auth.isAuthenticated) {
      _didAutoJoin = false;
      return;
    }
    await _joinMember();
  }

  Future<void> _ensureMedia() async {
    if (kIsWeb) return;
    try {
      final perms = <Permission>[
        Permission.microphone,
        if (!widget.voiceOnly) Permission.camera,
      ];
      await perms.request().timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> _startLobbyPreview() async {
    await _ensureMedia();
    if (!mounted || _previewCam != null || _room != null) return;
    try {
      final track = await LocalVideoTrack.createCameraTrack();
      if (!mounted || _room != null) {
        await track.stop();
        return;
      }
      setState(() {
        _previewCam = track;
        _cam = true;
      });
    } catch (_) {
      if (mounted) setState(() => _cam = false);
    }
  }

  Future<void> _stopLobbyPreview() async {
    await _previewCam?.stop();
    if (mounted) {
      setState(() => _previewCam = null);
    } else {
      _previewCam = null;
    }
  }

  Future<void> _toggleLobbyCam() async {
    final next = !_cam;
    try {
      if (next) {
        if (_previewCam == null) {
          await _startLobbyPreview();
          return;
        }
        await _previewCam!.unmute();
      } else {
        await _previewCam?.mute();
      }
    } catch (_) {}
    if (mounted) setState(() => _cam = next);
  }

  Future<void> _loadLobbyMeeting() async {
    try {
      if (!widget.asGuest) {
        for (var i = 0; i < 20; i++) {
          if (!mounted) return;
          if (ref.read(authNotifierProvider).status != AuthStatus.unknown) break;
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
      final meeting = await ref.read(meetRepositoryProvider).getByCode(_code);
      if (!mounted) return;
      setState(() => _lobbyMeeting = meeting);
      if (!_connecting && _room == null && !_waiting && (meeting.isHost || widget.autoJoin)) {
        unawaited(_tryAutoJoin());
      }
    } catch (_) {}
  }

  Future<void> _restoreGuestName() async {
    final session = await loadMeetSession(_code);
    final name = session?.guestName?.trim();
    if (name != null && name.isNotEmpty && mounted) {
      _name.text = name;
    }
  }

  Future<void> _leaveLobby() async {
    await clearMeetSession(_code);
    await _stopLobbyPreview();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/meet');
    }
  }

  bool _isEndedError(Object error) {
    final lower = '$error'.toLowerCase();
    return lower.contains('ended') || lower.contains('cancelled') || lower.contains('canceled');
  }

  bool _isJoinSignalTimeout(Object error) {
    final raw = '$error'.toLowerCase();
    return raw.contains('signaljoin') || raw.contains('timed out waiting');
  }

  Future<void> _showJoinError(Object error, {Future<void> Function()? onRetry}) async {
    final raw = '$error';
    final lower = raw.toLowerCase();
    final title = lower.contains('ended')
        ? 'Meeting ended'
        : lower.contains('cancel')
            ? 'Meeting cancelled'
            : lower.contains('not found') || lower.contains('invalid')
                ? 'Invalid meeting code'
                : "Couldn't join";
    final message = lower.contains('ended')
        ? 'This meeting has already ended.'
        : lower.contains('cancel')
            ? 'This meeting was cancelled.'
            : lower.contains('not found') || lower.contains('invalid')
                ? 'This meeting code is invalid. Check the code and try again.'
                : _isJoinSignalTimeout(error)
                    ? 'Could not reach the meeting room after refresh. Wait a moment and try again.'
                    : lower.contains('ice') || lower.contains('peerconnection') || lower.contains('mediaconnect')
                        ? 'Could not connect audio/video. Check that LiveKit is running, then try joining again.'
                        : raw;
    final retry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('OK')),
          if (onRetry != null && !_isEndedError(error))
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Try again')),
        ],
      ),
    );
    if (_isEndedError(error)) await clearMeetSession(_code);
    if (retry == true && mounted && !_isEndedError(error)) await onRetry?.call();
  }

  Future<void> _bindSocket(String meetingId, {String? guestToken}) async {
    final token = guestToken ?? await ref.read(secureStorageProvider).readToken();
    if (token == null || token.isEmpty) return;
    final socket = ref.read(collabSocketProvider)..connect(token: token);
    socket.joinMeeting(meetingId);
    socket.onMeetingChat((row) {
      if (!mounted) return;
      setState(() => _upsertChat(row, toast: true));
    });
    socket.onMeetingTranscript((row) {
      if (!mounted) return;
      setState(() {
        _captions.removeWhere((e) => e.id == row.id);
        _captions.add(row);
        if (_captions.length > 40) {
          _captions.removeRange(0, _captions.length - 40);
        }
      });
    });
    socket.onMeetingTranscriptLang((language) {
      if (!mounted) return;
      setState(() => _transcriptLang = language);
      _stt?.setLanguage(language);
    });
    try {
      final history = await ref.read(meetRepositoryProvider).listChat(
            meetingId,
            bearer: await _meetBearer(guestToken: guestToken),
          );
      if (mounted && history.isNotEmpty) {
        setState(() {
          for (final row in history) {
            _upsertChat(row);
          }
        });
      }
    } catch (_) {}
    socket.onWaitingUpdate((waiting) {
      if (!mounted) return;
      setState(() => _waitingFor = waiting);
    });
    socket.onWaitingKnock((person) {
      if (!mounted) return;
      setState(() {
        if (_waitingFor.any((p) => p.id != null && p.id == person.id)) return;
        _waitingFor = [..._waitingFor, person];
      });
    });
    socket.onJoinApproved((participantId) async {
      if (!_waiting) return;
      if (participantId != null && _myParticipantId != null && participantId != _myParticipantId) {
        return;
      }
      try {
        final payload = _guestToken != null
            ? await ref.read(meetRepositoryProvider).guestEnter(_guestToken!)
            : await ref.read(meetRepositoryProvider).join(_code);
        if (!mounted) return;
        if (!payload.waiting && payload.livekitUrl.isNotEmpty) {
          await _connect(payload, guestToken: _guestToken);
        }
      } catch (_) {
        if (mounted) setState(() => _connecting = false);
      }
    });
    socket.onJoinDenied((participantId) {
      if (!_waiting) return;
      if (participantId != null && _myParticipantId != null && participantId != _myParticipantId) {
        return;
      }
      if (!mounted) return;
      setState(() => _waiting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The host declined your request to join')),
      );
    });
    socket.onMeetingEnded((meetingId, _) {
      if (_join?.meeting.id != meetingId) return;
      if (_join?.meeting.isHost == true) return;
      unawaited(_onRemoteEnded());
    });
    socket.onMeetingHand((row) {
      if (!mounted) return;
      final id = row['identity']?.toString() ?? '';
      if (id.isEmpty) return;
      setState(() {
        if (row['raised'] == false) {
          _hands.remove(id);
          if (id == _room?.localParticipant?.identity) _handRaised = false;
        } else {
          _hands[id] = row['name']?.toString() ?? 'Someone';
          if (id == _room?.localParticipant?.identity) _handRaised = true;
        }
      });
    });
    socket.onMeetingReaction((row) {
      if (!mounted) return;
      final emoji = row['emoji']?.toString() ?? '';
      if (emoji.isEmpty) return;
      final id = '${DateTime.now().microsecondsSinceEpoch}';
      setState(() {
        _floatReactions.add((id: id, emoji: emoji, name: row['name']?.toString() ?? ''));
        if (_floatReactions.length > 10) _floatReactions.removeRange(0, _floatReactions.length - 10);
      });
      _reactionTimers[id]?.cancel();
      _reactionTimers[id] = Timer(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        setState(() => _floatReactions.removeWhere((r) => r.id == id));
        _reactionTimers.remove(id);
      });
    });
    socket.onMeetingRemoved((row) {
      final part = row['participantId']?.toString();
      final identity = row['identity']?.toString();
      final mine = _myParticipantId;
      final meIdentity = _room?.localParticipant?.identity;
      final isMe = (part != null && mine != null && part == mine) ||
          (identity != null && meIdentity != null && identity == meIdentity);
      if (!isMe) return;
      _onKicked();
    });
    socket.onRecording((active) {
      if (!mounted) return;
      if (_join?.meeting.isHost == true && _localRecorder.active) {
        setState(() => _recording = true);
        return;
      }
      setState(() => _recording = active);
    });
  }

  void _upsertChat(Map<String, dynamic> row, {bool toast = false}) {
    final id = row['id']?.toString();
    if (id != null && id.isNotEmpty) {
      final existing = _chat.indexWhere((r) => r['id']?.toString() == id);
      if (existing >= 0) {
        _chat[existing] = row;
        return;
      }
    }
    final content = row['content']?.toString();
    _chat.removeWhere(
      (r) =>
          r['id']?.toString().startsWith('local-') == true &&
          r['content']?.toString() == content &&
          (r['scope'] ?? 'ROOM') == (row['scope'] ?? 'ROOM'),
    );
    _chat.add(row);
    if (toast) _pushChatToast(row);
  }

  String? get _myUserId =>
      ref.read(authNotifierProvider).user?.id ?? _join?.participant?.userId;

  bool _chatIsMine(Map<String, dynamic> row) {
    final senderUser = row['senderUserId']?.toString();
    final senderPart = row['senderParticipantId']?.toString();
    final meUser = _myUserId;
    if (meUser != null && meUser.isNotEmpty && senderUser == meUser) return true;
    if (_myParticipantId != null && senderPart == _myParticipantId) return true;
    return false;
  }

  bool _chatIsForMe(Map<String, dynamic> row) {
    if ((row['scope'] ?? 'ROOM') != 'DIRECT') return true;
    final recUser = row['recipientUserId']?.toString();
    final recPart = row['recipientParticipantId']?.toString();
    final meUser = _myUserId;
    if (meUser != null && meUser.isNotEmpty && recUser == meUser) return true;
    if (_myParticipantId != null && recPart == _myParticipantId) return true;
    return _chatIsMine(row);
  }

  void _pushChatToast(Map<String, dynamic> row) {
    if (!mounted) return;
    if (row['id']?.toString().startsWith('local-') == true) return;
    if (_chatIsMine(row)) return;
    if (row['scope'] == 'DIRECT' && !_chatIsForMe(row)) return;
    final showing = _chatOpen && ((row['scope'] ?? 'ROOM') == _chatMode);
    if (showing) return;
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    _chatToasts.removeWhere((t) => t['id']?.toString() == id);
    _chatToasts.add(row);
    if (_chatToasts.length > 3) _chatToasts.removeRange(0, _chatToasts.length - 3);
    _toastTimers[id]?.cancel();
    _toastTimers[id] = Timer(const Duration(milliseconds: 6500), () {
      if (!mounted) return;
      setState(() => _chatToasts.removeWhere((t) => t['id']?.toString() == id));
      _toastTimers.remove(id);
    });
  }

  String _peerKey(MeetingPerson p) {
    if (p.id != null && p.id!.isNotEmpty) return p.id!;
    if (p.userId != null && p.userId!.isNotEmpty) return 'user:${p.userId}';
    return p.name;
  }

  bool _isSelfPerson(MeetingPerson p) {
    if (_myParticipantId != null && p.id != null && p.id == _myParticipantId) return true;
    final meUser = _myUserId;
    if (meUser != null && meUser.isNotEmpty && p.userId == meUser) return true;
    return false;
  }

  List<MeetingPerson> _dmPeople() {
    final people = <MeetingPerson>[];
    final seen = <String>{};

    void add(MeetingPerson p) {
      if (_isSelfPerson(p)) return;
      final aliases = <String>[
        if (p.id != null && p.id!.isNotEmpty) p.id!,
        if (p.userId != null && p.userId!.isNotEmpty) 'user:${p.userId}',
      ];
      if (aliases.isEmpty || aliases.any(seen.contains)) return;
      seen.addAll(aliases);
      people.add(p);
    }

    for (final p in _join?.meeting.participants ?? const <MeetingPerson>[]) {
      add(p);
    }
    final hostId = _join?.meeting.hostUserId;
    if (hostId != null && hostId.isNotEmpty) {
      add(MeetingPerson(
        name: _join?.meeting.hostName ?? 'Host',
        userId: hostId,
        role: 'HOST',
      ));
    }
    final remotes = _room?.remoteParticipants.values;
    if (remotes != null) {
      for (final p in remotes) {
        final identity = p.identity;
        String? userId;
        String? partId;
        var guest = true;
        if (identity.startsWith('user:')) {
          userId = identity.substring(5);
          guest = false;
        } else if (identity.startsWith('guest:')) {
          partId = identity.substring(6);
        }
        add(MeetingPerson(
          name: p.name.trim().isEmpty ? (guest ? 'Guest' : 'Member') : p.name,
          id: partId,
          userId: userId,
          isGuest: guest,
        ));
      }
    }
    return people;
  }

  bool _dmThreadMatches(Map<String, dynamic> row, MeetingPerson peer) {
    if ((row['scope'] ?? 'ROOM') != 'DIRECT') return false;
    final peerUser = peer.userId;
    final peerPart = peer.id;
    final hit = (peerPart != null &&
            peerPart.isNotEmpty &&
            (row['senderParticipantId']?.toString() == peerPart ||
                row['recipientParticipantId']?.toString() == peerPart)) ||
        (peerUser != null &&
            peerUser.isNotEmpty &&
            (row['senderUserId']?.toString() == peerUser ||
                row['recipientUserId']?.toString() == peerUser));
    return hit && (_chatIsMine(row) || _chatIsForMe(row));
  }

  Future<void> _dropRoom(Room? room) async {
    _whisperPoll?.cancel();
    _whisperPoll = null;
    await _stt?.stop();
    _stt = null;
    await _roomEvents?.dispose();
    _roomEvents = null;
    if (_localRecorder.active) {
      try {
        await _localRecorder.discard().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    if (room == null) return;
    room.removeListener(_onRoom);
    try {
      await room.disconnect().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> _closeShareOverlay() async {
    if (!_shareFullscreenOpen) return;
    _shareFullscreenOpen = false;
    if (!mounted) return;
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
    try {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
  }

  Future<void> _teardownCall({
    required String reason,
    bool popRoute = false,
  }) async {
    if (_leaving) return;
    if (mounted) {
      setState(() {
        _leaving = true;
        _busyLabel = popRoute ? 'Leaving meeting…' : 'Meeting ended. Cleaning up…';
      });
    }
    _admitPoll?.cancel();
    _hostWaitPoll?.cancel();
    await _closeShareOverlay();
    await clearMeetSession(_code);
    final room = _room;
    _room = null;
    try {
      await _dropRoom(room).timeout(const Duration(seconds: 4));
    } catch (_) {}
    if (!mounted) return;
    if (popRoute) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _leaving = false;
      _busyLabel = null;
      _summary = reason;
      _recording = false;
    });
  }

  Future<void> _publishLocalMedia(Room room) async {
    try {
      await room.localParticipant?.setMicrophoneEnabled(_mic).timeout(const Duration(seconds: 10));
    } catch (_) {}
    if (widget.voiceOnly || !_cam) return;
    try {
      await room.localParticipant?.setCameraEnabled(true).timeout(const Duration(seconds: 10));
    } catch (_) {
      if (mounted) setState(() => _cam = false);
    }
  }

  void _bindSttRoomEvents(Room room) {
    unawaited(_roomEvents?.dispose());
    final events = room.createListener();
    _roomEvents = events;
    events
      ..on<LocalTrackPublishedEvent>((e) {
        if (e.publication.source == TrackSource.microphone) {
          _stt?.attach(room);
        }
      })
      ..on<TrackUnmutedEvent>((e) {
        if (e.participant is LocalParticipant &&
            e.publication.source == TrackSource.microphone) {
          _stt?.setMicEnabled(true);
          _stt?.attach(room);
        }
      });
  }

  Future<void> _connect(MeetJoinPayload payload, {String? guestToken}) async {
    _admitPoll?.cancel();
    setState(() {
      _connecting = true;
      _waiting = false;
    });
    final previous = _room;
    _room = null;
    await _dropRoom(previous);
    await _stopLobbyPreview();
    await _ensureMedia();

    if (payload.livekitUrl.isEmpty || payload.livekitToken.isEmpty) {
      throw Exception('Meeting room is not available yet. Try again.');
    }

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    room.addListener(_onRoom);
    try {
      await room
          .connect(
            payload.livekitUrl,
            payload.livekitToken,
            connectOptions: const ConnectOptions(
              timeouts: _connectTimeouts,
              rtcConfiguration: _rtcConfig,
            ),
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () => throw Exception(
              'Timed out connecting to the meeting room. Check that LiveKit is running, then try again.',
            ),
          );
    } catch (e) {
      await _dropRoom(room);
      rethrow;
    }

    if (!mounted) {
      await _dropRoom(room);
      return;
    }
    setState(() {
      _room = room;
      _join = payload;
      _connecting = false;
      _recording = false;
      _waitingFor = payload.meeting.waitingParticipants;
    });
    try {
      await _bindSocket(payload.meeting.id, guestToken: guestToken);
      await saveMeetSession(
        code: _code,
        guest: guestToken != null,
        guestToken: guestToken,
        guestName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
    } catch (_) {}
    await _publishLocalMedia(room);
    if (!mounted) return;
    _bindSttRoomEvents(room);
    _transcriptLang = payload.meeting.transcriptLanguage ?? 'en';
    _whisperOnline = payload.meeting.whisperOnline;
    _captions
      ..clear()
      ..addAll(payload.meeting.utterances);
    final stt = MeetBhashiniStt(repo: ref.read(meetRepositoryProvider));
    _stt = stt;
    final bearer = await _meetBearer(guestToken: guestToken);
    unawaited(stt.start(
      meetingId: payload.meeting.id,
      language: _transcriptLang,
      bearer: bearer,
      room: room,
    ));
    _startWhisperPoll(bearer: bearer);
    if (payload.meeting.isHost) _startHostWaitingPoll();
  }

  Future<void> _beginWait(MeetJoinPayload payload, {String? guestToken}) async {
    setState(() {
      _waiting = true;
      _join = payload;
      _guestToken = guestToken;
      _myParticipantId = payload.participant?.id;
      _waitingFor = payload.meeting.waitingParticipants;
    });
    await _bindSocket(payload.meeting.id, guestToken: guestToken);
    _startAdmitPoll();
  }

  void _startAdmitPoll() {
    _admitPoll?.cancel();
    _admitPoll = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollAdmission());
    });
  }

  void _startHostWaitingPoll() {
    _hostWaitPoll?.cancel();
    _hostWaitPoll = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollHostWaiting());
    });
  }

  void _startWhisperPoll({String? bearer}) {
    _whisperPoll?.cancel();
    Future<void> tick() async {
      try {
        final status = await ref.read(meetRepositoryProvider).sttStatus(bearer: bearer);
        if (!mounted) return;
        if (_whisperOnline != status.online) {
          setState(() => _whisperOnline = status.online);
        }
      } catch (_) {
        if (mounted && _whisperOnline) setState(() => _whisperOnline = false);
      }
    }
    unawaited(tick());
    _whisperPoll = Timer.periodic(const Duration(seconds: 12), (_) => unawaited(tick()));
  }

  Future<void> _pollAdmission() async {
    if (!mounted || !_waiting || _room != null) return;
    try {
      final payload = _guestToken != null
          ? await ref.read(meetRepositoryProvider).guestEnter(_guestToken!)
          : await ref.read(meetRepositoryProvider).join(_code);
      if (!mounted || !_waiting) return;
      if (!payload.waiting && payload.livekitUrl.isNotEmpty) {
        _admitPoll?.cancel();
        await _connect(payload, guestToken: _guestToken);
      }
    } catch (_) {}
  }

  Future<void> _pollHostWaiting() async {
    final id = _join?.meeting.id;
    if (!mounted || id == null || _join?.meeting.isHost != true || _room == null) return;
    try {
      final meeting = await ref.read(meetRepositoryProvider).getById(id);
      if (!mounted) return;
      setState(() => _waitingFor = meeting.waitingParticipants);
    } catch (_) {}
  }

  Future<void> _joinMember() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      final payload = await ref.read(meetRepositoryProvider).join(_code);
      if (!mounted) return;
      _myParticipantId = payload.participant?.id;
      final host = payload.meeting.isHost;
      if (payload.waiting && !host) {
        await _beginWait(payload);
        if (mounted) setState(() => _connecting = false);
        return;
      }
      if (payload.livekitUrl.isEmpty || payload.livekitToken.isEmpty) {
        throw Exception('Meeting room is not available yet. Try again.');
      }
      try {
        await _connect(payload);
      } catch (e) {
        if (!_isJoinSignalTimeout(e) || !mounted) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final retry = await ref.read(meetRepositoryProvider).join(_code);
        if (!mounted) return;
        await _connect(retry);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _connecting = false);
      if (!widget.voiceOnly) await _startLobbyPreview();
      await _showJoinError(e, onRetry: _joinMember);
    }
  }

  Future<void> _enterGuest(String guestToken) async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      final payload = await ref.read(meetRepositoryProvider).guestEnter(guestToken);
      if (!mounted) return;
      _guestToken = guestToken;
      _myParticipantId = payload.participant?.id;
      await saveMeetSession(
        code: _code,
        guest: true,
        guestToken: guestToken,
        guestName: _name.text.trim().isEmpty ? payload.participant?.name : _name.text.trim(),
      );
      if (payload.waiting) {
        await _beginWait(payload, guestToken: guestToken);
        if (mounted) setState(() => _connecting = false);
        return;
      }
      if (payload.livekitUrl.isEmpty || payload.livekitToken.isEmpty) {
        throw Exception('Meeting room is not available yet. Try again.');
      }
      try {
        await _connect(payload, guestToken: guestToken);
      } catch (e) {
        if (!_isJoinSignalTimeout(e) || !mounted) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final retry = await ref.read(meetRepositoryProvider).guestEnter(guestToken);
        if (!mounted) return;
        await _connect(retry, guestToken: guestToken);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _connecting = false);
      await _startLobbyPreview();
      await _showJoinError(e, onRetry: () => _enterGuest(guestToken));
    }
  }

  Future<void> _joinGuest() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      final saved = await loadMeetSession(_code);
      if (saved?.guest == true && saved?.guestToken != null && saved!.guestToken!.isNotEmpty) {
        setState(() => _connecting = false);
        await _enterGuest(saved.guestToken!);
        return;
      }
      final payload = await ref.read(meetRepositoryProvider).guestJoin(_code, _name.text.trim());
      if (!mounted) return;
      _guestToken = payload.guestToken;
      _myParticipantId = payload.participant?.id;
      await saveMeetSession(
        code: _code,
        guest: true,
        guestToken: payload.guestToken,
        guestName: _name.text.trim(),
      );
      if (payload.waiting) {
        await _beginWait(payload, guestToken: payload.guestToken);
        if (mounted) setState(() => _connecting = false);
        return;
      }
      if (payload.livekitUrl.isEmpty || payload.livekitToken.isEmpty) {
        throw Exception('Meeting room is not available yet. Try again.');
      }
      try {
        await _connect(payload, guestToken: payload.guestToken);
      } catch (e) {
        if (!_isJoinSignalTimeout(e) || !mounted) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final token = payload.guestToken;
        final retry = token != null
            ? await ref.read(meetRepositoryProvider).guestEnter(token)
            : await ref.read(meetRepositoryProvider).guestJoin(_code, _name.text.trim());
        if (!mounted) return;
        await _connect(retry, guestToken: retry.guestToken ?? token);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _connecting = false);
      await _startLobbyPreview();
      await _showJoinError(e, onRetry: _joinGuest);
    }
  }

  Future<void> _onKicked() async {
    await _teardownCall(reason: 'The host removed you from this meeting.');
  }

  Future<void> _onRemoteEnded() async {
    await _teardownCall(reason: 'This meeting has ended. The host closed the room.');
  }

  Future<bool> _confirmEndMeet() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this meeting?'),
        content: Text(
          _recording
              ? 'Your recording will be saved on this device first, then everyone will be removed. This meeting link cannot be used again.'
              : 'Everyone will be removed and this meeting link cannot be used again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('End meet'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _leaveCall() async {
    await _teardownCall(reason: '', popRoute: true);
  }

  Future<void> _endMeetFromCall() async {
    if (!await _confirmEndMeet() || !mounted) return;
    final join = _join;
    if (join == null) return;
    if (_localRecorder.active) {
      try {
        final saved = await _localRecorder.stopAndSave();
        try {
          await ref.read(meetRepositoryProvider).stopRecording(join.meeting.id);
        } catch (_) {}
        if (mounted) {
          setState(() => _recording = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(saved == null ? 'Recording discarded' : 'Recording saved on this device')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
    final token = _guestToken ?? await ref.read(secureStorageProvider).readToken();
    if (token != null) {
      ref.read(collabSocketProvider).connect(token: token);
    }
    if (!mounted) return;
    final ended = await showEndMeetProgress(
      context: context,
      meetingId: join.meeting.id,
      socket: ref.read(collabSocketProvider),
      repo: ref.read(meetRepositoryProvider),
      hasRecording: false,
    );
    if (!mounted) return;
    await clearMeetSession(_code);
    final room = _room;
    _room = null;
    await _dropRoom(room);
    if (!mounted) return;
    setState(() => _summary = ended?.summaryText ?? 'Meeting ended.');
    setState(() => _conversation = ended?.conversationText);
  }

  Future<void> _leave() async {
    final join = _join;
    final me = ref.read(authNotifierProvider).user?.id;
    final isHost = join != null &&
        (join.meeting.isHost || join.meeting.participants.any((p) => p.role == 'HOST' && p.userId == me));
    if (isHost) {
      await _endMeetFromCall();
      return;
    }
    await _leaveCall();
  }

  Future<bool> _confirmStopPresenting() async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Stop presenting?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'You will stop sharing your screen with everyone in this meeting.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC5A059),
              foregroundColor: const Color(0xFF161616),
            ),
            child: const Text('Stop presenting'),
          ),
        ],
      ),
    );
    return stop == true;
  }

  Future<void> _pickTranscriptLanguage() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Speech-to-text language',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            for (final lang in meetSttLanguages)
              ListTile(
                title: Text(lang.label, style: const TextStyle(color: Colors.white)),
                trailing: lang.code == _transcriptLang
                    ? const NbIcon(Icons.check, color: Color(0xFFC5A059))
                    : null,
                onTap: () => Navigator.pop(ctx, lang.code),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _transcriptLang = picked);
    _stt?.setLanguage(picked);
    final id = _join?.meeting.id;
    if (id == null) return;
    try {
      await ref.read(meetRepositoryProvider).setTranscriptLanguage(id, picked);
    } catch (_) {}
  }

  Future<void> _toggleScreenShare() async {
    if (_share) {
      final stop = await _confirmStopPresenting();
      if (!stop || !mounted) return;
      try {
        await _room!.localParticipant?.setScreenShareEnabled(false);
      } catch (_) {}
      await stopAndroidScreenShare();
      return;
    }
    if (lkPlatformIsWebMobile()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screen share is not supported in mobile browsers. Use the Android or iOS app.')),
      );
      return;
    }
    try {
      if (mounted) setState(() => _busyLabel = 'Starting screen share…');
      if (lkPlatformIs(PlatformType.android)) {
        final ok = await prepareAndroidScreenShare();
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Screen share permission was denied')),
            );
          }
          return;
        }
      }
      if (lkPlatformIsDesktop()) {
        final source = await showDialog<DesktopCapturerSource>(
          context: context,
          builder: (ctx) => ScreenSelectDialog(),
        );
        if (source == null || !mounted) return;
        final track = await LocalVideoTrack.createScreenShareTrack(
          ScreenShareCaptureOptions(sourceId: source.id, maxFrameRate: 15),
        );
        await _room!.localParticipant?.publishVideoTrack(track);
        return;
      }
      await _room!.localParticipant?.setScreenShareEnabled(
        true,
        captureScreenAudio: true,
        screenShareCaptureOptions: const _ScreenShareNoCursorOptions(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Screen share failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  Future<void> _sendReaction(String emoji) async {
    final id = _join?.meeting.id;
    if (id == null) return;
    setState(() => _emojiOpen = false);
    ref.read(collabSocketProvider).meetingReaction(meetingId: id, emoji: emoji);
  }

  Future<void> _toggleHand() async {
    final id = _join?.meeting.id;
    if (id == null) return;
    final next = !_handRaised;
    setState(() => _handRaised = next);
    ref.read(collabSocketProvider).meetingHand(meetingId: id, raised: next);
  }

  MeetingPerson? _rosterFor(Participant p) {
    final parsedUser = p.identity.startsWith('user:') ? p.identity.substring(5) : null;
    final parsedGuest = p.identity.startsWith('guest:') ? p.identity.substring(6) : null;
    for (final person in _join?.meeting.participants ?? const <MeetingPerson>[]) {
      if (parsedUser != null && person.userId == parsedUser) return person;
      if (parsedGuest != null && person.id == parsedGuest) return person;
    }
    return null;
  }

  Future<void> _removeParticipant(Participant p) async {
    final meetingId = _join?.meeting.id;
    final person = _rosterFor(p);
    if (meetingId == null || person?.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remove from meeting?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${p.name.isEmpty ? 'This guest' : p.name} will be removed from the call.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(meetRepositoryProvider).removeParticipant(meetingId, person!.id!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _toggleRecording() async {
    final id = _join?.meeting.id;
    if (id == null) return;
    final start = !_recording;
    if (start && _room == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          start ? 'Start recording?' : 'Stop recording?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          start
              ? 'Only you (the host) can record. The file is saved on this device, not in the cloud. When asked, pick this meeting window so everyone on screen is captured.'
              : 'Stop recording and save the file on this device?',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: start ? const Color(0xFFB91C1C) : const Color(0xFFC5A059),
              foregroundColor: start ? Colors.white : const Color(0xFF161616),
            ),
            child: Text(start ? 'Start recording' : 'Stop recording'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyLabel = start ? 'Starting recording…' : 'Saving recording…');
    try {
      if (start) {
        await _localRecorder.start(room: _room!, code: _code);
        try {
          await ref.read(meetRepositoryProvider).startRecording(id);
        } catch (_) {}
        if (!mounted) return;
        setState(() => _recording = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording on this device')),
        );
      } else {
        final saved = await _localRecorder.stopAndSave();
        try {
          await ref.read(meetRepositoryProvider).stopRecording(id);
        } catch (_) {}
        if (!mounted) return;
        setState(() => _recording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(saved == null ? 'Recording discarded' : 'Recording saved on this device')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  Future<void> _admitPerson(MeetingPerson person, {required bool admit}) async {
    final id = person.id;
    if (id == null || _join == null || _busyAdmit.contains(id)) return;
    setState(() => _busyAdmit.add(id));
    try {
      if (admit) {
        await ref.read(meetRepositoryProvider).admit(_join!.meeting.id, id);
      } else {
        await ref.read(meetRepositoryProvider).deny(_join!.meeting.id, id);
      }
      if (!mounted) return;
      setState(() => _waitingFor = _waitingFor.where((p) => p.id != id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyAdmit.remove(id));
    }
  }

  Future<void> _admitAllWaiting() async {
    final people = List<MeetingPerson>.from(_waitingFor);
    for (final person in people) {
      await _admitPerson(person, admit: true);
    }
  }

  bool _isLocal(Participant p) => p is LocalParticipant || identical(p, _room?.localParticipant);

  String _labelFor(Participant p) => meetParticipantLabel(
        name: p.name,
        identity: p.identity,
        isLocal: _isLocal(p),
      );

  String? _photoForParticipant(Participant p) {
    final people = _join?.meeting.participants ?? const <MeetingPerson>[];
    final identity = p.identity;
    MeetingPerson? match;
    if (identity.isNotEmpty) {
      final uid = identity.startsWith('user:') ? identity.substring(5) : identity;
      for (final person in people) {
        if (person.userId == uid ||
            person.userId == identity ||
            person.id == uid ||
            person.id == identity) {
          match = person;
          break;
        }
      }
    }
    match ??= people.where((x) => x.name == p.name).firstOrNull;
    if ((match?.photoUrl ?? '').isNotEmpty) return match!.photoUrl;
    final meta = p.metadata;
    if (meta != null && meta.isNotEmpty) {
      try {
        final decoded = jsonDecode(meta);
        if (decoded is Map && decoded['photoUrl'] != null) {
          final url = decoded['photoUrl'].toString().trim();
          if (url.isNotEmpty) return url;
        }
      } catch (_) {}
    }
    return null;
  }

  VideoTrack? _screenTrack(Participant p) {
    for (final pub in p.videoTrackPublications) {
      if (pub.source == TrackSource.screenShareVideo && !pub.muted && pub.track is VideoTrack) {
        return pub.track as VideoTrack;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (prev?.isAuthenticated == true || !next.isAuthenticated) return;
      unawaited(_loadLobbyMeeting());
      if (widget.autoJoin) unawaited(_tryAutoJoin());
    });
    if (_leaving && _summary == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LinearProgressIndicator(
                  minHeight: 4,
                  color: Color(0xFFC5A059),
                  backgroundColor: Color(0xFF333333),
                ),
                const SizedBox(height: 20),
                Text(
                  _busyLabel ?? 'Leaving meeting…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, height: 1.35),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait while this device disconnects.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_summary != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meeting ended')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'AI summary',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(_summary!, style: const TextStyle(height: 1.45)),
            if ((_conversation ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Conversation (person & time)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(_conversation!.trim(), style: const TextStyle(height: 1.45)),
            ],
          ],
        ),
      );
    }
    if (_waiting && _room == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NbIcon(Icons.hourglass_top, color: Color(0xFFC5A059), size: 48),
                const SizedBox(height: 16),
                const LinearProgressIndicator(
                  minHeight: 4,
                  color: Color(0xFFC5A059),
                  backgroundColor: Color(0xFF333333),
                ),
                const SizedBox(height: 16),
                Text(
                  'Asking to join',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'You’ll join ${_join?.meeting.title ?? 'the meeting'} when the host lets you in.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(_code, style: const TextStyle(color: Colors.white38, fontFamily: 'monospace')),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () {
                    _admitPoll?.cancel();
                    setState(() => _waiting = false);
                    if (context.canPop()) context.pop();
                  },
                  child: const Text('Leave'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_room == null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
      final text = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
      final muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
      final bar = isDark ? const Color(0xFF1A1816) : Colors.white;
      if (!widget.asGuest && auth.status == AuthStatus.unknown) {
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bar,
            foregroundColor: text,
            elevation: 0,
            leading: IconButton(
              icon: const NbIcon(Icons.arrow_back_rounded),
              onPressed: _leaveLobby,
            ),
            title: Text('Join $_code', style: TextStyle(fontWeight: FontWeight.w700, color: text)),
          ),
          body: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFC5A059)),
                ),
                SizedBox(height: 16),
                Text('Opening your meeting…', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }
      final loggedIn = auth.isAuthenticated && !widget.asGuest;
      final isHost = _isHostViewer(auth);
      final needsKnock = _lobbyMeeting?.waitingRoom == true && !isHost;
      final previewOn = _cam && _previewCam != null && !_previewCam!.muted;
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bar,
          foregroundColor: text,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const NbIcon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: _leaveLobby,
          ),
          title: Text(isHost ? 'Your meeting' : 'Join $_code', style: TextStyle(fontWeight: FontWeight.w700, color: text)),
          bottom: _connecting
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: Color(0xFFC5A059),
                    backgroundColor: Color(0x33000000),
                  ),
                )
              : null,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFF263238),
                          child: previewOn
                              ? VideoTrackRenderer(_previewCam!, fit: VideoViewFit.cover)
                              : const Center(
                                  child: NbIcon(Icons.videocam_off, color: Colors.white38, size: 56),
                                ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 16,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _LobbyRoundButton(
                                icon: _mic ? Icons.mic_rounded : Icons.mic_off_rounded,
                                on: _mic,
                                tooltip: _mic ? 'Turn off microphone' : 'Turn on microphone',
                                onPressed: () => setState(() => _mic = !_mic),
                              ),
                              const SizedBox(width: 16),
                              _LobbyRoundButton(
                                icon: _cam ? Icons.videocam : Icons.videocam_off,
                                on: _cam,
                                tooltip: _cam ? 'Turn off camera' : 'Turn on camera',
                                onPressed: _toggleLobbyCam,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isHost ? 'Start your meeting' : 'Ready to join?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: text,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.voiceOnly
                      ? 'Microphone is on. Camera stays off unless you turn it on. You can share your screen in the call.'
                      : isHost
                          ? 'You are the host. Join to open the room for everyone else.'
                          : needsKnock
                              ? 'This meeting is set to ask to join. The host must admit you before you can enter — including guests.'
                              : loggedIn
                                  ? 'Check your camera and microphone, then join with your signed-in account.'
                                  : 'Enter your full name to join. No account or email is needed.',
                  style: TextStyle(color: muted),
                ),
                if (needsKnock) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A059).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC5A059).withValues(alpha: 0.45)),
                    ),
                    child: const Text(
                      'You will wait in the lobby until the host admits you.',
                      style: TextStyle(fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (loggedIn) ...[
                  FilledButton(
                    onPressed: _connecting ? null : _joinMember,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: Text(
                      _connecting
                          ? (isHost || !needsKnock ? 'Joining…' : 'Asking to join…')
                          : needsKnock
                              ? 'Ask to join'
                              : isHost
                                  ? 'Join your meeting'
                                  : 'Join with account',
                    ),
                  ),
                  if (_connecting) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _leaveLobby,
                      child: const Text('Cancel'),
                    ),
                  ],
                ]
                else ...[
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      hintText: 'e.g. Jane Doe',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _connecting || _name.text.trim().length < 2 ? null : _joinGuest,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: Text(
                      _connecting
                          ? (needsKnock ? 'Asking to join…' : 'Joining…')
                          : needsKnock
                              ? 'Ask to join as guest'
                              : 'Join as guest',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final participants = <Participant>[
      if (_room!.localParticipant != null) _room!.localParticipant!,
      ..._room!.remoteParticipants.values,
    ];
    final shares = <({Participant presenter, VideoTrack screen})>[];
    for (final p in participants) {
      final track = _screenTrack(p);
      if (track != null) shares.add((presenter: p, screen: track));
    }
    final share = shares.isEmpty
        ? null
        : shares[((_presenterIndex % shares.length) + shares.length) % shares.length];
    final presenter = share?.presenter;
    final screen = share?.screen;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _meetTopBar(participants),
                if (_busyLabel != null) ...[
                  const LinearProgressIndicator(
                    minHeight: 3,
                    color: Color(0xFFC5A059),
                    backgroundColor: Color(0xFF333333),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _busyLabel!,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_join?.meeting.isHost == true && _waitingFor.isNotEmpty) _knockPanel(),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    if (screen != null && presenter != null)
                      Expanded(
                        child: _presentingLayout(
                          screen: screen,
                          presenter: presenter,
                          participants: participants,
                          shares: shares,
                        ),
                      )
                    else
                      Expanded(child: _peopleGrid(participants)),
                  ],
                ),
                if (_chatToasts.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: _chatOpen
                        ? (MediaQuery.sizeOf(context).width >= 700 ? 332 : MediaQuery.sizeOf(context).width * 0.92 + 12)
                        : 72,
                    bottom: 12,
                    child: IgnorePointer(
                      ignoring: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final t in _chatToasts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _MeetChatToast(
                                senderName: '${t['senderName'] ?? ''}',
                                content: '${t['content'] ?? ''}',
                                direct: (t['scope'] ?? 'ROOM') == 'DIRECT',
                                onTap: () {
                                  setState(() {
                                    _chatOpen = true;
                                    _chatMode = (t['scope'] ?? 'ROOM') == 'DIRECT' ? 'DIRECT' : 'ROOM';
                                    final key = t['senderParticipantId']?.toString();
                                    final userKey = t['senderUserId']?.toString();
                                    if (_chatMode == 'DIRECT') {
                                      _dmTo = (key != null && key.isNotEmpty)
                                          ? key
                                          : (userKey != null && userKey.isNotEmpty)
                                              ? 'user:$userKey'
                                              : _dmTo;
                                    }
                                    _chatToasts.removeWhere((x) => x['id'] == t['id']);
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_floatReactions.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final r in _floatReactions)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(r.emoji, style: const TextStyle(fontSize: 32)),
                                  Text(
                                    r.name,
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_emojiOpen)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 8,
                    child: Center(
                      child: Material(
                        color: const Color(0xF2222222),
                        borderRadius: BorderRadius.circular(28),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final emoji in meetReactionEmojis)
                                IconButton(
                                  onPressed: () => _sendReaction(emoji),
                                  icon: Text(emoji, style: const TextStyle(fontSize: 22)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_peopleOpen)
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width >= 700 ? 320 : MediaQuery.sizeOf(context).width * 0.92,
                      child: Material(
                        color: const Color(0xFF161616),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                              child: Row(
                                children: [
                                  const Text('People', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  IconButton(
                                    color: Colors.white,
                                    onPressed: () => setState(() => _peopleOpen = false),
                                    icon: const NbIcon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                children: [
                                  for (final p in participants)
                                    ListTile(
                                      title: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _labelFor(p),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ),
                                          if (isMeetGuestIdentity(p.identity)) ...[
                                            const SizedBox(width: 8),
                                            const _GuestBadge(),
                                          ],
                                        ],
                                      ),
                                      subtitle: Text(
                                        _hands[p.identity] != null ? 'Hand raised' : (p.isMicrophoneEnabled() ? 'In this call' : 'Muted'),
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                      trailing: (_join?.meeting.isHost == true) && !_isLocal(p)
                                          ? TextButton(
                                              onPressed: () => _removeParticipant(p),
                                              child: const Text('Remove', style: TextStyle(color: Color(0xFFF87171))),
                                            )
                                          : (_hands[p.identity] != null
                                              ? const Text('✋', style: TextStyle(fontSize: 18))
                                              : null),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_captionsOn && _captions.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final row in _captions.length <= 3
                                    ? _captions
                                    : _captions.sublist(_captions.length - 3))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${meetClock(row.spokenAt)} ',
                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                          ),
                                          TextSpan(
                                            text: '${row.speakerName}: ',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          TextSpan(
                                            text: row.text,
                                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_chatOpen)
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width >= 700 ? 320 : MediaQuery.sizeOf(context).width * 0.92,
                      child: Material(
                        color: const Color(0xFF161616),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                              child: Row(
                                children: [
                                  const Text(
                                    'In-meet chat',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    color: Colors.white,
                                    onPressed: () => setState(() => _chatOpen = false),
                                    icon: const NbIcon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(child: _chatPane()),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LobbyRoundButton(
                  icon: _mic ? Icons.mic_rounded : Icons.mic_off_rounded,
                  on: _mic,
                  tooltip: _mic ? 'Microphone is on' : 'Microphone is off',
                  onPressed: () async {
                    final next = !_mic;
                    await _room!.localParticipant?.setMicrophoneEnabled(next);
                    _stt?.setMicEnabled(next);
                    if (next && _room != null) _stt?.attach(_room!);
                    setState(() => _mic = next);
                  },
                ),
                const SizedBox(width: 14),
                _LobbyRoundButton(
                  icon: _cam ? Icons.videocam : Icons.videocam_off,
                  on: _cam,
                  tooltip: _cam ? 'Camera is on' : 'Camera is off',
                  onPressed: () async {
                    final next = !_cam;
                    await _room!.localParticipant?.setCameraEnabled(next);
                    setState(() => _cam = next);
                  },
                ),
                const SizedBox(width: 14),
                _LobbyRoundButton(
                  icon: Icons.present_to_all,
                  on: !_share,
                  tooltip: _share
                      ? 'Stop sharing screen'
                      : widget.voiceOnly
                          ? 'Share screen'
                          : 'Present now',
                  onPressed: _toggleScreenShare,
                  accent: _share,
                ),
                const SizedBox(width: 14),
                _LobbyRoundButton(
                  icon: Icons.emoji_emotions_outlined,
                  on: !_emojiOpen,
                  tooltip: 'Send a reaction',
                  onPressed: () => setState(() {
                    _emojiOpen = !_emojiOpen;
                    _peopleOpen = false;
                  }),
                  accent: _emojiOpen,
                ),
                const SizedBox(width: 14),
                _LobbyRoundButton(
                  icon: Icons.back_hand_outlined,
                  on: !_handRaised,
                  tooltip: _handRaised ? 'Lower hand' : 'Raise hand',
                  onPressed: _toggleHand,
                  accent: _handRaised,
                ),
                const SizedBox(width: 14),
                _LobbyRoundButton(
                  icon: Icons.chat,
                  on: !_chatOpen,
                  tooltip: _chatOpen ? 'Hide chat' : 'Chat',
                  onPressed: () => setState(() {
                    _chatOpen = !_chatOpen;
                    if (_chatOpen) _peopleOpen = false;
                  }),
                  accent: _chatOpen,
                ),
                const SizedBox(width: 14),
                _LobbyRoundButton(
                  icon: Icons.people_alt_outlined,
                  on: !_peopleOpen,
                  tooltip: 'People',
                  onPressed: () => setState(() {
                    _peopleOpen = !_peopleOpen;
                    if (_peopleOpen) _chatOpen = false;
                  }),
                  accent: _peopleOpen,
                ),
                const SizedBox(width: 14),
                _LobbyRoundButton(
                  icon: Icons.closed_caption,
                  on: !_captionsOn,
                  tooltip: _whisperOnline
                      ? (_captionsOn ? 'Hide captions · Whisper on' : 'Show captions · Whisper on')
                      : (_captionsOn ? 'Hide captions · Whisper off' : 'Show captions · Whisper off'),
                  onPressed: () => setState(() => _captionsOn = !_captionsOn),
                  accent: _captionsOn,
                  badge: _whisperOnline ? const Color(0xFF34D399) : const Color(0xFFF87171),
                ),
                if (_join?.meeting.isHost == true) ...[
                  const SizedBox(width: 14),
                  _LobbyRoundButton(
                    icon: Icons.translate,
                    on: true,
                    tooltip: 'Speech-to-text language',
                    onPressed: _pickTranscriptLanguage,
                  ),
                ],
                if (_join?.meeting.isHost == true) ...[
                  const SizedBox(width: 14),
                  _LobbyRoundButton(
                    icon: Icons.fiber_manual_record,
                    on: !_recording,
                    tooltip: _recording ? 'Stop recording' : 'Record meeting',
                    onPressed: _toggleRecording,
                    danger: _recording,
                  ),
                ],
                const SizedBox(width: 14),
                _LobbyRoundButton(
                  icon: Icons.call_end,
                  on: false,
                  tooltip: _join?.meeting.isHost == true ? 'End meet' : 'Leave call',
                  onPressed: _leave,
                ),
              ],
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meetTopBar(List<Participant> participants) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final join = _join;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  join?.meeting.title ?? 'Meeting',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(_code, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    _peopleChip(participants),
                    _WhisperStatusChip(online: _whisperOnline),
                    if (join?.meeting.isHost == true && _waitingFor.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC5A059),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _waitingFor.length == 1 ? '1 waiting' : '${_waitingFor.length} waiting',
                          style: const TextStyle(
                            color: Color(0xFF161616),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (compact)
                      IconButton(
                        tooltip: 'Copy meet link',
                        color: Colors.white,
                        onPressed: _copyInvite,
                        icon: const NbIcon(Icons.link_rounded),
                      )
                    else
                      TextButton.icon(
                        onPressed: _copyInvite,
                        icon: const NbIcon(Icons.link_rounded, color: Colors.white70, size: 18),
                        label: const Text('Copy meet link', style: TextStyle(color: Colors.white)),
                      ),
                    if (join?.meeting.isHost == true)
                      compact
                          ? IconButton(
                              tooltip: 'End meet',
                              color: const Color(0xFFF87171),
                              onPressed: _endMeetFromCall,
                              icon: const NbIcon(Icons.call_end_rounded),
                            )
                          : TextButton(
                              onPressed: _endMeetFromCall,
                              child: const Text(
                                'End meet',
                                style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.w800),
                              ),
                            ),
                    if (_share)
                      compact
                          ? IconButton(
                              tooltip: 'Stop presenting',
                              color: const Color(0xFFC5A059),
                              onPressed: _toggleScreenShare,
                              icon: const NbIcon(Icons.stop_screen_share_rounded),
                            )
                          : TextButton(
                              onPressed: _toggleScreenShare,
                              child: const Text('Stop presenting', style: TextStyle(color: Color(0xFFC5A059))),
                            ),
                    if (_recording)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text('REC', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _peopleChip(List<Participant> participants) {
    final extras = participants.length > 4 ? participants.length - 4 : 0;
    final shown = participants.take(4).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...shown.asMap().entries.map((e) {
          final p = e.value;
          final photo = _photoForParticipant(p);
          final label = _labelFor(p);
          return Padding(
            padding: EdgeInsets.only(left: e.key == 0 ? 0 : 4),
            child: Tooltip(
              message: isMeetGuestIdentity(p.identity) ? '$label · Guest' : label,
              child: NbProfilePhoto(
                url: (photo ?? '').isNotEmpty ? photo : null,
                name: label,
                identity: p.identity,
                radius: 11,
                backgroundColor: const Color(0xFF374151),
              ),
            ),
          );
        }),
        if (extras > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: CircleAvatar(
              radius: 11,
              backgroundColor: const Color(0xFF4B5563),
              child: Text('+$extras', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
        const SizedBox(width: 8),
        Text(
          '${participants.length} in this call',
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _copyInvite() {
    final item = _join?.meeting;
    if (item != null) {
      copyMeetLink(context, item);
      return;
    }
    copyMeetLink(
      context,
      MeetingItem(id: '', code: _code, title: 'Meeting', status: 'LIVE'),
    );
  }

  Widget _screenShareStage(VideoTrack screen, Participant presenter, {required int shareCount}) {
    final local = _isLocal(presenter);
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black,
            child: VideoTrackRenderer(screen, fit: VideoViewFit.contain),
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              local
                  ? 'You are presenting'
                  : '${_labelFor(presenter)}${isMeetGuestIdentity(presenter.identity) ? ' (Guest)' : ''} is presenting'
                      '${shareCount > 1 ? ' (${(_presenterIndex % shareCount) + 1}/$shareCount)' : ''}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        if (shareCount > 1) ...[
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => setState(() => _presenterIndex--),
                icon: const NbIcon(Icons.chevron_left_rounded, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => setState(() => _presenterIndex++),
                icon: const NbIcon(Icons.chevron_right_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
        Positioned(
          right: 12,
          bottom: 12,
          child: IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            tooltip: 'Full screen',
            onPressed: () => _openShareFullscreen(screen, presenter, shareCount),
            icon: const NbIcon(Icons.fullscreen_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _openShareFullscreen(VideoTrack screen, Participant presenter, int shareCount) async {
    final mobile = MediaQuery.sizeOf(context).shortestSide < 700;
    if (mobile) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (!mounted) return;
    _shareFullscreenOpen = true;
    try {
      await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (ctx, _, __) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(child: VideoTrackRenderer(screen, fit: VideoViewFit.contain)),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () => Navigator.pop(ctx),
                      icon: const NbIcon(Icons.fullscreen_exit_rounded, color: Colors.white),
                    ),
                  ),
                  if (shareCount > 1) ...[
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          onPressed: () {
                            setState(() => _presenterIndex--);
                            Navigator.pop(ctx);
                          },
                          icon: const NbIcon(Icons.chevron_left_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          onPressed: () {
                            setState(() => _presenterIndex++);
                            Navigator.pop(ctx);
                          },
                          icon: const NbIcon(Icons.chevron_right_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
    } finally {
      _shareFullscreenOpen = false;
      if (mounted && !_leaving && _summary == null) {
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  Widget _presentingLayout({
    required VideoTrack screen,
    required Participant presenter,
    required List<Participant> participants,
    required List<({Participant presenter, VideoTrack screen})> shares,
  }) {
    final desktop = MediaQuery.sizeOf(context).width >= 800;
    final shareCount = shares.length;
    final stage = Column(
      children: [
        if (shareCount > 1)
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              itemCount: shareCount,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final row = shares[i];
                final selected = identical(row.screen, screen) || row.presenter.identity == presenter.identity;
                return GestureDetector(
                  onTap: () => setState(() => _presenterIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 112,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? const Color(0xFFC5A059) : Colors.white24,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoTrackRenderer(row.screen, fit: VideoViewFit.cover),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Text(
                              _isLocal(row.presenter) ? 'Your screen' : _labelFor(row.presenter),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(child: _screenShareStage(screen, presenter, shareCount: shareCount)),
      ],
    );
    if (desktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: stage),
          _attendeeStrip(participants, vertical: true),
        ],
      );
    }
    return Column(
      children: [
        Expanded(child: stage),
        _attendeeStrip(participants, vertical: false),
      ],
    );
  }

  Size _pipSize({required bool vertical}) {
    final size = MediaQuery.sizeOf(context);
    if (vertical) {
      final w = (size.width * 0.18).clamp(176.0, 228.0);
      return Size(w, w * 9 / 16);
    }
    final width = (size.width * 0.38).clamp(148.0, 200.0);
    return Size(width, width * 9 / 16);
  }

  Widget _attendeeStrip(List<Participant> participants, {required bool vertical}) {
    final pip = _pipSize(vertical: vertical);
    Widget tile(Participant p) {
      return _ParticipantTile(
        participant: p,
        label: _labelFor(p),
        photoUrl: _photoForParticipant(p),
        handRaised: _hands.containsKey(p.identity),
        canRemove: _join?.meeting.isHost == true && !_isLocal(p),
        onRemove: () => _removeParticipant(p),
      );
    }

    if (vertical) {
      return ColoredBox(
        color: const Color(0xFF111214),
        child: SizedBox(
          width: pip.width + 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Text(
                  'In this call',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: participants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    return SizedBox(
                      width: pip.width,
                      height: pip.height,
                      child: tile(participants[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFF111214),
      child: SizedBox(
        height: pip.height + 16,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          scrollDirection: Axis.horizontal,
          itemCount: participants.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            return SizedBox(
              width: pip.width,
              height: pip.height,
              child: tile(participants[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _knockPanel() {
    final people = _waitingFor;
    if (people.isEmpty) return const SizedBox.shrink();
    const gold = Color(0xFFC5A059);
    ButtonStyle compactText({required Color color}) => TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
    final admitStyle = FilledButton.styleFrom(
      backgroundColor: gold,
      foregroundColor: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      elevation: 0,
    );
    return Material(
      color: const Color(0xFF2A1C0C),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: people.length > 2 ? 96 : 52),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: gold, width: 1.5)),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          itemCount: people.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) {
            final person = people[i];
            final busy = person.id != null && _busyAdmit.contains(person.id);
            return SizedBox(
              height: 36,
              child: Row(
                children: [
                  NbProfilePhoto(
                    url: person.photoUrl,
                    name: person.name,
                    identity: person.userId ?? person.id ?? person.name,
                    radius: 14,
                    backgroundColor: gold,
                    foregroundColor: const Color(0xFF161616),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: person.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          TextSpan(
                            text: people.length == 1 ? ' wants to join' : ' waiting',
                            style: const TextStyle(color: Color(0xFFE8D5A8), fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                          if (person.isGuest)
                            const TextSpan(
                              text: ' · Guest',
                              style: TextStyle(color: Color(0xFFE8D5A8), fontSize: 12),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (i == 0 && people.length > 1)
                    TextButton(
                      onPressed: _admitAllWaiting,
                      style: compactText(color: gold),
                      child: const Text('Admit all', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  TextButton(
                    onPressed: busy || person.id == null ? null : () => _admitPerson(person, admit: false),
                    style: compactText(color: const Color(0xFFF87171)),
                    child: const Text('Deny', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: busy || person.id == null ? null : () => _admitPerson(person, admit: true),
                    style: admitStyle,
                    child: Text(
                      busy ? '…' : 'Admit',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _peopleGrid(List<Participant> participants) {
    return LayoutBuilder(
      builder: (context, box) {
        final n = participants.length;
        if (n == 0) return const SizedBox.shrink();

        Widget tile(Participant p) {
          return _ParticipantTile(
            participant: p,
            label: _labelFor(p),
            photoUrl: _photoForParticipant(p),
            handRaised: _hands.containsKey(p.identity),
            canRemove: _join?.meeting.isHost == true && !_isLocal(p),
            onRemove: () => _removeParticipant(p),
          );
        }

        const pad = 16.0;
        const gap = 10.0;
        final maxW = (box.maxWidth - pad * 2).clamp(0.0, box.maxWidth);
        final maxH = (box.maxHeight - pad * 2).clamp(0.0, box.maxHeight);

        Size fit({required int cols, required int rows, double aspect = 16 / 9}) {
          final cellW = (maxW - gap * (cols - 1)) / cols;
          final cellH = (maxH - gap * (rows - 1)) / rows;
          var w = cellW;
          var h = w / aspect;
          if (h > cellH) {
            h = cellH;
            w = h * aspect;
          }
          return Size(w, h);
        }

        if (n == 1) {
          final size = fit(cols: 1, rows: 1);
          return Center(
            child: SizedBox(width: size.width, height: size.height, child: tile(participants.first)),
          );
        }

        final width = box.maxWidth;
        final cols = width < 520
            ? (n == 2 ? 1 : 2)
            : n <= 2
                ? 2
                : n <= 4
                    ? 2
                    : n <= 9
                        ? (width >= 900 ? 3 : 2)
                        : (width >= 1100 ? 4 : 3);
        final rows = (n / cols).ceil();
        final size = fit(cols: cols, rows: rows);
        return Center(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: WrapAlignment.center,
            children: [
              for (final p in participants)
                SizedBox(width: size.width, height: size.height, child: tile(p)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMeetChat() async {
    final text = _draft.text.trim();
    final people = _dmPeople();
    if (text.isEmpty || _join == null) return;
    if (_chatMode == 'DIRECT' && (_dmTo == null || _dmTo!.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            people.isEmpty
                ? 'No one else is in this meeting yet.'
                : 'Pick the host, a teammate, or a guest to message them privately.',
          ),
        ),
      );
      return;
    }
    final peer = people.where((p) => _peerKey(p) == _dmTo).firstOrNull;
    final me = ref.read(authNotifierProvider).user;
    setState(() {
      _upsertChat({
        'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
        'scope': _chatMode,
        'content': text,
        'senderName': me?.name ?? _join?.participant?.name ?? 'You',
        'senderUserId': me?.id ?? _join?.participant?.userId,
        'senderParticipantId': _myParticipantId,
        'recipientUserId': peer?.userId,
        'recipientParticipantId': peer?.id,
        'recipientName': peer?.name,
      });
      _draft.clear();
    });
    ref.read(collabSocketProvider).meetingChat(
          meetingId: _join!.meeting.id,
          content: text,
          scope: _chatMode,
          recipientUserId: _chatMode == 'DIRECT'
              ? (peer?.userId ?? (_dmTo!.startsWith('user:') ? _dmTo!.substring(5) : null))
              : null,
          recipientParticipantId: _chatMode == 'DIRECT'
              ? (peer?.id ?? (_dmTo!.startsWith('user:') ? null : _dmTo))
              : null,
        );
  }

  Widget _chatPane() {
    final people = _dmPeople();
    final selected = people.where((p) => _peerKey(p) == _dmTo).firstOrNull;
    final rows = _chat.where((r) {
      if (_chatMode == 'ROOM') return (r['scope'] ?? 'ROOM') == 'ROOM';
      if ((r['scope'] ?? 'ROOM') != 'DIRECT') return false;
      if (selected == null) return true;
      return _dmThreadMatches(r, selected);
    }).toList();
    const gold = Color(0xFFC5A059);
    return ColoredBox(
      color: const Color(0xFF161616),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                _chatTab('Everyone', 'ROOM', gold),
                const SizedBox(width: 8),
                _chatTab('Direct', 'DIRECT', gold),
              ],
            ),
          ),
          if (_chatMode == 'DIRECT')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _directRecipientPicker(),
            ),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    children: rows
                        .map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _chatIsMine(r)
                                      ? (r['scope'] == 'DIRECT' && r['recipientName'] != null
                                          ? 'You → ${r['recipientName']}'
                                          : 'You')
                                      : '${r['senderName'] ?? ''}${r['scope'] == 'DIRECT' ? ' → you' : ''}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${r['content'] ?? ''}',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _draft,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: gold,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMeetChat(),
                    decoration: InputDecoration(
                      hintText: _chatMode == 'DIRECT' && (_dmTo == null || _dmTo!.isEmpty)
                          ? 'Pick someone first'
                          : 'Send a message',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF262626),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: gold),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  color: gold,
                  onPressed: _sendMeetChat,
                  icon: const NbIcon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _directRecipientPicker() {
    final people = _dmPeople();
    if (people.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'No one else is in this meeting yet. Direct messages work with the host, teammates, and guests.',
          style: TextStyle(color: Color(0xFFE5E7EB), fontSize: 13, height: 1.35),
        ),
      );
    }
    final selected = people.where((p) => _peerKey(p) == _dmTo).firstOrNull;
    String labelFor(MeetingPerson p) {
      if (p.role == 'HOST' || p.userId == _join?.meeting.hostUserId) return '${p.name} (Host)';
      if (p.isGuest) return '${p.name} (Guest)';
      return p.name;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => setState(() => _dmPickerOpen = !_dmPickerOpen),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected == null ? 'Pick anyone in this meeting' : labelFor(selected),
                      style: TextStyle(
                        color: selected == null ? const Color(0xFFE5E7EB) : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  NbIcon(
                    _dmPickerOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_dmPickerOpen)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: people.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
              itemBuilder: (context, i) {
                final p = people[i];
                final on = _peerKey(p) == _dmTo;
                return ListTile(
                  dense: true,
                  selected: on,
                  selectedTileColor: const Color(0x33C5A059),
                  title: Text(labelFor(p), style: const TextStyle(color: Colors.white)),
                  onTap: () => setState(() {
                    _dmTo = _peerKey(p);
                    _dmPickerOpen = false;
                  }),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _chatTab(String label, String mode, Color gold) {
    final on = _chatMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _chatMode = mode;
          if (mode != 'DIRECT') _dmPickerOpen = false;
        }),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? gold.withValues(alpha: 0.18) : const Color(0xFF262626),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? gold : Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? gold : Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _LobbyRoundButton extends StatelessWidget {
  const _LobbyRoundButton({
    required this.icon,
    required this.on,
    required this.tooltip,
    required this.onPressed,
    this.accent = false,
    this.danger = false,
    this.badge,
  });

  final IconData icon;
  final bool on;
  final String tooltip;
  final VoidCallback onPressed;
  final bool accent;
  final bool danger;
  final Color? badge;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (danger || !on) {
      bg = const Color(0xFFB91C1C);
      fg = Colors.white;
    } else if (accent) {
      bg = const Color(0xFFC5A059);
      fg = Colors.black87;
    } else {
      bg = Colors.white;
      fg = Colors.black87;
    }
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              children: [
                Center(child: NbIcon(icon, color: fg)),
                if (badge != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: badge,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WhisperStatusChip extends StatelessWidget {
  const _WhisperStatusChip({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFF34D399) : const Color(0xFFF87171);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NbIcon(Icons.graphic_eq_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            online ? 'Whisper on' : 'Whisper off',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GuestBadge extends StatelessWidget {
  const _GuestBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Guest',
        style: TextStyle(
          color: Color(0xFF161616),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.label,
    this.photoUrl,
    this.handRaised = false,
    this.canRemove = false,
    this.onRemove,
  });

  final Participant participant;
  final String label;
  final String? photoUrl;
  final bool handRaised;
  final bool canRemove;
  final VoidCallback? onRemove;

  VideoTrack? get _camera {
    for (final pub in participant.videoTrackPublications) {
      if (pub.source == TrackSource.camera && !pub.muted && pub.track is VideoTrack) {
        return pub.track as VideoTrack;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: participant,
      builder: (context, _) {
        final track = _camera;
        final micOn = participant.isMicrophoneEnabled();
        final speaking = micOn && (participant.isSpeaking || participant.audioLevel > 0.08);
        Widget body = Center(
          child: NbProfilePhoto(
            url: photoUrl,
            name: label,
            identity: participant.identity,
            radius: 36,
          ),
        );
        if (track != null) {
          body = SizedBox.expand(
            child: VideoTrackRenderer(track, fit: VideoViewFit.cover),
          );
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: speaking ? const Color(0xFF8AB4F8) : Colors.transparent,
              width: 3,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxHeight < 150;
                final chipMax = (box.maxWidth * 0.72).clamp(72.0, 200.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: const Color(0xFF111827), child: body),
                    Positioned(
                      left: compact ? 8 : 10,
                      bottom: compact ? 8 : 10,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(compact ? 8 : 10, compact ? 5 : 7, compact ? 6 : 8, compact ? 5 : 7),
                        decoration: BoxDecoration(
                          color: const Color(0xCC202124),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: chipMax),
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 12 : 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isMeetGuestIdentity(participant.identity)) ...[
                              const SizedBox(width: 6),
                              const _GuestBadge(),
                            ],
                            const SizedBox(width: 6),
                            _MeetMicBadge(
                              micOn: micOn,
                              speaking: speaking,
                              level: participant.audioLevel,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (handRaised)
                      Positioned(
                        top: compact ? 8 : 10,
                        right: compact ? 8 : 10,
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: Color(0xFFFBBF24), shape: BoxShape.circle),
                          child: const Text('✋', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    if (canRemove && onRemove != null)
                      Positioned(
                        top: compact ? 6 : 8,
                        left: compact ? 6 : 8,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: onRemove,
                          child: const Text('Remove', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _MeetMicBadge extends StatelessWidget {
  const _MeetMicBadge({
    required this.micOn,
    required this.speaking,
    required this.level,
  });

  final bool micOn;
  final bool speaking;
  final double level;

  @override
  Widget build(BuildContext context) {
    if (!micOn) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(color: Color(0xFFB91C1C), shape: BoxShape.circle),
        child: const NbIcon(Icons.mic_off_rounded, size: 14, color: Colors.white),
      );
    }
    if (speaking) {
      final a = (4 + 10 * (level * 0.55).clamp(0.18, 1)).toDouble();
      final b = (4 + 14 * level.clamp(0.22, 1)).toDouble();
      final c = (4 + 10 * (level * 0.8).clamp(0.18, 1)).toDouble();
      return SizedBox(
        width: 22,
        height: 22,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(a),
            const SizedBox(width: 2),
            _bar(b),
            const SizedBox(width: 2),
            _bar(c),
          ],
        ),
      );
    }
    return const NbIcon(Icons.mic_rounded, size: 16, color: Colors.white);
  }

  Widget _bar(double height) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _MeetChatToast extends StatelessWidget {
  const _MeetChatToast({
    required this.senderName,
    required this.content,
    required this.direct,
    required this.onTap,
  });

  final String senderName;
  final String content;
  final bool direct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(-16 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Material(
        color: const Color(0xED27272A),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    direct ? '$senderName · Direct message' : senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7DD3FC),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenShareNoCursorOptions extends ScreenShareCaptureOptions {
  const _ScreenShareNoCursorOptions() : super(captureScreenAudio: true);

  @override
  Map<String, dynamic> toMediaConstraintsMap() {
    final constraints = super.toMediaConstraintsMap();
    constraints['cursor'] = 'never';
    return constraints;
  }
}
