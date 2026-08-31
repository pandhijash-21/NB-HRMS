import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/collab_models.dart';
import '../collab_providers.dart';
import '../meet_helpers.dart';

enum MeetListKind { scheduled, past, org }

class MeetListScreen extends ConsumerStatefulWidget {
  const MeetListScreen({super.key, required this.kind});

  final MeetListKind kind;

  @override
  ConsumerState<MeetListScreen> createState() => _MeetListScreenState();
}

class _MeetListScreenState extends ConsumerState<MeetListScreen> {
  final _search = TextEditingController();
  List<MeetingItem> _items = [];
  bool _loading = true;
  String? _error;

  String get _title => switch (widget.kind) {
        MeetListKind.scheduled => 'Scheduled meetings',
        MeetListKind.past => 'Past meetings',
        MeetListKind.org => 'Organisation meetings',
      };

  String get _hint => switch (widget.kind) {
        MeetListKind.scheduled => 'Search upcoming meetings',
        MeetListKind.past => 'Search ended meetings',
        MeetListKind.org => 'Search all organisation meetings',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(meetRepositoryProvider);
      final admin = Permissions.isAdmin(ref.read(authNotifierProvider).user?.role);
      List<MeetingItem> rows;
      if (widget.kind == MeetListKind.org || (widget.kind == MeetListKind.past && admin)) {
        try {
          rows = await repo.adminAll();
        } catch (_) {
          rows = await repo.mine();
        }
      } else {
        rows = await repo.mine();
      }
      final filtered = rows.where((m) {
        if (widget.kind == MeetListKind.scheduled) {
          return m.status == 'SCHEDULED' || m.status == 'LIVE';
        }
        if (widget.kind == MeetListKind.past) {
          return m.status == 'ENDED' || m.status == 'CANCELLED';
        }
        return true;
      }).toList();
      if (!mounted) return;
      setState(() {
        _items = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<MeetingItem> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((m) {
      return m.title.toLowerCase().contains(q) ||
          m.code.toLowerCase().contains(q) ||
          (m.agenda ?? '').toLowerCase().contains(q) ||
          (m.hostName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/meet'),
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _hint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _visible.isEmpty
                        ? Center(
                            child: Text(
                              _search.text.isEmpty ? 'No meetings yet' : 'No matches',
                              style: TextStyle(color: Theme.of(context).hintColor),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _visible.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _MeetCard(
                              item: _visible[i],
                              kind: widget.kind,
                              onChanged: _load,
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _MeetCard extends ConsumerWidget {
  const _MeetCard({required this.item, required this.kind, required this.onChanged});
  final MeetingItem item;
  final MeetListKind kind;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = item.isHost && item.status == 'SCHEDULED';
    final isAdmin = Permissions.isAdmin(ref.watch(authNotifierProvider).user?.role);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                _StatusChip(status: item.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (kind == MeetListKind.past) ...[
                  if (meetWhen(item.startedAt).isNotEmpty) 'Started ${meetWhen(item.startedAt)}',
                  if (meetWhen(item.endedAt).isNotEmpty) 'Ended ${meetWhen(item.endedAt)}',
                  if (meetDurationLabel(item.startedAt, item.endedAt).isNotEmpty)
                    meetDurationLabel(item.startedAt, item.endedAt),
                ] else if (meetWhen(item.scheduledStart).isNotEmpty)
                  meetWhen(item.scheduledStart),
                if (item.agenda != null && item.agenda!.isNotEmpty) item.agenda,
                if (item.hostName != null) 'Host: ${item.hostName}',
                item.code,
              ].join(' · '),
              style: TextStyle(color: Theme.of(context).hintColor, height: 1.4),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (kind == MeetListKind.past)
                  OutlinedButton.icon(
                    onPressed: () => _showMeetDetails(context, item),
                    icon: const Icon(Icons.info_outline_rounded, size: 16),
                    label: const Text('View details'),
                  ),
                if (item.hasRecording || (item.recordingUrl ?? '').isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/meet/recording/${item.id}'),
                    icon: const Icon(Icons.play_circle_rounded, size: 18),
                    label: const Text('Watch recording'),
                  ),
                if (isAdmin && (item.hasRecording || (item.recordingUrl ?? '').isNotEmpty))
                  OutlinedButton.icon(
                    onPressed: () => _deleteMeetRecording(context, ref, item, onChanged),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete recording'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => copyMeetLink(context, item),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy invite'),
                ),
                if (item.status == 'SCHEDULED' || item.status == 'LIVE')
                  FilledButton(
                    onPressed: () async {
                      await openMeetRoom(context, item.code);
                      onChanged();
                    },
                    child: Text(item.status == 'LIVE' ? 'Join live' : 'Enter'),
                  ),
                if (item.isHost && item.status == 'LIVE')
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('End this meeting?'),
                          content: const Text(
                            'Everyone will be removed and this meeting link cannot be used again.',
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
                      if (ok != true || !context.mounted) return;
                      try {
                        await ref.read(meetRepositoryProvider).end(item.id);
                        await clearMeetSession(item.code);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Meeting ended. Nobody can rejoin this link.')),
                        );
                        onChanged();
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
                    icon: const Icon(Icons.call_end_rounded, size: 16),
                    label: const Text('End meet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                    ),
                  ),
                if (canEdit)
                  TextButton(
                    onPressed: () => context.push('/meet/schedule/${item.id}'),
                    child: const Text('Edit'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _deleteMeetRecording(
  BuildContext context,
  WidgetRef ref,
  MeetingItem item,
  VoidCallback onChanged,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete this recording?'),
      content: Text('“${item.title}” recording will be removed. Attendees will not be able to watch it.'),
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
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(meetRepositoryProvider).deleteRecording(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording deleted')));
    onChanged();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

void _showMeetDetails(BuildContext context, MeetingItem item) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _MeetDetailsDialog(item: item),
  );
}

class _MeetDetailsDialog extends ConsumerStatefulWidget {
  const _MeetDetailsDialog({required this.item});
  final MeetingItem item;

  @override
  ConsumerState<_MeetDetailsDialog> createState() => _MeetDetailsDialogState();
}

class _MeetDetailsDialogState extends ConsumerState<_MeetDetailsDialog> {
  MeetingItem? _full;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final full = await ref.read(meetRepositoryProvider).getById(widget.item.id);
      if (!mounted) return;
      setState(() {
        _full = full;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _full ?? widget.item;
    final muted = Theme.of(context).hintColor;
    return AlertDialog(
      title: Text(m.title),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? Text(_error!)
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Code: ${m.code}', style: const TextStyle(fontFamily: 'monospace')),
                        const SizedBox(height: 8),
                        if ((m.hostName ?? '').isNotEmpty) Text('Host: ${m.hostName}'),
                        if (meetWhen(m.startedAt).isNotEmpty) Text('Started: ${meetWhen(m.startedAt)}'),
                        if (meetWhen(m.endedAt).isNotEmpty) Text('Ended: ${meetWhen(m.endedAt)}'),
                        if (meetDurationLabel(m.startedAt, m.endedAt).isNotEmpty)
                          Text('Duration: ${meetDurationLabel(m.startedAt, m.endedAt)}'),
                        if (meetWhen(m.scheduledStart).isNotEmpty && m.startedAt == null)
                          Text('Scheduled: ${meetWhen(m.scheduledStart)}'),
                        const SizedBox(height: 8),
                        Text('Status: ${m.status}', style: TextStyle(color: muted)),
                        if ((m.agenda ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Agenda', style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
                          Text(m.agenda!.trim()),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          m.participants.isEmpty ? 'Attendees' : 'Attendees (${m.participants.length})',
                          style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        if (m.participants.isEmpty)
                          Text('No attendees were recorded.', style: TextStyle(color: muted))
                        else
                          ...m.participants.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                [
                                  p.name,
                                  if (p.isGuest) 'Guest',
                                  if ((p.email ?? '').isNotEmpty) p.email,
                                  if (meetWhen(p.joinedAt).isNotEmpty) 'in ${meetWhen(p.joinedAt)}',
                                  if (meetWhen(p.leftAt).isNotEmpty) 'out ${meetWhen(p.leftAt)}',
                                ].join(' · '),
                              ),
                            ),
                          ),
                        if ((m.summaryText ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Summary', style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
                          Text(m.summaryText!.trim()),
                        ],
                      ],
                    ),
                  ),
      ),
      actions: [
        if (m.hasRecording || (m.recordingUrl ?? '').isNotEmpty)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/meet/recording/${m.id}');
            },
            child: const Text('Watch recording'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'LIVE' => const Color(0xFF16A34A),
      'SCHEDULED' => Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFC5A059)
          : const Color(0xFF2563EB),
      'CANCELLED' => const Color(0xFFDC2626),
      _ => const Color(0xFF64748B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
