import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/crm_repository.dart';

/// Compact 9ance dialer strip: status, live calls, disposition. Softphone on web via click-to-call + live board.
class CrmNineanceDialerPanel extends StatefulWidget {
  const CrmNineanceDialerPanel({
    super.key,
    this.onIncomingLead,
  });

  final void Function(String leadId)? onIncomingLead;

  @override
  State<CrmNineanceDialerPanel> createState() => _CrmNineanceDialerPanelState();
}

class _CrmNineanceDialerPanelState extends State<CrmNineanceDialerPanel> {
  bool _expanded = false;
  bool _loading = false;
  String _status = 'offline';
  String? _agentId;
  Map<String, dynamic>? _dialerConfig;
  List<Map<String, dynamic>> _live = [];
  String? _lastCallId;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_expanded) _refreshLive();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final repo = context.read<CrmRepository>();
      final cfg = await repo.getNineanceDialerConfig();
      if (!mounted) return;
      setState(() {
        _dialerConfig = cfg;
        _status = cfg['agent']?['status']?.toString() ??
            (cfg['ready'] == true ? 'ready' : 'offline');
        _agentId = cfg['agent']?['id']?.toString();
        _loading = false;
      });
      await _refreshLive();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshLive() async {
    try {
      final raw = await context.read<CrmRepository>().listNineanceLiveCalls();
      List<Map<String, dynamic>> list = [];
      if (raw is List) {
        list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (raw is Map) {
        final inner = raw['calls'] ?? raw['results'] ?? raw['data'];
        if (inner is List) {
          list = inner.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      if (!mounted) return;
      setState(() => _live = list);
      for (final c in list) {
        final id = (c['id'] ?? c['call_id'])?.toString();
        if (id != null && id.isNotEmpty) _lastCallId = id;
      }
    } catch (_) {}
  }

  Future<void> _setStatus(String status, {String? breakType}) async {
    if (_agentId == null || _agentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No agent linked. Map your agent in Settings → 9ance Cloud Telephony.'),
        ),
      );
      return;
    }
    try {
      await context.read<CrmRepository>().setNineanceAgentStatus(
            _agentId!,
            status,
            breakType: breakType,
          );
      if (!mounted) return;
      setState(() => _status = status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status: $status')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _disposition(String callId) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Call outcome', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.thumb_up, color: Color(0xFF16A34A)),
              title: const Text('Interested'),
              onTap: () => Navigator.pop(ctx, 'interested'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Color(0xFF2563EB)),
              title: const Text('Callback'),
              onTap: () => Navigator.pop(ctx, 'callback'),
            ),
            ListTile(
              leading: const Icon(Icons.thumb_down, color: Colors.red),
              title: const Text('Not interested'),
              onTap: () => Navigator.pop(ctx, 'not_interested'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      await context.read<CrmRepository>().dispositionNineanceCall(
            callId,
            disposition: choice,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: $choice')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _onLiveTap(Map<String, dynamic> call) async {
    final phone =
        (call['from_number'] ?? call['to_number'] ?? call['customer_number'] ?? '').toString();
    final callId = (call['id'] ?? call['call_id'] ?? '').toString();
    if (callId.isNotEmpty) _lastCallId = callId;
    if (phone.isEmpty) return;
    try {
      final match = await context.read<CrmRepository>().matchNineancePhone(phone);
      final local = match['local'];
      if (local is Map && local['id'] != null && widget.onIncomingLead != null) {
        widget.onIncomingLead!(local['id'].toString());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ready = _dialerConfig?['ready'] == true;
    final blockers = (_dialerConfig?['blockers'] is List)
        ? (_dialerConfig!['blockers'] as List).join(', ')
        : '';

    return Material(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            leading: Icon(
              Icons.phone_in_talk_rounded,
              color: ready ? const Color(0xFF4ADE80) : Colors.orangeAccent,
            ),
            title: const Text(
              '9ance Dialer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
            subtitle: Text(
              _loading
                  ? 'Loading…'
                  : ready
                      ? 'Status: $_status · ${_live.length} live${kIsWeb ? " · browser softphone ready" : ""}'
                      : (blockers.isNotEmpty
                          ? blockers
                          : 'Use click-to-call on leads. Expand for live calls.'),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            trailing: IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white70),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Wrap(
                spacing: 6,
                children: [
                  _chip('Ready', () => _setStatus('ready')),
                  _chip('Break', () => _setStatus('break', breakType: 'short')),
                  _chip('Busy', () => _setStatus('busy')),
                  _chip('Refresh', _refresh),
                  if (_lastCallId != null)
                    _chip('Disposition', () => _disposition(_lastCallId!)),
                ],
              ),
            ),
            if (_live.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No live calls', style: TextStyle(color: Colors.white54, fontSize: 12)),
              )
            else
              ..._live.take(5).map((c) {
                final label =
                    '${c['direction'] ?? ''} ${c['from_number'] ?? ''} → ${c['to_number'] ?? ''} · ${c['status'] ?? ''}';
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.ring_volume, color: Color(0xFF4ADE80), size: 18),
                  title: Text(label.trim(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  onTap: () => _onLiveTap(c),
                );
              }),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onTap,
      backgroundColor: Colors.white10,
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}
