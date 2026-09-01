import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_back_button.dart';
import '../../domain/crm_models.dart';
import '../crm_providers.dart';

class CrmBinScreen extends ConsumerStatefulWidget {
  const CrmBinScreen({super.key});

  @override
  ConsumerState<CrmBinScreen> createState() => _CrmBinScreenState();
}

class _CrmBinScreenState extends ConsumerState<CrmBinScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFFC5A059).withOpacity(0.18)
        : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('CRM Bin (Recycle & Archive)'),
        leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pre-sales Leads'),
            Tab(text: 'Post-sales Archive'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Bin',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(crmBinLeadsProvider);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildPreSalesBinTab(isDark, cardBg, borderColor, textMuted),
          _buildPostSalesBinTab(isDark, cardBg, borderColor, textMuted),
        ],
      ),
    );
  }

  Widget _buildPreSalesBinTab(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
  ) {
    final binLeadsAsync = ref.watch(crmBinLeadsProvider);

    return binLeadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error loading bin leads: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (leads) {
        if (leads.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 48, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bin is Empty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'No discarded or expired pre-sales leads in the bin.',
                  style: TextStyle(fontSize: 13, color: textMuted),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: leads.length,
          itemBuilder: (context, index) {
            final lead = leads[index];
            final dateStr = lead.deletedAt != null
                ? '${lead.deletedAt!.day}/${lead.deletedAt!.month}/${lead.deletedAt!.year}'
                : (lead.notInterestedAt != null
                    ? '${lead.notInterestedAt!.day}/${lead.notInterestedAt!.month}/${lead.notInterestedAt!.year}'
                    : 'N/A');

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 450;

                  Widget avatarAndDetails = Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.red.withOpacity(0.12),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  lead.name.isNotEmpty ? lead.name : 'Unnamed Lead',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    lead.status.displayName,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 12,
                              runSpacing: 2,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.phone_outlined, size: 13, color: textMuted),
                                    const SizedBox(width: 3),
                                    Text(lead.phone, style: TextStyle(fontSize: 12, color: textMuted)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 13, color: textMuted),
                                    const SizedBox(width: 3),
                                    Text('Moved: $dateStr', style: TextStyle(fontSize: 11, color: textMuted)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  Widget restoreButton = ElevatedButton.icon(
                    onPressed: () => _restoreLead(context, lead),
                    icon: const Icon(Icons.restore_from_trash_rounded, size: 16),
                    label: const Text('Restore', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        avatarAndDetails,
                        const SizedBox(height: 10),
                        restoreButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: avatarAndDetails),
                      const SizedBox(width: 8),
                      restoreButton,
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostSalesBinTab(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.archive_outlined, size: 48, color: Colors.purple),
          ),
          const SizedBox(height: 16),
          Text(
            'Post-Sales Archive',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Completed client handovers & closed tickets archive.',
            style: TextStyle(fontSize: 13, color: textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreLead(BuildContext context, CrmLead lead) async {
    try {
      await ref.read(crmLeadsProvider.notifier).restoreFromBin(lead.id);
      ref.invalidate(crmBinLeadsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lead "${lead.name}" restored to Pre-Sales with status "Not started"!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore lead: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
