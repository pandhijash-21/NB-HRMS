import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/collab_models.dart';
import '../collab_providers.dart';
import '../end_meet_progress.dart';
import '../meet_helpers.dart';

class MeetHubScreen extends ConsumerStatefulWidget {
  const MeetHubScreen({super.key});

  @override
  ConsumerState<MeetHubScreen> createState() => _MeetHubScreenState();
}

class _MeetHubScreenState extends ConsumerState<MeetHubScreen> {
  List<MeetingItem> _live = [];
  bool _loading = true;
  bool _starting = false;
  bool _ending = false;
  bool _waitingRoom = true;
  bool _canAdmin = false;
  final _title = TextEditingController(text: 'Team meeting');
  final _agenda = TextEditingController();
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _agenda.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = ref.read(authNotifierProvider);
    final canAdmin = Permissions.isAdmin(auth.user?.role) ||
        Permissions.canAccessAdminPortal(auth.permissions, auth.user?.employeeViewScope);
    try {
      final mine = await ref.read(meetRepositoryProvider).mine();
      if (!mounted) return;
      setState(() {
        _live = mine.where((m) => m.status == 'LIVE').toList();
        _canAdmin = canAdmin;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canAdmin = canAdmin;
        _loading = false;
      });
    }
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final meeting = await ref.read(meetRepositoryProvider).create(
            title: _title.text.trim().isEmpty ? 'Meeting' : _title.text.trim(),
            agenda: _agenda.text.trim().isEmpty ? null : _agenda.text.trim(),
            instant: true,
            waitingRoom: _waitingRoom,
          );
      if (!mounted) return;
      context.push('/meet/r/${meeting.code}').then((_) {
        if (mounted) _load();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _joinCode() {
    final code = _code.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a meeting code')));
      return;
    }
    context.push('/meet/r/$code').then((_) {
      if (mounted) _load();
    });
  }

  Future<void> _endMeeting(MeetingItem meeting) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this meeting?'),
        content: Text(
          '“${meeting.title}” will close for everyone. This link cannot be used to rejoin.',
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
    if (ok != true || !mounted) return;
    setState(() => _ending = true);
    try {
      final token = await ref.read(secureStorageProvider).readToken();
      if (token != null) ref.read(collabSocketProvider).connect(token: token);
      await showEndMeetProgress(
        context: context,
        meetingId: meeting.id,
        socket: ref.read(collabSocketProvider),
        repo: ref.read(meetRepositoryProvider),
        hasRecording: meeting.recordEnabled || meeting.hasRecording,
      );
      await clearMeetSession(meeting.code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting ended. Nobody can rejoin this link.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF212F3D);
    final muted = isDark ? Colors.white60 : const Color(0xFF607D8B);
    final wide = MediaQuery.sizeOf(context).width >= 880;
    final startCard = _HubCard(
      color: card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Start instant meeting', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: text)),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title_rounded)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _agenda,
            decoration: const InputDecoration(labelText: 'Agenda (optional)', prefixIcon: Icon(Icons.notes_rounded)),
          ),
          const SizedBox(height: 12),
          _AccessChoice(waitingRoom: _waitingRoom, onChanged: (v) => setState(() => _waitingRoom = v)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _starting ? null : _start,
            icon: _starting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.videocam_rounded),
            label: const Text('Start now'),
          ),
        ],
      ),
    );
    final joinCard = _HubCard(
      color: card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Join a meeting', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: text)),
          const SizedBox(height: 6),
          Text('Enter the code someone shared with you.', style: TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              labelText: 'Meeting code',
              hintText: 'abc-defg-hij',
              prefixIcon: Icon(Icons.pin_rounded),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _joinCode,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Join'),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        title: Text('Meet', style: TextStyle(fontWeight: FontWeight.w700, color: text, letterSpacing: -0.4)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF6F5428), Color(0xFFA37F3E), Color(0xFFC5A059)]
                          : const [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF0EA5E9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? AppColors.bronze : const Color(0xFF2563EB)).withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.videocam_rounded, color: Colors.white, size: 32),
                      SizedBox(height: 12),
                      Text('Meet with your team', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text(
                        'Start now, join with a code, or schedule and invite people across the organisation.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: startCard),
                      const SizedBox(width: 16),
                      Expanded(child: joinCard),
                    ],
                  )
                else ...[
                  startCard,
                  const SizedBox(height: 16),
                  joinCard,
                ],
                if (_live.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Live now', style: TextStyle(fontWeight: FontWeight.w800, color: text)),
                  const SizedBox(height: 8),
                  ..._live.map(
                    (m) => Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFFDCFCE7),
                                    child: Icon(Icons.circle, color: Color(0xFF16A34A), size: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        Text(m.code, style: const TextStyle(fontFamily: 'monospace')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                const Spacer(),
                                if (m.isHost) ...[
                                  OutlinedButton.icon(
                                    onPressed: _ending ? null : () => _endMeeting(m),
                                    icon: _ending
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.call_end_rounded, size: 18),
                                    label: const Text('End meet'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFDC2626),
                                      side: const BorderSide(color: Color(0xFFDC2626)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                FilledButton(
                                  onPressed: () => context.push('/meet/r/${m.code}').then((_) {
                                    if (mounted) _load();
                                  }),
                                  child: const Text('Join'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Text('Manage meetings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: text)),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: wide ? 3 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: wide ? 1.15 : 0.88,
                  children: [
                    _ActionTile(
                      icon: Icons.event_available_rounded,
                      color: isDark ? AppColors.bronze : const Color(0xFF2563EB),
                      title: 'Schedule a meet',
                      subtitle: 'Pick time & invite people',
                      onTap: () => context.push('/meet/schedule'),
                    ),
                    _ActionTile(
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFF0F766E),
                      title: 'View scheduled',
                      subtitle: 'Upcoming invites',
                      onTap: () => context.push('/meet/scheduled'),
                    ),
                    _ActionTile(
                      icon: Icons.history_rounded,
                      color: const Color(0xFF7C3AED),
                      title: 'View past meets',
                      subtitle: 'Search ended rooms',
                      onTap: () => context.push('/meet/past'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _AccessChoice extends StatelessWidget {
  const _AccessChoice({required this.waitingRoom, required this.onChanged});
  final bool waitingRoom;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tile({required bool value, required String title, required String subtitle}) {
      final selected = waitingRoom == value;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? const Color(0xFF1D4ED8) : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        tile(
          value: false,
          title: 'Direct entry',
          subtitle: 'Anyone with the link joins immediately',
        ),
        tile(
          value: true,
          title: 'Ask to join',
          subtitle: 'You admit each person, like Google Meet',
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E1B18) : Colors.white;
    return Material(
      color: surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.18)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [color.withValues(alpha: 0.16), surface]
                  : [color.withValues(alpha: 0.10), Colors.white],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.22 : 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Open',
                      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

