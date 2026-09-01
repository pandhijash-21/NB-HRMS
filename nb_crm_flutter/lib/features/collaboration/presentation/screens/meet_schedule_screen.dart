import 'package:flutter/material.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/zoomable_photo.dart';
import '../../domain/collab_models.dart';
import '../collab_providers.dart';
import '../meet_helpers.dart';
import 'meet_invite_people_screen.dart';

class MeetScheduleScreen extends ConsumerStatefulWidget {
  const MeetScheduleScreen({super.key, this.meetingId});

  final String? meetingId;

  @override
  ConsumerState<MeetScheduleScreen> createState() => _MeetScheduleScreenState();
}

class _MeetScheduleScreenState extends ConsumerState<MeetScheduleScreen> {
  final _title = TextEditingController(text: 'Team meeting');
  final _agenda = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _waitingRoom = false;
  bool _recordEnabled = false;
  bool _loading = false;
  bool _saving = false;
  List<CollabProfile> _selectedPeople = [];
  final Set<String> _inviteeIds = {};

  bool get _editing => widget.meetingId != null && widget.meetingId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _title.dispose();
    _agenda.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      MeetingItem? existing;
      if (_editing) {
        existing = await ref.read(meetRepositoryProvider).getById(widget.meetingId!);
      }
      if (!mounted) return;
      setState(() {
        if (existing != null) {
          _title.text = existing.title;
          _agenda.text = existing.agenda ?? '';
          _start = existing.scheduledStart?.toLocal();
          _end = existing.scheduledEnd?.toLocal();
          _waitingRoom = existing.waitingRoom;
          _recordEnabled = existing.recordEnabled;
          final invited = existing.participants.where((p) => p.userId != null && p.role != 'HOST').toList();
          _inviteeIds
            ..clear()
            ..addAll(invited.map((p) => p.userId!));
          _selectedPeople = invited
              .map(
                (p) => CollabProfile(
                  userId: p.userId!,
                  name: p.name,
                  photoUrl: p.photoUrl,
                  role: p.role,
                ),
              )
              .toList();
        } else {
          _start = DateTime.now().add(const Duration(minutes: 30));
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openPeoplePicker() async {
    final result = await context.push<MeetInviteResult>(
      '/meet/invite-people',
      extra: MeetInviteResult(
        ids: Set<String>.from(_inviteeIds),
        people: List<CollabProfile>.from(_selectedPeople),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _inviteeIds
        ..clear()
        ..addAll(result.ids);
      _selectedPeople = result.people;
    });
  }

  Future<void> _pickDateTime({required bool end}) async {
    final initial = (end ? _end : _start) ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (end) {
        _end = value;
      } else {
        _start = value;
      }
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a title')));
      return;
    }
    if (_start == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a start time')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(meetRepositoryProvider);
      if (_editing) {
        await repo.update(
          widget.meetingId!,
          title: title,
          agenda: _agenda.text.trim(),
          scheduledStart: _start!.toUtc().toIso8601String(),
          scheduledEnd: _end?.toUtc().toIso8601String(),
          waitingRoom: _waitingRoom,
          recordEnabled: _recordEnabled,
          inviteeIds: _inviteeIds.toList(),
        );
      } else {
        await repo.create(
          title: title,
          agenda: _agenda.text.trim().isEmpty ? null : _agenda.text.trim(),
          scheduledStart: _start!.toUtc().toIso8601String(),
          scheduledEnd: _end?.toUtc().toIso8601String(),
          instant: false,
          waitingRoom: _waitingRoom,
          recordEnabled: _recordEnabled,
          inviteeIds: _inviteeIds.toList(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? 'Meeting updated' : 'Meeting scheduled. Invitees will be notified.')),
      );
      context.go('/meet/scheduled');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/meet'),
        title: Text(_editing ? 'Edit meeting' : 'Schedule a meeting', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title', prefixIcon: NbIcon(Icons.title_rounded)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _agenda,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Agenda', prefixIcon: NbIcon(Icons.notes_rounded)),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const NbIcon(Icons.schedule_rounded),
                  title: const Text('Starts'),
                  subtitle: Text(_start == null ? 'Pick date & time' : meetWhen(_start)),
                  trailing: TextButton(onPressed: () => _pickDateTime(end: false), child: const Text('Choose')),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const NbIcon(Icons.event_rounded),
                  title: const Text('Ends (optional)'),
                  subtitle: Text(_end == null ? 'Not set' : meetWhen(_end)),
                  trailing: TextButton(onPressed: () => _pickDateTime(end: true), child: const Text('Choose')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ask to join'),
                  subtitle: const Text('Host admits everyone before they enter, including guests and invited people.'),
                  value: _waitingRoom,
                  onChanged: (v) => setState(() => _waitingRoom = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Host recording'),
                  subtitle: const Text('The host can record on their device. The file stays on the host phone or computer.'),
                  value: _recordEnabled,
                  onChanged: (v) => setState(() => _recordEnabled = v),
                ),
                const SizedBox(height: 8),
                Text('Invite people', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Invited people are notified. Anyone with the code can still join.',
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Material(
                  color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _openPeoplePicker,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: (isDark ? AppColors.bronze : Theme.of(context).colorScheme.primary)
                                .withValues(alpha: 0.18),
                            child: NbIcon(
                              Icons.group_add_rounded,
                              color: isDark ? AppColors.bronze : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _inviteeIds.isEmpty ? 'Select people' : '${_inviteeIds.length} people selected',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _inviteeIds.isEmpty
                                      ? 'Browse everyone in the organisation'
                                      : _selectedPeople.take(3).map((p) => p.name).join(', ') +
                                          (_selectedPeople.length > 3 ? '…' : ''),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const NbIcon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_selectedPeople.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedPeople.take(12).map((p) {
                      return InputChip(
                        avatar: ZoomablePhoto(
                          url: p.photoUrl,
                          label: p.name,
                          child: CircleAvatar(
                          backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                          child: p.photoUrl == null
                              ? Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase())
                              : null,
                        ),
                        ),
                        label: Text(p.name, overflow: TextOverflow.ellipsis),
                        onDeleted: () {
                          setState(() {
                            _inviteeIds.remove(p.userId);
                            _selectedPeople.removeWhere((x) => x.userId == p.userId);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (_selectedPeople.length > 12)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${_selectedPeople.length - 12} more',
                        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const NbIcon(Icons.event_available_rounded),
                  label: Text(_editing ? 'Save changes' : 'Schedule meeting'),
                ),
              ],
            ),
    );
  }
}
