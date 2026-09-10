import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../data/dpr_repository.dart';
import '../bloc/erp_dpr_bloc.dart';

class DprDetailScreen extends StatelessWidget {
  const DprDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ErpDprBloc(dprRepository: ctx.read<DprRepository>())
        ..add(ErpDprDetailRequested(id)),
      child: _DprDetailView(id: id),
    );
  }
}

class _DprDetailView extends StatelessWidget {
  const _DprDetailView({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ErpDprBloc>().state;
    final df = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('DPR Detail'),
        leading: const AppBackButton(fallbackLocation: '/erp/dpr'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ErpDprBloc>().add(ErpDprDetailRequested(id)),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.status == LoadStatus.loading && state.selectedDpr == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == LoadStatus.failure && state.selectedDpr == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.errorMessage ?? 'Failed to load DPR details'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => context.read<ErpDprBloc>().add(ErpDprDetailRequested(id)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final dpr = state.selectedDpr;
          if (dpr == null) {
            return const Center(child: Text('DPR not found'));
          }
          return RepaintBoundary(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(dpr.dprNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                const SizedBox(height: 8),
                Text(
                  [
                    dpr.project?.name ?? dpr.projectId,
                    df.format(dpr.reportDate),
                    if (dpr.createdByName != null) 'By ${dpr.createdByName}',
                  ].join(' · '),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < dpr.lines.length; i++)
                  Card(
                    child: ListTile(
                      title: Text('${i + 1}. ${dpr.lines[i].activityName ?? 'Activity'} · ${dpr.lines[i].taskName ?? 'Task'}'),
                      subtitle: Text(
                        [
                          dpr.lines[i].contractorName,
                          dpr.lines[i].towerName,
                          if (dpr.lines[i].floorNo != null) 'Floor ${dpr.lines[i].floorNo}',
                          dpr.lines[i].unitLabel,
                          'Qty ${dpr.lines[i].consumedQty}',
                          if (dpr.lines[i].completionPct != null) '${dpr.lines[i].completionPct}%',
                          dpr.lines[i].statusCode,
                        ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
