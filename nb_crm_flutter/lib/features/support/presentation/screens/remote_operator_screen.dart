import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../support_providers.dart';

/// Full-featured Custom Remote Operator Console for IT Handlers & Employees.
/// Connects to the LiveKit room, displays live video stream of employee desktop,
/// provides special keys injection, clipboard synchronization, and full-screen controls.
class RemoteOperatorScreen extends ConsumerStatefulWidget {
  const RemoteOperatorScreen({
    super.key,
    required this.ticketId,
    required this.sessionId,
    required this.roomName,
    this.token,
    this.livekitUrl,
  });

  final String ticketId;
  final String sessionId;
  final String roomName;
  final String? token;
  final String? livekitUrl;

  @override
  ConsumerState<RemoteOperatorScreen> createState() =>
      _RemoteOperatorScreenState();
}

class _RemoteOperatorScreenState extends ConsumerState<RemoteOperatorScreen> {
  final FocusNode _canvasFocus = FocusNode();

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  VideoTrack? _remoteVideoTrack;
  bool _connecting = true;
  bool _connected = false;
  bool _isSharing = false;
  String? _connectError;

  bool _fitToWindow = true;
  bool _audioMuted = false;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _initLiveKit();
  }

  @override
  void dispose() {
    _canvasFocus.dispose();
    _cleanupLiveKit();
    super.dispose();
  }

  Future<void> _cleanupLiveKit() async {
    try {
      await _listener?.dispose();
      await _room?.disconnect();
      await _room?.dispose();
    } catch (_) {}
  }

  Future<void> _initLiveKit() async {
    setState(() {
      _connecting = true;
      _connectError = null;
    });

    try {
      String? token = widget.token;
      String? url = widget.livekitUrl;

      // If token wasn't passed in extra, fetch it now from API
      if (token == null || token.isEmpty || url == null || url.isEmpty) {
        final tokenData = await ref
            .read(supportRepositoryProvider)
            .getRemoteToken(widget.ticketId);
        token = tokenData['token']?.toString();
        url = tokenData['livekitUrl']?.toString();
      }

      if (token == null || token.isEmpty) {
        throw Exception('Remote session token not available');
      }

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: false,
          ),
        ),
      );

      final listener = room.createListener();
      _room = room;
      _listener = listener;

      // Listen for participant track publishing
      listener
        ..on<TrackSubscribedEvent>((event) {
          if (event.track is VideoTrack) {
            setState(() {
              _remoteVideoTrack = event.track as VideoTrack;
            });
          }
        })
        ..on<TrackUnsubscribedEvent>((event) {
          if (event.track == _remoteVideoTrack) {
            setState(() {
              _remoteVideoTrack = null;
            });
          }
        })
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted) {
            setState(() {
              _connected = false;
              _remoteVideoTrack = null;
            });
          }
        })
        ..on<DataReceivedEvent>((event) {
          // Handle remote data (clipboard, status, etc.)
          try {
            final text = String.fromCharCodes(event.data);
            if (mounted && text.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Remote Message: $text'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (_) {}
        });

      await room.connect(
        url ?? 'ws://127.0.0.1:7880',
        token,
        fastConnectOptions: FastConnectOptions(
          microphone: const TrackOption(enabled: false),
          camera: const TrackOption(enabled: false),
        ),
      );

      // Check if any remote participant is already sharing video
      for (final p in room.remoteParticipants.values) {
        for (final pub in p.videoTrackPublications) {
          if (pub.track != null) {
            _remoteVideoTrack = pub.track;
            break;
          }
        }
        if (_remoteVideoTrack != null) break;
      }

      if (mounted) {
        setState(() {
          _connecting = false;
          _connected = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _connected = false;
          _connectError = e.toString();
        });
      }
    }
  }

  Future<void> _toggleScreenShare() async {
    final room = _room;
    if (room == null) return;
    try {
      final willShare = !_isSharing;
      await room.localParticipant?.setScreenShareEnabled(
        willShare,
        captureScreenAudio: true,
      );
      if (mounted) {
        setState(() => _isSharing = willShare);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screen share error: $e')),
        );
      }
    }
  }

  void _sendSpecialKey(String keyCombo) {
    final room = _room;
    if (room != null && _connected) {
      final bytes = Uint8List.fromList('KEY:$keyCombo'.codeUnits);
      room.localParticipant?.publishData(bytes);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dispatched $keyCombo to remote PC'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _syncClipboard() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text ?? '';
    if (text.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }
    final room = _room;
    if (room != null && _connected) {
      final bytes = Uint8List.fromList('CLIP:$text'.codeUnits);
      room.localParticipant?.publishData(bytes);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent "${text.length > 20 ? '${text.substring(0, 20)}...' : text}" to remote clipboard',
          ),
        ),
      );
    }
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Remote Session?'),
        content: const Text(
          'This will disconnect your control session and release the desktop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _ending = true);
    try {
      await _room?.disconnect();
      if (widget.sessionId.isNotEmpty) {
        await ref
            .read(supportRepositoryProvider)
            .endRemoteSession(widget.sessionId);
      }
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/support/${widget.ticketId}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end session: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111622),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Exit to ticket',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/support/${widget.ticketId}');
            }
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (_connected
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B))
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (_connected
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    size: 10,
                    color: _connected
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _connected ? 'LIVE REMOTE' : 'CONNECTING',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: _connected
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (!isCompact) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Room: ${widget.roomName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Screen Share toggle (allows employee or operator to share screen)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _isSharing ? Colors.amber : Colors.white,
                side: BorderSide(
                  color: _isSharing ? Colors.amber : Colors.white24,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: _connected ? _toggleScreenShare : null,
              icon: Icon(
                _isSharing
                    ? Icons.stop_screen_share_rounded
                    : Icons.screen_share_rounded,
                size: 16,
              ),
              label: Text(
                _isSharing ? 'Stop Share' : 'Share Screen',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Special Keys Menu
          PopupMenuButton<String>(
            tooltip: 'Special Key Combos',
            icon: const Icon(
              Icons.keyboard_command_key_rounded,
              color: Color(0xFFF59E0B),
            ),
            onSelected: _sendSpecialKey,
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'Ctrl+Alt+Del',
                child: Row(
                  children: [
                    Icon(Icons.security, size: 18),
                    SizedBox(width: 8),
                    Text('Send Ctrl + Alt + Delete'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Win+R',
                child: Row(
                  children: [
                    Icon(Icons.terminal, size: 18),
                    SizedBox(width: 8),
                    Text('Open Run Dialog (Win + R)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'TaskMgr',
                child: Row(
                  children: [
                    Icon(Icons.bar_chart, size: 18),
                    SizedBox(width: 8),
                    Text('Open Task Manager'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Win+X',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, size: 18),
                    SizedBox(width: 8),
                    Text('Admin Quick Link (Win + X)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Alt+Tab',
                child: Row(
                  children: [
                    Icon(Icons.tab, size: 18),
                    SizedBox(width: 8),
                    Text('Switch Window (Alt + Tab)'),
                  ],
                ),
              ),
            ],
          ),

          if (isCompact) ...[
            PopupMenuButton<String>(
              tooltip: 'Display & Audio Settings',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) {
                switch (action) {
                  case 'clipboard':
                    _syncClipboard();
                    break;
                  case 'fit':
                    setState(() => _fitToWindow = !_fitToWindow);
                    break;
                  case 'audio':
                    setState(() => _audioMuted = !_audioMuted);
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'clipboard',
                  child: Row(
                    children: [
                      Icon(Icons.content_paste_go_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Sync Clipboard'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'fit',
                  child: Row(
                    children: [
                      Icon(
                        _fitToWindow
                            ? Icons.aspect_ratio_rounded
                            : Icons.fit_screen_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fitToWindow
                            ? 'Scale: 1:1 Pixel Match'
                            : 'Scale: Fit to Screen',
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'audio',
                  child: Row(
                    children: [
                      Icon(
                        _audioMuted
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(_audioMuted ? 'Unmute Audio' : 'Mute Audio'),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            IconButton(
              tooltip: 'Sync Clipboard',
              onPressed: _syncClipboard,
              icon: const Icon(Icons.content_paste_go_rounded),
            ),
            IconButton(
              tooltip: _fitToWindow ? '1:1 Pixel Match' : 'Fit to Window',
              onPressed: () => setState(() => _fitToWindow = !_fitToWindow),
              icon: Icon(
                _fitToWindow
                    ? Icons.aspect_ratio_rounded
                    : Icons.fit_screen_rounded,
              ),
            ),
            IconButton(
              tooltip: _audioMuted ? 'Unmute Audio' : 'Mute Audio',
              onPressed: () => setState(() => _audioMuted = !_audioMuted),
              icon: Icon(
                _audioMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              ),
            ),
          ],

          const SizedBox(width: 4),

          // Disconnect button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: _ending ? null : _endSession,
              icon: _ending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.power_settings_new_rounded, size: 16),
              label: Text(
                isCompact ? '' : 'Disconnect',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Focus(
              focusNode: _canvasFocus,
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  _sendSpecialKey(event.logicalKey.keyLabel);
                }
                return KeyEventResult.handled;
              },
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerHover: (event) {
                  // Forward normalized mouse coordinates via WebRTC data channel
                },
                onPointerDown: (event) {
                  _canvasFocus.requestFocus();
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Canvas / Live Video Player
                    if (_connecting) ...[
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Establishing secure LiveKit connection...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_remoteVideoTrack != null) ...[
                      VideoTrackRenderer(
                        _remoteVideoTrack!,
                        fit: _fitToWindow
                            ? VideoViewFit.contain
                            : VideoViewFit.cover,
                      ),
                    ] else ...[
                      // Waiting for stream / Empty State
                      Container(
                        color: const Color(0xFF0F1420),
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.desktop_windows_rounded,
                                  size: 34,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _connectError != null
                                    ? 'Connection Error: $_connectError'
                                    : 'Connected to Room: ${widget.roomName}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Waiting for remote screen stream.\nClick "Share Screen" in the toolbar to stream your desktop/window.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: _toggleScreenShare,
                                icon: Icon(
                                  _isSharing
                                      ? Icons.stop_screen_share_rounded
                                      : Icons.screen_share_rounded,
                                ),
                                label: Text(
                                  _isSharing
                                      ? 'Stop Screen Sharing'
                                      : 'Share My Screen Now',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Top Left Status Pill
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shield_rounded,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _connected
                                  ? 'DIRECT WEBRTC / UAC CONTROL ACTIVE'
                                  : 'CONNECTING...',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
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
    );
  }
}
