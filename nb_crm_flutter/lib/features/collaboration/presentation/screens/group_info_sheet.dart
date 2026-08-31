import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/zoomable_photo.dart';
import '../../domain/collab_models.dart';
import '../../data/collab_socket.dart';
import '../../data/chat_repository.dart';
import '../collab_providers.dart';

const _purple = Color(0xFF5B5FC7);

Future<void> showChatInfoSheet({
  required BuildContext context,
  required ChatChannel channel,
  required String? me,
  required ValueChanged<ChatChannel> onUpdated,
  required VoidCallback onLeft,
  required Future<void> Function(String userId) onMessageMember,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.92,
      child: channel.isGroup
          ? _GroupInfoSheet(
              channel: channel,
              me: me,
              onUpdated: onUpdated,
              onLeft: onLeft,
              onMessageMember: onMessageMember,
            )
          : _DmInfoSheet(channel: channel, me: me),
    ),
  );
}

String _abs(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/')) return '${AppConfig.socketOrigin}$url';
  return url;
}

bool _canAdmin(ChatChannel ch, String? me) {
  final mine = ch.members.where((m) => m.userId == me).firstOrNull;
  return mine?.role == 'owner' || mine?.role == 'admin';
}

bool _isOwner(ChatChannel ch, String? me) {
  return ch.members.where((m) => m.userId == me).firstOrNull?.role == 'owner';
}

String _roleLabel(String? role) {
  switch (role) {
    case 'owner':
      return 'Owner';
    case 'admin':
      return 'Admin';
    default:
      return 'Member';
  }
}

class _GroupInfoSheet extends ConsumerStatefulWidget {
  const _GroupInfoSheet({
    required this.channel,
    required this.me,
    required this.onUpdated,
    required this.onLeft,
    required this.onMessageMember,
  });

  final ChatChannel channel;
  final String? me;
  final ValueChanged<ChatChannel> onUpdated;
  final VoidCallback onLeft;
  final Future<void> Function(String userId) onMessageMember;

