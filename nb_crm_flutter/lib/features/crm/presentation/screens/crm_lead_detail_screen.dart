import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';
import '../widgets/crm_send_whatsapp_dialog.dart';

Color _getStatusColor(CrmStatus status) {
  switch (status) {
    case CrmStatus.notStarted:
      return const Color(0xFF64748B);
    case CrmStatus.assigned:
      return const Color(0xFF6366F1);
    case CrmStatus.cnr:
      return const Color(0xFFF59E0B);
    case CrmStatus.scheduledVisit:
      return const Color(0xFF2563EB);
    case CrmStatus.notInterested:
      return const Color(0xFFEF4444);
    case CrmStatus.siteVisitDone:
      return const Color(0xFF10B981);
    case CrmStatus.followUp:
      return const Color(0xFFD97706);
    case CrmStatus.interested:
      return const Color(0xFF8B5CF6);
    case CrmStatus.proposalSent:
      return const Color(0xFF06B6D4);
    case CrmStatus.bookingConfirmed:
      return const Color(0xFF16A34A);
    case CrmStatus.rejected:
      return const Color(0xFFDC2626);
  }
}

IconData _getStatusIcon(CrmStatus status) {
  switch (status) {
    case CrmStatus.notStarted:
      return Icons.radio_button_unchecked_rounded;
    case CrmStatus.assigned:
      return Icons.assignment_ind_rounded;
    case CrmStatus.cnr:
      return Icons.phone_missed_rounded;
    case CrmStatus.scheduledVisit:
      return Icons.calendar_month_rounded;
    case CrmStatus.notInterested:
      return Icons.cancel_outlined;
    case CrmStatus.siteVisitDone:
      return Icons.where_to_vote_rounded;
    case CrmStatus.followUp:
      return Icons.schedule_rounded;
    case CrmStatus.interested:
      return Icons.thumb_up_alt_rounded;
    case CrmStatus.proposalSent:
      return Icons.description_rounded;
    case CrmStatus.bookingConfirmed:
      return Icons.verified_rounded;
    case CrmStatus.rejected:
      return Icons.block_rounded;
  }
}

class CrmLeadDetailScreen extends StatefulWidget {
  final String leadId;
  final CrmLead? initialLead;

  const CrmLeadDetailScreen({
    super.key,
    required this.leadId,
    this.initialLead,
  });

  @override
  State<CrmLeadDetailScreen> createState() => _CrmLeadDetailScreenState();
}

