import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/project_repository.dart';
import '../../domain/project_models.dart';
import '../bloc/erp_projects_bloc.dart';

class ProjectsListScreen extends StatelessWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ErpProjectsBloc>(
      create: (ctx) => ErpProjectsBloc(
        projectRepository: ctx.read<ProjectRepository>(),
      )..add(const ErpProjectsLoadRequested()),
      child: const _ProjectsListView(),
    );
  }
}

class _ProjectsListView extends StatelessWidget {
  const _ProjectsListView();

  Future<void> _delete(BuildContext context, ErpProject p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          'This will permanently delete ${p.name} along with its towers, units, and documents.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (context.mounted) {
      context.read<ErpProjectsBloc>().add(ErpProjectDeleted(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final canWrite = Permissions.canWriteProjects(auth.permissions, auth.user?.role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<ErpProjectsBloc, ErpProjectsState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
          );
        } else if (state.actionMessage != null && state.actionMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!), backgroundColor: Colors.green),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
            elevation: 0,
            title: const Text('Projects', style: TextStyle(fontWeight: FontWeight.w700)),
            leading: const AppBackButton(fallbackLocation: '/erp/home'),
            actions: [
              HeaderActionButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                label: 'Refresh',
                onPressed: () => context.read<ErpProjectsBloc>().add(const ErpProjectsLoadRequested()),
              ),
            ],
          ),
          floatingActionButton: canWrite
              ? FloatingActionButton.extended(
                  onPressed: () => context.go('/erp/projects/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Project'),
                )
              : null,
          body: () {
            if (state.status == LoadStatus.loading && state.projects.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == LoadStatus.failure && state.projects.isEmpty) {
              return Center(child: Text(state.errorMessage ?? 'Failed to load projects'));
            }
            final items = state.projects;
            if (items.isEmpty) {
              return const Center(child: Text('No projects yet. Tap Add Project.'));
            }
            return RepaintBoundary(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final p = items[i];
                  return Material(
                    color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                              : const Color(0xFFCFD8DC),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF2563eb).withValues(alpha: 0.12),
                            child: Text(
                              p.displayId,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563eb),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    p.organization?.name,
                                    p.institute?.name,
                                    p.statusCode,
                                    '${p.towerCount} tower(s)',
                                  ].where((s) => s != null && s.toString().isNotEmpty).join(' • '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (canWrite)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Manage Structure',
                                  onPressed: () =>
                                      context.go('/erp/structure/${p.id}'),
                                  icon: const Icon(Icons.account_tree_outlined),
                                  color: const Color(0xFF2563eb),
                                ),
                                IconButton(
                                  tooltip: 'Edit Project',
                                  onPressed: () => context.go('/erp/projects/${p.id}'),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete Project',
                                  onPressed: () => _delete(context, p),
                                  icon: const Icon(Icons.delete_outline),
                                  color: const Color(0xFFEF4444),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }(),
        );
      },
    );
  }
}
