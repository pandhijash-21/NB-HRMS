import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';

/// Clean 9ance Cloud Telephony settings: Connect · Numbers · Agents · Campaigns
class CrmNineanceTelephonyTab extends StatefulWidget {
  const CrmNineanceTelephonyTab({
    super.key,
    required this.settings,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textMuted,
    required this.onSettingsChanged,
  });

  final CrmSettings settings;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textMuted;
  final VoidCallback onSettingsChanged;

  @override
  State<CrmNineanceTelephonyTab> createState() => _CrmNineanceTelephonyTabState();
}

class _CrmNineanceTelephonyTabState extends State<CrmNineanceTelephonyTab> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _apiKey;
  late final TextEditingController _apiSecret;
  late final TextEditingController _provider;
  late final TextEditingController _displayName;
  late final TextEditingController _baseUrl;

  late final TextEditingController _campName;
  late final TextEditingController _campCallflow;
  late final TextEditingController _campDestination;

  bool _busy = false;
  bool _connected = false;
  String _webhookToken = '';
  String _webhookUrl = '';
  List<Map<String, dynamic>> _agents = [];
  List<Map<String, dynamic>> _dids = [];
  List<CrmTelecallerTelephony> _telecallers = [];
  List<CrmSalesUser> _users = [];
  List<Map<String, dynamic>> _campaigns = [];
  String? _defaultDidId;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _email = TextEditingController(text: s.nineanceEmail);
    _password = TextEditingController(text: s.nineanceHasPassword ? '' : '');
    _apiKey = TextEditingController(text: '');
    _apiSecret = TextEditingController(text: '');
    _provider = TextEditingController(text: s.nineanceProviderKey.isNotEmpty ? s.nineanceProviderKey : 'indiavoice');
    _displayName = TextEditingController(text: s.nineanceDisplayName);
    _baseUrl = TextEditingController(text: s.nineanceBaseUrl.isNotEmpty ? s.nineanceBaseUrl : 'https://crmapi.9ance.com');
    _campName = TextEditingController();
    _campCallflow = TextEditingController(text: 'IVR_Default');
    _campDestination = TextEditingController();
    _connected = s.nineanceConnected;
    _webhookToken = s.nineanceWebhookToken;
    _webhookUrl = s.nineanceWebhookUrl;
    _defaultDidId = s.nineanceDefaultDidId.isEmpty ? null : s.nineanceDefaultDidId;
    _bootstrap();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _apiKey.dispose();
    _apiSecret.dispose();
    _provider.dispose();
    _displayName.dispose();
    _baseUrl.dispose();
    _campName.dispose();
    _campCallflow.dispose();
    _campDestination.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final repo = context.read<CrmRepository>();
      final results = await Future.wait([
        repo.listTelecallerTelephony(),
        repo.getHrmsEmployees(),
      ]);
      if (!mounted) return;
      setState(() {
        _telecallers = (results[0] as CrmTelecallerTelephonyList).telecallers;
        _users = results[1] as List<CrmSalesUser>;
      });
      if (_connected) {
        await _refreshAgentsAndDids(silent: true);
        await _refreshCampaigns(silent: true);
      }
    } catch (_) {}
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : const Color(0xFF16A34A),
      ),
    );
  }

  Future<void> _saveCredentials() async {
    setState(() => _busy = true);
    try {
      final repo = context.read<CrmRepository>();
      final body = <String, dynamic>{
        'nineance_base_url': _baseUrl.text.trim(),
        'nineance_email': _email.text.trim(),
        'nineance_provider_key': _provider.text.trim().isEmpty ? 'indiavoice' : _provider.text.trim(),
        'nineance_display_name': _displayName.text.trim(),
      };
      if (_password.text.trim().isNotEmpty) body['nineance_password'] = _password.text.trim();
      if (_apiKey.text.trim().isNotEmpty) body['nineance_api_key'] = _apiKey.text.trim();
      if (_apiSecret.text.trim().isNotEmpty) body['nineance_api_secret'] = _apiSecret.text.trim();
      await repo.updateSettings(body);
      _snack('Credentials saved');
      widget.onSettingsChanged();
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      await _saveCredentials();
      final res = await context.read<CrmRepository>().testNineanceConnection();
      _snack(res['message']?.toString() ?? 'Connection OK');
      setState(() => _connected = true);
      widget.onSettingsChanged();
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate() async {
    if (_email.text.trim().isEmpty) {
      _snack('Email is required', error: true);
      return;
    }
    if (_password.text.trim().isEmpty && !widget.settings.nineanceHasPassword) {
      _snack('Password (portal login) is required', error: true);
      return;
    }
    if (_apiKey.text.trim().isEmpty && !widget.settings.nineanceHasApiKey) {
      _snack('API key (API Username) is required', error: true);
      return;
    }
    if (_apiSecret.text.trim().isEmpty && !widget.settings.nineanceHasApiSecret) {
      _snack('API secret (API password) is required', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'nineance_base_url': _baseUrl.text.trim(),
        'nineance_email': _email.text.trim(),
        'nineance_provider_key': _provider.text.trim().isEmpty ? 'indiavoice' : _provider.text.trim(),
        'nineance_display_name': _displayName.text.trim(),
      };
      if (_password.text.trim().isNotEmpty) body['nineance_password'] = _password.text.trim();
      if (_apiKey.text.trim().isNotEmpty) body['nineance_api_key'] = _apiKey.text.trim();
      if (_apiSecret.text.trim().isNotEmpty) body['nineance_api_secret'] = _apiSecret.text.trim();

      final res = await context.read<CrmRepository>().activateNineance(body);
      setState(() {
        _connected = true;
        _webhookToken = res['webhook_token']?.toString() ?? _webhookToken;
        _webhookUrl = res['webhook_url']?.toString() ?? _webhookUrl;
      });
      await _refreshAgentsAndDids(silent: true);
      _snack(res['message']?.toString() ?? 'Activated');
      widget.onSettingsChanged();
    } catch (e) {
      final msg = '$e';
      _snack(msg, error: true);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Activate failed'),
            content: SelectableText(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshAgentsAndDids({bool silent = false}) async {
    try {
      final repo = context.read<CrmRepository>();
      final agents = await repo.syncNineanceAgents();
      final dids = await repo.syncNineanceDids();
      if (!mounted) return;
      setState(() {
        _agents = agents;
        _dids = dids;
      });
      if (!silent) _snack('Synced ${agents.length} agents · ${dids.length} numbers');
    } catch (e) {
      if (!silent) _snack('$e', error: true);
      try {
        final repo = context.read<CrmRepository>();
        final agents = await repo.listNineanceAgents();
        final dids = await repo.listNineanceDids();
        if (!mounted) return;
        setState(() {
          _agents = agents;
          _dids = dids;
        });
      } catch (_) {}
    }
  }

  Future<void> _setDefaultDid(String id) async {
    try {
      await context.read<CrmRepository>().setNineanceDefaultDid(id);
      setState(() => _defaultDidId = id);
      _snack('Default number updated');
      widget.onSettingsChanged();
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _createAgentDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final sipCtrl = TextEditingController();
    String access = '2';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Create 9ance agent'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'Ramesh'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (10 digits)',
                    hintText: '9876543210',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: access,
                  decoration: const InputDecoration(labelText: 'Access'),
                  items: const [
                    DropdownMenuItem(value: '2', child: Text('Agent (2)')),
                    DropdownMenuItem(value: '1', child: Text('Admin (1)')),
                  ],
                  onChanged: (v) => setLocal(() => access = v ?? '2'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sipCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'SIP password (optional)',
                    hintText: 'Write-only; never returned',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      sipCtrl.dispose();
      return;
    }
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final sip = sipCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    sipCtrl.dispose();
    if (name.isEmpty || phone.isEmpty) {
      _snack('Name and phone are required', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<CrmRepository>().createNineanceAgent(
            name: name,
            phone: phone,
            access: access,
            sipPassword: sip.isEmpty ? null : sip,
          );
      await _refreshAgentsAndDids(silent: true);
      _snack('Agent created on 9ance');
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAgent(Map<String, dynamic> agent) async {
    final agentId = agent['id']?.toString() ?? '';
    final providerId = agent['provider_agent_id']?.toString() ?? '';
    final name = agent['name']?.toString() ?? 'Agent';
    final deleteKey = agentId.isNotEmpty ? agentId : providerId;
    if (deleteKey.isEmpty) {
      _snack('This agent has no id — Sync agents, then try again', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete agent?'),
        content: Text('Delete "$name" from 9ance? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = context.read<CrmRepository>();
      try {
        await repo.deleteNineanceAgent(deleteKey);
      } catch (firstErr) {
        // Fallback: 9ance sometimes wants provider/member id instead of UUID.
        if (providerId.isNotEmpty && providerId != deleteKey) {
          await repo.deleteNineanceAgent(providerId);
        } else {
          throw firstErr;
        }
      }
      // Clear local CRM mapping if this agent was mapped.
      final mappedEmp = _employeeMappedTo(agentId);
      if (mappedEmp != null) {
        try {
          await repo.saveTelecallerTelephony(mappedEmp, {
            'agent_id': '',
            'agent_number': '',
            'agent_email': '',
          });
        } catch (_) {}
      }
      await _refreshAgentsAndDids(silent: true);
      _snack('Agent deleted');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _mapAgent(String agentId, int? employeeId) async {
    if (employeeId == null) return;
    try {
      final repo = context.read<CrmRepository>();
      final previous = _employeeMappedTo(agentId);
      if (previous != null && previous != employeeId) {
        await repo.saveTelecallerTelephony(previous, {
          'agent_id': '',
          'agent_number': '',
          'agent_email': '',
        });
      }
      await repo.assignNineanceAgent(agentId, employeeId: employeeId);
      Map<String, dynamic>? agent;
      for (final a in _agents) {
        if (a['id']?.toString() == agentId) {
          agent = a;
          break;
        }
      }
      await repo.saveTelecallerTelephony(employeeId, {
        'agent_id': agentId,
        'agent_number': agent?['phone']?.toString() ?? '',
        'agent_email': agent?['email']?.toString() ?? '',
      });
      final tc = await repo.listTelecallerTelephony();
      if (!mounted) return;
      setState(() => _telecallers = tc.telecallers);
      _snack('Agent mapped to ${_mappedUserLabel(employeeId)}');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  Future<void> _refreshCampaigns({bool silent = false}) async {
    try {
      final raw = await context.read<CrmRepository>().listNineanceCampaigns();
      List<Map<String, dynamic>> list = [];
      if (raw is List) {
        list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (raw is Map) {
        final inner = raw['results'] ?? raw['campaigns'] ?? raw['data'];
        if (inner is List) {
          list = inner.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      if (!mounted) return;
      setState(() => _campaigns = list);
    } catch (e) {
      if (!silent) _snack('$e', error: true);
    }
  }

  Future<void> _createCampaign() async {
    if (_campName.text.trim().isEmpty || _campCallflow.text.trim().isEmpty) {
      _snack('Name and IVR callflow are required', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<CrmRepository>().createNineanceCampaign({
        'name': _campName.text.trim(),
        'callflow_name': _campCallflow.text.trim(),
        'destination': _campDestination.text.trim(),
        'entity_type': 'lead',
        'filters': {'status': 'NOT_STARTED'},
      });
      _campName.clear();
      await _refreshCampaigns();
      _snack('Campaign created');
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int? _employeeMappedTo(String agentId) {
    for (final t in _telecallers) {
      if (t.config.agentId == agentId) return t.employeeId;
    }
    return null;
  }

  String _mappedUserLabel(int? employeeId) {
    if (employeeId == null) return '— Not mapped —';
    for (final u in _users) {
      if (u.employeeId == employeeId) {
        final role = (u.role ?? u.designation ?? '').trim();
        return role.isEmpty ? u.fullName : '${u.fullName} · $role';
      }
    }
    for (final t in _telecallers) {
      if (t.employeeId == employeeId) {
        final desig = (t.designation ?? '').trim();
        return desig.isEmpty ? t.name : '${t.name} · $desig';
      }
    }
    return 'Employee #$employeeId';
  }

  Future<void> _pickUserForAgent(String agentId) async {
    if (_users.isEmpty) {
      try {
        final users = await context.read<CrmRepository>().getHrmsEmployees();
        if (!mounted) return;
        setState(() => _users = users);
      } catch (e) {
        _snack('$e', error: true);
        return;
      }
    }

    String query = '';
    final selected = await showDialog<int?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final q = query.trim().toLowerCase();
            final filtered = _users.where((u) {
              if (q.isEmpty) return true;
              return u.fullName.toLowerCase().contains(q) ||
                  (u.designation ?? '').toLowerCase().contains(q) ||
                  (u.department ?? '').toLowerCase().contains(q) ||
                  (u.role ?? '').toLowerCase().contains(q) ||
                  (u.organization ?? '').toLowerCase().contains(q) ||
                  (u.subOrganization ?? '').toLowerCase().contains(q) ||
                  u.employeeId.toString().contains(q);
            }).toList()
              ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

            return AlertDialog(
              title: const Text('Map agent to user'),
              content: SizedBox(
                width: 480,
                height: 520,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search name, role, dept, org…',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      onChanged: (v) => setLocal(() => query = v),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filtered.length} users',
                        style: TextStyle(fontSize: 12, color: widget.textMuted),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text('No users match', style: TextStyle(color: widget.textMuted)),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final u = filtered[i];
                                final subtitle = [
                                  if ((u.role ?? '').isNotEmpty) u.role,
                                  if ((u.designation ?? '').isNotEmpty) u.designation,
                                  if ((u.department ?? '').isNotEmpty) u.department,
                                ].whereType<String>().join(' · ');
                                return ListTile(
                                  dense: true,
                                  title: Text(u.fullName),
                                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                                  onTap: () => Navigator.pop(ctx, u.employeeId),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, -1),
                  child: const Text('Clear mapping'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null) return;
    if (selected == -1) {
      await _unmapAgent(agentId);
      return;
    }
    await _mapAgent(agentId, selected);
  }

  Future<void> _unmapAgent(String agentId) async {
    final empId = _employeeMappedTo(agentId);
    if (empId == null) return;
    try {
      final repo = context.read<CrmRepository>();
      await repo.saveTelecallerTelephony(empId, {
        'agent_id': '',
        'agent_number': '',
        'agent_email': '',
      });
      final tc = await repo.listTelecallerTelephony();
      if (!mounted) return;
      setState(() => _telecallers = tc.telecallers);
      _snack('Mapping cleared');
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  String _normalizePhone10(dynamic raw) {
    var phone = (raw ?? '').toString().replaceAll(RegExp(r'\D'), '');
    if (phone.length > 10) phone = phone.substring(phone.length - 10);
    return phone;
  }

  String _didLabel(Map<String, dynamic> a) {
    final candidates = [a['default_did_number'], a['effective_did'], a['default_did'], a['did_number']];
    for (final c in candidates) {
      if (c == null) continue;
      if (c is Map) {
        final n = c['number'] ?? c['did'] ?? c['value'];
        if (n != null && n.toString().trim().isNotEmpty) return n.toString().trim();
      } else {
        final s = c.toString().trim();
        // Skip Dart Map.toString() garbage like "{id: ..., number: ...}"
        if (s.isNotEmpty && !s.startsWith('{')) return s;
      }
    }
    return '';
  }

  String _agentDedupeKey(Map<String, dynamic> a) {
    // Phone first so create+sync duplicates with different UUIDs collapse.
    final phone = _normalizePhone10(a['phone'] ?? a['sip_username']);
    if (phone.length >= 10) return 'ph:$phone';
    final providerId = a['provider_agent_id']?.toString().trim() ?? '';
    if (providerId.isNotEmpty) return 'p:$providerId';
    final id = a['id']?.toString() ?? '';
    if (id.isNotEmpty) return 'id:$id';
    final name = (a['name'] ?? '').toString().trim().toLowerCase();
    return 'n:$name|$phone';
  }

  int _agentScore(Map<String, dynamic> a) {
    var s = 0;
    if (a['user'] != null || a['user_id'] != null || (a['user_name']?.toString().isNotEmpty ?? false)) {
      s += 8;
    }
    if (a['is_active'] == true) s += 4;
    if (a['sip_password_set'] == true) s += 2;
    if ((a['phone']?.toString() ?? '').isNotEmpty) s += 1;
    return s;
  }

  List<Map<String, dynamic>> get _uniqueAgents {
    final best = <String, Map<String, dynamic>>{};
    for (final a in _agents) {
      final key = _agentDedupeKey(a);
      final prev = best[key];
      if (prev == null || _agentScore(a) >= _agentScore(prev)) {
        best[key] = a;
      }
    }
    return best.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDark ? Colors.white : const Color(0xFF1E293B);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionCard(
                icon: Icons.cloud_outlined,
                iconColor: const Color(0xFF16A34A),
                title: '1. Connect 9ance',
                subtitle: 'One account for click-to-call, IVR campaigns, and recordings.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(
                          avatar: Icon(
                            _connected ? Icons.check_circle : Icons.cloud_off,
                            size: 16,
                            color: _connected ? const Color(0xFF16A34A) : Colors.orange,
                          ),
                          label: Text(_connected ? 'Connected' : 'Not connected'),
                          backgroundColor: (_connected ? const Color(0xFF16A34A) : Colors.orange)
                              .withValues(alpha: 0.12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Map what 9ance sent you:\n'
                      '• Email → Email\n'
                      '• Portal / login password → Password\n'
                      '• API Username → API key\n'
                      '• API password → API secret',
                      style: TextStyle(fontSize: 12, height: 1.35, color: widget.textMuted),
                    ),
                    const SizedBox(height: 12),
                    _field('Email', _email, hint: 'info@…'),
                    const SizedBox(height: 10),
                    _field(
                      'Password (portal login)',
                      _password,
                      hint: widget.settings.nineanceHasPassword ? 'Leave blank to keep saved' : 'Login password from 9ance',
                      obscure: true,
                    ),
                    const SizedBox(height: 10),
                    _field(
                      'API key (API Username)',
                      _apiKey,
                      hint: widget.settings.nineanceHasApiKey ? 'Leave blank to keep saved' : 'API Username from 9ance',
                      obscure: true,
                    ),
                    const SizedBox(height: 10),
                    _field(
                      'API secret (API password)',
                      _apiSecret,
                      hint: widget.settings.nineanceHasApiSecret ? 'Leave blank to keep saved' : 'API password from 9ance',
                      obscure: true,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _field('Provider key', _provider, hint: 'indiavoice')),
                        const SizedBox(width: 12),
                        Expanded(child: _field('Display name', _displayName, hint: 'NB Dialer')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _field('API base URL', _baseUrl, hint: 'https://crmapi.9ance.com'),
                    if (_webhookToken.isNotEmpty || _webhookUrl.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Webhook (register on 9ance dashboard)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: titleColor),
                      ),
                      const SizedBox(height: 6),
                      _copyBox(_webhookUrl.isNotEmpty ? _webhookUrl : _webhookToken),
                      const SizedBox(height: 6),
                      Text(
                        'Also keep our CRM receiver for inbound logs: https://crm.nbdeveloper.co.in/api/crm/telephony/webhook',
                        style: TextStyle(fontSize: 11, color: widget.textMuted),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _busy ? null : _saveCredentials,
                          child: const Text('Save'),
                        ),
                        OutlinedButton(
                          onPressed: _busy ? null : _test,
                          child: const Text('Test login'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _busy ? null : _activate,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.bolt_rounded, size: 18),
                          label: Text(_busy ? 'Working…' : 'Activate & sync'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.dialpad_rounded,
                iconColor: const Color(0xFF2563EB),
                title: '2. Numbers (DIDs)',
                subtitle: 'Choose the default outbound number.',
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _busy ? null : () => _refreshAgentsAndDids(),
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Sync numbers'),
                      ),
                    ),
                    if (_dids.isEmpty)
                      Text('No numbers yet. Activate & sync first.', style: TextStyle(color: widget.textMuted))
                    else
                      ..._dids.map((d) {
                        final id = d['id']?.toString() ?? '';
                        final number = d['number']?.toString() ?? id;
                        final isDefault = id == _defaultDidId || d['is_default'] == true;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(number, style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                          subtitle: Text(isDefault ? 'Default' : 'Tap to set as default'),
                          trailing: isDefault
                              ? const Icon(Icons.check_circle, color: Color(0xFF16A34A))
                              : TextButton(
                                  onPressed: id.isEmpty ? null : () => _setDefaultDid(id),
                                  child: const Text('Set default'),
                                ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.headset_mic_rounded,
                iconColor: const Color(0xFF7C3AED),
                title: '3. Agents',
                subtitle: 'Map each 9ance agent to any CRM user (searchable) for click-to-call.',
                child: Column(
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _busy ? null : _createAgentDialog,
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('Create agent'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _refreshAgentsAndDids(),
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('Sync agents'),
                        ),
                      ],
                    ),
                    if (_agents.isEmpty)
                      Text(
                        'No agents yet. Create one here or Sync from 9ance.',
                        style: TextStyle(color: widget.textMuted),
                      )
                    else ...[
                      Text(
                        'Real/mobile number is on each agent (shown below). Virtual DID is separate (Numbers section).',
                        style: TextStyle(fontSize: 11, color: widget.textMuted),
                      ),
                      const SizedBox(height: 8),
                      ..._uniqueAgents.map((a) {
                        final id = a['id']?.toString() ?? '';
                        final name = a['name']?.toString() ?? 'Agent';
                        final phone = a['phone']?.toString() ?? '';
                        final did = _didLabel(a);
                        final mapped = _employeeMappedTo(id);
                        final canDelete = id.isNotEmpty || (a['provider_agent_id']?.toString().isNotEmpty ?? false);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: widget.isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
                                const SizedBox(height: 4),
                                Text(
                                  phone.isNotEmpty
                                      ? 'Real phone (rings first): $phone'
                                      : 'Real phone: not set on 9ance agent — edit in 9ance → Users',
                                  style: TextStyle(fontSize: 12, color: widget.textMuted),
                                ),
                                if (did.isNotEmpty)
                                  Text(
                                    'Outbound DID: $did',
                                    style: TextStyle(fontSize: 12, color: widget.textMuted),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: id.isEmpty ? null : () => _pickUserForAgent(id),
                                        icon: const Icon(Icons.person_search_rounded, size: 18),
                                        label: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _mappedUserLabel(mapped),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                          alignment: Alignment.centerLeft,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete agent',
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: canDelete ? () => _deleteAgent(a) : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.campaign_rounded,
                iconColor: const Color(0xFFEA580C),
                title: '4. IVR campaigns',
                subtitle: 'Auto-dial lists with a callflow (IVR).',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field('Campaign name', _campName, hint: 'Diwali follow-up'),
                    const SizedBox(height: 8),
                    _field('IVR callflow name', _campCallflow, hint: 'IVR_Followup'),
                    const SizedBox(height: 8),
                    _field('Destination number', _campDestination, hint: '07935486114'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _busy ? null : _createCampaign,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Create campaign'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(onPressed: () => _refreshCampaigns(), child: const Text('Refresh')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_campaigns.isEmpty)
                      Text('No campaigns yet.', style: TextStyle(color: widget.textMuted))
                    else
                      ..._campaigns.map((c) {
                        final id = c['id']?.toString() ?? '';
                        final name = c['name']?.toString() ?? 'Campaign';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(name, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
                          subtitle: Text(c['status']?.toString() ?? id),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Start',
                                icon: const Icon(Icons.play_arrow, color: Color(0xFF16A34A)),
                                onPressed: id.isEmpty
                                    ? null
                                    : () async {
                                        try {
                                          await context.read<CrmRepository>().startNineanceCampaign(id);
                                          _snack('Campaign started');
                                          await _refreshCampaigns(silent: true);
                                        } catch (e) {
                                          _snack('$e', error: true);
                                        }
                                      },
                              ),
                              IconButton(
                                tooltip: 'Stop',
                                icon: const Icon(Icons.stop, color: Colors.red),
                                onPressed: id.isEmpty
                                    ? null
                                    : () async {
                                        try {
                                          await context.read<CrmRepository>().stopNineanceCampaign(id);
                                          _snack('Campaign stopped');
                                          await _refreshCampaigns(silent: true);
                                        } catch (e) {
                                          _snack('$e', error: true);
                                        }
                                      },
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: widget.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    String? hint,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: c,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _copyBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF2563EB)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              _snack('Copied');
            },
          ),
        ],
      ),
    );
  }
}
