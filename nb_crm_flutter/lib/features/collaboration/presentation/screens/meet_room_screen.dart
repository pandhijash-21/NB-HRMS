import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/collab_models.dart';
import '../collab_providers.dart';
import '../end_meet_progress.dart';
import '../meet_helpers.dart';

class MeetRoomScreen extends ConsumerStatefulWidget {
  const MeetRoomScreen({super.key, required this.code, this.asGuest = false, this.voiceOnly = false});

  final String code;
  final bool asGuest;
  final bool voiceOnly;

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
  String? _summary;
  LocalVideoTrack? _previewCam;
  Timer? _admitPoll;
  Timer? _hostWaitPoll;

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
      if (!widget.voiceOnly) await _startLobbyPreview();
    });
  }

  @override
  void dispose() {
    _admitPoll?.cancel();
    _hostWaitPoll?.cancel();
    final room = _room;
    _room = null;
    room?.removeListener(_onRoom);
    room?.disconnect();
    _previewCam?.stop();
    _name.dispose();
    _draft.dispose();
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

  Future<void> _ensureMedia() async {
    await [Permission.camera, Permission.microphone].request();
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

  Future<void> _restoreGuestName() async {
    final session = await loadMeetSession(widget.code);
    final name = session?.guestName?.trim();
    if (name != null && name.isNotEmpty && mounted) {
      _name.text = name;
    }
  }

  Future<void> _leaveLobby() async {
    await clearMeetSession(widget.code);
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
    if (_isEndedError(error)) await clearMeetSession(widget.code);
    if (retry == true && mounted && !_isEndedError(error)) await onRetry?.call();
  }

  Future<void> _bindSocket(String meetingId, {String? guestToken}) async {
    final token = guestToken ?? await ref.read(secureStorageProvider).readToken();
    if (token == null) return;
    final socket = ref.read(collabSocketProvider)..connect(token: token);
    socket.joinMeeting(meetingId);
    socket.onMeetingChat((row) {
      if (!mounted) return;
      setState(() => _upsertChat(row));
    });
    try {
      final history = await ref.read(meetRepositoryProvider).listChat(meetingId);
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
    socket.onJoinApproved((participantId) async {
      if (!_waiting) return;
      if (participantId != null && _myParticipantId != null && participantId != _myParticipantId) {
        return;
      }
      try {
        final payload = _guestToken != null
            ? await ref.read(meetRepositoryProvider).guestEnter(_guestToken!)
            : await ref.read(meetRepositoryProvider).join(widget.code);
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
      _onRemoteEnded();
    });
  }

  void _upsertChat(Map<String, dynamic> row) {
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
  }

  Future<void> _dropRoom(Room? room) async {
    if (room == null) return;
    room.removeListener(_onRoom);
    try {
      await room.disconnect();
    } catch (_) {}
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
    await Future<void>.delayed(const Duration(milliseconds: 120));

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
      if (!mounted) {
        await _dropRoom(room);
        return;
      }
      try {
        await room.localParticipant?.setMicrophoneEnabled(_mic);
      } catch (_) {}
      try {
        await room.localParticipant?.setCameraEnabled(_cam);
      } catch (_) {
        if (mounted) setState(() => _cam = false);
      }
    } catch (e) {
      await _dropRoom(room);
      rethrow;
    }

    await _bindSocket(payload.meeting.id, guestToken: guestToken);
    await saveMeetSession(
      code: widget.code,
      guest: guestToken != null,
      guestToken: guestToken,
      guestName: _name.text.trim().isEmpty ? null : _name.text.trim(),
    );
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

  Future<void> _pollAdmission() async {
    if (!mounted || !_waiting || _room != null) return;
    try {
      final payload = _guestToken != null
          ? await ref.read(meetRepositoryProvider).guestEnter(_guestToken!)
          : await ref.read(meetRepositoryProvider).join(widget.code);
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
      final payload = await ref.read(meetRepositoryProvider).join(widget.code);
      if (!mounted) return;
      _myParticipantId = payload.participant?.id;
      if (payload.waiting || payload.livekitUrl.isEmpty) {
        await _beginWait(payload);
        if (mounted) setState(() => _connecting = false);
        return;
      }
      try {
        await _connect(payload);
      } catch (e) {
        if (!_isJoinSignalTimeout(e) || !mounted) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final retry = await ref.read(meetRepositoryProvider).join(widget.code);
        if (!mounted) return;
        await _connect(retry);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _connecting = false);
      await _startLobbyPreview();
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
        code: widget.code,
        guest: true,
        guestToken: guestToken,
        guestName: _name.text.trim().isEmpty ? payload.participant?.name : _name.text.trim(),
      );
      if (payload.waiting || payload.livekitUrl.isEmpty) {
        await _beginWait(payload, guestToken: guestToken);
        if (mounted) setState(() => _connecting = false);
        return;
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
      final saved = await loadMeetSession(widget.code);
      if (saved?.guest == true && saved?.guestToken != null && saved!.guestToken!.isNotEmpty) {
        setState(() => _connecting = false);
        await _enterGuest(saved.guestToken!);
        return;
      }
      final payload = await ref.read(meetRepositoryProvider).guestJoin(widget.code, _name.text.trim());
      if (!mounted) return;
      _guestToken = payload.guestToken;
      _myParticipantId = payload.participant?.id;
      await saveMeetSession(
        code: widget.code,
        guest: true,
        guestToken: payload.guestToken,
        guestName: _name.text.trim(),
      );
      if (payload.waiting || payload.livekitUrl.isEmpty) {
        await _beginWait(payload, guestToken: payload.guestToken);
        if (mounted) setState(() => _connecting = false);
        return;
      }
      try {
        await _connect(payload, guestToken: payload.guestToken);
      } catch (e) {
        if (!_isJoinSignalTimeout(e) || !mounted) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final token = payload.guestToken;
        final retry = token != null
            ? await ref.read(meetRepositoryProvider).guestEnter(token)
            : await ref.read(meetRepositoryProvider).guestJoin(widget.code, _name.text.trim());
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

  Future<void> _onRemoteEnded() async {
    await clearMeetSession(widget.code);
    final room = _room;
    _room = null;
    await _dropRoom(room);
    if (!mounted) return;
    setState(() => _summary = 'This meeting has ended. The host closed the room.');
  }

  Future<bool> _confirmEndMeet() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this meeting?'),
        content: Text(
          _recording
              ? 'Recording will be saved first, then everyone will be removed. This meeting link cannot be used again.'
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
    _admitPoll?.cancel();
    _hostWaitPoll?.cancel();
    await clearMeetSession(widget.code);
    final room = _room;
    _room = null;
    await _dropRoom(room);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _endMeetFromCall() async {
    if (!await _confirmEndMeet() || !mounted) return;
    final join = _join;
    if (join == null) return;
    final token = _guestToken ?? await ref.read(secureStorageProvider).readToken();
    if (token != null) {
      ref.read(collabSocketProvider).connect(token: token);
    }
    final ended = await showEndMeetProgress(
      context: context,
      meetingId: join.meeting.id,
      socket: ref.read(collabSocketProvider),
      repo: ref.read(meetRepositoryProvider),
      hasRecording: _recording || join.meeting.recordEnabled,
    );
    if (!mounted) return;
    await clearMeetSession(widget.code);
    final room = _room;
    _room = null;
    await _dropRoom(room);
    if (!mounted) return;
    setState(() => _summary = ended?.summaryText ?? 'Meeting ended.');
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

  Future<void> _toggleScreenShare() async {
    if (_share) {
      final stop = await _confirmStopPresenting();
      if (!stop || !mounted) return;
    }
    try {
      await _room!.localParticipant?.setScreenShareEnabled(
        !_share,
        screenShareCaptureOptions: const _ScreenShareNoCursorOptions(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Screen share failed: $e')),
      );
    }
  }

  Future<void> _toggleRecording() async {
    final id = _join?.meeting.id;
    if (id == null) return;
    final start = !_recording;
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
              ? 'Everyone in this meeting will be recorded. The recording is saved for people who can view this meeting later.'
              : 'Stop the recording now? You can watch it from Past meetings after it finishes processing.',
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
    try {
      if (start) {
        await ref.read(meetRepositoryProvider).startRecording(id);
      } else {
        await ref.read(meetRepositoryProvider).stopRecording(id);
      }
      if (!mounted) return;
      setState(() => _recording = start);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
    if (_summary != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meeting ended')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_summary!),
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
                Text(widget.code, style: const TextStyle(color: Colors.white38, fontFamily: 'monospace')),
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
      final loggedIn = auth.isAuthenticated && !widget.asGuest;
      final previewOn = _cam && _previewCam != null && !_previewCam!.muted;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
      final text = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
      final muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
      final bar = isDark ? const Color(0xFF1A1816) : Colors.white;
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
          title: Text('Join ${widget.code}', style: TextStyle(fontWeight: FontWeight.w700, color: text)),
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
                                  child: const NbIcon(Icons.videocam_off, color: Colors.white38, size: 56),
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
                  'Ready to join?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: text,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.voiceOnly
                      ? 'Microphone is on. Camera stays off unless you turn it on. You can share your screen in the call.'
                      : loggedIn
                          ? 'Check your camera and microphone, then join with your signed-in account.'
                          : 'Enter your full name to join. No account or email is needed.',
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 20),
                if (loggedIn) ...[
                  FilledButton(
                    onPressed: _connecting ? null : _joinMember,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: Text(_connecting ? 'Joining…' : 'Join with account'),
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
                    child: Text(_connecting ? 'Joining…' : 'Join as guest'),
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
    Participant? presenter;
    VideoTrack? screen;
    for (final p in participants) {
      final track = _screenTrack(p);
      if (track != null) {
        presenter = p;
        screen = track;
        break;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _meetTopBar(participants),
          ),
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
                        ),
                      )
                    else
                      Expanded(child: _peopleGrid(participants, fill: true)),
                  ],
                ),
                if (_join?.meeting.isHost == true && _waitingFor.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: _knockPanel(),
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
                  icon: Icons.chat,
                  on: !_chatOpen,
                  tooltip: _chatOpen ? 'Hide chat' : 'Chat',
                  onPressed: () => setState(() => _chatOpen = !_chatOpen),
                  accent: _chatOpen,
                ),
                if ((_join?.meeting.isHost == true) || Permissions.isAdmin(auth.user?.role)) ...[
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
                    Text(widget.code, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    _peopleChip(participants),
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
          final photo = _join?.meeting.participants.where((x) => x.name == p.name).firstOrNull?.photoUrl;
          final label = _isLocal(p) ? 'You' : (p.name.isEmpty ? 'Guest' : p.name);
          return Padding(
            padding: EdgeInsets.only(left: e.key == 0 ? 0 : 4),
            child: Tooltip(
              message: label,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: const Color(0xFF374151),
                backgroundImage: (photo ?? '').isNotEmpty ? NetworkImage(photo!) : null,
                child: (photo ?? '').isEmpty
                    ? Text(
                        label.isNotEmpty ? label[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      )
                    : null,
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
      MeetingItem(id: '', code: widget.code, title: 'Meeting', status: 'LIVE'),
    );
  }

  Widget _screenShareStage(VideoTrack screen, Participant presenter) {
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
              local ? 'You are presenting' : '${presenter.name} is presenting',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _presentingLayout({
    required VideoTrack screen,
    required Participant presenter,
    required List<Participant> participants,
  }) {
    final desktop = MediaQuery.sizeOf(context).width >= 800;
    final stage = _screenShareStage(screen, presenter);
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
        label: _isLocal(p) ? 'You' : (p.name.isEmpty ? 'Guest' : p.name),
        photoUrl: _join?.meeting.participants.where((x) => x.name == p.name).firstOrNull?.photoUrl,
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: const Color(0xFF202124),
        elevation: 12,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _waitingFor.length == 1
                      ? '${_waitingFor.first.name} wants to join'
                      : '${_waitingFor.length} people want to join',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Admit them like Google Meet. They can only enter after you let them in.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 10),
                ..._waitingFor.map((person) {
                  final busy = person.id != null && _busyAdmit.contains(person.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: person.photoUrl != null ? NetworkImage(person.photoUrl!) : null,
                          child: person.photoUrl == null
                              ? Text(person.name.isEmpty ? '?' : person.name[0], style: const TextStyle(fontSize: 13))
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            person.name + (person.isGuest ? ' (guest)' : ''),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: busy || person.id == null ? null : () => _admitPerson(person, admit: false),
                          child: const Text('Deny', style: TextStyle(color: Color(0xFFF87171))),
                        ),
                        FilledButton(
                          onPressed: busy || person.id == null ? null : () => _admitPerson(person, admit: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFC5A059),
                            foregroundColor: const Color(0xFF161616),
                          ),
                          child: Text(busy ? '…' : 'Admit'),
                        ),
                      ],
                    ),
                  );
                }),
                if (_waitingFor.length > 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _admitAllWaiting,
                      child: const Text('Admit all'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _peopleGrid(List<Participant> participants, {required bool fill}) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      scrollDirection: fill ? Axis.vertical : Axis.horizontal,
      gridDelegate: fill
          ? SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width >= 800 ? 3 : 1,
              childAspectRatio: 16 / 10,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            )
          : const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              childAspectRatio: 16 / 10,
              mainAxisSpacing: 8,
            ),
      itemCount: participants.length,
      itemBuilder: (context, i) {
        final p = participants[i];
        final person = _join?.meeting.participants.where((x) => x.name == p.name).firstOrNull;
        return _ParticipantTile(
          participant: p,
          label: _isLocal(p) ? 'You' : (p.name.isEmpty ? 'Guest' : p.name),
          photoUrl: person?.photoUrl,
        );
      },
    );
  }

  Widget _chatPane() {
    final rows = _chat.where((r) => (r['scope'] ?? 'ROOM') == _chatMode).toList();
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
                                  '${r['senderName'] ?? ''}',
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
                    decoration: InputDecoration(
                      hintText: 'Message',
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
                  onPressed: () {
                    final text = _draft.text.trim();
                    if (text.isEmpty || _join == null) return;
                    if (_chatMode == 'DIRECT' && (_dmTo == null || _dmTo!.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'You are the only person in this meeting. Use Everyone to leave a note, or invite someone for a direct message.',
                          ),
                        ),
                      );
                      return;
                    }
                    final me = ref.read(authNotifierProvider).user;
                    setState(() {
                      _upsertChat({
                        'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
                        'scope': _chatMode,
                        'content': text,
                        'senderName': me?.name ?? 'You',
                        'senderUserId': me?.id,
                      });
                      _draft.clear();
                    });
                    ref.read(collabSocketProvider).meetingChat(
                          meetingId: _join!.meeting.id,
                          content: text,
                          scope: _chatMode,
                          recipientUserId: _chatMode == 'DIRECT' ? _dmTo : null,
                        );
                  },
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
    final me = ref.read(authNotifierProvider).user?.id;
    final people = <MeetingPerson>[];
    final seen = <String>{};
    for (final p in _join?.meeting.participants ?? const <MeetingPerson>[]) {
      final id = p.userId;
      if (id == null || id.isEmpty || id == me || seen.contains(id) || p.isGuest) continue;
      seen.add(id);
      people.add(p);
    }
    if (people.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'No other members in this meeting yet. Invite someone to send a direct message.',
          style: TextStyle(color: Color(0xFFE5E7EB), fontSize: 13, height: 1.35),
        ),
      );
    }
    final selected = people.where((p) => p.userId == _dmTo).firstOrNull;
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
                      selected?.name ?? 'Pick a teammate',
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
                final on = p.userId == _dmTo;
                return ListTile(
                  dense: true,
                  selected: on,
                  selectedTileColor: const Color(0x33C5A059),
                  title: Text(p.name, style: const TextStyle(color: Colors.white)),
                  onTap: () => setState(() {
                    _dmTo = p.userId;
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
  });

  final IconData icon;
  final bool on;
  final String tooltip;
  final VoidCallback onPressed;
  final bool accent;
  final bool danger;

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
            child: NbIcon(icon, color: fg),
          ),
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
  });

  final Participant participant;
  final String label;
  final String? photoUrl;

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
          child: CircleAvatar(
            radius: 36,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null ? Text(label.isEmpty ? '?' : label[0]) : null,
          ),
        );
        if (track != null) {
          body = VideoTrackRenderer(track, fit: VideoViewFit.cover);
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: LayoutBuilder(
              builder: (context, box) {
                final compact = box.maxHeight < 150;
                final chipMax = (box.maxWidth * 0.72).clamp(72.0, 200.0);
                return Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: const Color(0xFF111827), child: body)),
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

class _ScreenShareNoCursorOptions extends ScreenShareCaptureOptions {
  const _ScreenShareNoCursorOptions() : super(captureScreenAudio: true);

  @override
  Map<String, dynamic> toMediaConstraintsMap() {
    final constraints = super.toMediaConstraintsMap();
    constraints['cursor'] = 'never';
    return constraints;
  }
}