class _CrmLeadDetailScreenState extends State<CrmLeadDetailScreen> {
  CrmLead? _lead;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _lead = widget.initialLead;
    _fetchLeadDetails();
  }

  Future<void> _fetchLeadDetails() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<CrmRepository>();
      final lead = await repo.getLeadById(widget.leadId);
      if (mounted) {
        setState(() {
          _lead = lead;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_lead == null) {
            _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          }
        });
      }
    }
  }

  Future<void> _handleRestore() async {
    if (_lead == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Lead'),
        content: Text('Restore "${_lead!.name.isNotEmpty ? _lead!.name : _lead!.phone}" back to active leads?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final repo = context.read<CrmRepository>();
        await repo.restoreFromBin(_lead!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lead restored successfully.'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          _fetchLeadDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to restore: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleMoveToBin() async {
    if (_lead == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Bin'),
        content: Text('Are you sure you want to move "${_lead!.name.isNotEmpty ? _lead!.name : _lead!.phone}" to the Bin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Move to Bin'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final repo = context.read<CrmRepository>();
        await repo.moveToBin(_lead!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lead moved to Bin.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
          _fetchLeadDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to move to bin: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard!'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (_lead == null && _isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(leading: const AppBackButton(), title: const Text('Loading Lead...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_lead == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(leading: const AppBackButton(), title: const Text('Lead Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage ?? 'Lead details could not be found.', style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _fetchLeadDetails, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final lead = _lead!;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(lead, isDark, cardBg, borderColor, textMuted),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bin Alert Banner (if in bin)
                    if (lead.isDeleted) ...[
                      _buildBinAlertBanner(lead, isDark),
                      const SizedBox(height: 16),
                    ],

                    // Hero Profile Banner
                    _buildHeroBanner(lead, isDark, cardBg, borderColor, textMuted),
                    const SizedBox(height: 16),

                    // Grid of Detailed Information Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 900;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    _buildContactDetailsCard(lead, isDark, cardBg, borderColor, textMuted),
                                    const SizedBox(height: 16),
                                    _buildAllocationHistoryCard(lead, isDark, cardBg, borderColor, textMuted),
                                    const SizedBox(height: 16),
                                    _buildCustomFieldsCard(lead, isDark, cardBg, borderColor, textMuted),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    _buildCampaignContextCard(lead, isDark, cardBg, borderColor, textMuted),
                                    const SizedBox(height: 16),
                                    _buildActivityTimelineCard(lead, isDark, cardBg, borderColor, textMuted),
                                    const SizedBox(height: 16),
                                    _buildSystemMetadataCard(lead, isDark, cardBg, borderColor, textMuted),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildContactDetailsCard(lead, isDark, cardBg, borderColor, textMuted),
                              const SizedBox(height: 16),
                              _buildCampaignContextCard(lead, isDark, cardBg, borderColor, textMuted),
                              const SizedBox(height: 16),
                              _buildAllocationHistoryCard(lead, isDark, cardBg, borderColor, textMuted),
                              const SizedBox(height: 16),
                              _buildActivityTimelineCard(lead, isDark, cardBg, borderColor, textMuted),
                              const SizedBox(height: 16),
                              _buildCustomFieldsCard(lead, isDark, cardBg, borderColor, textMuted),
                              const SizedBox(height: 16),
                              _buildSystemMetadataCard(lead, isDark, cardBg, borderColor, textMuted),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(CrmLead lead, bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 8),
          const Icon(Icons.diamond_rounded, size: 18, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 6),
          Text(
            'Lead Mine',
            style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 14, color: textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              lead.name.isNotEmpty ? lead.name : 'Client #${lead.phone}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Action Buttons
          if (lead.isDeleted)
            FilledButton.icon(
              onPressed: _handleRestore,
              icon: const Icon(Icons.restore_from_trash_rounded, size: 15),
              label: const Text('Restore Lead', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _handleMoveToBin,
              icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
              label: const Text('Move to Bin', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444)),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Send WhatsApp Message',
            onPressed: () => showSendWhatsappDialog(context, lead: lead),
            icon: const Icon(Icons.chat_bubble_rounded, size: 18, color: Color(0xFF22C55E)),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Refresh Lead Data',
            onPressed: _fetchLeadDetails,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildBinAlertBanner(CrmLead lead, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 24, color: Color(0xFFEF4444)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Archived / In Bin Lead',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'This lead was removed from the active pipeline and archived into the Bin. You can inspect all its past interactions and restore it back to the active pre-sales pipeline anytime.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF7F1D1D),
                  ),
                ),
                if (lead.deletedAt != null || lead.notInterestedReason != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (lead.deletedAt != null)
                        Text(
                          'Deleted on: ${DateFormat("dd MMM yyyy, hh:mm a").format(lead.deletedAt!.toLocal())}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      if (lead.notInterestedReason != null && lead.notInterestedReason!.isNotEmpty)
                        Text(
                          'Reason: ${lead.notInterestedReason}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _handleRestore,
            icon: const Icon(Icons.restore_from_trash_rounded, size: 14),
            label: const Text('Restore', style: TextStyle(fontSize: 11.5)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(CrmLead lead, bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lead.name.isNotEmpty ? lead.name : 'Unknown Client',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        _buildStatusBadge(lead.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone_rounded, size: 13, color: textMuted),
                        const SizedBox(width: 4),
                        SelectableText(
                          lead.phone,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy Phone',
                          icon: const Icon(Icons.copy_rounded, size: 13),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => _copyToClipboard(lead.phone, 'Phone number'),
                        ),
                        const SizedBox(width: 8),
                        if (lead.customFields['email'] != null || lead.customFields['Email'] != null) ...[
                          Icon(Icons.email_outlined, size: 13, color: textMuted),
                          const SizedBox(width: 4),
                          SelectableText(
                            (lead.customFields['email'] ?? lead.customFields['Email']).toString(),
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Quick Pills Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildPill(
                icon: Icons.campaign_rounded,
                label: 'Campaign: ${lead.campaignName ?? "None"}',
                color: const Color(0xFF8B5CF6),
              ),
              _buildPill(
                icon: lead.telecallerName != null ? Icons.headset_mic_rounded : Icons.hourglass_top_rounded,
                label: 'Allocated: ${lead.telecallerName ?? "Waiting List"}',
                color: lead.telecallerName != null ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              ),
              _buildPill(
                icon: Icons.source_rounded,
                label: 'Source: ${lead.leadSource ?? (lead.isManual ? "Manual" : "Excel")}',
                color: const Color(0xFF0284C7),
              ),
              _buildPill(
                icon: Icons.calendar_today_rounded,
                label: 'Added: ${DateFormat("dd MMM yyyy, hh:mm a").format(lead.createdAt.toLocal())}',
                color: const Color(0xFF64748B),
              ),
              if (lead.isDeleted)
                _buildPill(
                  icon: Icons.delete_rounded,
                  label: 'Archived in Bin',
                  color: const Color(0xFFEF4444),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactDetailsCard(CrmLead lead, bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    final cf = lead.customFields;
    final altPhone = cf['altPhone'] ?? cf['alternatePhone'] ?? cf['Alternate Phone'] ?? cf['Secondary Phone'];
    final email = cf['email'] ?? cf['Email'] ?? cf['emailId'];
    final city = cf['city'] ?? cf['City'];
    final state = cf['state'] ?? cf['State'];
    final country = cf['country'] ?? cf['Country'] ?? 'India';
    final pincode = cf['pincode'] ?? cf['Pincode'] ?? cf['postalCode'] ?? cf['Zip'];
    final address = cf['address'] ?? cf['Address'];
    final company = cf['company'] ?? cf['Company'] ?? cf['organization'];

    return _buildSectionCard(
      title: 'Contact & Personal Profile',
      icon: Icons.person_outline_rounded,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      children: [
        _buildInfoRow('Full Name', lead.name.isNotEmpty ? lead.name : 'N/A', isDark, textMuted),
        _buildInfoRow('Primary Phone', lead.phone, isDark, textMuted, canCopy: true),
        if (altPhone != null)
          _buildInfoRow('Alternate Phone', altPhone.toString(), isDark, textMuted, canCopy: true),
        if (email != null)
          _buildInfoRow('Email Address', email.toString(), isDark, textMuted, canCopy: true),
        if (company != null)
          _buildInfoRow('Organization / Company', company.toString(), isDark, textMuted),
        if (city != null)
          _buildInfoRow('City', city.toString(), isDark, textMuted),
        if (state != null)
          _buildInfoRow('State', state.toString(), isDark, textMuted),
        if (country != null)
          _buildInfoRow('Country', country.toString(), isDark, textMuted),
        if (pincode != null)
          _buildInfoRow('Postal / Zip Code', pincode.toString(), isDark, textMuted),
        if (address != null)
          _buildInfoRow('Full Address', address.toString(), isDark, textMuted),
      ],
    );
  }

  Widget _buildCampaignContextCard(CrmLead lead, bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return _buildSectionCard(
      title: 'Campaign & Acquisition Context',
      icon: Icons.campaign_outlined,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      children: [
        _buildInfoRow('Campaign Name', lead.campaignName ?? 'Unassigned', isDark, textMuted),
        if (lead.campaignId != null)
          _buildInfoRow('Campaign ID', lead.campaignId!, isDark, textMuted, canCopy: true),
        _buildInfoRow('Acquisition Source', lead.leadSource ?? (lead.isManual ? 'MANUAL' : 'EXCEL'), isDark, textMuted),
        _buildInfoRow('Lead Flow Type', lead.isManual ? 'Manual Entry' : 'Automated Ingestion', isDark, textMuted),
        if (lead.channelPartnerName != null)
          _buildInfoRow('Channel Partner', lead.channelPartnerName!, isDark, textMuted),
        if (lead.referenceType != null)
          _buildInfoRow('Reference Type', lead.referenceType!, isDark, textMuted),
        if (lead.referenceName != null)
          _buildInfoRow('Reference Name', lead.referenceName!, isDark, textMuted),
        if (lead.importBatchId != null)
          _buildInfoRow('Import Batch ID', lead.importBatchId!, isDark, textMuted, canCopy: true),
      ],
    );
  }

  Widget _buildAllocationHistoryCard(CrmLead lead, bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    final cf = lead.customFields;
    List<dynamic> history = [];
    if (cf['transferHistory'] is List) {
      history = cf['transferHistory'] as List;
    } else if (cf['transfer_history'] is List) {
      history = cf['transfer_history'] as List;
    }

    final previousTelecaller = cf['previousTelecallerName'] ?? cf['lastTransferredFrom'];

    return _buildSectionCard(
      title: 'Telecaller Allocation & Assignment Journey',
      icon: Icons.history_edu_rounded,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      children: [
        _buildInfoRow(
          'Current Telecaller',
          lead.telecallerName ?? 'Waiting List (WL)',
          isDark,
          textMuted,
          highlight: lead.telecallerName != null,
          highlightColor: const Color(0xFF16A34A),
        ),
        if (lead.assignedToName != null)
          _buildInfoRow('Sales Representative', lead.assignedToName!, isDark, textMuted),
        if (previousTelecaller != null && previousTelecaller.toString().isNotEmpty)
          _buildInfoRow('Previously Assigned To', previousTelecaller.toString(), isDark, textMuted, highlight: true, highlightColor: const Color(0xFF8B5CF6)),

        const SizedBox(height: 8),
        const Text(
          'Reassignment & Transfer Trail:',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        if (history.isEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lead.telecallerName != null
                        ? '${lead.telecallerName} is the primary and only assignee for this lead (No reassignments).'
                        : 'Lead is currently pending in waiting queue.',
                    style: TextStyle(fontSize: 11.5, color: textMuted, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: history.map((item) {
              final map = item is Map ? item : {};
              final from = map['fromName'] ?? map['from'] ?? map['previousTelecallerName'] ?? 'Previous Agent';
              final to = map['toName'] ?? map['to'] ?? map['newTelecallerName'] ?? 'New Agent';
              final by = map['transferredBy'] ?? map['by'] ?? 'Admin';
              final remarks = map['remarks'] ?? map['reason'] ?? '';
              final atRaw = map['transferredAt'] ?? map['at'];
              String? atStr;
              if (atRaw != null) {
                final d = DateTime.tryParse(atRaw.toString());
                if (d != null) atStr = DateFormat('dd MMM yyyy, hh:mm a').format(d.toLocal());
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                              children: [
                                const TextSpan(text: 'Reassigned from '),
                                TextSpan(text: '$from ', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                                const TextSpan(text: '→ '),
                                TextSpan(text: '$to', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                              ],
                            ),
                          ),
                          if (atStr != null || by.toString().isNotEmpty)
                            Text(
                              '${atStr != null ? "$atStr " : ""}(by $by)',
                              style: TextStyle(fontSize: 10, color: textMuted),
                            ),
                          if (remarks.toString().isNotEmpty)
                            Text(
                              'Note: "$remarks"',
                              style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildActivityTimelineCard(CrmLead lead, bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return _buildSectionCard(
      title: 'Activity & Interactions',
      icon: Icons.timeline_rounded,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      children: [
        if (lead.lastCallAt != null)
          _buildInfoRow('Last Call Connected', DateFormat("dd MMM yyyy, hh:mm a").format(lead.lastCallAt!.toLocal()), isDark, textMuted),
        if (lead.scheduledVisitAt != null)
          _buildInfoRow('Scheduled Site Visit', DateFormat("dd MMM yyyy, hh:mm a").format(lead.scheduledVisitAt!.toLocal()), isDark, textMuted),
        if (lead.visitedAt != null)
          _buildInfoRow('Site Visit Completed', DateFormat("dd MMM yyyy, hh:mm a").format(lead.visitedAt!.toLocal()), isDark, textMuted),
        if (lead.latestFollowUp != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 4),
                    Text('Active Scheduled Follow-up', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Scheduled on: ${DateFormat("dd MMM yyyy").format(lead.latestFollowUp!.scheduledDate.toLocal())} at ${lead.latestFollowUp!.scheduledTime}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                if (lead.latestFollowUp!.remarks != null && lead.latestFollowUp!.remarks!.isNotEmpty)
                  Text(
                    'Remarks: "${lead.latestFollowUp!.remarks}"',
                    style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ],
        if (lead.lastCallAt == null && lead.scheduledVisitAt == null && lead.latestFollowUp == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No external call or visit activities logged yet.', style: TextStyle(fontSize: 11.5, color: textMuted, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _buildCustomFieldsCard(CrmLead lead, bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    final cf = lead.customFields;
    final excludedKeys = {
      'transferHistory', 'transfer_history', 'previousTelecallerName', 'lastTransferredFrom',
      'email', 'Email', 'altPhone', 'alternatePhone', 'Alternate Phone', 'city', 'City',
      'state', 'State', 'country', 'Country', 'pincode', 'Pincode', 'address', 'Address',
      'company', 'Company', 'organization', 'importBatchId', 'import_batch_id',
    };

    final extraEntries = cf.entries.where((e) => !excludedKeys.contains(e.key)).toList();

    return _buildSectionCard(
      title: 'Raw Custom Fields & Ingestion Metadata (${extraEntries.length} attributes)',
      icon: Icons.data_object_rounded,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      children: [
        if (extraEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No additional custom fields recorded for this lead.', style: TextStyle(fontSize: 11.5, color: textMuted, fontStyle: FontStyle.italic)),
          )
        else
          Column(
            children: extraEntries.map((e) {
              final val = e.value;
              String displayVal = '';
              if (val is Map || val is List) {
                displayVal = val.toString();
              } else {
                displayVal = val?.toString() ?? 'N/A';
              }
              return _buildInfoRow(e.key, displayVal, isDark, textMuted, canCopy: true);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSystemMetadataCard(CrmLead lead, bool isDark, Color cardBg, Color borderColor, Color textMuted) {
    return _buildSectionCard(
      title: 'System & Audit Metadata',
      icon: Icons.terminal_rounded,
      isDark: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      children: [
        _buildInfoRow('Lead ID (UUID)', lead.id, isDark, textMuted, canCopy: true),
        _buildInfoRow('Platform Scope', lead.scope, isDark, textMuted),
        _buildInfoRow('Date Ingested', DateFormat("yyyy-MM-dd HH:mm:ss").format(lead.createdAt.toLocal()), isDark, textMuted),
        _buildInfoRow('Last Updated', DateFormat("yyyy-MM-dd HH:mm:ss").format(lead.updatedAt.toLocal()), isDark, textMuted),
        _buildInfoRow('Archived / In Bin', lead.isDeleted ? 'YES' : 'NO', isDark, textMuted, highlight: lead.isDeleted, highlightColor: Colors.red),
        if (lead.deletedAt != null)
          _buildInfoRow('Deleted At', DateFormat("yyyy-MM-dd HH:mm:ss").format(lead.deletedAt!.toLocal()), isDark, textMuted),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    bool isDark,
    Color textMuted, {
    bool canCopy = false,
    bool highlight = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                color: highlight
                    ? highlightColor
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
          ),
          if (canCopy)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 13),
              tooltip: 'Copy $label',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              onPressed: () => _copyToClipboard(value, label),
            ),
        ],
      ),
    );
  }

  Widget _buildPill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(CrmStatus status) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