  @override
  ConsumerState<_GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends ConsumerState<_GroupInfoSheet> {
  late ChatChannel _channel;
  bool _busy = false;
  CollabSocket? _socket;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final socket = ref.read(collabSocketProvider);
      _socket = socket;
      socket.onPresence(_onPresence);
    });
    _reload();
  }

  @override
  void dispose() {
    _socket?.offPresence(_onPresence);
    super.dispose();
  }

  void _onPresence(String userId, bool online) {
    if (!mounted || userId.isEmpty) return;
    setState(() {
      _channel = _channel.copyWith(
        members: [
          for (final m in _channel.members)
            if (m.userId == userId) m.copyWith(online: online) else m,
        ],
      );
    });
  }

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  Future<void> _reload() async {
    try {
      final fresh = await _repo.getChannel(_channel.id);
      if (!mounted) return;
      setState(() => _channel = fresh);
      widget.onUpdated(fresh);
    } catch (_) {
      /* keep local copy */
    }
  }

  Future<void> _apply(Future<ChatChannel> job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await job;
      if (!mounted) return;
      setState(() {
        _channel = next;
        _busy = false;
      });
      widget.onUpdated(next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _channel.name ?? '');
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Group name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (next == null || next.length < 2 || next == _channel.name) return;
    await _apply(_repo.updateGroup(_channel.id, name: next));
  }

  Future<void> _editTopic() async {
    final ctrl = TextEditingController(text: _channel.topic ?? '');
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Group description'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'What is this group for?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (next == null) return;
    await _apply(_repo.updateGroup(_channel.id, topic: next));
  }

  Future<void> _changePhoto() async {
    final pick = await FilePicker.pickFiles(withData: true, type: FileType.image);
    if (pick == null || pick.files.isEmpty || pick.files.first.bytes == null) return;
    final file = pick.files.first;
    setState(() => _busy = true);
    try {
      final uploaded = await _repo.upload(file.bytes!, file.name);
      final url = uploaded['fileUrl']?.toString() ?? '';
      if (url.isEmpty) throw Exception('Upload failed');
      final next = await _repo.updateGroup(_channel.id, avatarUrl: url);
      if (!mounted) return;
      setState(() {
        _channel = next;
        _busy = false;
      });
      widget.onUpdated(next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _removePhoto() async {
    await _apply(_repo.updateGroup(_channel.id, clearAvatar: true));
  }

  Future<void> _addPeople() async {
    var people = await _repo.directory('');
    if (!mounted) return;
    final existing = _channel.members.map((m) => m.userId).toSet();
    final selected = <String>{};
    final search = TextEditingController();
    final added = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> searchPeople(String q) async {
              people = await _repo.directory(q);
              if (ctx.mounted) setLocal(() {});
            }

            final visible = people.where((p) => !existing.contains(p.userId)).toList();
            return AlertDialog(
              title: const Text('Add people'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: search,
                      onChanged: searchPeople,
                      decoration: const InputDecoration(
                        hintText: 'Search people',
                        prefixIcon: NbIcon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final p in visible)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: NbProfilePhoto(
                                url: p.photoUrl != null && p.photoUrl!.isNotEmpty ? _abs(p.photoUrl!) : null,
                                name: p.name,
                                identity: p.userId,
                                radius: 20,
                              ),
                              title: Text(p.name),
                              subtitle: p.department != null ? Text(p.department!) : null,
                              trailing: Checkbox(
                                value: selected.contains(p.userId),
                                onChanged: (v) => setLocal(() {
                                  if (v == true) {
                                    selected.add(p.userId);
                                  } else {
                                    selected.remove(p.userId);
                                  }
                                }),
                              ),
                              onTap: () => setLocal(() {
                                if (selected.contains(p.userId)) {
                                  selected.remove(p.userId);
                                } else {
                                  selected.add(p.userId);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, selected.toList()),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    search.dispose();
    if (added == null || added.isEmpty) return;
    await _apply(_repo.updateGroup(_channel.id, addMemberIds: added));
  }

  Future<void> _removeMember(CollabProfile person) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${person.name}?'),
        content: Text('${person.name} will no longer see this group chat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await _apply(_repo.updateGroup(_channel.id, removeMemberIds: [person.userId]));
  }

  Future<void> _setRole(CollabProfile person, String role) async {
    await _apply(_repo.setMemberRole(_channel.id, person.userId, role));
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text('You will stop receiving messages from this group.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.leaveGroup(_channel.id);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onLeft();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final admin = _canAdmin(_channel, widget.me);
    final owner = _isOwner(_channel, widget.me);
    final photo = _channel.avatarUrl;
    final members = [..._channel.members]..sort((a, b) {
        int rank(String? r) => r == 'owner' ? 0 : r == 'admin' ? 1 : 2;
        final d = rank(a.role) - rank(b.role);
        if (d != 0) return d;
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Group info'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Stack(
              children: [
                _GroupAvatar(name: _channel.name ?? 'Group', url: photo, size: 96),
                if (admin)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: _purple,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _changePhoto,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: NbIcon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _channel.name ?? 'Group',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            _channel.presenceSubtitle(widget.me),
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? AppColors.textSecondaryDark : const Color(0xFF616161)),
          ),
          if (_channel.anyOtherOnline(widget.me) && _channel.members.length > 1)
            Text(
              '${_channel.members.length} members',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF616161),
              ),
            ),
          if ((_channel.topic ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _channel.topic!,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? AppColors.textSecondaryDark : const Color(0xFF616161)),
            ),
          ],
          const SizedBox(height: 16),
          if (admin) ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionChip(icon: Icons.edit_outlined, label: 'Edit name', onTap: _editName),
                _ActionChip(icon: Icons.notes_outlined, label: 'Description', onTap: _editTopic),
                _ActionChip(icon: Icons.photo_outlined, label: 'Photo', onTap: _changePhoto),
                if (photo != null && photo.isNotEmpty)
                  _ActionChip(icon: Icons.hide_image_outlined, label: 'Remove photo', onTap: _removePhoto),
                _ActionChip(icon: Icons.person_add_outlined, label: 'Add people', onTap: _addPeople),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text('Members', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _MemberTile(
                    person: members[i],
                    me: widget.me,
                    canManage: admin && members[i].role != 'owner' && members[i].userId != widget.me,
                    canChangeRole: owner && members[i].userId != widget.me && members[i].role != 'owner',
                    onMessage: members[i].userId == widget.me
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await widget.onMessageMember(members[i].userId);
                          },
                    onRemove: () => _removeMember(members[i]),
                    onMakeAdmin: () => _setRole(members[i], 'admin'),
                    onMakeMember: () => _setRole(members[i], 'member'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _leave,
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            icon: const NbIcon(Icons.logout_rounded),
            label: const Text('Leave group'),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? theme.colorScheme.onSurface : _purple;
    return ActionChip(
      avatar: NbIcon(icon, size: 16, color: fg),
      label: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
      backgroundColor: isDark
          ? const Color(0xFF333333)
          : _purple.withValues(alpha: 0.12),
      side: BorderSide(
        color: isDark ? theme.colorScheme.outlineVariant : _purple.withValues(alpha: 0.28),
      ),
      onPressed: onTap,
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.person,
    required this.me,
    required this.canManage,
    required this.canChangeRole,
    required this.onMessage,
    required this.onRemove,
    required this.onMakeAdmin,
    required this.onMakeMember,
  });

  final CollabProfile person;
  final String? me;
  final bool canManage;
  final bool canChangeRole;
  final VoidCallback? onMessage;
  final VoidCallback onRemove;
  final VoidCallback onMakeAdmin;
  final VoidCallback onMakeMember;

  @override
  Widget build(BuildContext context) {
    final mine = person.userId == me;
    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            NbProfilePhoto(
              url: person.photoUrl != null && person.photoUrl!.isNotEmpty ? _abs(person.photoUrl!) : null,
              name: person.name,
              identity: person.userId,
              radius: 20,
              backgroundColor: _purple,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: person.online ? const Color(0xFF13A10E) : const Color(0xFF9CA3AF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
      title: Text(mine ? '${person.name} (You)' : person.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        [
          _roleLabel(person.role),
          if (person.department != null && person.department!.isNotEmpty) person.department,
          person.online ? 'Available' : 'Away',
        ].join(' · '),
      ),
      trailing: mine && !canManage
          ? null
          : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'message') onMessage?.call();
                if (value == 'admin') onMakeAdmin();
                if (value == 'member') onMakeMember();
                if (value == 'remove') onRemove();
              },
              itemBuilder: (ctx) => [
                if (onMessage != null) const PopupMenuItem(value: 'message', child: Text('Message')),
                if (canChangeRole && person.role != 'admin')
                  const PopupMenuItem(value: 'admin', child: Text('Make admin')),
                if (canChangeRole && person.role == 'admin')
                  const PopupMenuItem(value: 'member', child: Text('Dismiss as admin')),
                if (canManage) const PopupMenuItem(value: 'remove', child: Text('Remove from group')),
              ],
            ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.name, this.url, this.size = 40});
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = url != null && url!.isNotEmpty ? _abs(url!) : null;
    return NbProfilePhoto(
      url: resolved,
      name: name,
      identity: 'group-$name',
      radius: size / 2,
      backgroundColor: _purple,
      fallback: NbIcon(Icons.groups_rounded, color: Colors.white, size: size * 0.48),
    );
  }
}

class _DmInfoSheet extends StatelessWidget {
  const _DmInfoSheet({required this.channel, required this.me});
  final ChatChannel channel;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final other = channel.members.where((m) => m.userId != me).firstOrNull;
    final self = other == null;
    final name = self ? 'Note to self' : (other.name);
    final photo = self
        ? channel.members.where((m) => m.userId == me).firstOrNull?.photoUrl
        : other.photoUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('Chat info')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Center(
            child: NbProfilePhoto(
              url: photo != null && photo.isNotEmpty ? _abs(photo) : null,
              name: name,
              identity: self ? me : other.userId,
              radius: 48,
              backgroundColor: _purple,
            ),
          ),
          const SizedBox(height: 12),
          Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (!self && other.email != null) ...[
            const SizedBox(height: 4),
            Text(other.email!, textAlign: TextAlign.center),
          ],
          if (!self && other.department != null) ...[
            const SizedBox(height: 4),
            Text(other.department!, textAlign: TextAlign.center),
          ],
          if (!self) ...[
            const SizedBox(height: 8),
            Text(
              other.online ? 'Available' : 'Away',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _purple, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
