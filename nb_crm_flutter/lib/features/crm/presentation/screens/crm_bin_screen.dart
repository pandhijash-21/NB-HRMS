import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/tour/models/tour_models.dart';
import '../../../../core/tour/widgets/tour_target.dart';
import '../../../../core/widgets/bloc_async_body.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';
import '../bloc/crm_bin_bloc.dart';
import '../widgets/crm_scope_selector.dart';

class CrmBinScreen extends StatelessWidget {
  const CrmBinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrmBinBloc>(
      create: (ctx) => CrmBinBloc(
        crmRepository: ctx.read<CrmRepository>(),
      )..add(const CrmBinLoadRequested(module: 'PRE_SALES')),
      child: const _CrmBinView(),
    );
  }
}

class _CrmBinView extends StatefulWidget {
  const _CrmBinView();

  @override
  State<_CrmBinView> createState() => _CrmBinViewState();
}

class _CrmBinViewState extends State<_CrmBinView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final module = _tabController.index == 0 ? 'PRE_SALES' : 'POST_SALES';
      setState(() => _selectedIds.clear());
      context.read<CrmBinBloc>().add(CrmBinModuleChanged(module));
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmPermanentDelete(List<String> ids) async {
    if (ids.isEmpty) return;
    final bloc = context.read<CrmBinBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          ids.length == 1
              ? 'This lead will be removed forever and cannot be restored.'
              : '${ids.length} leads will be removed forever and cannot be restored.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (ids.length == 1) {
      bloc.add(CrmBinLeadPermanentlyDeleted(ids.first));
    } else {
      bloc.add(CrmBinBulkPermanentlyDeleted(ids));
    }
    setState(() => _selectedIds.clear());
  }

  void _restoreSelected(BuildContext context) {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    context.read<CrmBinBloc>().add(CrmBinBulkRestored(ids));
    setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFFC5A059).withValues(alpha: 0.18)
        : const Color(0xFFE2E8F0);
    final textMuted = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B);

    return BlocConsumer<CrmBinBloc, CrmBinState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state.actionSuccessMessage != null &&
            state.actionSuccessMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('CRM Bin (Recycle & Archive)'),
            leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
            backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: TourTarget(
                id: TourIds.step('crm.bin', 2),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Pre-sales Leads'),
                    Tab(text: 'Post-sales Archive'),
                  ],
                ),
              ),
            ),
            actions: [
              CrmScopeSelectorWidget(
                onScopeChanged: () {
                  setState(() => _selectedIds.clear());
                  context.read<CrmBinBloc>().add(const CrmBinRefreshRequested());
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh Bin',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  context.read<CrmBinBloc>().add(const CrmBinRefreshRequested());
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              if (_selectedIds.isNotEmpty)
                Material(
                  color: isDark ? const Color(0xFF1E1B18) : const Color(0xFFEFF6FF),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          '${_selectedIds.length} selected',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: state.isActing ? null : () => setState(() => _selectedIds.clear()),
                          child: const Text('Clear'),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton.icon(
                          onPressed: state.isActing ? null : () => _restoreSelected(context),
                          icon: const Icon(Icons.restore_from_trash_rounded, size: 16),
                          label: Text('Restore ${_selectedIds.length}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: state.isActing
                              ? null
                              : () => _confirmPermanentDelete(_selectedIds.toList()),
                          icon: const Icon(Icons.delete_forever_rounded, size: 16),
                          label: Text('Delete ${_selectedIds.length}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPreSalesBinTab(context, state, isDark, cardBg, borderColor, textMuted),
                    _buildPostSalesBinTab(isDark, cardBg, borderColor, textMuted),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreSalesBinTab(
    BuildContext context,
    CrmBinState state,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMuted,
  ) {
    return BlocAsyncBody<List<CrmLead>>(
      status: state.status,
      data: state.leads,
      errorMessage: state.errorMessage,
      onRetry: () => context.read<CrmBinBloc>().add(const CrmBinRefreshRequested()),
      isEmpty: (leads) => leads.isEmpty,
      builder: (leads) {
        final allSelected = leads.isNotEmpty && leads.every((l) => _selectedIds.contains(l.id));
        final someSelected = leads.any((l) => _selectedIds.contains(l.id));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected
                        ? true
                        : (someSelected ? null : false),
                    tristate: true,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.addAll(leads.map((l) => l.id));
                        } else {
                          for (final l in leads) {
                            _selectedIds.remove(l.id);
                          }
                        }
                      });
                    },
                  ),
                  Text(
                    'Select all (${leads.length})',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: leads.length,
                itemBuilder: (context, index) {
                  final lead = leads[index];
                  final selected = _selectedIds.contains(lead.id);
                  final dateStr = lead.deletedAt != null
                      ? '${lead.deletedAt!.day}/${lead.deletedAt!.month}/${lead.deletedAt!.year}'
                      : (lead.notInterestedAt != null
                          ? '${lead.notInterestedAt!.day}/${lead.notInterestedAt!.month}/${lead.notInterestedAt!.year}'
                          : 'N/A');

                  return RepaintBoundary(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                            : cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? const Color(0xFF2563EB) : borderColor,
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 520;

                          Widget avatarAndDetails = Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedIds.add(lead.id);
                                    } else {
                                      _selectedIds.remove(lead.id);
                                    }
                                  });
                                },
                              ),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.red.withValues(alpha: 0.12),
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
                                            color: Colors.red.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            lead.status.displayName,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
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

                          Widget actions = Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: state.isActing
                                    ? null
                                    : () => context.read<CrmBinBloc>().add(CrmBinLeadRestored(lead.id)),
                                icon: const Icon(Icons.restore_from_trash_rounded, size: 16),
                                label: const Text('Restore', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: state.isActing
                                    ? null
                                    : () => _confirmPermanentDelete([lead.id]),
                                icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Color(0xFFDC2626)),
                                label: const Text(
                                  'Delete',
                                  style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFDC2626)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          );

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                avatarAndDetails,
                                const SizedBox(height: 10),
                                actions,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: avatarAndDetails),
                              const SizedBox(width: 8),
                              actions,
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
              color: Colors.purple.withValues(alpha: 0.12),
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
}
