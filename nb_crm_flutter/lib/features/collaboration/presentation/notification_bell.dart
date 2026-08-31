import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/nb_icon.dart';
import 'meet_helpers.dart';
import 'app_notifications.dart';

enum NotificationBellVariant { icon, sidebar }

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({
    super.key,
    this.compact = false,
    this.variant = NotificationBellVariant.icon,
    this.expanded = false,
  });

  final bool compact;
  final NotificationBellVariant variant;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appNotificationsProvider);
    final unread = state.unread;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : const Color(0xFF263238);
    final bell = NbIcon(
      unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
      color: iconColor,
      size: variant == NotificationBellVariant.sidebar ? 20 : 24,
    );
    final badge = Badge(
      isLabelVisible: unread > 0,
      backgroundColor: const Color(0xFFEF4444),
      label: Text(
        unread > 9 ? '9+' : '$unread',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
      child: bell,
    );

    if (variant != NotificationBellVariant.sidebar) {
      return IconButton(
        tooltip: 'Notifications',
        visualDensity: compact ? VisualDensity.compact : null,
        onPressed: () => _openSheet(context, ref),
        icon: badge,
      );
    }

    final circle = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.16) : Colors.white,
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withValues(alpha: 0.38)
              : const Color(0xFFCCD6DD),
        ),
      ),
      alignment: Alignment.center,
      child: badge,
    );

    if (!expanded) {
      return Center(
        child: Tooltip(
          message: 'Notifications',
          child: InkWell(
            onTap: () => _openSheet(context, ref),
            customBorder: const CircleBorder(),
            child: circle,
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Notifications',
      child: InkWell(
        onTap: () => _openSheet(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 8),
              circle,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Notifications',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF263238),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    await ref.read(appNotificationsProvider.notifier).markAllRead();
    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref, _) {
            final items = ref.watch(appNotificationsProvider).items;
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.62,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
                      child: Row(
                        children: [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: items.isEmpty
                                ? null
                                : () => ref.read(appNotificationsProvider.notifier).clearAll(),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text(
                                'No notifications yet',
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                              ),
                            )
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                              ),
                              itemBuilder: (context, i) {
                                final n = items[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _kindColor(n.kind).withValues(alpha: 0.18),
                                    child: NbIcon(_kindIcon(n.kind), color: _kindColor(n.kind), size: 20),
                                  ),
                                  title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    n.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    _ago(n.at),
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _openNotice(context, n);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openNotice(BuildContext context, AppNotice n) {
    final code = sanitizeMeetCode(n.code ?? meetLinkInText(n.path ?? n.body)?.code);
    if (code.isNotEmpty) {
      openMeetRoom(context, code, voice: n.kind == 'voice_call', auto: true);
      return;
    }
    final path = n.path;
    if (path != null && path.isNotEmpty && context.mounted) {
      context.go(path.startsWith('/') ? path : '/$path');
    }
  }
}

class IncomingCallHost extends ConsumerWidget {
  const IncomingCallHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appNotificationsProvider.select((s) => s.incoming?.code));
    final call = ref.watch(appNotificationsProvider).incoming;
    if (call == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(18),
            color: isDark ? const Color(0xFF1E1B18) : Colors.white,
            child: Container(
              width: 440,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF5B5FC7).withValues(alpha: 0.45)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF5B5FC7).withValues(alpha: 0.18),
                        child: NbIcon(
                          call.voice ? Icons.call_rounded : Icons.videocam_rounded,
                          color: const Color(0xFF5B5FC7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              call.voice ? 'Incoming voice call' : 'Incoming meeting',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              call.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => ref.read(appNotificationsProvider.notifier).dismissCall(),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                          onPressed: () => ref.read(appNotificationsProvider.notifier).acceptCall(context),
                          child: const Text('Join'),
                        ),
                      ),
                    ],
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

IconData _kindIcon(String kind) {
  switch (kind) {
    case 'voice_call':
      return Icons.call_rounded;
    case 'meet_call':
    case 'meet':
      return Icons.videocam_rounded;
    case 'mention':
      return Icons.alternate_email_rounded;
    default:
      return Icons.chat_rounded;
  }
}

Color _kindColor(String kind) {
  switch (kind) {
    case 'voice_call':
      return const Color(0xFF16A34A);
    case 'meet_call':
    case 'meet':
      return const Color(0xFF5B5FC7);
    case 'mention':
      return const Color(0xFFC5A059);
    default:
      return const Color(0xFF2563EB);
  }
}

String _ago(DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  return '${d.inDays}d';
}
