import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/crm_repository.dart';

/// Admin / ITADMIN-only ops console: health probes, backups, leads, live logs.
class CrmOpsHealthScreen extends StatefulWidget {
  const CrmOpsHealthScreen({super.key});

  @override
  State<CrmOpsHealthScreen> createState() => _CrmOpsHealthScreenState();
}

class _CrmOpsHealthScreenState extends State<CrmOpsHealthScreen> {
  bool _loading = true;
  bool _backingUp = false;
  String? _error;
  Map<String, dynamic> _data = {};

  bool _isOpsAdmin(String? role) {
    if (Permissions.isAdmin(role)) return true;
    final r = (role ?? '').toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return const ['ADMIN', 'SUPERADMIN', 'SYSTEMADMIN', 'ITADMIN'].contains(r);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<CrmRepository>().getOpsDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _runBackup() async {
    setState(() => _backingUp = true);
    try {
      final info = await context.read<CrmRepository>().createOpsBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup saved: ${info['fileName'] ?? 'ok'}'),
          backgroundColor: Colors.green,
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final role = auth.user?.role;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final border = isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFFE2E8F0);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final primary = isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB);

    if (!_isOpsAdmin(role)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ops Health'),
          leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
        ),
        body: const Center(child: Text('Restricted to admins / ITADMIN')),
      );
    }

    final probes = (_data['probes'] as Map?)?.cast<String, dynamic>() ?? {};
    final leads = (_data['leads'] as Map?)?.cast<String, dynamic>() ?? {};
    final system = (_data['system'] as Map?)?.cast<String, dynamic>() ?? {};
    final backups = (_data['backups'] as Map?)?.cast<String, dynamic>() ?? {};
    final backupItems = (backups['items'] as List?) ?? const [];
    final lastIngested = (_data['lastIngested'] as List?) ?? const [];
    final liveLogs = (_data['liveLogs'] as List?) ?? const [];
    final auditLogs = (_data['auditLogs'] as List?) ?? const [];
    final overall = _data['overall']?.toString() ?? '—';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Ops Health'),
        leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && _data.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  _section(
                    cardBg,
                    border,
                    title: 'System health',
                    trailing: _pill(
                      overall.toUpperCase(),
                      overall == 'healthy' ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Env ${system['env'] ?? '—'} · Port ${system['port'] ?? '—'} · '
                          'Uptime ${system['uptimeSec'] ?? 0}s · RSS ${system['memoryMb'] ?? 0} MB · ${system['node'] ?? ''}',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _probeCard('Database', probes['database'], primary),
                            _probeCard('API', probes['api'], primary),
                            _probeCard('Redis', probes['redis'], primary),
                            _probeCard('Cloudinary', probes['cloudinary'], primary),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _section(
                    cardBg,
                    border,
                    title: 'Backup centre',
                    trailing: FilledButton.icon(
                      onPressed: _backingUp ? null : _runBackup,
                      icon: _backingUp
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.backup_rounded, size: 16),
                      label: Text(_backingUp ? 'Backing up…' : 'Run backup now'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Local daily DB dumps under ${backups['dir'] ?? 'backups/db'} '
                          '(keeps ~14 days). Latest: ${(backups['latest'] as Map?)?['fileName'] ?? 'none yet'}.',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 10),
                        if (backupItems.isEmpty)
                          Text('No backups yet.', style: TextStyle(color: muted))
                        else
                          ...backupItems.take(8).map((raw) {
                            final b = Map<String, dynamic>.from(raw as Map);
                            final bytes = (b['sizeBytes'] as num?)?.toInt() ?? 0;
                            final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.storage_rounded, size: 18),
                              title: Text(b['fileName']?.toString() ?? '—', style: const TextStyle(fontSize: 13)),
                              subtitle: Text(
                                '${b['createdAt'] ?? ''} · $mb MB',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _section(
                    cardBg,
                    border,
                    title: 'Lead status',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _statChip('Total', leads['total'], primary),
                        _statChip('Excel', leads['excel'], const Color(0xFF16A34A)),
                        _statChip('Manual', leads['manual'], const Color(0xFF8B5CF6)),
                        _statChip('Ads', leads['ads'], const Color(0xFF0891B2)),
                        _statChip('Meta', leads['meta'], const Color(0xFF2563EB)),
                        _statChip('Google', leads['google'], const Color(0xFFEA4335)),
                        _statChip('Webhook', leads['webhook'], const Color(0xFF0F766E)),
                        _statChip('Bin', leads['inBin'], const Color(0xFFDC2626)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _section(
                    cardBg,
                    border,
                    title: 'Last 10 ingested leads',
                    child: lastIngested.isEmpty
                        ? Text('No recent leads.', style: TextStyle(color: muted))
                        : Column(
                            children: lastIngested.map((raw) {
                              final l = Map<String, dynamic>.from(raw as Map);
                              final created = l['createdAt'] != null
                                  ? DateFormat('dd MMM HH:mm').format(
                                      DateTime.tryParse(l['createdAt'].toString())?.toLocal() ??
                                          DateTime.now(),
                                    )
                                  : '—';
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${l['name'] ?? 'Unnamed'} · ${l['phone'] ?? ''}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${l['leadSource'] ?? '—'} · ${l['campaignName'] ?? 'No campaign'} · $created',
                                  style: TextStyle(fontSize: 11, color: muted),
                                ),
                                trailing: Text(
                                  l['status']?.toString() ?? '',
                                  style: TextStyle(fontSize: 11, color: muted),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 14),
                  _section(
                    cardBg,
                    border,
                    title: 'Live logs (API traffic)',
                    child: liveLogs.isEmpty
                        ? Text('No traffic captured yet. Use the app, then refresh.', style: TextStyle(color: muted))
                        : Column(
                            children: liveLogs.take(40).map((raw) {
                              final log = Map<String, dynamic>.from(raw as Map);
                              final ok = ((log['status'] as num?)?.toInt() ?? 0) < 400;
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  ok ? Icons.check_circle_outline : Icons.error_outline,
                                  size: 16,
                                  color: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                ),
                                title: Text(
                                  '${log['method']} ${log['path']}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${log['status']} · ${log['ms']}ms · ${log['userRole'] ?? 'anon'} · ${log['at'] ?? ''}',
                                  style: TextStyle(fontSize: 10, color: muted),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 14),
                  _section(
                    cardBg,
                    border,
                    title: 'Portal audit trail',
                    child: auditLogs.isEmpty
                        ? Text('No audit rows yet.', style: TextStyle(color: muted))
                        : Column(
                            children: auditLogs.take(30).map((raw) {
                              final a = Map<String, dynamic>.from(raw as Map);
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${a['tableName']}.${a['fieldName']}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${a['changedBy'] ?? '—'} · ${a['changedAt'] ?? ''} · ${a['changeReason'] ?? ''}',
                                  style: TextStyle(fontSize: 10, color: muted),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _section(
    Color cardBg,
    Color border, {
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _probeCard(String name, dynamic raw, Color primary) {
    final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final ok = m['ok'] == true;
    final ms = m['latencyMs'] ?? m['ms'] ?? '—';
    final err = m['error']?.toString();
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ok ? const Color(0xFF16A34A).withValues(alpha: 0.35) : const Color(0xFFDC2626).withValues(alpha: 0.35)),
        color: (ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: primary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(ok ? 'OK · ${ms}ms' : 'DOWN', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          if (err != null && err.isNotEmpty)
            Text(err, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626))),
        ],
      ),
    );
  }

  Widget _statChip(String label, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: ${value ?? 0}',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
