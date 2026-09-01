import 'package:flutter/material.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/utils/open_url.dart';
import '../../../../core/widgets/zoomable_photo.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/collab_models.dart';
import '../collab_providers.dart';
import '../meet_helpers.dart';
import '../recording_player.dart';

class MeetRecordingScreen extends ConsumerStatefulWidget {
  const MeetRecordingScreen({super.key, required this.meetingId});

  final String meetingId;

  @override
  ConsumerState<MeetRecordingScreen> createState() => _MeetRecordingScreenState();
}

class _MeetRecordingScreenState extends ConsumerState<MeetRecordingScreen> {
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  MeetingRecording? _rec;

  bool get _isAdmin {
    final rec = _rec;
    if (rec != null) return rec.canDelete;
    return Permissions.isAdmin(ref.read(authNotifierProvider).user?.role);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(meetRepositoryProvider).recordingPlayback(widget.meetingId);
      if (!mounted) return;
      setState(() {
        _rec = data;
        _loading = false;
        if (!data.ready && data.url.isEmpty) {
          _error = 'This recording is still processing, or it did not save.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this recording?'),
        content: const Text(
          'The video file will be removed. People who attended will no longer be able to watch it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete recording'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(meetRepositoryProvider).deleteRecording(widget.meetingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording deleted')),
      );
      context.go('/meet/past');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rec = _rec;
    final url = rec?.url;
    final ready = rec?.ready == true && (url ?? '').isNotEmpty;
    final title = rec?.title ?? 'Recording';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F8),
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/meet/past'),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (ready)
            IconButton(
              tooltip: 'Copy link',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recording link copied')),
                );
              },
              icon: const NbIcon(Icons.link_rounded),
            ),
          if (ready)
            IconButton(
              tooltip: 'Open in new tab',
              onPressed: () => openExternalUrl(url!),
              icon: const NbIcon(Icons.open_in_new_rounded),
            ),
          if (_isAdmin && rec != null && !_deleting)
            IconButton(
              tooltip: 'Delete recording',
              onPressed: _delete,
              icon: const NbIcon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _PlayerCard(
                  ready: ready,
                  url: url,
                  error: _error,
                  onRetry: _load,
                ),
                if (rec != null) ...[
                  const SizedBox(height: 16),
                  _DetailsCard(rec: rec, isAdmin: _isAdmin, deleting: _deleting, onDelete: _delete),
                ],
              ],
            ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.ready,
    required this.url,
    required this.error,
    required this.onRetry,
  });

  final bool ready;
  final String? url;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF0B0B0B),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ready && url != null
            ? meetingRecordingPlayer(url!)
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const NbIcon(Icons.videocam_off_outlined, color: Colors.white54, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        error ?? 'Recording is not ready yet',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: onRetry,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.rec,
    required this.isAdmin,
    required this.deleting,
    required this.onDelete,
  });

  final MeetingRecording rec;
  final bool isAdmin;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    final started = meetWhen(rec.startedAt);
    final ended = meetWhen(rec.endedAt);
    final duration = meetDurationLabel(rec.startedAt, rec.endedAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rec.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                if (rec.code.isNotEmpty) _MetaChip(icon: Icons.pin_rounded, label: rec.code),
                if (started.isNotEmpty) _MetaChip(icon: Icons.schedule_rounded, label: started),
                if (ended.isNotEmpty) _MetaChip(icon: Icons.flag_rounded, label: 'Ended $ended'),
                if (duration.isNotEmpty) _MetaChip(icon: Icons.timer_outlined, label: duration),
                if ((rec.hostName ?? '').isNotEmpty) _MetaChip(icon: Icons.person_rounded, label: 'Host: ${rec.hostName}'),
              ],
            ),
            if ((rec.agenda ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Agenda', style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              Text(rec.agenda!.trim(), style: const TextStyle(height: 1.4)),
            ],
            const SizedBox(height: 16),
            Text(
              rec.attendees.isEmpty ? 'Attendees' : 'Attendees (${rec.attendees.length})',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (rec.attendees.isEmpty)
              Text('No attendee list was saved for this meeting.', style: TextStyle(color: muted))
            else
              ...rec.attendees.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ZoomablePhoto(
                        url: p.photoUrl,
                        label: p.name,
                        child: CircleAvatar(
                        radius: 16,
                        backgroundImage: (p.photoUrl ?? '').isNotEmpty ? NetworkImage(p.photoUrl!) : null,
                        child: (p.photoUrl ?? '').isEmpty
                            ? Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?')
                            : null,
                      ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              [
                                if (p.isGuest) 'Guest',
                                if ((p.role ?? '').isNotEmpty) p.role,
                                if ((p.email ?? '').isNotEmpty) p.email,
                                if (meetWhen(p.joinedAt).isNotEmpty) 'Joined ${meetWhen(p.joinedAt)}',
                              ].join(' · '),
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if ((rec.summaryText ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('AI summary', style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              Text(rec.summaryText!.trim(), style: const TextStyle(height: 1.45)),
            ],
            if ((rec.conversationText ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Conversation (person & time)',
                style: TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(rec.conversationText!.trim(), style: const TextStyle(height: 1.45)),
            ],
            if (isAdmin) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: deleting ? null : onDelete,
                  icon: deleting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const NbIcon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete recording'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NbIcon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
