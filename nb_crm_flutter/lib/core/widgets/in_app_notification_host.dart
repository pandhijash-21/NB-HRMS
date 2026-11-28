import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/collaboration/presentation/app_notifications.dart';
import '../router/app_navigation_service.dart';
import '../theme/nb_icon.dart';

/// Top-level in-app notification heads-up card.
/// Automatically appears with smooth animation when any push/in-app notification arrives,
/// and redirects to the target page when tapped.
class InAppNotificationHost extends ConsumerStatefulWidget {
  const InAppNotificationHost({super.key});

  @override
  ConsumerState<InAppNotificationHost> createState() =>
      _InAppNotificationHostState();
}

class _InAppNotificationHostState extends ConsumerState<InAppNotificationHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  AppNotice? _displayedNotice;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onNoticeArrived(AppNotice notice) {
    setState(() {
      _displayedNotice = notice;
    });
    _animCtrl.forward(from: 0.0);
  }

  void _dismiss() {
    _animCtrl.reverse().then((_) {
      if (mounted) {
        setState(() {
          _displayedNotice = null;
        });
        ref.read(appNotificationsProvider.notifier).dismissBanner();
      }
    });
  }

  void _onTap(AppNotice notice) {
    _dismiss();
    ref.read(appNotificationsProvider.notifier).markRead(notice.id);

    final path = notice.path?.trim();
    if (path != null && path.isNotEmpty) {
      AppNavigationService.navigateTo(path);
    } else {
      AppNavigationService.navigateTo('/notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppNotice?>(
      appNotificationsProvider.select((s) => s.bannerNotice),
      (prev, next) {
        if (next != null && next.id != prev?.id) {
          _onNoticeArrived(next);
        } else if (next == null && _displayedNotice != null) {
          _dismiss();
        }
      },
    );

    final notice = _displayedNotice;
    if (notice == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = _NotificationKindMeta.resolve(notice.kind);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Dismissible(
                  key: ValueKey(notice.id),
                  direction: DismissDirection.up,
                  onDismissed: (_) => _dismiss(),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 500),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161B26) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: meta.color.withValues(alpha: isDark ? 0.35 : 0.28),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: meta.color.withValues(alpha: isDark ? 0.12 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => _onTap(notice),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row: Category Pill + Just Now + Close Button
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: meta.color.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: meta.color.withValues(alpha: 0.25),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        NbIcon(
                                          meta.icon,
                                          size: 13,
                                          color: meta.color,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          meta.label,
                                          style: TextStyle(
                                            color: meta.color,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Just now',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.4)
                                          : const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Tooltip(
                                    message: 'Dismiss',
                                    child: InkWell(
                                      onTap: _dismiss,
                                      borderRadius: BorderRadius.circular(99),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 17,
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.5)
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Content row: Leading Icon Avatar + Title/Body + Arrow
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: meta.color.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: NbIcon(
                                      meta.icon,
                                      size: 20,
                                      color: meta.color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notice.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (notice.body.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            notice.body,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.35,
                                              color: isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.75)
                                                  : const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.06)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Open',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: meta.color,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 12,
                                          color: meta.color,
                                        ),
                                      ],
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationKindMeta {
  const _NotificationKindMeta({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  static _NotificationKindMeta resolve(String? kind) {
    final k = (kind ?? '').toLowerCase();
    if (k.contains('support')) {
      return const _NotificationKindMeta(
        label: 'IT SUPPORT',
        icon: Icons.confirmation_number_rounded,
        color: Color(0xFF2563EB), // Vibrant Royal Blue
      );
    }
    if (k.contains('announce')) {
      return const _NotificationKindMeta(
        label: 'ANNOUNCEMENT',
        icon: Icons.campaign_rounded,
        color: Color(0xFFD97706), // Amber
      );
    }
    if (k.contains('task')) {
      return const _NotificationKindMeta(
        label: 'TASK',
        icon: Icons.assignment_turned_in_rounded,
        color: Color(0xFF8B5CF6), // Purple
      );
    }
    if (k.contains('leave')) {
      return const _NotificationKindMeta(
        label: 'LEAVE',
        icon: Icons.event_note_rounded,
        color: Color(0xFF059669), // Emerald
      );
    }
    if (k.contains('profile')) {
      return const _NotificationKindMeta(
        label: 'PROFILE',
        icon: Icons.badge_rounded,
        color: Color(0xFFDB2777), // Pink
      );
    }
    if (k.contains('chat')) {
      return const _NotificationKindMeta(
        label: 'CHAT',
        icon: Icons.forum_rounded,
        color: Color(0xFF4F46E5), // Indigo
      );
    }
    if (k.contains('meet')) {
      return const _NotificationKindMeta(
        label: 'MEETING',
        icon: Icons.videocam_rounded,
        color: Color(0xFF10B981), // Green
      );
    }
    if (k.contains('crm') || k.contains('erp')) {
      return const _NotificationKindMeta(
        label: 'BUSINESS',
        icon: Icons.business_center_rounded,
        color: Color(0xFF0284C7), // Sky Blue
      );
    }
    return const _NotificationKindMeta(
      label: 'NOTIFICATION',
      icon: Icons.notifications_active_rounded,
      color: Color(0xFFC5A36A), // NB Luxury Gold
    );
  }
}
