import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/domain/permissions.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../collaboration/presentation/app_notifications.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late final NotificationsRepository _repo;
  List<AppUserNotification> _items = const [];
  bool _loading = true;
  String? _error;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final dio = context.read<DioClient>();
    _repo = NotificationsRepository(dioClient: dio);
    unawaited(_load());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.list();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
      // Keep bell panel in sync with server announcements.
      ref.read(appNotificationsProvider.notifier).mergeServerNotifications([
        for (final n in list)
          AppNotice(
            id: n.id,
            kind: n.kind,
            title: n.title,
            body: n.body,
            at: n.createdAt,
            path: n.path,
            read: n.isRead,
          ),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _repo.markAllRead();
      await ref.read(appNotificationsProvider.notifier).markAllRead();
      await _load();
    } catch (_) {}
  }

  Future<void> _sendBroadcast() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.length < 2 || body.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title and message')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final result = await _repo.broadcast(title: title, body: body);
      if (!mounted) return;
      _titleCtrl.clear();
      _bodyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent to ${result.sent} employees')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _canBroadcast(AuthState auth) {
    final role = auth.user?.role;
    return Permissions.isAdmin(role) ||
        (auth.user?.companyAdminGranted == true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final canSend = _canBroadcast(auth);
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            onPressed: _items.isEmpty ? null : _markAllRead,
            icon: const Icon(Icons.done_all),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 16 : 24,
            vertical: 16,
          ),
          children: [
            if (canSend) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Notify all employees',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sends to everyone in your company. Appears in their notification panel and this screen.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bodyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _sending ? null : _sendBroadcast,
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.campaign_outlined),
                        label: Text(_sending ? 'Sending…' : 'Send to all employees'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Inbox',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              )
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('No notifications yet')),
              )
            else
              ..._items.map((n) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: n.isRead
                          ? theme.colorScheme.surfaceContainerHighest
                          : const Color(0xFFC5A36A).withValues(alpha: 0.25),
                      child: Icon(
                        n.kind == 'announce'
                            ? Icons.campaign_outlined
                            : Icons.notifications_outlined,
                        color: n.isRead
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : const Color(0xFFC5A36A),
                      ),
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(n.body),
                        const SizedBox(height: 6),
                        Text(
                          _fmt(n.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      if (!n.isRead) {
                        try {
                          await _repo.markRead(n.id);
                        } catch (_) {}
                      }
                      if (!mounted) return;
                      final path = n.path?.trim();
                      if (path != null &&
                          path.isNotEmpty &&
                          path != '/notifications') {
                        context.go(path);
                      } else {
                        await _load();
                      }
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime at) {
    final local = at.toLocal();
    final d =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final t =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$d · $t';
  }
}
