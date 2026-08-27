import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/structure_models.dart';
import '../project_providers.dart';

class ProjectStructureScreen extends ConsumerWidget {
  const ProjectStructureScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final canWrite = Permissions.hasPermission(auth.permissions, 'PROJECTS', 'WRITE');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final towersAsync = ref.watch(projectTowersProvider(projectId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(
          projectAsync.asData?.value.name ?? 'Project Structure',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: const AppBackButton(fallbackLocation: '/erp/projects'),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            label: 'Refresh',
            onPressed: () {
              ref.invalidate(projectTowersProvider(projectId));
              ref.invalidate(projectDetailProvider(projectId));
            },
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/erp/structure/$projectId/towers/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add Tower'),
            )
          : null,
      body: towersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (towers) {
          if (towers.isEmpty) {
            return const Center(
              child: Text('No towers yet. Tap Add Tower to start the project structure.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: towers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _TowerCard(
              tower: towers[i],
              canWrite: canWrite,
              projectId: projectId,
            ),
          );
        },
      ),
    );
  }
}

class _TowerCard extends ConsumerWidget {
  const _TowerCard({
    required this.tower,
    required this.canWrite,
    required this.projectId,
  });

  final ErpProjectTower tower;
  final bool canWrite;
  final String projectId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tower?'),
        content: Text(
          'This will delete ${tower.name} and all ${tower.unitCount} units in it.',
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
    try {
      await ref.read(projectRepositoryProvider).deleteTower(projectId, tower.id);
      ref.invalidate(projectTowersProvider(projectId));
      ref.invalidate(projectsListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2563eb).withValues(alpha: 0.12),
                  child: Text(
                    tower.name.isNotEmpty ? tower.name[0].toUpperCase() : 'T',
                    style: const TextStyle(
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
                        tower.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (tower.phase != null && tower.phase!.isNotEmpty) tower.phase,
                          '${tower.floorCount} floors × ${tower.flatsPerFloor} flats = ${tower.plannedUnits} units',
                          tower.hasGround ? 'GF flats (from 0)' : 'GF parking (from 1)',
                          if (tower.basementCount > 0) '${tower.basementCount} basement(s)',
                          tower.statusCode,
                        ].whereType<String>().join(' • '),
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
                        tooltip: 'Manage Tower',
                        onPressed: () => context.go(
                          '/erp/structure/$projectId/towers/${tower.id}/units',
                        ),
                        icon: const Icon(Icons.grid_view_rounded),
                        color: const Color(0xFF2563eb),
                      ),
                      IconButton(
                        tooltip: 'Edit Tower',
                        onPressed: () =>
                            context.go('/erp/structure/$projectId/towers/${tower.id}'),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete Tower',
                        onPressed: () => _delete(context, ref),
                        icon: const Icon(Icons.delete_outline),
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
