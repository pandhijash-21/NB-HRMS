import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../dpr_providers.dart';

class DprDetailScreen extends ConsumerWidget {
  const DprDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dprDetailProvider(id));
    final df = DateFormat('dd MMM yyyy');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('DPR Detail'),
        leading: const AppBackButton(fallbackLocation: '/erp/dpr'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (dpr) {
          return ListView(
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
          );
        },
      ),
    );
  }
}
