import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/bloc_async_body.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';
import '../bloc/crm_bin_bloc.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final module = _tabController.index == 0 ? 'PRE_SALES' : 'POST_SALES';
      context.read<CrmBinBloc>().add(CrmBinModuleChanged(module));
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
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
                  context.read<CrmBinBloc>().add(const CrmBinRefreshRequested());
                },
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildPreSalesBinTab(context, state, isDark, cardBg, borderColor, textMuted),
              _buildPostSalesBinTab(isDark, cardBg, borderColor, textMuted),
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

            return RepaintBoundary(
              child: Container(
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

                    Widget restoreButton = ElevatedButton.icon(
                      onPressed: state.isActing
                          ? null
                          : () => context
                              .read<CrmBinBloc>()
                              .add(CrmBinLeadRestored(lead.id)),
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
