import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/task_models.dart';
import '../tasks_providers.dart';
import '../widgets/assign_task_dialog.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/task_gantt_chart.dart';

class TasksHubScreen extends ConsumerStatefulWidget {
  const TasksHubScreen({super.key});

  @override
  ConsumerState<TasksHubScreen> createState() => _TasksHubScreenState();
}

class _TasksHubScreenState extends ConsumerState<TasksHubScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(myTasksProvider);
    final summary = ref.watch(taskSummaryProvider).asData?.value;
    final reportees = ref.watch(taskReporteesProvider).asData?.value ?? const [];
    final reviewBadge = summary?.review ?? 0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(
          'Tasks',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        leading: const AppBackButton(),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh',
            label: 'Refresh',
            icon: Icon(Icons.refresh_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF212F3D)),
            onPressed: () {
              ref.invalidate(myTasksProvider);
              ref.invalidate(taskSummaryProvider);
              ref.invalidate(taskReporteesProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF212F3D),
          indicatorColor: const Color(0xFFC5A059),
          tabs: [
            Tab(text: reviewBadge > 0 ? 'Board ($reviewBadge to review)' : 'Board'),
            const Tab(text: 'Gantt'),
          ],
        ),
      ),
      floatingActionButton: reportees.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAssignTaskDialog(context, ref),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Assign task'),
            ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load tasks: $e')),
        data: (tasks) {
          return TabBarView(
            controller: _tabs,
            children: [
              _BoardTab(tasks: tasks),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: TaskGanttChart(
                  tasks: tasks,
                  onSelect: (t) => showTaskDetailSheet(context, t),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BoardTab extends ConsumerWidget {
  const _BoardTab({required this.tasks});

  final List<WorkTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authMeId);
    final review = tasks.where((t) => t.assigner.id == me && t.status == 'COMPLETED').toList();
    final extra = tasks.where((t) => t.extraApprover?.id == me && t.extraApprovalStatus == 'PENDING').toList();
    final mine = tasks.where((t) => t.assignee.id == me && !t.isClosed).toList();
    final assigned = tasks.where((t) => t.assigner.id == me).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (review.isNotEmpty) _section(context, 'Waiting for your review', 'Assignee marked complete — approve, reject, or ask for changes', review),
        if (extra.isNotEmpty) _section(context, 'Extra approvals', 'Someone asked you to sign off', extra),
        _section(context, 'My tasks', 'Assigned to you', mine),
        _section(context, 'Assigned by me', 'Only 1st reporting can assign — people who list you as 1st reporting', assigned),
      ],
    );
  }

  Widget _section(BuildContext context, String title, String subtitle, List<WorkTask> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF212F3D))),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF607D8B))),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text('None', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38))
          else
            ...items.map((t) => _TaskCard(task: t)),
        ],
      ),
    );
  }
}

final authMeId = Provider<String>((ref) {
  return ref.watch(authNotifierProvider).user?.id ?? '';
});

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final WorkTask task;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? const Color(0xFFC5A059).withOpacity(0.18) : const Color(0xFFCFD8DC)),
      ),
      child: ListTile(
        onTap: () => showTaskDetailSheet(context, task),
        title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${task.assignee.name} · ${taskStatusLabel(task.status)} · due ${_short(task.deadline)}'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  String _short(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}
