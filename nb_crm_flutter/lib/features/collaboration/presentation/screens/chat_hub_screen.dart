import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/network/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/open_url.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/collab_models.dart';
import '../chat_emojis.dart';
import '../collab_providers.dart';
import '../meet_helpers.dart';
import '../chat_wallpaper.dart';
import '../chat_inbox.dart';
import '../chat_mentions.dart';
import 'group_info_sheet.dart';

const _teamsPurple = Color(0xFF5B5FC7);

class _PendingFile {
  const _PendingFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;

  bool get isImage {
    final n = name.toLowerCase();
    return n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.gif') ||
        n.endsWith('.webp') ||
        n.endsWith('.bmp');
  }

  String get sizeLabel {
    if (bytes.length < 1024) return '${bytes.length} B';
    if (bytes.length < 1024 * 1024) return '${(bytes.length / 1024).toStringAsFixed(1)} KB';
    return '${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ChatHubScreen extends ConsumerStatefulWidget {
  const ChatHubScreen({super.key});

  @override
  ConsumerState<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends ConsumerState<ChatHubScreen> {
  List<ChatChannel> _channels = [];
  List<ChatMessage> _messages = [];
  ChatChannel? _active;
  final _draft = TextEditingController();
  final _listSearch = TextEditingController();
  final _scroll = ScrollController();
  String? _typing;
  Timer? _typingClear;
  bool _loading = true;
  bool _emojiOpen = false;
  bool _sending = false;
  String? _error;
  List<_PendingFile> _pending = [];
  ChatMessage? _replyTo;
  int _wallpaper = 0;
  bool _startingCall = false;
  final _composerFocus = FocusNode();
  /// Meeting code → status (LIVE / ENDED / CANCELLED / …).
  Map<String, String> _meetStatusByCode = {};
  Timer? _meetStatusPoll;
  List<MentionChoice> _mentionHits = [];
  int _mentionAt = -1;
  int _mentionSel = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
    _listSearch.addListener(() => setState(() {}));
    _draft.addListener(_onDraftChanged);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _boot();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    _draft.dispose();
    _listSearch.dispose();
    _scroll.dispose();
    _composerFocus.dispose();
    _typingClear?.cancel();
    _meetStatusPoll?.cancel();
    final socket = ref.read(collabSocketProvider);
    socket.offNewMessage(_onNewMessage);
    socket.offMessageUpdated(_onMessageUpdated);
    socket.offChannelRead(_onChannelRead);
    socket.offUserTyping(_onUserTyping);
    socket.offMeetingEnded(_onMeetingEndedEvent);
    socket.offPresence(_onPresence);
    super.dispose();
  }

  void _onPresence(String userId, bool online) {
    if (!mounted || userId.isEmpty) return;
    List<CollabProfile> bump(List<CollabProfile> members) => [
          for (final m in members)
            if (m.userId == userId) m.copyWith(online: online) else m,
        ];
    setState(() {
      _channels = [for (final c in _channels) c.copyWith(members: bump(c.members))];
      final active = _active;
      if (active != null) {
        _active = active.copyWith(members: bump(active.members));
      }
    });
  }

  void _onMeetingEndedEvent(String meetingId, String? code) {
    if (!mounted) return;
    final key = (code ?? '').trim().toLowerCase();
    if (key.isEmpty) {
      unawaited(_refreshMeetStatuses(_messages));
      return;
    }
    setState(() {
      _meetStatusByCode = {..._meetStatusByCode, key: 'ENDED'};
    });
  }

  void _onNewMessage(ChatMessage m) {
    _upsertMessage(m, markReadIfOpen: true);
  }

  bool _isLocalId(String id) => id.startsWith('local:');

  List<ChatMessage> _mergeMessage(List<ChatMessage> current, ChatMessage m) {
    final existing = current.indexWhere((x) => x.id == m.id);
    if (existing >= 0) {
      final next = [...current];
      next[existing] = m;
      return next;
    }
    bool samePayload(ChatMessage x) =>
        x.channelId == m.channelId &&
        x.senderId == m.senderId &&
        (x.content ?? '') == (m.content ?? '') &&
        (x.replyToId ?? '') == (m.replyToId ?? '');
    if (_isLocalId(m.id)) {
      if (current.any((x) => !_isLocalId(x.id) && samePayload(x))) return current;
      return [...current, m];
    }
    final localIdx = current.indexWhere((x) => _isLocalId(x.id) && samePayload(x));
    if (localIdx >= 0) {
      final next = [...current];
      next[localIdx] = m;
      return next;
    }
    return [...current, m];
  }

  void _upsertMessage(ChatMessage m, {bool markReadIfOpen = false}) {
    if (!mounted) return;
    final open = _active?.id == m.channelId;
    final me = ref.read(authNotifierProvider).user?.id;
    final own = _isLocalId(m.id) || (me != null && m.senderId == me);
    setState(() {
      if (open) {
        _messages = _mergeMessage(_messages, m);
      }
      _channels = [
        for (final c in _channels)
          if (c.id == m.channelId)
            c.copyWith(
              unread: open ? 0 : (own ? c.unread : c.unread + 1),
              lastPreview: m.content ?? (m.attachments.isNotEmpty ? 'Attachment' : c.lastPreview),
              lastAt: m.createdAt ?? DateTime.now(),
            )
          else
            c,
      ]..sort((a, b) => (b.lastAt ?? DateTime(0)).compareTo(a.lastAt ?? DateTime(0)));
    });
    if (open) {
      _scrollToEnd();
      if (markReadIfOpen && !_isLocalId(m.id)) {
        unawaited(ref.read(chatRepositoryProvider).markRead(m.channelId));
        final link = meetLinkInText(m.content);
        if (link != null) unawaited(_refreshMeetStatuses([m]));
      }
    }
    if (!_isLocalId(m.id)) {
      unawaited(ref.read(chatUnreadProvider.notifier).refresh());
    }
  }

  void _onMessageUpdated(ChatMessage m) {
    if (!mounted) return;
    setState(() {
      _messages = _messages.map((x) => x.id == m.id ? m : x).toList();
    });
  }

  void _onChannelRead(String channelId, String userId, DateTime? at) {
    if (!mounted || at == null) return;
    setState(() {
      _channels = [
        for (final c in _channels)
          if (c.id == channelId)
            c.copyWith(
              members: [
                for (final member in c.members)
                  member.userId == userId ? member.copyWith(lastReadAt: at) : member,
              ],
            )
          else
            c,
      ];
      if (_active?.id == channelId) {
        _active = _active!.copyWith(
          members: [
            for (final member in _active!.members)
              member.userId == userId ? member.copyWith(lastReadAt: at) : member,
          ],
        );
      }
    });
  }

  void _onUserTyping(String channelId, String name) {
    if (!mounted || _active?.id != channelId) return;
    setState(() => _typing = name);
    _typingClear?.cancel();
    _typingClear = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _typing = null);
    });
  }

  Future<void> _boot() async {
    try {
      final token = await ref.read(secureStorageProvider).readToken();
      final socket = ref.read(collabSocketProvider);
      if (token != null) socket.connect(token: token);
      socket.onNewMessage(_onNewMessage);
      socket.onMessageUpdated(_onMessageUpdated);
      socket.onChannelRead(_onChannelRead);
      socket.onUserTyping(_onUserTyping);
      socket.onMeetingEnded(_onMeetingEndedEvent);
      socket.onPresence(_onPresence);
      _meetStatusPoll?.cancel();
      _meetStatusPoll = Timer.periodic(const Duration(seconds: 20), (_) {
        if (!mounted || _messages.isEmpty) return;
        unawaited(_refreshMeetStatuses(_messages));
      });
      final channels = await ref.read(chatRepositoryProvider).channels();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _loading = false;
      });
      unawaited(ref.read(chatUnreadProvider.notifier).refresh());
      final lastId = await loadLastChatChannelId();
      final target = lastId == null
          ? null
          : channels.where((c) => c.id == lastId).firstOrNull;
      if (target != null && mounted) await _open(target);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _refreshChannels() async {
    final channels = await ref.read(chatRepositoryProvider).channels();
    if (!mounted) return;
    setState(() => _channels = channels);
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (!mounted || _active == null) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    if (_mentionHits.isNotEmpty) {
      setState(() {
        _mentionHits = [];
        _mentionAt = -1;
      });
      return true;
    }
    _closeThread();
    return true;
  }

  void _onDraftChanged() {
    final ch = _active;
    final me = ref.read(authNotifierProvider).user?.id;
    if (ch == null || !ch.isGroup) {
      if (_mentionHits.isNotEmpty) {
        setState(() {
          _mentionHits = [];
          _mentionAt = -1;
        });
      }
      return;
    }
    final cursor = _draft.selection.baseOffset;
    final found = mentionDraftQuery(_draft.text, cursor < 0 ? _draft.text.length : cursor);
    if (found == null) {
      if (_mentionHits.isNotEmpty) {
        setState(() {
          _mentionHits = [];
          _mentionAt = -1;
        });
      }
      return;
    }
    final hits = mentionChoicesFor(channel: ch, me: me, query: found.query);
    setState(() {
      _mentionHits = hits;
      _mentionAt = found.start;
      if (_mentionSel >= hits.length) _mentionSel = 0;
    });
  }

  void _applyMention(MentionChoice choice) {
    if (_mentionAt < 0) return;
    applyMentionInsert(draft: _draft, atIndex: _mentionAt, insert: choice.insert);
    setState(() {
      _mentionHits = [];
      _mentionAt = -1;
      _mentionSel = 0;
    });
    _composerFocus.requestFocus();
  }

  void _startMention() {
    final ch = _active;
    if (ch == null || !ch.isGroup) return;
    final text = _draft.text;
    final cursor = _draft.selection.baseOffset < 0 ? text.length : _draft.selection.baseOffset;
    final atCursor = cursor > 0 && text.substring(cursor - 1, cursor) == '@';
    if (!atCursor) {
      final prefix = cursor > 0 && !RegExp(r'\s').hasMatch(text.substring(cursor - 1, cursor)) ? ' @' : '@';
      final next = text.replaceRange(cursor, cursor, prefix);
      _draft.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: cursor + prefix.length),
      );
    }
    _composerFocus.requestFocus();
  }

  void _submitComposer() {
    if (_mentionHits.isNotEmpty) {
      _applyMention(_mentionHits[_mentionSel.clamp(0, _mentionHits.length - 1)]);
      return;
    }
    _send();
  }

  void _closeThread() {
    final id = _active?.id;
    if (id == null) return;
    ref.read(collabSocketProvider).leaveChannel(id);
    _composerFocus.unfocus();
    setState(() {
      _active = null;
      _messages = [];
      _emojiOpen = false;
      _pending = [];
      _replyTo = null;
      _typing = null;
      _sending = false;
      _mentionHits = [];
      _mentionAt = -1;
      _draft.clear();
    });
    unawaited(clearLastChatChannelId());
    unawaited(ref.read(chatUnreadProvider.notifier).refresh());
  }

  Future<void> _open(ChatChannel ch) async {
    ref.read(collabSocketProvider).leaveChannel(_active?.id ?? '');
    ref.read(collabSocketProvider).joinChannel(ch.id);
    final msgs = await ref.read(chatRepositoryProvider).messages(ch.id);
    await ref.read(chatRepositoryProvider).markRead(ch.id);
    final latest = await ref.read(chatRepositoryProvider).channels();
    if (!mounted) return;
    final fresh = latest.where((c) => c.id == ch.id).firstOrNull ?? ch;
    final wallpaper = await loadChatWallpaper(fresh.id);
    if (!mounted) return;
    setState(() {
      _channels = [
        for (final c in latest)
          if (c.id == fresh.id) c.copyWith(unread: 0) else c,
      ];
      _active = fresh.copyWith(unread: 0);
      _messages = msgs;
      _emojiOpen = false;
      _pending = [];
      _replyTo = null;
      _wallpaper = wallpaper;
      _sending = false;
      _typing = null;
      if (_channels.every((c) => c.id != fresh.id)) {
        _channels = [fresh.copyWith(unread: 0), ..._channels];
      }
    });
    _scrollToEnd();
    unawaited(saveLastChatChannelId(fresh.id));
    unawaited(_refreshMeetStatuses(msgs));
    unawaited(ref.read(chatUnreadProvider.notifier).refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  Future<void> _refreshMeetStatuses(List<ChatMessage> msgs) async {
    final codes = <String>{};
    for (final m in msgs) {
      final link = meetLinkInText(m.content);
      if (link != null) codes.add(link.code.toLowerCase());
    }
    if (codes.isEmpty) return;
    final next = Map<String, String>.from(_meetStatusByCode);
    await Future.wait(codes.map((code) async {
      try {
        final item = await ref.read(meetRepositoryProvider).getByCode(code);
        next[code] = item.status;
      } catch (_) {
        next[code] = 'ENDED';
      }
    }));
    if (!mounted) return;
    setState(() => _meetStatusByCode = next);
  }

  Future<String> _attachmentUrl(ChatAttachment attachment) async {
    var url = '';
    if (attachment.id != null && attachment.id!.isNotEmpty) {
      url = await ref.read(chatRepositoryProvider).attachmentUrl(attachment.id!);
    }
    if (url.isEmpty) url = attachment.fileUrl ?? '';
    return _absoluteFileUrl(url);
  }

  Future<void> _viewAttachment(ChatAttachment attachment) async {
    try {
      final url = await _attachmentUrl(attachment);
      if (url.isEmpty || _isBlockedPublicFileUrl(url)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This file is not available')),
        );
        return;
      }
      if (attachment.isImage && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) {
            final size = MediaQuery.sizeOf(ctx);
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width * 0.9,
                  maxHeight: size.height * 0.88,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                      child: Row(
                        children: [
                          Expanded(child: Text(attachment.fileName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          IconButton(
                            tooltip: 'Download',
                            onPressed: () => _downloadAttachment(attachment),
                            icon: const NbIcon(Icons.download_rounded),
                          ),
                          IconButton(onPressed: () => Navigator.pop(ctx), icon: const NbIcon(Icons.close)),
                        ],
                      ),
                    ),
                    Expanded(child: InteractiveViewer(child: Image.network(url))),
                  ],
                ),
              ),
            );
          },
        );
        return;
      }
      await openExternalUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _downloadAttachment(ChatAttachment attachment) async {
    try {
      final url = await _attachmentUrl(attachment);
      if (url.isEmpty || _isBlockedPublicFileUrl(url)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This file is not available')),
        );
        return;
      }
      await downloadUrl(url, attachment.fileName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _showReactionPicker(ChatMessage message) {
    showChatEmojiSheet(
      context: context,
      title: 'React',
      onPick: (emoji) => ref.read(collabSocketProvider).react(message.id, emoji),
    );
  }

  void _showMessageActions(ChatMessage message) {
    final channel = _active;
    final me = ref.read(authNotifierProvider).user?.id;
    if (channel == null || message.deleted) return;
    final canMutate = message.senderId == me && receiptsFor(message, channel).seen.isEmpty;
    final canEdit = canMutate && (message.content ?? '').trim().isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const NbIcon(Icons.emoji_emotions_outlined),
                title: const Text('React'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReactionPicker(message);
                },
              ),
              ListTile(
                leading: const NbIcon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyTo = message);
                  _composerFocus.requestFocus();
                },
              ),
              if (canEdit)
                ListTile(
                  leading: const NbIcon(Icons.edit_outlined),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_editMessage(message));
                  },
                ),
              if (canMutate)
                ListTile(
                  leading: const NbIcon(Icons.delete_outline, color: Color(0xFFDC2626)),
                  title: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_deleteMessage(message));
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editMessage(ChatMessage message) async {
    final ctrl = TextEditingController(text: message.content ?? '');
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Message'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (next == null || next.isEmpty || next == message.content) return;
    try {
      final updated = await ref.read(chatRepositoryProvider).editMessage(message.id, next);
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((x) => x.id == updated.id ? updated : x).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This removes the message for everyone. You can only do this if nobody has seen it yet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final updated = await ref.read(chatRepositoryProvider).deleteMessage(message.id);
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((x) => x.id == updated.id ? updated : x).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _showSeenDetails(ChatMessage message) {
    final channel = _active;
    if (channel == null) return;
    final receipts = receiptsFor(message, channel);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Message status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                if (receipts.seen.isEmpty && receipts.unseen.isEmpty)
                  const Text('No one else is in this chat'),
                if (receipts.seen.isNotEmpty) ...[
                  Text('Seen (${receipts.seen.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ...receipts.seen.map((p) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: _Avatar(name: p.name, url: p.photoUrl, size: 32),
                        title: Text(p.name),
                        trailing: const NbIcon(Icons.done_all, size: 16, color: Color(0xFF5B5FC7)),
                      )),
                ],
                if (receipts.unseen.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Not seen (${receipts.unseen.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ...receipts.unseen.map((p) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: _Avatar(name: p.name, url: p.photoUrl, size: 32),
                        title: Text(p.name),
                        trailing: NbIcon(Icons.done, size: 16, color: mutedOf(Theme.of(ctx).brightness == Brightness.dark)),
                      )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSelfChat() async {
    final me = ref.read(authNotifierProvider).user?.id;
    if (me == null) return;
    final ch = await ref.read(chatRepositoryProvider).startDm(me);
    await _refreshChannels();
    await _open(ch);
  }

  Future<void> _send() async {
    final text = _draft.text.replaceAll('\r\n', '\n').trim();
    final ch = _active;
    if (ch == null || _sending || (text.isEmpty && _pending.isEmpty)) return;
    final pending = List<_PendingFile>.from(_pending);
    final reply = _replyTo;
    final replyId = reply?.id;
    setState(() {
      _emojiOpen = false;
      _sending = true;
    });
    try {
      if (pending.isEmpty) {
        _draft.clear();
        setState(() => _replyTo = null);
        _emitChatText(ch, text, replyId: replyId, replyTo: reply);
        return;
      }
      final attachments = <Map<String, dynamic>>[];
      for (final file in pending) {
        attachments.add(await ref.read(chatRepositoryProvider).upload(file.bytes, file.name));
      }
      final sent = await ref.read(chatRepositoryProvider).send(
        channelId: ch.id,
        content: text.isEmpty ? null : text,
        replyToId: replyId,
        attachments: attachments,
      );
      _draft.clear();
      if (mounted) {
        setState(() {
          _pending = [];
          _replyTo = null;
        });
        _upsertMessage(sent, markReadIfOpen: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _composerFocus.requestFocus();
      }
    }
  }

  void _emitChatText(
    ChatChannel ch,
    String text, {
    String? replyId,
    ChatMessage? replyTo,
  }) {
    final me = ref.read(authNotifierProvider).user;
    final optimistic = ChatMessage(
      id: 'local:${DateTime.now().microsecondsSinceEpoch}',
      channelId: ch.id,
      senderId: me?.id ?? '',
      senderName: me?.name,
      senderPhoto: me?.photoUrl,
      content: text,
      replyToId: replyId,
      replyTo: replyTo == null
          ? null
          : ChatReplyPreview(
              id: replyTo.id,
              senderName: replyTo.senderName ?? 'Member',
              content: replyTo.content,
              senderId: replyTo.senderId,
            ),
      createdAt: DateTime.now(),
    );
    _upsertMessage(optimistic);
    ref.read(collabSocketProvider).sendMessage(ch.id, text, replyToId: replyId);
  }

  Future<void> _startVoiceCall() async {
    final ch = _active;
    if (ch == null || _startingCall) return;
    final me = ref.read(authNotifierProvider).user?.id;
    final invitees = ch.members.map((m) => m.userId).where((id) => id.isNotEmpty && id != me).toList();
    final title = ch.type == 'GROUP'
        ? '${ch.name?.trim().isNotEmpty == true ? ch.name : 'Group'} voice call'
        : 'Voice call with ${_channelTitle(ch, me)}';
    setState(() => _startingCall = true);
    final tab = prepareMeetTab();
    try {
      final meeting = await ref.read(meetRepositoryProvider).create(
            title: title,
            instant: true,
            waitingRoom: false,
            inviteeIds: invitees,
          );
      final link = () {
        final base = meetingShareUrl(meeting);
        return base.contains('?') ? '$base&voice=1' : '$base?voice=1';
      }();
      _emitChatText(ch, 'Started a voice call. Join: $link');
      if (!mounted) {
        tab?.dismiss();
        return;
      }
      await openMeetRoom(context, meeting.code, voice: true, tab: tab);
      if (mounted) {
        setState(() => _meetStatusByCode = {
              ..._meetStatusByCode,
              meeting.code.toLowerCase(): meeting.status,
            });
      }
    } catch (e) {
      tab?.dismiss();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _startingCall = false);
    }
  }

  Future<void> _showChatInfo() async {
    final ch = _active;
    if (ch == null) return;
    await showChatInfoSheet(
      context: context,
      channel: ch,
      me: ref.read(authNotifierProvider).user?.id,
      onUpdated: (next) {
        if (!mounted) return;
        setState(() {
          _active = next;
          _channels = [
            for (final c in _channels)
              if (c.id == next.id)
                next.copyWith(
                  unread: c.unread,
                  lastPreview: c.lastPreview,
                  lastAt: c.lastAt,
                )
              else
                c,
          ];
        });
      },
      onLeft: () {
        final id = ch.id;
        if (!mounted) return;
        final remaining = _channels.where((c) => c.id != id).toList();
        setState(() {
          _channels = remaining;
          if (_active?.id == id) _active = null;
        });
        unawaited(clearLastChatChannelId());
        unawaited(ref.read(chatUnreadProvider.notifier).refresh());
        if (remaining.isNotEmpty) {
          unawaited(_open(remaining.first));
        }
      },
      onMessageMember: (userId) async {
        final dm = await ref.read(chatRepositoryProvider).startDm(userId);
        await _refreshChannels();
        await _open(dm);
      },
    );
  }

  Future<void> _attach() async {
    if (_active == null) return;
    final pick = await FilePicker.pickFiles(withData: true, allowMultiple: true);
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final added = <_PendingFile>[
      for (final file in pick.files)
        if (file.bytes != null) _PendingFile(name: file.name, bytes: file.bytes!),
    ];
    if (added.isEmpty) return;
    setState(() => _pending = [..._pending, ...added]);
    _composerFocus.requestFocus();
  }

  Future<void> _newChat({required bool group}) async {
    final me = ref.read(authNotifierProvider).user;
    var people = await ref.read(chatRepositoryProvider).directory('');
    if (!mounted) return;
    final selected = <String>{};
    final nameCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> search(String q) async {
              people = await ref.read(chatRepositoryProvider).directory(q);
              if (ctx.mounted) setLocal(() {});
            }

            return AlertDialog(
              title: Text(group ? 'New group' : 'New chat'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (group)
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Group name',
                          prefixIcon: NbIcon(Icons.group_outlined),
                        ),
                      ),
                    if (group) const SizedBox(height: 10),
                    TextField(
                      controller: searchCtrl,
                      onChanged: search,
                      decoration: const InputDecoration(
                        hintText: 'Search people',
                        prefixIcon: NbIcon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!group && me != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _Avatar(name: me.name, url: me.photoUrl),
                        title: Text('${me.name} (You)'),
                        subtitle: const Text('Note to self'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _openSelfChat();
                        },
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView(
                        shrinkWrap: true,
                        children: people
                            .where((p) => group || p.userId != me?.id)
                            .map(
                              (p) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: _Avatar(name: p.name, url: p.photoUrl, online: p.online),
                                title: Text(p.name),
                                subtitle: p.department != null ? Text(p.department!) : null,
                                trailing: group
                                    ? Checkbox(
                                        value: selected.contains(p.userId),
                                        onChanged: (v) => setLocal(() {
                                          if (v == true) {
                                            selected.add(p.userId);
                                          } else {
                                            selected.remove(p.userId);
                                          }
                                        }),
                                      )
                                    : null,
                                onTap: group
                                    ? () => setLocal(() {
                                          if (selected.contains(p.userId)) {
                                            selected.remove(p.userId);
                                          } else {
                                            selected.add(p.userId);
                                          }
                                        })
                                    : () async {
                                        Navigator.pop(ctx);
                                        final ch = await ref.read(chatRepositoryProvider).startDm(p.userId);
                                        await _refreshChannels();
                                        await _open(ch);
                                      },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                if (group)
                  FilledButton(
                    onPressed: selected.isEmpty || nameCtrl.text.trim().length < 2
                        ? null
                        : () async {
                            final ch = await ref.read(chatRepositoryProvider).createGroup(
                                  nameCtrl.text,
                                  selected.toList(),
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _refreshChannels();
                            await _open(ch);
                          },
                    child: const Text('Create'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  List<ChatChannel> get _visible {
    final q = _listSearch.text.trim().toLowerCase();
    if (q.isEmpty) return _channels;
    final me = ref.read(authNotifierProvider).user?.id;
    return _channels.where((c) {
      final title = _channelTitle(c, me).toLowerCase();
      return title.contains(q) || (c.lastPreview ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authNotifierProvider).user?.id;
    final screenW = MediaQuery.sizeOf(context).width;
    final wide = screenW >= 900;
    final listWidth = screenW >= 1280 ? 360.0 : 300.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: Center(child: Text(_error!)),
      );
    }

    final list = _TeamsChatList(
      channels: _visible,
      activeId: _active?.id,
      me: me,
      search: _listSearch,
      isDark: isDark,
      onOpen: _open,
      onNewDm: () => _newChat(group: false),
      onNewGroup: () => _newChat(group: true),
    );

    final thread = _active == null
        ? _TeamsEmpty(isDark: isDark, onNew: () => _newChat(group: false))
        : _TeamsThread(
            channel: _active!,
            messages: _messages,
            me: me,
            draft: _draft,
            composerFocus: _composerFocus,
            typing: _typing,
            emojiOpen: _emojiOpen,
            scroll: _scroll,
            showBack: !wide,
            isDark: isDark,
            wallpaper: ChatWallpaper.byId(_wallpaper),
            meetStatusByCode: _meetStatusByCode,
            replyTo: _replyTo,
            startingCall: _startingCall,
            onBack: _closeThread,
            onSend: _submitComposer,
            onAttach: _attach,
            pending: _pending,
            sending: _sending,
            onRemovePending: (i) => setState(() => _pending = [..._pending]..removeAt(i)),
            onToggleEmoji: () {
              setState(() => _emojiOpen = !_emojiOpen);
              _composerFocus.requestFocus();
            },
            onPickEmoji: (e) {
              _draft.text += e;
              _draft.selection = TextSelection.collapsed(offset: _draft.text.length);
              _composerFocus.requestFocus();
            },
            onReact: (id, e) => ref.read(collabSocketProvider).react(id, e),
            onReactPicker: _showMessageActions,
            onViewAttachment: _viewAttachment,
            onDownloadAttachment: _downloadAttachment,
            onShowReceipts: _showSeenDetails,
            onReply: (m) {
              setState(() => _replyTo = m);
              _composerFocus.requestFocus();
            },
            onClearReply: () => setState(() => _replyTo = null),
            onVoiceCall: _startVoiceCall,
            onWallpaper: () async {
              await pickChatWallpaper(
                context: context,
                selected: _wallpaper,
                onPick: (id) async {
                  final ch = _active;
                  if (ch == null) return;
                  await saveChatWallpaper(ch.id, id);
                  if (mounted) setState(() => _wallpaper = id);
                },
              );
              if (mounted) _composerFocus.requestFocus();
            },
            onOpenInfo: _showChatInfo,
            onChanged: () {
              final id = _active?.id;
              if (id != null) ref.read(collabSocketProvider).typing(id);
            },
            mentionHits: _mentionHits,
            mentionSel: _mentionSel,
            onPickMention: _applyMention,
            onMentionSel: (i) => setState(() => _mentionSel = i),
            onStartMention: _startMention,
            onMentionMove: (delta) {
              if (_mentionHits.isEmpty) return;
              setState(() {
                _mentionSel = (_mentionSel + delta) % _mentionHits.length;
                if (_mentionSel < 0) _mentionSel = _mentionHits.length - 1;
              });
            },
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_mentionHits.isNotEmpty) {
            setState(() {
              _mentionHits = [];
              _mentionAt = -1;
            });
            return;
          }
          _closeThread();
        },
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
        body: wide
            ? Row(
                children: [
                  SizedBox(width: listWidth, child: list),
                  VerticalDivider(width: 1, color: isDark ? AppColors.borderDark : const Color(0xFFE0E0E0)),
                  Expanded(child: thread),
                ],
              )
            : (_active == null ? list : thread),
      ),
    );
  }
}

class _TeamsChatList extends StatelessWidget {
  const _TeamsChatList({
    required this.channels,
    required this.activeId,
    required this.me,
    required this.search,
    required this.isDark,
    required this.onOpen,
    required this.onNewDm,
    required this.onNewGroup,
  });

  final List<ChatChannel> channels;
  final String? activeId;
  final String? me;
  final TextEditingController search;
  final bool isDark;
  final void Function(ChatChannel) onOpen;
  final VoidCallback onNewDm;
  final VoidCallback onNewGroup;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : Colors.white;
    final text = isDark ? AppColors.textPrimaryDark : const Color(0xFF242424);
    final muted = isDark ? AppColors.textSecondaryDark : const Color(0xFF616161);
    return ColoredBox(
      color: bg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chat',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.4),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'New',
                  icon: const NbIcon(Icons.edit_outlined, color: _teamsPurple),
                  onSelected: (v) => v == 'group' ? onNewGroup() : onNewDm(),
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'dm', child: Text('New chat')),
                    PopupMenuItem(value: 'group', child: Text('New group')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: search,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const NbIcon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: isDark ? AppColors.backgroundDark : const Color(0xFFF0F0F0),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: channels.isEmpty
                ? Center(
                    child: Text('No chats yet', style: TextStyle(color: muted)),
                  )
                : ListView.builder(
                    itemCount: channels.length,
                    itemBuilder: (context, i) {
                      final c = channels[i];
                      final selected = c.id == activeId;
                      final title = _channelTitle(c, me);
                      final photo = _channelPhoto(c, me);
                      final other = c.members.where((m) => m.userId != me).firstOrNull;
                      return Material(
                        color: selected
                            ? (isDark ? const Color(0xFF2F2B4A) : const Color(0xFFE8EBFA))
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => onOpen(c),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                _Avatar(
                                  name: title,
                                  url: photo,
                                  isGroup: c.type == 'GROUP',
                                  online: c.type == 'GROUP'
                                      ? c.anyOtherOnline(me)
                                      : other?.online == true,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: c.unread > 0 ? FontWeight.w800 : FontWeight.w600,
                                                color: text,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          if (c.lastAt != null)
                                            Text(
                                              _chatWhen(c.lastAt!),
                                              style: TextStyle(fontSize: 11, color: muted),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (c.lastPreview ?? '').isEmpty ? 'No messages yet' : c.lastPreview!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: muted,
                                          fontWeight: c.unread > 0 ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (c.unread > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    decoration: BoxDecoration(
                                      color: _teamsPurple,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${c.unread}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TeamsEmpty extends StatelessWidget {
  const _TeamsEmpty({required this.isDark, required this.onNew});
  final bool isDark;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.textSecondaryDark : const Color(0xFF616161);
    return ColoredBox(
      color: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NbIcon(Icons.chat, size: 56, color: muted.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
              'Select a chat to start messaging',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF242424)),
            ),
            const SizedBox(height: 6),
            Text('Or start a new conversation', style: TextStyle(color: muted)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onNew,
              style: FilledButton.styleFrom(backgroundColor: _teamsPurple),
              icon: const NbIcon(Icons.edit_outlined, size: 18),
              label: const Text('New chat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamsThread extends StatelessWidget {
  const _TeamsThread({
    required this.channel,
    required this.messages,
    required this.me,
    required this.draft,
    required this.composerFocus,
    required this.typing,
    required this.emojiOpen,
    required this.scroll,
    required this.showBack,
    required this.isDark,
    required this.wallpaper,
    required this.meetStatusByCode,
    required this.replyTo,
    required this.startingCall,
    required this.onBack,
    required this.onSend,
    required this.onAttach,
    required this.pending,
    required this.sending,
    required this.onRemovePending,
    required this.onToggleEmoji,
    required this.onPickEmoji,
    required this.onReact,
    required this.onReactPicker,
    required this.onViewAttachment,
    required this.onDownloadAttachment,
    required this.onShowReceipts,
    required this.onReply,
    required this.onClearReply,
    required this.onVoiceCall,
    required this.onWallpaper,
    required this.onOpenInfo,
    required this.onChanged,
    required this.mentionHits,
    required this.mentionSel,
    required this.onPickMention,
    required this.onMentionSel,
    required this.onStartMention,
    required this.onMentionMove,
  });

  final ChatChannel channel;
  final List<ChatMessage> messages;
  final String? me;
  final TextEditingController draft;
  final FocusNode composerFocus;
  final String? typing;
  final bool emojiOpen;
  final ScrollController scroll;
  final bool showBack;
  final bool isDark;
  final ChatWallpaper wallpaper;
  final Map<String, String> meetStatusByCode;
  final ChatMessage? replyTo;
  final bool startingCall;
  final VoidCallback onBack;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final List<_PendingFile> pending;
  final bool sending;
  final void Function(int index) onRemovePending;
  final VoidCallback onToggleEmoji;
  final void Function(String) onPickEmoji;
  final void Function(String id, String emoji) onReact;
  final void Function(ChatMessage) onReactPicker;
  final void Function(ChatAttachment) onViewAttachment;
  final void Function(ChatAttachment) onDownloadAttachment;
  final void Function(ChatMessage) onShowReceipts;
  final void Function(ChatMessage) onReply;
  final VoidCallback onClearReply;
  final VoidCallback onVoiceCall;
  final VoidCallback onWallpaper;
  final VoidCallback onOpenInfo;
  final VoidCallback onChanged;
  final List<MentionChoice> mentionHits;
  final int mentionSel;
  final void Function(MentionChoice) onPickMention;
  final void Function(int) onMentionSel;
  final VoidCallback onStartMention;
  final void Function(int delta) onMentionMove;

  @override
  Widget build(BuildContext context) {
    final title = _channelTitle(channel, me);
    final photo = _channelPhoto(channel, me);
    final other = channel.members.where((m) => m.userId != me).firstOrNull;
    final subtitle = typing != null
        ? '$typing is typing…'
        : channel.presenceSubtitle(me);
    final headerBg = isDark ? AppColors.surfaceDark : Colors.white;
    final text = isDark ? AppColors.textPrimaryDark : const Color(0xFF242424);
    final muted = isDark ? AppColors.textSecondaryDark : const Color(0xFF616161);
    final narrow = MediaQuery.sizeOf(context).width < 420;

    return ColoredBox(
      color: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
      child: Column(
        children: [
          Material(
            color: headerBg,
            elevation: 0,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? AppColors.borderDark : const Color(0xFFE0E0E0)),
                ),
              ),
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: onBack,
                      icon: const NbIcon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: InkWell(
                      onTap: onOpenInfo,
                      borderRadius: BorderRadius.circular(8),
                      child: Tooltip(
                        message: channel.type == 'GROUP' ? 'Group info' : 'Chat info',
                        child: Row(
                        children: [
                          _Avatar(
                            name: title,
                            url: photo,
                            isGroup: channel.type == 'GROUP',
                            online: channel.type == 'GROUP'
                                ? channel.anyOtherOnline(me)
                                : other?.online == true,
                            size: 36,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w700, color: text),
                                ),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: typing != null ? _teamsPurple : muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!narrow) NbIcon(Icons.chevron_right_rounded, color: muted, size: 20),
                          const SizedBox(width: 4),
                        ],
                      ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Wallpaper',
                    visualDensity: VisualDensity.compact,
                    onPressed: onWallpaper,
                    icon: NbIcon(Icons.wallpaper_rounded, color: muted),
                  ),
                  IconButton(
                    tooltip: channel.type == 'GROUP' ? 'Group voice call' : 'Voice call',
                    visualDensity: VisualDensity.compact,
                    onPressed: startingCall ? null : onVoiceCall,
                    icon: startingCall
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const NbIcon(Icons.call_rounded, color: _teamsPurple),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: wallpaper.build(
                isDark: isDark,
                child: ListView.builder(
                controller: scroll,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                final mine = m.senderId == me;
                final prev = i > 0 ? messages[i - 1] : null;
                final grouped = prev != null && prev.senderId == m.senderId;
                final showDate = prev == null || !_sameDay(prev.createdAt, m.createdAt);
                return Column(
                  children: [
                    if (showDate && m.createdAt != null) _DateChip(date: m.createdAt!, isDark: isDark),
                    _MessageBubble(
                      message: m,
                      mine: mine,
                      grouped: grouped,
                      isDark: isDark,
                      channel: channel,
                      me: me,
                      onReact: onReact,
                      onReactPicker: onReactPicker,
                      onViewAttachment: onViewAttachment,
                      onDownloadAttachment: onDownloadAttachment,
                      onShowReceipts: onShowReceipts,
                      onReply: onReply,
                      onJoinMeet: (code, {required bool voice}) {
                        openMeetRoom(context, code, voice: voice);
                      },
                      meetEnded: () {
                        final link = meetLinkInText(m.content);
                        if (link == null) return false;
                        return meetCardEnded(
                          meetStatusByCode[link.code.toLowerCase()],
                          voice: link.voice,
                        );
                      }(),
                    ),
                  ],
                );
              },
            ),
              ),
            ),
          ),
          if (emojiOpen)
            Material(
              color: headerBg,
              child: SizedBox(
                height: 220,
                child: ChatEmojiGrid(
                  onPick: onPickEmoji,
                  isDark: isDark,
                ),
              ),
            ),
          Material(
            color: headerBg,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mentionHits.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: Material(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        elevation: 6,
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: mentionHits.length,
                          itemBuilder: (context, i) {
                            final hit = mentionHits[i];
                            final selected = i == mentionSel;
                            return InkWell(
                              onTap: () => onPickMention(hit),
                              onHover: (_) => onMentionSel(i),
                              child: ColoredBox(
                                color: selected
                                    ? _teamsPurple.withValues(alpha: isDark ? 0.22 : 0.12)
                                    : Colors.transparent,
                                child: ListTile(
                                  dense: true,
                                  leading: hit.everyone
                                      ? const CircleAvatar(
                                          radius: 14,
                                          backgroundColor: _teamsPurple,
                                          child: NbIcon(Icons.groups_rounded, color: Colors.white, size: 16),
                                        )
                                      : _Avatar(
                                          name: hit.label,
                                          url: hit.person?.photoUrl,
                                          size: 28,
                                          online: hit.person?.online == true,
                                        ),
                                  title: Text(
                                    hit.everyone ? 'Everyone' : hit.label,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    hit.everyone ? 'Notify all members' : (hit.person?.online == true ? 'Available' : 'Away'),
                                    style: TextStyle(fontSize: 11, color: muted),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (pending.isNotEmpty)
                    SizedBox(
                      height: 108,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.hardEdge,
                        itemCount: pending.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final file = pending[i];
                          return Stack(
                            children: [
                              Container(
                                width: 96,
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.backgroundDark : const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE0E0E0)),
                                ),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 40,
                                      width: 72,
                                      child: file.isImage
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.memory(file.bytes, fit: BoxFit.cover, width: 72, height: 40),
                                            )
                                          : const Center(
                                              child: NbIcon(Icons.insert_drive_file_outlined, color: _teamsPurple, size: 26),
                                            ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      file.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text),
                                    ),
                                    Text(file.sizeLabel, style: TextStyle(fontSize: 9, color: muted)),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: InkWell(
                                  onTap: sending ? null : () => onRemovePending(i),
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.black87 : Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
                                      ],
                                    ),
                                    child: const NbIcon(Icons.close, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  if (replyTo != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                      child: Row(
                        children: [
                          Container(width: 3, height: 36, color: _teamsPurple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Replying to ${replyTo!.senderName ?? 'message'}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _teamsPurple),
                                ),
                                Text(
                                  (replyTo!.content ?? '').trim().isNotEmpty
                                      ? replyTo!.content!.trim()
                                      : (replyTo!.attachments.isNotEmpty ? 'Attachment' : 'Message'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cancel reply',
                            onPressed: onClearReply,
                            icon: NbIcon(Icons.close_rounded, size: 18, color: muted),
                          ),
                        ],
                      ),
                    ),
                  SafeArea(
                    top: false,
                    child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Attach',
                          visualDensity: VisualDensity.compact,
                          onPressed: onAttach,
                          icon: NbIcon(Icons.attach_file_rounded, color: muted),
                        ),
                        IconButton(
                          tooltip: 'Emoji',
                          visualDensity: VisualDensity.compact,
                          onPressed: onToggleEmoji,
                          icon: NbIcon(
                            emojiOpen ? Icons.emoji_emotions : Icons.emoji_emotions_outlined,
                            color: emojiOpen ? _teamsPurple : muted,
                          ),
                        ),
                        if (channel.isGroup)
                          IconButton(
                            tooltip: 'Mention someone',
                            visualDensity: VisualDensity.compact,
                            onPressed: onStartMention,
                            icon: NbIcon(Icons.alternate_email_rounded, color: muted),
                          ),
                        Expanded(
                          child: CallbackShortcuts(
                            bindings: {
                              if (mentionHits.isNotEmpty) ...{
                                const SingleActivator(LogicalKeyboardKey.arrowDown): () => onMentionMove(1),
                                const SingleActivator(LogicalKeyboardKey.arrowUp): () => onMentionMove(-1),
                              },
                              const SingleActivator(LogicalKeyboardKey.enter): onSend,
                              const SingleActivator(LogicalKeyboardKey.numpadEnter): onSend,
                              const SingleActivator(LogicalKeyboardKey.escape): onBack,
                            },
                            child: TextField(
                              controller: draft,
                              focusNode: composerFocus,
                              autofocus: true,
                              showCursor: true,
                              minLines: 1,
                              maxLines: 6,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              onTapOutside: (_) {},
                              onChanged: (_) => onChanged(),
                              decoration: InputDecoration(
                                hintText: pending.isEmpty ? 'Type a message' : 'Add a caption',
                                filled: true,
                                fillColor: isDark ? AppColors.backgroundDark : const Color(0xFFF0F0F0),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: _teamsPurple,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: sending ? null : onSend,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: sending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const NbIcon(Icons.send_rounded, color: Colors.white, size: 18),
                            ),
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
        ],
      ),
    );
  }
}

String _breakLongTokens(String s) {
  return s.replaceAllMapped(RegExp(r'(https?://[^\s]+)'), (m) {
    return m[1]!
        .replaceAll('/', '/\u200B')
        .replaceAll('?', '?\u200B')
        .replaceAll('&', '&\u200B')
        .replaceAll('=', '\u200B=');
  });
}

class _VoiceCallCard extends StatelessWidget {
  const _VoiceCallCard({required this.voice, this.onJoin, this.ended = false});

  final bool voice;
  final bool ended;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _teamsPurple.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: NbIcon(
              voice ? Icons.call_rounded : Icons.videocam,
              color: _teamsPurple,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ended
                  ? (voice ? 'Voice call ended' : 'Meeting ended')
                  : (voice ? 'Voice call' : 'Meeting'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: ended ? Colors.white54 : null,
              ),
            ),
          ),
          if (!ended)
            FilledButton(
              onPressed: onJoin,
              style: FilledButton.styleFrom(
                backgroundColor: _teamsPurple,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Join'),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.grouped,
    required this.isDark,
    required this.channel,
    required this.me,
    required this.onReact,
    required this.onReactPicker,
    required this.onViewAttachment,
    required this.onDownloadAttachment,
    required this.onShowReceipts,
    required this.onReply,
    this.onJoinMeet,
    this.meetEnded = false,
  });

  final ChatMessage message;
  final bool mine;
  final bool grouped;
  final bool isDark;
  final ChatChannel channel;
  final String? me;
  final void Function(String id, String emoji) onReact;
  final void Function(ChatMessage) onReactPicker;
  final void Function(ChatAttachment) onViewAttachment;
  final void Function(ChatAttachment) onDownloadAttachment;
  final void Function(ChatMessage) onShowReceipts;
  final void Function(ChatMessage) onReply;
  final void Function(String code, {required bool voice})? onJoinMeet;
  final bool meetEnded;

  @override
  Widget build(BuildContext context) {
    final ownBg = isDark ? const Color(0xFF3B3A6A) : const Color(0xFFE8EBFA);
    final otherBg = isDark ? AppColors.surfaceDark : Colors.white;
    final text = isDark ? AppColors.textPrimaryDark : const Color(0xFF242424);
    final muted = mutedOf(isDark);
    final call = message.deleted ? null : meetLinkInText(message.content);
    final showText = call == null && (message.deleted || (message.content != null && message.content!.trim().isNotEmpty));
    return Padding(
      padding: EdgeInsets.only(top: grouped ? 2 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: grouped
                  ? const SizedBox(width: 28)
                  : _Avatar(name: message.senderName ?? '?', url: message.senderPhoto, size: 28),
            ),
          Flexible(
            child: Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!mine && !grouped)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        message.senderName ?? '',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
                      ),
                    ),
                  Dismissible(
                    key: ValueKey('reply-${message.id}'),
                    direction: message.deleted
                        ? DismissDirection.none
                        : (mine ? DismissDirection.endToStart : DismissDirection.startToEnd),
                    confirmDismiss: (_) async {
                      onReply(message);
                      return false;
                    },
                    background: Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: NbIcon(Icons.reply_rounded, color: muted),
                      ),
                    ),
                    child: GestureDetector(
                    onLongPress: message.deleted ? null : () => onReactPicker(message),
                    onSecondaryTap: message.deleted ? null : () => onReactPicker(message),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: mine ? ownBg : otherBg,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: Radius.circular(mine ? 12 : 4),
                          bottomRight: Radius.circular(mine ? 4 : 12),
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.replyTo != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: const Border(left: BorderSide(color: _teamsPurple, width: 3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.replyTo!.senderName,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _teamsPurple),
                                    ),
                                    Text(
                                      (message.replyTo!.content ?? '').trim().isEmpty
                                          ? 'Attachment'
                                          : (message.replyTo!.content ?? '').trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: muted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (call != null)
                            _VoiceCallCard(
                              voice: call.voice,
                              ended: meetEnded,
                              onJoin: meetEnded || onJoinMeet == null
                                  ? null
                                  : () => onJoinMeet!(call.code, voice: call.voice),
                            )
                          else if (showText)
                            message.deleted
                                ? Text(
                                    'This message was deleted',
                                    style: TextStyle(color: text, fontStyle: FontStyle.italic, height: 1.35),
                                  )
                                : Text.rich(
                                    TextSpan(
                                      style: TextStyle(color: text, height: 1.35),
                                      children: mentionTextSpans(
                                        text: _breakLongTokens(message.content ?? ''),
                                        members: channel.members,
                                        mentionColor: _teamsPurple,
                                      ),
                                    ),
                                  ),
                          ...message.attachments.map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    NbIcon(
                                      a.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
                                      size: 18,
                                      color: _teamsPurple,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        a.fileName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: _teamsPurple),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'View',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => onViewAttachment(a),
                                      icon: const NbIcon(Icons.visibility_outlined, size: 18, color: _teamsPurple),
                                    ),
                                    IconButton(
                                      tooltip: 'Download',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => onDownloadAttachment(a),
                                      icon: const NbIcon(Icons.download_rounded, size: 18, color: _teamsPurple),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                  ),
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 4,
                      children: [
                        ...message.reactions.map(
                          (r) => InkWell(
                            onTap: () => onReact(message.id, r.emoji),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: r.mine ? const Color(0x335B5FC7) : (isDark ? AppColors.surfaceDark : Colors.white),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: r.mine ? _teamsPurple : (isDark ? AppColors.borderDark : const Color(0xFFE0E0E0)),
                                ),
                              ),
                              child: Text('${r.emoji} ${r.count}', style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  _MessageMeta(
                    message: message,
                    mine: mine,
                    channel: channel,
                    me: me,
                    muted: muted,
                    onShowReceipts: onShowReceipts,
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
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({
    required this.message,
    required this.mine,
    required this.channel,
    required this.me,
    required this.muted,
    required this.onShowReceipts,
  });

  final ChatMessage message;
  final bool mine;
  final ChatChannel channel;
  final String? me;
  final Color muted;
  final void Function(ChatMessage) onShowReceipts;

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt == null ? '' : _clock(message.createdAt!);
    final edited = message.editedAt != null ? ' · Edited' : '';
    final stamp = '$time$edited';
    final selfDm = channel.type != 'GROUP' && channel.members.where((m) => m.userId != me).isEmpty;
    if (!mine || selfDm) {
      if (stamp.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(stamp, style: TextStyle(fontSize: 10.5, color: muted)),
      );
    }
    final receipts = receiptsFor(message, channel);
    final total = receipts.seen.length + receipts.unseen.length;
    if (channel.type == 'GROUP') {
      final label = receipts.seen.isEmpty
          ? '$stamp  Sent'
          : '$stamp  Seen by ${receipts.seen.length} of $total';
      return InkWell(
        onTap: total == 0 ? null : () => onShowReceipts(message),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Text(label, style: TextStyle(fontSize: 10.5, color: muted)),
        ),
      );
    }
    final seen = receipts.seen.isNotEmpty;
    return InkWell(
      onTap: () => onShowReceipts(message),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(stamp, style: TextStyle(fontSize: 10.5, color: muted)),
            const SizedBox(width: 4),
            NbIcon(
              seen ? Icons.done_all : Icons.done,
              size: 14,
              color: seen ? _teamsPurple : muted,
            ),
            const SizedBox(width: 2),
            Text(seen ? 'Seen' : 'Sent', style: TextStyle(fontSize: 10.5, color: seen ? _teamsPurple : muted)),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.isDark});
  final DateTime date;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final label = day == today
        ? 'Today'
        : day == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : '${local.day}/${local.month}/${local.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.textSecondaryDark : const Color(0xFF616161))),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    this.url,
    this.online = false,
    this.isGroup = false,
    this.size = 40,
  });
  final String name;
  final String? url;
  final bool online;
  final bool isGroup;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = url != null && url!.isNotEmpty;
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: size / 2,
            backgroundColor: _teamsPurple,
            backgroundImage: hasPhoto ? NetworkImage(url!) : null,
            child: hasPhoto
                ? null
                : isGroup
                    ? NbIcon(Icons.groups_rounded, color: Colors.white, size: size * 0.5)
                    : Text(letter, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.38)),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: const Color(0xFF13A10E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Color mutedOf(bool isDark) => isDark ? AppColors.textSecondaryDark : const Color(0xFF616161);

({List<CollabProfile> seen, List<CollabProfile> unseen}) receiptsFor(ChatMessage message, ChatChannel channel) {
  final others = channel.members.where((m) => m.userId != message.senderId).toList();
  if (others.isEmpty) {
    return (
      seen: message.seenBy,
      unseen: message.unseenBy,
    );
  }
  final seen = <CollabProfile>[];
  final unseen = <CollabProfile>[];
  for (final person in others) {
    final read = person.lastReadAt;
    final sent = message.createdAt;
    if (read != null && sent != null && !read.isBefore(sent)) {
      seen.add(person);
    } else {
      unseen.add(person);
    }
  }
  return (seen: seen, unseen: unseen);
}

String _clock(DateTime value) {
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

String _absoluteFileUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/')) return '${AppConfig.socketOrigin}$url';
  return url;
}

bool _isBlockedPublicFileUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return true;
  final signed = uri.queryParameters.containsKey('X-Amz-Signature') ||
      uri.queryParameters.containsKey('X-Amz-Algorithm') ||
      uri.queryParameters.containsKey('X-Amz-Credential');
  if (signed) return false;
  return uri.port == 9000 || uri.path.contains('/crm-files/');
}

void showChatEmojiSheet({
  required BuildContext context,
  required void Function(String emoji) onPick,
  String title = 'Emoji',
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.55,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const NbIcon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ChatEmojiGrid(
                  onPick: (emoji) {
                    Navigator.pop(ctx);
                    onPick(emoji);
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class ChatEmojiGrid extends StatefulWidget {
  const ChatEmojiGrid({super.key, required this.onPick, required this.isDark});
  final void Function(String emoji) onPick;
  final bool isDark;

  @override
  State<ChatEmojiGrid> createState() => _ChatEmojiGridState();
}

class _ChatEmojiGridState extends State<ChatEmojiGrid> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim();
    List<ChatEmojiCategory> categories;
    if (q.isEmpty) {
      categories = kChatEmojiCategories;
    } else {
      final matches = kAllChatEmojis.where((e) => e.contains(q)).toList();
      categories = matches.isEmpty ? kChatEmojiCategories : [ChatEmojiCategory('Results', matches)];
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search emoji',
              prefixIcon: const NbIcon(Icons.search_rounded, size: 18),
              isDense: true,
              filled: true,
              fillColor: widget.isDark ? AppColors.backgroundDark : const Color(0xFFF0F0F0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            itemCount: categories.length,
            itemBuilder: (context, i) {
              final cat = categories[i];
              if (cat.emojis.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No matching emoji', style: TextStyle(color: mutedOf(widget.isDark))),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Text(
                      cat.label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: mutedOf(widget.isDark)),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cat.emojis.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemBuilder: (context, j) {
                      final emoji = cat.emojis[j];
                      return InkWell(
                        onTap: () => widget.onPick(emoji),
                        borderRadius: BorderRadius.circular(8),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

String _channelTitle(ChatChannel c, String? me) {
  if (c.type == 'GROUP') return c.name ?? 'Group';
  final other = c.members.where((m) => m.userId != me).firstOrNull;
  if (other == null) return c.name ?? 'Note to self';
  return other.name;
}

String? _channelPhoto(ChatChannel c, String? me) {
  if (c.type == 'GROUP') {
    final url = c.avatarUrl;
    if (url != null && url.isNotEmpty) return _absoluteFileUrl(url);
    return null;
  }
  if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) return _absoluteFileUrl(c.avatarUrl!);
  final other = c.members.where((m) => m.userId != me).firstOrNull;
  final url = other?.photoUrl ?? c.members.where((m) => m.userId == me).firstOrNull?.photoUrl;
  if (url == null || url.isEmpty) return null;
  return _absoluteFileUrl(url);
}

String _chatWhen(DateTime value) {
  final d = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  String two(int n) => n.toString().padLeft(2, '0');
  if (day == today) return '${two(d.hour)}:${two(d.minute)}';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${two(d.day)}/${two(d.month)}';
}

bool _sameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}
