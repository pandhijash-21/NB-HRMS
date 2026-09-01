import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../domain/crm_models.dart';
import '../crm_providers.dart';

class CrmHeadersScreen extends ConsumerStatefulWidget {
  const CrmHeadersScreen({super.key});

  @override
  ConsumerState<CrmHeadersScreen> createState() => _CrmHeadersScreenState();
}

class _CrmHeadersScreenState extends ConsumerState<CrmHeadersScreen> {
  CrmProject? _selectedProject;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFFC5A059).withOpacity(0.18)
        : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B);
    final primaryGold = isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB);

    final projectsAsync = ref.watch(crmProjectsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_selectedProject == null
            ? 'Projects & Campaign Webhooks'
            : '${_selectedProject!.name} — Campaigns & Headers'),
        leading: _selectedProject != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _selectedProject = null;
                  });
                  ref.read(selectedProjectIdProvider.notifier).setProjectId(null);
                },
              )
            : const AppBackButton(fallbackLocation: '/crm/pre-sales'),
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (_selectedProject == null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => _showAddProjectDialog(context, primaryGold),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => _showAddCampaignDialog(context, _selectedProject!, primaryGold),
                icon: const Icon(Icons.campaign_rounded, size: 18),
                label: const Text('Add Campaign'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(crmProjectsProvider);
              ref.invalidate(crmCampaignsProvider);
              ref.invalidate(crmColumnsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Headers & Projects refreshed'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
      body: _selectedProject == null
          ? _buildProjectsView(projectsAsync, isDark, cardBg, borderColor, textMuted, primaryGold)
          : _buildProjectDetailView(_selectedProject!, isDark, cardBg, borderColor, textMuted, primaryGold),
    );
  }

  // ---------------------------------------------------------------------------
  // View 1: Projects List
  // ---------------------------------------------------------------------------
  Widget _buildProjectsView(
    AsyncValue<List<CrmProject>> projectsAsync,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Info
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B18) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.account_tree_outlined, color: primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Campaigns & Header Ingestion',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select or create a project to manage its marketing campaigns, copy inbound Webhook URLs, and control dynamic table headers.',
                        style: TextStyle(fontSize: 13, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALL PROJECTS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          projectsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (err, _) => Center(child: Text('Error loading projects: $err', style: const TextStyle(color: Colors.red))),
            data: (projects) {
              if (projects.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open_outlined, size: 48, color: textMuted),
                        const SizedBox(height: 14),
                        const Text(
                          'No Projects Created Yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Click "+ Add Project" to create your first real estate project / module.',
                          style: TextStyle(fontSize: 13, color: textMuted),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _showAddProjectDialog(context, primaryColor),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Project'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 2 : 1,
                      mainAxisExtent: 170,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: projects.length,
                    itemBuilder: (context, idx) {
                      final project = projects[idx];
                      return _buildProjectCard(project, isDark, cardBg, borderColor, textMuted, primaryColor);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(
    CrmProject project,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return InkWell(
      onTap: () {
        setState(() {
          _selectedProject = project;
        });
        ref.read(selectedProjectIdProvider.notifier).setProjectId(project.id);
        ref.read(selectedCampaignIdProvider.notifier).setCampaignId(null);
        ref.invalidate(crmCampaignsProvider);
        ref.invalidate(crmColumnsProvider);
        ref.invalidate(crmLeadsProvider);
        ref.invalidate(crmKpiProvider);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.apartment_rounded, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Code: ${project.code}${project.location != null ? " • ${project.location}" : ""}',
                        style: TextStyle(fontSize: 12, color: textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: textMuted),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showEditProjectDialog(context, project);
                    } else if (val == 'delete') {
                      _confirmDeleteProject(context, project);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                  ],
                ),
              ],
            ),
            if (project.description != null && project.description!.isNotEmpty)
              Text(
                project.description!,
                style: TextStyle(fontSize: 12, color: textMuted, fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_outlined, size: 14, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        '${project.campaigns.length} Campaigns',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
                      ),
                    ],
                  ),
                ),
                if (project.startDate != null)
                  Text(
                    'Started: ${dateFormat.format(project.startDate!)}',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // View 2: Project Detail (Campaigns & Headers)
  // ---------------------------------------------------------------------------
  Widget _buildProjectDetailView(
    CrmProject project,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
    Color primaryColor,
  ) {
    final campaignsAsync = ref.watch(crmCampaignsProvider);
    final selectedCampaignId = ref.watch(selectedCampaignIdProvider);
    final columnsAsync = ref.watch(crmColumnsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Summary Banner (Clean, no duplicate New Campaign button)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.apartment_rounded, color: primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Code: ${project.code}${project.location != null ? " • ${project.location}" : ""}',
                        style: TextStyle(fontSize: 13, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Campaigns List Section
          Text(
            'CAMPAIGNS & INBOUND WEBHOOKS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 12),

          campaignsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (err, _) => Text('Error loading campaigns: $err', style: const TextStyle(color: Colors.red)),
            data: (campaigns) {
              if (campaigns.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.campaign_outlined, size: 36, color: textMuted),
                        const SizedBox(height: 10),
                        Text(
                          '0 Campaigns created for this project yet.',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Click "+ Add Campaign" in the top-right toolbar to create your first campaign.',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final effectiveCampaignId =
                  (selectedCampaignId != null && campaigns.any((c) => c.id == selectedCampaignId))
                      ? selectedCampaignId
                      : campaigns.first.id;

              if (effectiveCampaignId != selectedCampaignId) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  ref.read(selectedCampaignIdProvider.notifier).setCampaignId(effectiveCampaignId);
                  ref.invalidate(crmColumnsProvider);
                  ref.invalidate(crmLeadsProvider);
                });
              }

              return Column(
                children: [
                  // Campaign Selector Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: campaigns.map((camp) {
                        final isSelected = camp.id == effectiveCampaignId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            selected: isSelected,
                            onSelected: (_) {
                              ref.read(selectedCampaignIdProvider.notifier).setCampaignId(camp.id);
                              ref.invalidate(crmColumnsProvider);
                            },
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.campaign_outlined,
                                  size: 16,
                                  color: isSelected ? Colors.white : primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  camp.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white.withOpacity(0.25) : (isDark ? Colors.white12 : Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${camp.leadsCount} leads',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSelected ? Colors.white : textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            selectedColor: primaryColor,
                            backgroundColor: isDark ? const Color(0xFF282521) : const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? primaryColor : borderColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selected Campaign Webhook URL & Actions card
                  ...campaigns.where((c) => c.id == effectiveCampaignId).map((activeCamp) {
                    final webhookUrl = activeCamp.webhookUrl;
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.campaign_rounded, color: primaryColor, size: 20),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Campaign: ${activeCamp.name}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (activeCamp.adId != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Ad ID: ${activeCamp.adId}',
                                          style: const TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Edit Campaign',
                                    onPressed: () => _showEditCampaignDialog(context, activeCamp, primaryColor),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                    tooltip: 'Delete Campaign',
                                    onPressed: () => _confirmDeleteCampaign(context, activeCamp),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.link_rounded, color: textMuted, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Inbound Webhook URL (Meta / Google Ads / Website)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141210) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    webhookUrl.isNotEmpty ? webhookUrl : 'Generating webhook endpoint...',
                                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  tooltip: 'Copy Webhook URL',
                                  onPressed: webhookUrl.isNotEmpty
                                      ? () {
                                          Clipboard.setData(ClipboardData(text: webhookUrl));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Webhook URL copied to clipboard! Paste into Meta/Google Ads webhook settings.'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // Headers & Dynamic Columns Management
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TABLE HEADERS & VISIBILITY TOGGLE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Toggle ON to display in Pre-Sales table. Toggle OFF to hide.',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showMergeColumnsDialog(context, primaryColor),
                    icon: const Icon(Icons.call_merge_rounded, size: 16),
                    label: const Text('Merge Columns'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddColumnDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Header'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Columns Table
          columnsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            error: (err, _) => Center(child: Text('Error loading headers: $err', style: const TextStyle(color: Colors.red))),
            data: (cols) {
              if (cols.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.view_column_outlined, size: 40, color: textMuted),
                        const SizedBox(height: 12),
                        const Text('No headers discovered or created for this campaign yet.'),
                        const SizedBox(height: 6),
                        Text(
                          'Incoming webhooks will automatically register headers here with First Letter Capitalization and Underscores.',
                          style: TextStyle(fontSize: 12, color: textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cols.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                  itemBuilder: (context, idx) {
                    final col = cols[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF282521) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      col.label,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.black12,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        col.dataType,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textMuted),
                                      ),
                                    ),
                                    if (col.isSystem) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('DEFAULT', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Key: ${col.columnKey}${col.options.isNotEmpty ? " • Options: [${col.options.join(', ')}]" : ""}',
                                  style: TextStyle(fontSize: 12, color: textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Horizontal Visibility Toggle (Zero vertical overflow)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                col.isVisibleInTable ? 'VISIBLE' : 'HIDDEN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: col.isVisibleInTable ? const Color(0xFF16A34A) : textMuted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Switch(
                                value: col.isVisibleInTable,
                                activeColor: primaryColor,
                                onChanged: (val) async {
                                  try {
                                    await ref.read(crmColumnsProvider.notifier).toggleVisibility(col.id, val);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(val
                                              ? 'Header "${col.label}" is now visible in Pre-Sales table'
                                              : 'Header "${col.label}" hidden from Pre-Sales table'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to update toggle: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          if (!col.isSystem) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              tooltip: 'Delete Column',
                              onPressed: () => _confirmDeleteColumn(context, col),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Add Project
  // ---------------------------------------------------------------------------
  void _showAddProjectDialog(BuildContext context, Color primaryColor) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Real Estate Project'),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Project Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Skyline Heights, Greenwood Residency',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final generated = val.toUpperCase().trim().replaceAll(RegExp(r'[^A-Z0-9_]'), '_');
                      codeCtrl.text = generated;
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 14),

                  const Text('Project Code *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. SKYLINE_HEIGHTS',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Location / City', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Ahmedabad, SG Highway',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Start Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Description (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 3 & 4 BHK Luxury Apartments',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim();
                if (name.isEmpty || code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Project Name and Code')),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);
                try {
                  await ref.read(crmProjectsProvider.notifier).createProject({
                    'name': name,
                    'code': code,
                    'location': locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                    'startDate': selectedDate.toIso8601String(),
                    'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Project "$name" created successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create project: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Create Project'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProjectDialog(BuildContext context, CrmProject project) {
    final nameCtrl = TextEditingController(text: project.name);
    final locationCtrl = TextEditingController(text: project.location ?? '');
    final descCtrl = TextEditingController(text: project.description ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Edit Project: ${project.name}'),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Project Name', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogCtx);
              try {
                await ref.read(crmProjectsProvider.notifier).updateProject(project.id, {
                  'name': name,
                  'location': locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Project "$name" updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update project: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProject(BuildContext context, CrmProject project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text('Are you sure you want to delete project "${project.name}"? All associated campaigns will also be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(crmProjectsProvider.notifier).deleteProject(project.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Project "${project.name}" deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete project: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Add Campaign
  // ---------------------------------------------------------------------------
  void _showAddCampaignDialog(BuildContext context, CrmProject project, Color primaryColor) {
    final nameCtrl = TextEditingController();
    final adIdCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Add Campaign — ${project.name}'),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Campaign Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Meta Lead Ads, Google Search 2026',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Ad ID (ad_id) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: adIdCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 2385194820194, AD_FB_01',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Campaign Launch Date *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                          const Icon(Icons.calendar_today_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Description (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Targeting 3 BHK buyers in Ahmedabad',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: primaryColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'A unique Webhook URL will be automatically generated upon creation.',
                            style: TextStyle(fontSize: 12, color: primaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final adId = adIdCtrl.text.trim();
                if (name.isEmpty || adId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Campaign Name and Ad ID')),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);
                try {
                  final created = await ref.read(crmCampaignsProvider.notifier).createCampaign({
                    'projectId': project.id,
                    'name': name,
                    'adId': adId,
                    'startDate': selectedDate.toIso8601String(),
                    'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    'module': 'PRE_SALES',
                  });

                  ref.read(selectedCampaignIdProvider.notifier).setCampaignId(created.id);
                  ref.invalidate(crmColumnsProvider);
                  ref.invalidate(crmLeadsProvider);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Campaign "$name" created successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create campaign: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Create Campaign'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Add Dynamic Column
  // ---------------------------------------------------------------------------
  void _showAddColumnDialog(BuildContext context) {
    final labelCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    final optionsCtrl = TextEditingController();
    String selectedType = 'TEXT';
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Table Header'),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Header Label *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Client Budget, Unit Preference',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final generated = val
                          .trim()
                          .replaceAll(RegExp(r'[\s\-.]+'), '_')
                          .split('_')
                          .where((p) => p.isNotEmpty)
                          .map((p) => p[0].toUpperCase() + p.substring(1))
                          .join('_');
                      keyCtrl.text = generated;
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 14),

                  const Text('Normalized Key (Underscore & Capitalized) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: keyCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Client_Budget, Unit_Preference',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Data Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedType,
                    items: const [
                      DropdownMenuItem(value: 'TEXT', child: Text('Text')),
                      DropdownMenuItem(value: 'NUMBER', child: Text('Number')),
                      DropdownMenuItem(value: 'DATE', child: Text('Date')),
                      DropdownMenuItem(value: 'SELECT', child: Text('Dropdown (Select)')),
                      DropdownMenuItem(value: 'PHONE', child: Text('Phone Number')),
                      DropdownMenuItem(value: 'EMAIL', child: Text('Email Address')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),

                  if (selectedType == 'SELECT') ...[
                    const SizedBox(height: 14),
                    const Text('Dropdown Choices (Comma separated)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: optionsCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 1 BHK, 2 BHK, 3 BHK, Villa',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mandatory / Required Field'),
                    value: isRequired,
                    onChanged: (val) => setDialogState(() => isRequired = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final label = labelCtrl.text.trim();
                final key = keyCtrl.text.trim();
                if (label.isEmpty || key.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Header Label and Key')),
                  );
                  return;
                }

                List<String> options = [];
                if (selectedType == 'SELECT' && optionsCtrl.text.trim().isNotEmpty) {
                  options = optionsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                }

                Navigator.pop(dialogCtx);
                try {
                  await ref.read(crmColumnsProvider.notifier).createColumn({
                    'module': 'PRE_SALES',
                    'columnKey': key,
                    'label': label,
                    'dataType': selectedType,
                    'options': options,
                    'isRequired': isRequired,
                    'isVisibleInTable': true,
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Header "$label" added successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add header: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Add Header'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Merge Columns
  // ---------------------------------------------------------------------------
  void _showMergeColumnsDialog(BuildContext context, Color primaryColor) {
    final cols = ref.read(crmColumnsProvider).value ?? [];
    if (cols.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 columns are required to perform a merge.')),
      );
      return;
    }

    String sourceKey = cols[0].columnKey;
    String targetKey = cols[1].columnKey;
    String retainedLabel = cols[1].label;
    final labelCtrl = TextEditingController(text: retainedLabel);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Merge Columns'),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      'Merge two columns that have the same meaning (e.g. "client_name" into "Name"). All existing lead data from Source will be transferred to Target, and Source column will be deleted.',
                      style: TextStyle(fontSize: 12, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Source Column (To be merged & removed) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: sourceKey,
                    items: cols
                        .map((c) => DropdownMenuItem(
                              value: c.columnKey,
                              child: Text('${c.label} (${c.columnKey})', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => sourceKey = val);
                      }
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),

                  const Text('Target Column (To keep & store data) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: targetKey,
                    items: cols
                        .map((c) => DropdownMenuItem(
                              value: c.columnKey,
                              child: Text('${c.label} (${c.columnKey})', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          targetKey = val;
                          final match = cols.firstWhere((c) => c.columnKey == val);
                          retainedLabel = match.label;
                          labelCtrl.text = match.label;
                        });
                      }
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),

                  const Text('Final Retained Header Label *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Client Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                if (sourceKey == targetKey) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Source and Target columns cannot be the same')),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);
                try {
                  final res = await ref.read(crmColumnsProvider.notifier).mergeColumns(
                    sourceKey: sourceKey,
                    targetKey: targetKey,
                    targetLabel: labelCtrl.text.trim(),
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message']?.toString() ?? 'Columns merged successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to merge columns: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Confirm & Merge'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCampaignDialog(BuildContext context, CrmCampaign camp, Color primaryColor) {
    final nameCtrl = TextEditingController(text: camp.name);
    final adIdCtrl = TextEditingController(text: camp.adId ?? '');
    final descCtrl = TextEditingController(text: camp.description ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Edit Campaign — ${camp.name}'),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Campaign Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: adIdCtrl,
                decoration: const InputDecoration(labelText: 'Ad ID', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogCtx);
              try {
                await ref.read(crmCampaignsProvider.notifier).updateCampaign(camp.id, {
                  'name': name,
                  'adId': adIdCtrl.text.trim().isEmpty ? null : adIdCtrl.text.trim(),
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                });
                ref.invalidate(crmCampaignsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Campaign "$name" updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update campaign: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteColumn(BuildContext context, CrmColumnConfig col) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Header?'),
        content: Text('Are you sure you want to delete header "${col.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(crmColumnsProvider.notifier).deleteColumn(col.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Header "${col.label}" removed')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete header: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCampaign(BuildContext context, CrmCampaign camp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Campaign?'),
        content: Text('Are you sure you want to delete campaign "${camp.name}"? Leads and webhook configurations under this campaign will be archived.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(crmCampaignsProvider.notifier).deleteCampaign(camp.id);
                ref.read(selectedCampaignIdProvider.notifier).setCampaignId(null);
                ref.invalidate(crmCampaignsProvider);
                ref.invalidate(crmProjectsProvider);
                ref.invalidate(crmColumnsProvider);
                ref.invalidate(crmLeadsProvider);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Campaign "${camp.name}" deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete campaign: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete Campaign'),
          ),
        ],
      ),
    );
  }
}
