import 'package:flutter/material.dart';

import '../data/collab_socket.dart';
import '../data/meet_repository.dart';
import '../domain/collab_models.dart';

Future<MeetingItem?> showEndMeetProgress({
  required BuildContext context,
  required String meetingId,
  required CollabSocket socket,
  required MeetRepository repo,
  required bool hasRecording,
}) {
  return showDialog<MeetingItem>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _EndMeetProgressDialog(
      meetingId: meetingId,
      socket: socket,
      repo: repo,
      hasRecording: hasRecording,
    ),
  );
}

class _EndMeetProgressDialog extends StatefulWidget {
  const _EndMeetProgressDialog({
    required this.meetingId,
    required this.socket,
    required this.repo,
    required this.hasRecording,
  });

  final String meetingId;
  final CollabSocket socket;
  final MeetRepository repo;
  final bool hasRecording;

  @override
  State<_EndMeetProgressDialog> createState() => _EndMeetProgressDialogState();
}

class _EndMeetProgressDialogState extends State<_EndMeetProgressDialog> {
  final _status = <String, String>{
    'stop_recording': 'pending',
    'save_cloud': 'pending',
    'close_room': 'pending',
    'summary': 'pending',
  };
  final _labels = <String, String>{
    'stop_recording': 'Stopping recording',
    'save_cloud': 'Saving recording to the cloud',
    'close_room': 'Closing the meeting room',
    'summary': 'Preparing the summary',
  };

  String? _error;
  bool _started = false;

  List<String> get _steps => widget.hasRecording
      ? const ['stop_recording', 'save_cloud', 'close_room', 'summary']
      : const ['close_room', 'summary'];

  @override
  void initState() {
    super.initState();
    if (!widget.hasRecording) {
      _status['stop_recording'] = 'skipped';
      _status['save_cloud'] = 'skipped';
    }
    widget.socket.onMeetingEndProgress(_onProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _onProgress(Map<String, dynamic> row) {
    final step = row['step']?.toString();
    final status = row['status']?.toString();
    final label = row['label']?.toString();
    if (step == null || status == null || !mounted) return;
    setState(() {
      _status[step] = status;
      if (label != null && label.isNotEmpty) _labels[step] = label;
    });
  }

  Future<void> _run() async {
    if (_started) return;
    _started = true;
    try {
      final ended = await widget.repo.end(widget.meetingId);
      if (!mounted) return;
      setState(() {
        for (final step in _steps) {
          if (_status[step] == 'pending' || _status[step] == 'running') {
            _status[step] = 'done';
          }
        }
      });
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.pop(context, ended);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ending meeting'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._steps.map(_stepRow),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), height: 1.35)),
            ],
          ],
        ),
      ),
      actions: [
        if (_error != null)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  Widget _stepRow(String step) {
    final status = _status[step] ?? 'pending';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _indicator(status),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _labels[step] ?? step,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: status == 'error' ? const Color(0xFFDC2626) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicator(String status) {
    switch (status) {
      case 'running':
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        );
      case 'done':
        return const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22);
      case 'skipped':
        return const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF94A3B8), size: 22);
      case 'error':
        return const Icon(Icons.error_rounded, color: Color(0xFFDC2626), size: 22);
      default:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFCBD5E1), width: 2.4),
          ),
        );
    }
  }
}
