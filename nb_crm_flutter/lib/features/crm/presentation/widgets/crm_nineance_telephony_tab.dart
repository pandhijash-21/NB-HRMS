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
      final tc = await repo.listTelecallerTelephony();
      if (!mounted) return;
      setState(() => _telecallers = tc.telecallers);
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

  Future<void> _mapAgent(String agentId, int? employeeId) async {
    if (employeeId == null) return;
    try {
      final repo = context.read<CrmRepository>();
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
      _snack('Agent mapped to telecaller');
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
                subtitle: 'Map each 9ance agent to a Telecaller employee for click-to-call.',
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _busy ? null : () => _refreshAgentsAndDids(),
                        icon: const Icon(Icons.sync, size: 16),
                        label: const Text('Sync agents'),
                      ),
                    ),
                    if (_agents.isEmpty)
                      Text('No agents yet. Activate & sync first.', style: TextStyle(color: widget.textMuted))
                    else
                      ..._agents.map((a) {
                        final id = a['id']?.toString() ?? '';
                        final name = a['name']?.toString() ?? 'Agent';
                        final phone = a['phone']?.toString() ?? '';
                        final mapped = _employeeMappedTo(id);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: widget.isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$name${phone.isNotEmpty ? ' · $phone' : ''}',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int?>(
                                  value: mapped,
                                  decoration: InputDecoration(
                                    labelText: 'Map to telecaller',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(value: null, child: Text('— Not mapped —')),
                                    ..._telecallers.map(
                                      (t) => DropdownMenuItem<int?>(
                                        value: t.employeeId,
                                        child: Text(t.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (empId) {
                                    if (empId != null) _mapAgent(id, empId);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
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
