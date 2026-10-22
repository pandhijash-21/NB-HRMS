import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';

void showSendWhatsappDialog(
  BuildContext context, {
  required CrmLead lead,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CrmSendWhatsappDialog(lead: lead),
  );
}

class CrmSendWhatsappDialog extends StatefulWidget {
  final CrmLead lead;

  const CrmSendWhatsappDialog({
    super.key,
    required this.lead,
  });

  @override
  State<CrmSendWhatsappDialog> createState() => _CrmSendWhatsappDialogState();
}

class _CrmSendWhatsappDialogState extends State<CrmSendWhatsappDialog> {
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isSending = false;
  String? _errorMessage;

  List<BotbizTemplateModel> _templates = [];
  BotbizTemplateModel? _selectedTemplate;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _calendarLinkController;
  late final TextEditingController _headerMediaUrlController;
  late final TextEditingController _headerTextController;

  // Dynamic additional variables
  final Map<String, TextEditingController> _customVarControllers = {};
  final List<String> _customVarKeys = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    final initialName = widget.lead.name.trim().isNotEmpty
        ? widget.lead.name.trim()
        : (widget.lead.customFields['client_name']?.toString() ??
            widget.lead.customFields['name']?.toString() ??
            'Valued Client');

    _nameController = TextEditingController(text: initialName);
    _phoneController = TextEditingController(text: widget.lead.phone);
    _dateController = TextEditingController(text: dateStr);
    _timeController = TextEditingController(text: timeStr);
    _calendarLinkController = TextEditingController();
    _headerMediaUrlController = TextEditingController();
    _headerTextController = TextEditingController();

    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _calendarLinkController.dispose();
    _headerMediaUrlController.dispose();
    _headerTextController.dispose();
    for (final c in _customVarControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<CrmRepository>();
      final results = await Future.wait([
        repo.getWhatsappTemplates().catchError((_) => <BotbizTemplateModel>[]),
        repo.getWhatsappConfig().catchError((_) => CrmWhatsappConfig.fromJson(const {})),
      ]);

      final templates = results[0] as List<BotbizTemplateModel>;
      final config = results[1] as CrmWhatsappConfig;

      BotbizTemplateModel? chosenTemplate;
      if (templates.isNotEmpty) {
        // Prefer 'newlead' if available as requested by user
        final newLeadTmpl = templates.firstWhere(
          (t) => t.name.toLowerCase() == 'newlead',
          orElse: () => templates.first,
        );
        chosenTemplate = newLeadTmpl;
      }

      if (mounted) {
        setState(() {
          _templates = templates;
          _selectedTemplate = chosenTemplate;
          if (config.defaultCalendarLink.isNotEmpty) {
            _calendarLinkController.text = config.defaultCalendarLink;
          }
          final headerUrl = chosenTemplate?.headerExampleUrl;
          if (headerUrl != null && headerUrl.isNotEmpty) {
            _headerMediaUrlController.text = headerUrl;
          }
          _syncTemplateVariables(chosenTemplate);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshTemplates() async {
    setState(() => _isSyncing = true);
    try {
      final repo = context.read<CrmRepository>();
      await repo.syncWhatsappTemplates().catchError((_) => <String, dynamic>{});
      final templates = await repo.getWhatsappTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          if (_selectedTemplate != null) {
            final updated = templates.firstWhere(
              (t) => t.id == _selectedTemplate!.id,
              orElse: () => templates.isNotEmpty ? templates.first : _selectedTemplate!,
            );
            _selectedTemplate = updated;
            _syncTemplateVariables(updated);
          } else if (templates.isNotEmpty) {
            _selectedTemplate = templates.first;
            _syncTemplateVariables(templates.first);
          }
          _isSyncing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-synced ${templates.length} templates from BotBiz!'),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _syncTemplateVariables(BotbizTemplateModel? template) {
    if (template == null) return;

    // Check variables defined in the template
    final standardKeys = {'1', '2', '3', '4', 'name', 'date', 'time', 'calendar_link', 'calendarlink', 'phone', 'number'};
    final detected = template.bodyExampleVariables;

    for (final rawKey in detected) {
      final key = rawKey.trim();
      if (key.isEmpty) continue;
      if (standardKeys.contains(key.toLowerCase())) continue;

      if (!_customVarControllers.containsKey(key)) {
        String initialVal = '';
        if (key.toLowerCase().contains('project')) {
          initialVal = widget.lead.campaignName ?? 'Legacy Tower';
        } else if (key.toLowerCase().contains('advisor') || key.toLowerCase().contains('agent')) {
          initialVal = widget.lead.assignedToName ?? 'Property Advisor';
        }
        _customVarControllers[key] = TextEditingController(text: initialVal);
        _customVarKeys.add(key);
      }
    }
  }

  void _onTemplateSelected(BotbizTemplateModel? template) {
    if (template == null) return;
    setState(() {
      _selectedTemplate = template;
      if (template.headerExampleUrl != null && template.headerExampleUrl!.isNotEmpty) {
        _headerMediaUrlController.text = template.headerExampleUrl!;
      }
      _syncTemplateVariables(template);
    });
  }

  void _addCustomVariableDialog() {
    final keyCtrl = TextEditingController();
    final valCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Template Variable', style: TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Variable Name / Index',
                hintText: 'e.g. 5, offer, project_name',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valCtrl,
              decoration: const InputDecoration(
                labelText: 'Variable Value',
                hintText: 'e.g. 10% Discount, Tower A',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final k = keyCtrl.text.trim();
              final v = valCtrl.text.trim();
              if (k.isNotEmpty) {
                setState(() {
                  if (!_customVarControllers.containsKey(k)) {
                    _customVarControllers[k] = TextEditingController(text: v);
                    _customVarKeys.add(k);
                  } else {
                    _customVarControllers[k]!.text = v;
                  }
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked != null) {
      final dt = DateTime(2026, 1, 1, picked.hour, picked.minute);
      setState(() {
        _timeController.text = DateFormat('hh:mm a').format(dt);
      });
    }
  }

  Future<void> _sendWhatsappMessage() async {
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a template to send.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lead phone number is required.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final repo = context.read<CrmRepository>();

      final variables = <String, String>{
        'name': _nameController.text.trim(),
        'phone': phone,
        'number': phone,
        if (_dateController.text.trim().isNotEmpty) 'date': _dateController.text.trim(),
        if (_timeController.text.trim().isNotEmpty) 'time': _timeController.text.trim(),
        if (_calendarLinkController.text.trim().isNotEmpty)
          'calendar_link': _calendarLinkController.text.trim(),
      };

      // Add all detected / custom variables
      for (final k in _customVarKeys) {
        final ctrl = _customVarControllers[k];
        if (ctrl != null && ctrl.text.trim().isNotEmpty) {
          variables[k] = ctrl.text.trim();
        }
      }

      final headerMedia = _headerMediaUrlController.text.trim().isNotEmpty
          ? _headerMediaUrlController.text.trim()
          : null;
      final headerText = _headerTextController.text.trim().isNotEmpty
          ? _headerTextController.text.trim()
          : null;

      final res = await repo.sendLeadWhatsapp(
        widget.lead.id,
        templateId: _selectedTemplate!.id,
        templateName: _selectedTemplate!.name,
        headerMediaUrl: headerMedia,
        headerText: headerText,
        variables: variables,
      );

      if (mounted) {
        setState(() => _isSending = false);
        Navigator.of(context).pop();

        final isSuccess = res['success'] == true;
        final msg = res['message'] ?? (isSuccess ? 'WhatsApp message dispatched successfully via BotBiz!' : 'Send status unknown');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(msg.toString())),
              ],
            ),
            backgroundColor: isSuccess ? const Color(0xFF16A34A) : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send WhatsApp template: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white70 : const Color(0xFF64748B);
    const primaryGreen = Color(0xFF22C55E);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 780),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131720) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: primaryGreen, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send BotBiz WhatsApp Template',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Direct dispatch to ${widget.lead.name} (${widget.lead.phone})',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 3, color: primaryGreen),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber),
                                const SizedBox(height: 12),
                                Text(
                                  'Failed to load WhatsApp data',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(fontSize: 12, color: textMuted),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: _loadData,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Lead Information Card
                              _buildLeadInfoCard(isDark, cardBg, borderColor, textMuted),
                              const SizedBox(height: 16),

                              // 2. Template Selector with Sync / Refresh button
                              _buildTemplateSelector(isDark, cardBg, borderColor, textMuted),
                              const SizedBox(height: 16),

                              // Template Preview (Body text) if available
                              if (_selectedTemplate?.bodyText != null && _selectedTemplate!.bodyText!.isNotEmpty)
                                _buildTemplateBodyPreview(isDark, cardBg, borderColor, textMuted),

                              if (_selectedTemplate?.bodyText != null && _selectedTemplate!.bodyText!.isNotEmpty)
                                const SizedBox(height: 16),

                              // 3. Header Media / Text Section
                              if (_selectedTemplate != null && _selectedTemplate!.headerFormat != 'NONE')
                                _buildHeaderSection(isDark, cardBg, borderColor, textMuted),

                              if (_selectedTemplate != null && _selectedTemplate!.headerFormat != 'NONE')
                                const SizedBox(height: 16),

                              // 4. Dynamic Template Variables
                              _buildVariablesSection(isDark, cardBg, borderColor, textMuted),
                              const SizedBox(height: 16),

                              // 5. BotBiz API Parameters Preview
                              _buildParametersPreview(isDark, cardBg, borderColor, textMuted),
                            ],
                          ),
                        ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSending || _isLoading || _selectedTemplate == null
                        ? null
                        : _sendWhatsappMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSending ? 'Sending via BotBiz...' : 'Send Template Message',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadInfoCard(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.15),
            child: Text(
              widget.lead.name.isNotEmpty ? widget.lead.name[0].toUpperCase() : 'L',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.lead.name.isNotEmpty ? widget.lead.name : 'Lead',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.lead.scope,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.phone_rounded, size: 13, color: textMuted),
                    const SizedBox(width: 4),
                    Text(widget.lead.phone, style: TextStyle(fontSize: 12, color: textMuted)),
                    if (widget.lead.assignedToName != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.badge_outlined, size: 13, color: textMuted),
                      const SizedBox(width: 4),
                      Text(widget.lead.assignedToName!, style: TextStyle(fontSize: 12, color: textMuted)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.layers_rounded, size: 18, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              const Text(
                'Select BotBiz Template',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              if (_isSyncing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF3B82F6)),
                  tooltip: 'Sync latest templates from BotBiz',
                  onPressed: _refreshTemplates,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 6),
              if (_templates.isNotEmpty)
                Text(
                  '${_templates.length} templates',
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_templates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No templates found in BotBiz account. Please sync templates in CRM Settings.',
                style: TextStyle(fontSize: 12, color: textMuted, fontStyle: FontStyle.italic),
              ),
            )
          else
            DropdownButtonFormField<BotbizTemplateModel>(
              initialValue: _selectedTemplate,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _templates.map((tmpl) {
                final headerFmt = tmpl.headerFormat?.toUpperCase() ?? 'NONE';
                final varCount = tmpl.bodyExampleVariables.isNotEmpty
                    ? tmpl.bodyExampleVariables.length
                    : (tmpl.variableCount ?? 0);
                return DropdownMenuItem<BotbizTemplateModel>(
                  value: tmpl,
                  child: Row(
                    children: [
                      Text(
                        tmpl.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: headerFmt == 'DOCUMENT'
                              ? Colors.purple.withValues(alpha: 0.15)
                              : headerFmt == 'IMAGE'
                                  ? Colors.teal.withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          headerFmt == 'DOCUMENT'
                              ? '📄 DOCUMENT'
                              : headerFmt == 'IMAGE'
                                  ? '🖼️ IMAGE'
                                  : headerFmt == 'VIDEO'
                                      ? '🎥 VIDEO'
                                      : headerFmt == 'TEXT'
                                          ? '📝 TEXT'
                                          : 'NO HEADER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: headerFmt == 'DOCUMENT'
                                ? Colors.purple
                                : headerFmt == 'IMAGE'
                                    ? Colors.teal
                                    : textMuted,
                          ),
                        ),
                      ),
                      if (varCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$varCount var',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        tmpl.category ?? 'MARKETING',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _onTemplateSelected,
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateBodyPreview(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2C) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_rounded, size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              const Text(
                'Template Message Preview:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _selectedTemplate!.bodyText!,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    final format = _selectedTemplate?.headerFormat?.toUpperCase() ?? 'NONE';
    final isMedia = format == 'DOCUMENT' || format == 'IMAGE' || format == 'VIDEO';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isMedia ? Icons.attachment_rounded : Icons.title_rounded,
                size: 18,
                color: const Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 8),
              Text(
                isMedia ? 'Template Header Media ($format)' : 'Template Header Text',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'template_header_media_url',
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.purple),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isMedia)
            TextField(
              controller: _headerMediaUrlController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Header Media URL (PDF, Wasabi S3, Image, Video)',
                hintText: 'https://bot-data.s3.ap-southeast-1.wasabisys.com/...',
                prefixIcon: const Icon(Icons.link_rounded, size: 18),
                suffixIcon: _headerMediaUrlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _headerMediaUrlController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )
          else
            TextField(
              controller: _headerTextController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Header Text Variable (template_header_variable-1)',
                prefixIcon: const Icon(Icons.text_fields_rounded, size: 18),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVariablesSection(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              const Text(
                'Template Dynamic Variables',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Variable', style: TextStyle(fontSize: 12)),
                onPressed: _addCustomVariableDialog,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Standard Row 1: Name and Phone
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Client Name (templateVariable-name-1 / {{1}})',
                    prefixIcon: const Icon(Icons.person_rounded, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Phone Number (phone_number)',
                    prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Standard Row 2: Date and Time
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dateController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Date (templateVariable-date-1 / {{2}})',
                    prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                      onPressed: _pickDate,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _timeController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Time (templateVariable-time-1 / {{3}})',
                    prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.schedule_rounded, size: 18),
                      onPressed: _pickTime,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Standard Row 3: Calendar / Appointment Link
          TextField(
            controller: _calendarLinkController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Calendar Link (templateVariable-calendar_link-1 / {{4}})',
              hintText: 'https://calendly.com/... or Google Calendar link',
              prefixIcon: const Icon(Icons.link_rounded, size: 18),
              suffixIcon: _calendarLinkController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _calendarLinkController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          // Dynamic detected / custom extra variables
          if (_customVarKeys.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.extension_rounded, size: 15, color: Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Text(
                  'Additional Template Variables (${_customVarKeys.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6366F1)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._customVarKeys.map((key) {
              final ctrl = _customVarControllers[key]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Variable: $key (templateVariable-$key-1)',
                          prefixIcon: const Icon(Icons.data_object_rounded, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      tooltip: 'Remove Variable',
                      onPressed: () {
                        setState(() {
                          _customVarKeys.remove(key);
                          _customVarControllers.remove(key);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildParametersPreview(bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    final tmplName = _selectedTemplate?.name ?? 'newlead';
    final tmplId = _selectedTemplate?.id ?? '463170';
    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Jash';
    final phone = _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : '91XXXXXXXXXX';
    final media = _headerMediaUrlController.text.trim();
    final date = _dateController.text.trim();
    final time = _timeController.text.trim();
    final cal = _calendarLinkController.text.trim();

    final buffer = StringBuffer();
    buffer.writeln('• phone_number: $phone');
    buffer.writeln('• template_id: $tmplId ($tmplName)');
    if (media.isNotEmpty) buffer.writeln('• template_header_media_url: $media');
    buffer.writeln('• templateVariable-name-1: $name');
    if (date.isNotEmpty) buffer.writeln('• templateVariable-date-1: $date');
    if (time.isNotEmpty) buffer.writeln('• templateVariable-time-1: $time');
    if (cal.isNotEmpty) buffer.writeln('• templateVariable-calendar_link-1: $cal');

    for (final k in _customVarKeys) {
      final ctrl = _customVarControllers[k];
      if (ctrl != null && ctrl.text.trim().isNotEmpty) {
        buffer.writeln('• templateVariable-$k-1: ${ctrl.text.trim()}');
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.code_rounded, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 6),
              Text(
                'BotBiz Dispatch Parameters Preview:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            buffer.toString().trim(),
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.4,
              color: Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }
}
