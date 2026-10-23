import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';

class CrmWhatsappSettingsWidget extends StatefulWidget {
  const CrmWhatsappSettingsWidget({
    super.key,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textMuted,
    required this.primaryColor,
  });

  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textMuted;
  final Color primaryColor;

  @override
  State<CrmWhatsappSettingsWidget> createState() =>
      _CrmWhatsappSettingsWidgetState();
}

class _CrmWhatsappSettingsWidgetState extends State<CrmWhatsappSettingsWidget> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _isTestingConnection = false;
  bool _isSyncingTemplates = false;
  String? _testStatusMessage;
  bool? _testSuccess;

  // Master Settings
  bool _automationEnabled = true;
  String _provider = 'botbiz';
  String _connectionStatus = 'NOT_CONFIGURED';
  bool _hasSavedApiKey = false;
  final _apiBaseController = TextEditingController(
    text: 'https://dash.botbiz.io/api/v1',
  );
  final _apiUrlController = TextEditingController(
    text: 'https://dash.botbiz.io/api/v1/whatsapp/send',
  );
  final _apiKeyController = TextEditingController();
  final _senderIdController = TextEditingController();
  final _projectNameController = TextEditingController(text: 'Legacy Tower');
  final _calendarLinkController = TextEditingController();
  final _defaultLocationController = TextEditingController(
    text: 'https://maps.google.com/?q=Legacy+Tower',
  );

  bool _obscureApiKey = true;

  // Test Phone Controller
  final _testPhoneController = TextEditingController(text: '9638930589');
  String? _selectedTestTemplateId;

  // Triggers List
  List<CrmWhatsappTrigger> _triggers = [];

  // Synced Templates List
  List<BotbizTemplateModel> _templates = [];

  // Logs List
  List<CrmWhatsappLogItem> _logs = [];
  bool _loadingLogs = false;

  // Available event options (Real Estate CRM)
  static const Map<String, String> _eventLabels = {
    'SITE_VISIT_SCHEDULED': 'Site Visit Scheduled & Confirmed',
    'SITE_VISIT_RESCHEDULED': 'Site Visit Rescheduled Notice',
    'SITE_VISIT_CANCELLED': 'Site Visit Cancelled Notice',
    'SITE_VISIT_DONE': 'Post Site Visit Follow-up & Feedback',
    'LEAD_CREATED': 'New Lead Received & Welcome Brochure',
    'LEAD_ASSIGNED': 'Property Advisor Assigned Notification',
    'FOLLOW_UP_DUE': 'Customer Follow-Up Due Reminder',
    'BOOKING_CONFIRMED': 'Unit Booking Confirmed Congratulation',
    'PAYMENT_RECEIVED': 'Payment Received Acknowledgement',
    'AFTER_CALL': 'Post-Call Greeting & Relationship',
  };

  // Available event options (Finserve Financial Services CRM)
  static const Map<String, String> _finserveEventLabels = {
    'LEAD_CREATED': 'Loan Inquiry Received & Welcome Guide',
    'LEAD_ASSIGNED': 'Financial Advisor Assigned Notification',
    'FOLLOW_UP_DUE': 'Customer Follow-Up Due Reminder',
    'CNR_ATTEMPTED': 'CNR (Call Not Reached) Notification',
    'VISIT_SCHEDULED': 'Consultation Scheduled & Confirmed',
    'VISIT_DONE': 'Consultation Done & Feedback',
    'DOCUMENTS_REQUESTED': 'Loan Documents Checklist Request',
    'LOAN_SANCTIONED': 'Loan Application Sanctioned Congratulation',
    'LOAN_DISBURSED': 'Loan Disbursed Congratulation',
    'NOT_INTERESTED': 'Application Closed / Inactive Follow-up',
    'AFTER_CALL': 'Post-Call Greeting & Relationship',
  };

  bool get _isFinserve => CrmRepository.crmScopeNotifier.value == 'NB_FINSERVE';
  Map<String, String> get _activeEventLabels => _isFinserve ? _finserveEventLabels : _eventLabels;

  @override
  void initState() {
    super.initState();
    CrmRepository.crmScopeNotifier.addListener(_onScopeChanged);
    _loadConfig();
    _loadTemplates();
    _loadLogs();
  }

  @override
  void dispose() {
    CrmRepository.crmScopeNotifier.removeListener(_onScopeChanged);
    _apiBaseController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _senderIdController.dispose();
    _projectNameController.dispose();
    _calendarLinkController.dispose();
    _defaultLocationController.dispose();
    _testPhoneController.dispose();
    super.dispose();
  }

  void _onScopeChanged() {
    if (!mounted) return;
    _apiKeyController.clear();
    _loadConfig();
    _loadTemplates();
    _loadLogs();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<CrmRepository>();
      final config = await repo.getWhatsappConfig();
      if (!mounted) return;

      final isFin = _isFinserve;
      setState(() {
        _automationEnabled = config.enabled;
        _provider = config.provider.isNotEmpty ? config.provider : 'botbiz';
        _connectionStatus = config.connectionStatus;
        _hasSavedApiKey = config.hasApiKey;
        _apiKeyController.clear();
        _apiBaseController.text = config.apiBase.isNotEmpty
            ? config.apiBase
            : 'https://dash.botbiz.io/api/v1';
        _apiUrlController.text = config.apiUrl.isNotEmpty
            ? config.apiUrl
            : 'https://dash.botbiz.io/api/v1/whatsapp/send';
        _senderIdController.text = config.senderId;
        _projectNameController.text = config.defaultProjectName.isNotEmpty
            ? config.defaultProjectName
            : (isFin ? 'NB Finserve' : 'Legacy Tower');
        _calendarLinkController.text = config.defaultCalendarLink;
        _defaultLocationController.text = config.defaultLocationUrl;
        _triggers = List.from(config.triggers);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load WhatsApp configuration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final repo = context.read<CrmRepository>();
      final list = await repo.getWhatsappTemplates();
      if (!mounted) return;
      setState(() {
        _templates = list;
        if (_selectedTestTemplateId == null && list.isNotEmpty) {
          final approved = list.firstWhere(
            (t) => t.status == 'APPROVED',
            orElse: () => list.first,
          );
          _selectedTestTemplateId = approved.id;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadLogs() async {
    setState(() => _loadingLogs = true);
    try {
      final repo = context.read<CrmRepository>();
      final items = await repo.getWhatsappLogs(50);
      if (!mounted) return;
      setState(() {
        _logs = items;
        _loadingLogs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTestingConnection = true);
    try {
      final repo = context.read<CrmRepository>();
      final res = await repo.testWhatsappConnection();
      if (!mounted) return;

      final success = res['success'] == true;
      final msg = res['message']?.toString() ?? 'Test completed';
      final status = res['connectionStatus']?.toString() ?? _connectionStatus;

      setState(() {
        _connectionStatus = status;
        _isTestingConnection = false;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: widget.cardBg,
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.info_rounded,
                color: success ? const Color(0xFF16A34A) : Colors.amber,
              ),
              const SizedBox(width: 10),
              Text(
                success ? 'Connection Verified' : 'BotBiz API Status',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              if (success) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Note: "Test Connection" validates your API Token and Phone ID with BotBiz servers (no message is sent to phones). To send a live template message to your phone, click the green WhatsApp icon on any lead in Pre-sales.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF16A34A)),
                  ),
                ),
              ],
              if (!success) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Note: If BotBiz returned 403 Access Denied, ensure the API token was generated with WhatsApp API permissions in your BotBiz Developer dashboard. Once access is active, re-test connection.',
                    style: TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTestingConnection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing connection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncTemplates() async {
    setState(() => _isSyncingTemplates = true);
    try {
      final repo = context.read<CrmRepository>();
      final res = await repo.syncWhatsappTemplates();
      if (!mounted) return;

      setState(() => _isSyncingTemplates = false);
      if (res['success'] == true) {
        await _loadTemplates();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced ${res['count'] ?? 0} templates from BotBiz!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Failed to sync templates'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncingTemplates = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template synchronization error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkSingleTemplateStatus(String templateId) async {
    try {
      final repo = context.read<CrmRepository>();
      final res = await repo.checkWhatsappTemplateStatus(templateId);
      if (!mounted) return;

      final status = res['status']?.toString() ?? 'UNKNOWN';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template $templateId status: $status'),
          backgroundColor: status == 'APPROVED' ? Colors.green : Colors.orange,
        ),
      );
      _loadTemplates();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check template status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _retryLog(String logId) async {
    try {
      final repo = context.read<CrmRepository>();
      final res = await repo.retryWhatsappLog(logId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Retry executed'),
          backgroundColor: res['success'] == true ? Colors.green : Colors.red,
        ),
      );
      _loadLogs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to retry message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  String _formatToIst(String rawTimestamp) {
    if (rawTimestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawTimestamp);
      final ist = dt.isUtc ? dt.add(const Duration(hours: 5, minutes: 30)) : dt.toLocal();
      final y = ist.year;
      final m = ist.month.toString().padLeft(2, '0');
      final d = ist.day.toString().padLeft(2, '0');
      final hr = ist.hour.toString().padLeft(2, '0');
      final min = ist.minute.toString().padLeft(2, '0');
      final sec = ist.second.toString().padLeft(2, '0');
      return '$y-$m-$d $hr:$min:$sec IST';
    } catch (_) {
      return rawTimestamp.length > 19
          ? rawTimestamp.substring(0, 19).replaceFirst('T', ' ')
          : rawTimestamp;
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      final repo = context.read<CrmRepository>();
      final payload = {
        'enabled': _automationEnabled,
        'provider': _provider,
        'apiBase': _apiBaseController.text.trim(),
        'apiUrl': _apiUrlController.text.trim(),
        'apiKey': _apiKeyController.text.trim(),
        'senderId': _senderIdController.text.trim(),
        'defaultProjectName': _projectNameController.text.trim(),
        'defaultCalendarLink': _calendarLinkController.text.trim(),
        'defaultLocationUrl': _defaultLocationController.text.trim(),
        'triggers': _triggers.map((t) => t.toJson()).toList(),
      };

      await repo.updateWhatsappConfig(payload);
      if (!mounted) return;
      _apiKeyController.clear();
      _hasSavedApiKey = true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp automation settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadConfig();
      _loadLogs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendTestMessage() async {
    final phone = _testPhoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a recipient phone number for testing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testStatusMessage = null;
      _testSuccess = null;
    });

    try {
      final repo = context.read<CrmRepository>();
      final res = await repo.testWhatsapp(
        phone,
        null,
        _selectedTestTemplateId,
      );
      if (!mounted) return;
      setState(() {
        _testSuccess = res['success'] != false;
        _testStatusMessage = res['error'] != null
            ? 'Error: ${res['error']}'
            : 'Test message dispatched to $phone! Check WhatsApp.';
      });
      _loadLogs();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testSuccess = false;
        _testStatusMessage = 'Error sending test message: $e';
      });
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _addNewTrigger() {
    final activeLabels = _activeEventLabels;
    final defaultEvent = activeLabels.keys.first;
    showDialog(
      context: context,
      builder: (ctx) {
        String selectedEvent = defaultEvent;
        String? selectedTemplateId = _templates.isNotEmpty
            ? (_templates.firstWhere((t) => t.status == 'APPROVED', orElse: () => _templates.first).id)
            : null;
        final nameCtrl = TextEditingController(text: activeLabels[defaultEvent] ?? defaultEvent);
        bool includeCal = true;

        return StatefulBuilder(
          builder: (context, setDlgState) {
            BotbizTemplateModel? selectedTmpl;
            if (selectedTemplateId != null) {
              try {
                selectedTmpl = _templates.firstWhere((t) => t.id == selectedTemplateId);
              } catch (_) {}
            }

            return AlertDialog(
              backgroundColor: widget.cardBg,
              title: const Row(
                children: [
                  Icon(Icons.add_link_rounded, color: Color(0xFF25D366)),
                  SizedBox(width: 8),
                  Text('Map CRM Event to Meta Template'),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Select CRM Event Trigger:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedEvent,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: activeLabels.entries.map((e) {
                          return DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() {
                              selectedEvent = val;
                              nameCtrl.text = activeLabels[val] ?? val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        '2. Trigger Display Label:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        '3. Select Meta Approved Template:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedTemplateId,
                        decoration: InputDecoration(
                          hintText: _templates.isEmpty ? 'No synced templates found' : 'Select Template',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: _templates.map((t) {
                          final isApproved = t.status == 'APPROVED';
                          return DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              '${t.name} (${t.category ?? "Template"} - ${t.status})',
                              style: TextStyle(
                                fontSize: 13,
                                color: isApproved ? const Color(0xFF16A34A) : Colors.orange,
                                fontWeight: isApproved ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDlgState(() => selectedTemplateId = val);
                        },
                      ),
                      if (selectedTmpl != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF25D366)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Template: ${selectedTmpl.name} | Category: ${selectedTmpl.category ?? "General"} | Language: ${selectedTmpl.language}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _isFinserve
                              ? 'Include Google Calendar Reminder Link (For Consultations)'
                              : 'Include Google Calendar Reminder Link (For Site Visits)',
                          style: const TextStyle(fontSize: 13),
                        ),
                        value: includeCal,
                        onChanged: (val) => setDlgState(() => includeCal = val ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                  onPressed: () {
                    final chosen = _templates.isNotEmpty
                        ? _templates.firstWhere((t) => t.id == selectedTemplateId, orElse: () => _templates.first)
                        : null;
                    final newT = CrmWhatsappTrigger(
                      id: 'trigger_${DateTime.now().millisecondsSinceEpoch}',
                      event: selectedEvent,
                      name: nameCtrl.text.trim(),
                      enabled: true,
                      messageType: selectedTemplateId != null ? 'TEMPLATE' : 'TEXT',
                      templateId: selectedTemplateId,
                      templateName: chosen?.name,
                      messageTemplate: chosen != null ? 'Template: ${chosen.name}' : '',
                      includeCalendarLink: includeCal,
                      mediaUrl: '',
                      locationUrl: _defaultLocationController.text.trim(),
                    );
                    setState(() {
                      _triggers.add(newT);
                    });
                    Navigator.pop(ctx);
                    _saveConfig();
                  },
                  child: const Text('Save & Map Trigger'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopHeaderCard(),
                const SizedBox(height: 20),
                _buildApiConfigCard(),
                const SizedBox(height: 20),
                _buildBotbizTemplatesSection(),
                const SizedBox(height: 20),
                _buildTestingCard(),
                const SizedBox(height: 20),
                _buildCalendarLinkCard(),
                const SizedBox(height: 20),
                _buildVariableLegendCard(),
                const SizedBox(height: 20),
                _buildTriggersSection(),
                const SizedBox(height: 24),
                _buildDeliveryLogsSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeaderCard() {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (_connectionStatus == 'CONNECTED_VERIFIED') {
      badgeColor = const Color(0xFF16A34A);
      badgeText = 'VERIFIED CONNECTED';
      badgeIcon = Icons.check_circle_rounded;
    } else if (_connectionStatus == 'CONFIGURED_UNVERIFIED') {
      badgeColor = Colors.amber.shade700;
      badgeText = 'CONFIGURED (UNVERIFIED / 403)';
      badgeIcon = Icons.lock_clock_rounded;
    } else {
      badgeColor = Colors.red;
      badgeText = 'NOT CONFIGURED';
      badgeIcon = Icons.error_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Color(0xFF25D366),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _isFinserve
                          ? 'BotBiz WhatsApp Integration (NB Finserve)'
                          : 'BotBiz WhatsApp Integration (NB Developer)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 12, color: badgeColor),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _isFinserve
                      ? 'Automated WhatsApp triggers, loan inquiries, and BotBiz delivery pipeline isolated for Finserve.'
                      : 'Automated WhatsApp triggers, message composition, variable rendering, and BotBiz delivery pipeline.',
                  style: TextStyle(fontSize: 13, color: widget.textMuted),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSaving ? null : _saveConfig,
          ),
        ],
      ),
    );
  }

  Widget _buildApiConfigCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.api_rounded, color: Color(0xFF3B82F6), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'BotBiz API Configuration & Credentials',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                icon: _isTestingConnection
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt_rounded, size: 16),
                label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  side: const BorderSide(color: Color(0xFF3B82F6)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: _isTestingConnection ? null : _testConnection,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Connect your BotBiz WhatsApp Business API account. Tokens are securely stored and masked.',
            style: TextStyle(fontSize: 12, color: widget.textMuted),
          ),
          const SizedBox(height: 14),

          // Diagnostic helper banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'BotBiz Token Generation Note: If BotBiz currently returns 403 Access Denied on token generation, this integration is ready to accept your token whenever access is granted without any code changes.',
                    style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.blue.shade200 : Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Base URL & Phone Number ID
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BotBiz API Base URL',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _apiBaseController,
                      decoration: InputDecoration(
                        hintText: 'https://dash.botbiz.io/api/v1',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        prefixIcon: const Icon(Icons.link_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WhatsApp Phone Number ID',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _senderIdController,
                      decoration: InputDecoration(
                        hintText: 'e.g. 521948294...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        prefixIcon: const Icon(Icons.phone_android_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // API Token with masking
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BotBiz API Token (apiToken)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (_hasSavedApiKey)
                    const Text(
                      '• Securely configured on server (Masked)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
                decoration: InputDecoration(
                  hintText: _hasSavedApiKey
                      ? '•••••••••••••••• (Leave blank to keep existing token)'
                      : 'Paste your BotBiz API Token here',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: const Icon(Icons.key_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotbizTemplatesSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.layers_rounded, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'BotBiz WhatsApp Templates (Meta Approved)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: _isSyncingTemplates
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(_isSyncingTemplates ? 'Syncing...' : 'Sync Templates from BotBiz'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: _isSyncingTemplates ? null : _syncTemplates,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Approved Meta templates fetched via documented BotBiz API (POST /whatsapp/get/template/list).',
            style: TextStyle(fontSize: 12, color: widget.textMuted),
          ),
          const SizedBox(height: 14),

          if (_templates.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: widget.borderColor),
              ),
              child: Center(
                child: Text(
                  'No templates synced yet. Click "Sync Templates from BotBiz" to load approved templates from your WhatsApp account.',
                  style: TextStyle(fontSize: 12, color: widget.textMuted),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _templates.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, i) {
                final tmpl = _templates[i];
                final isApproved = tmpl.status == 'APPROVED';
                final isPending = tmpl.status == 'PENDING';

                Color statusColor = Colors.grey;
                if (isApproved) statusColor = const Color(0xFF16A34A);
                if (isPending) statusColor = Colors.amber;
                if (tmpl.status == 'REJECTED') statusColor = Colors.red;

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        tmpl.status,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(tmpl.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              if (tmpl.headerFormat != null && tmpl.headerFormat!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tmpl.headerFormat == 'document'
                                        ? Colors.red.withValues(alpha: 0.12)
                                        : Colors.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: tmpl.headerFormat == 'document' ? Colors.red.shade400 : Colors.blue.shade400,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        tmpl.headerFormat == 'document'
                                            ? Icons.picture_as_pdf_rounded
                                            : Icons.image_rounded,
                                        size: 11,
                                        color: tmpl.headerFormat == 'document' ? Colors.red : Colors.blue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        tmpl.headerFormat!.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: tmpl.headerFormat == 'document' ? Colors.red : Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (tmpl.bodyExampleVariables.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Vars: ${tmpl.bodyExampleVariables.join(", ")}',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text('ID: ${tmpl.id} • Lang: ${tmpl.language} • ${tmpl.category ?? "MARKETING"}',
                              style: TextStyle(fontSize: 11, color: widget.textMuted)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _checkSingleTemplateStatus(tmpl.id),
                      child: const Text('Check Status', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTestingCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.send_rounded, size: 16, color: Color(0xFF25D366)),
                  SizedBox(width: 8),
                  Text(
                    'Verify & Send Test WhatsApp Template',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              if (_templates.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_templates.length} Templates Available',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select any Meta-approved template to test live delivery to your phone outside the 24-hour service window.',
            style: TextStyle(fontSize: 12, color: widget.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Meta Approved Template to Test:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedTestTemplateId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: _templates.isEmpty ? 'No synced templates found' : 'Choose Template',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _templates.map((t) {
                        return DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            '${t.name} (${t.status})',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedTestTemplateId = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recipient Phone Number:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _testPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. 9638930589',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: ElevatedButton.icon(
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(_isTesting ? 'Sending...' : 'Send Test WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isTesting ? null : _sendTestMessage,
                ),
              ),
            ],
          ),
          if (_testStatusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_testSuccess == true ? const Color(0xFF16A34A) : Colors.red)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _testSuccess == true ? const Color(0xFF16A34A) : Colors.red,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _testSuccess == true ? Icons.check_circle : Icons.error,
                    size: 16,
                    color: _testSuccess == true ? const Color(0xFF16A34A) : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testStatusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _testSuccess == true ? const Color(0xFF16A34A) : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarLinkCard() {
    return Container(
      padding: const EdgeInsets.all(22),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default Calendar & Appointment Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sent automatically to leads in BotBiz WhatsApp templates as {{calendar_link}} for booking visits or consultation calls.',
                      style: TextStyle(fontSize: 12, color: widget.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _calendarLinkController,
            decoration: InputDecoration(
              labelText: 'Calendar / Appointment Scheduling Link',
              hintText: 'https://calendly.com/your-team or https://calendar.google.com/calendar/appointments/...',
              prefixIcon: const Icon(Icons.link_rounded, size: 20),
              suffixIcon: _calendarLinkController.text.trim().isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      tooltip: 'Test Calendar Link',
                      onPressed: () {
                        final raw = _calendarLinkController.text.trim();
                        if (raw.isNotEmpty) {
                          launchUrl(Uri.parse(raw), mode: LaunchMode.externalApplication);
                        }
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              helperText: 'Mapped to BotBiz template variable templateVariable-calendar_link-1 (and templateVariable-4-1)',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildVariableLegendCard() {
    final isFin = _isFinserve;
    final variables = [
      {'tag': '{{customerName}}', 'desc': isFin ? 'Applicant / Customer Name' : 'Lead / Customer Name'},
      {'tag': '{{projectName}}', 'desc': isFin ? 'Company Name (NB Finserve)' : 'Project Name (Legacy Tower)'},
      {'tag': isFin ? '{{consultationDate}}' : '{{siteVisitDate}}', 'desc': isFin ? 'Scheduled Consultation Date' : 'Scheduled Visit Date (e.g. 12 Oct 2026)'},
      {'tag': isFin ? '{{consultationTime}}' : '{{siteVisitTime}}', 'desc': isFin ? 'Scheduled Consultation Time' : 'Scheduled Visit Time (e.g. 11:30 AM)'},
      {'tag': '{{salespersonName}}', 'desc': isFin ? 'Assigned Financial Advisor Name' : 'Assigned Sales Agent Name'},
      {'tag': '{{salespersonPhone}}', 'desc': isFin ? 'Financial Advisor Phone' : 'Sales Agent Phone Number'},
      {'tag': '{{paymentAmount}}', 'desc': isFin ? 'Loan / Disbursal Amount' : 'Booking / Payment Amount'},
      {'tag': '{{locationUrl}}', 'desc': isFin ? 'Branch / Office Location Pin' : 'Google Maps Location Pin'},
      {'tag': '{{calendarLink}}', 'desc': 'One-tap Add to Calendar Link'},
      {'tag': '{{brochureUrl}}', 'desc': isFin ? 'Loan Product Guide PDF Link' : 'Project Brochure PDF Link'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.6)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.data_object_rounded, size: 18, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Text(
                'Dynamic Variables (Tap to Copy):',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: variables.map((v) {
              return InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: v['tag']!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied ${v['tag']} to clipboard!'),
                      duration: const Duration(milliseconds: 1000),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        v['tag']!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        v['desc']!,
                        style: TextStyle(fontSize: 11, color: widget.textMuted),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggersSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: Color(0xFFF59E0B), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'CRM Event Triggers & WhatsApp Templates',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_isSaving ? 'Saving...' : 'Save Trigger Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _saveConfig,
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Event Trigger'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _addNewTrigger,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Map each CRM event directly to a Meta-approved BotBiz template. Sync new templates above whenever added in BotBiz.',
            style: TextStyle(fontSize: 12, color: widget.textMuted),
          ),
          const SizedBox(height: 18),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _triggers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final trigger = _triggers[index];
              return _buildTriggerCard(trigger, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerCard(CrmWhatsappTrigger trigger, int index) {
    // Find matching template in synced list
    BotbizTemplateModel? matchedTmpl;
    if (_templates.isNotEmpty) {
      try {
        matchedTmpl = _templates.firstWhere(
          (t) => t.id == trigger.templateId || t.name == trigger.templateName,
        );
      } catch (_) {}
    }

    final hasTemplate = matchedTmpl != null || (trigger.templateId != null && trigger.templateId!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: trigger.enabled ? const Color(0xFF25D366).withValues(alpha: 0.3) : widget.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trigger.event,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (hasTemplate ? Colors.purple : Colors.amber)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasTemplate ? 'META TEMPLATE' : 'UNMAPPED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: hasTemplate ? Colors.purple : Colors.amber.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trigger.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              Switch(
                value: trigger.enabled,
                activeThumbColor: const Color(0xFF25D366),
                onChanged: (val) {
                  setState(() {
                    _triggers[index] = trigger.copyWith(enabled: val);
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                onPressed: () {
                  setState(() {
                    _triggers.removeAt(index);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Meta Approved Template Mapping Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Meta Approved Template:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: matchedTmpl?.id,
                decoration: InputDecoration(
                  hintText: _templates.isEmpty ? 'No synced templates found' : 'Choose Meta Template',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('-- Select Template --', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ),
                  ..._templates.map((t) {
                    final isApproved = t.status == 'APPROVED';
                    return DropdownMenuItem<String>(
                      value: t.id,
                      child: Row(
                        children: [
                          Icon(
                            isApproved ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            size: 14,
                            color: isApproved ? const Color(0xFF16A34A) : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${t.name} (${t.category ?? "Template"} - ${t.status})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isApproved ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  final sel = val != null ? _templates.firstWhere((t) => t.id == val, orElse: () => _templates.first) : null;
                  setState(() {
                    _triggers[index] = trigger.copyWith(
                      templateId: val,
                      templateName: sel?.name,
                      messageType: val != null && val.isNotEmpty ? 'TEMPLATE' : 'TEXT',
                      messageTemplate: sel != null ? 'Template: ${sel.name}' : '',
                    );
                  });
                },
              ),
            ],
          ),
          if (matchedTmpl != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Text(
                    'Active Meta Template: "${matchedTmpl.name}" (${matchedTmpl.status}) • Category: ${matchedTmpl.category ?? "General"}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          Row(
            children: [
              Checkbox(
                value: trigger.includeCalendarLink,
                onChanged: (val) {
                  setState(() {
                    _triggers[index] = trigger.copyWith(includeCalendarLink: val ?? false);
                  });
                },
              ),
              const Text('Add Calendar Link', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: trigger.locationUrl,
                  decoration: InputDecoration(
                    labelText: 'Map Pin URL (Optional)',
                    labelStyle: const TextStyle(fontSize: 11),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (val) {
                    _triggers[index] = trigger.copyWith(locationUrl: val.trim());
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryLogsSection() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 20, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text(
                    'Recent WhatsApp Notification Activity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: _loadingLogs
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Activity Logs',
                onPressed: _loadingLogs ? null : _loadLogs,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No WhatsApp dispatches recorded yet.',
                  style: TextStyle(color: widget.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _logs.length > 15 ? 15 : _logs.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, i) {
                final log = _logs[i];
                final isSent = log.status == 'SENT';
                final isFailed = log.status == 'FAILED';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSent
                          ? Icons.check_circle_rounded
                          : (isFailed ? Icons.error_rounded : Icons.info_rounded),
                      size: 18,
                      color: isSent
                          ? const Color(0xFF16A34A)
                          : (isFailed ? Colors.red : Colors.orange),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  log.event,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                log.phone,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatToIst(log.timestamp),
                                style: TextStyle(fontSize: 11, color: widget.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: widget.textMuted),
                          ),
                          if (log.error != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              log.error!,
                              style: const TextStyle(fontSize: 11, color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isFailed) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Retry', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _retryLog(log.id),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
