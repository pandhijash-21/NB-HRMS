import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/leave_models.dart';
import '../leave_providers.dart';

class AdminLeavesSettingsScreen extends ConsumerWidget {
  const AdminLeavesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(adminLeaveTypesProvider);
    final settingsAsync = ref.watch(adminLeaveSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Leave Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/leaves'),
        ),
        actions: [
          IconButton(
            tooltip: 'Add leave type',
            icon: const Icon(Icons.add),
            onPressed: () => _showTypeDialog(context, ref),
          ),
          IconButton(
            tooltip: 'Run year-end',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _runYearEnd(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Leave Types',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          typesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bronze)),
            error: (e, _) => _errorTile('$e', () => ref.invalidate(adminLeaveTypesProvider)),
            data: (types) {
              if (types.isEmpty) return const Text('No leave types configured.');
              return Column(
                children: types.map((t) => _TypeTile(type: t)).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'System Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bronze)),
            error: (e, _) => _errorTile('$e', () => ref.invalidate(adminLeaveSettingsProvider)),
            data: (settings) {
              if (settings.isEmpty) return const Text('No settings found.');
              return Column(
                children: settings
                    .map((s) => _SettingTile(
                          setting: s,
                          onSave: (value) async {
                            await ref
                                .read(leaveRepositoryProvider)
                                .patchAdminSetting(s.key, value);
                            invalidateLeaveAdminData(ref);
                          },
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _errorTile(String message, VoidCallback onRetry) {
    return Column(
      children: [
        Text(message),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }

  Future<void> _runYearEnd(BuildContext context, WidgetRef ref) async {
    final year = DateTime.now().year;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Run year-end processing?'),
        content: Text('Process carry-forward for year $year?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Run')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(leaveRepositoryProvider).runYearEnd(year);
      invalidateLeaveAdminData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Year-end processing completed.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _showTypeDialog(
    BuildContext context,
    WidgetRef ref, {
    LeaveType? existing,
  }) async {
    final codeController = TextEditingController(text: existing?.code ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    var allowHalfDay = existing?.allowHalfDay ?? true;
    var isActive = existing?.isActive ?? true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add leave type' : 'Edit leave type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code'),
                enabled: existing == null,
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow half day'),
                value: allowHalfDay,
                onChanged: (v) => setLocal(() => allowHalfDay = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: isActive,
                onChanged: (v) => setLocal(() => isActive = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(leaveRepositoryProvider).upsertAdminType({
                    'code': codeController.text.trim(),
                    'name': nameController.text.trim(),
                    'allowHalfDay': allowHalfDay,
                    'isActive': isActive,
                    'applicableTo': existing?.applicableTo ?? 'ALL',
                  });
                  invalidateLeaveAdminData(ref);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    codeController.dispose();
    nameController.dispose();
  }
}

class _TypeTile extends ConsumerWidget {
  const _TypeTile({required this.type});

  final LeaveType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(type.name),
        subtitle: Text('${type.code} · ${type.isActive ? 'Active' : 'Inactive'}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete leave type?'),
                content: Text('Delete ${type.code}?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                ],
              ),
            );
            if (ok != true) return;
            try {
              await ref.read(leaveRepositoryProvider).deleteAdminType(type.code);
              invalidateLeaveAdminData(ref);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
        ),
      ),
    );
  }
}

class _SettingTile extends StatefulWidget {
  const _SettingTile({required this.setting, required this.onSave});

  final LeaveSetting setting;
  final Future<void> Function(String value) onSave;

  @override
  State<_SettingTile> createState() => _SettingTileState();
}

class _SettingTileState extends State<_SettingTile> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.setting.value);
  }

  @override
  void didUpdateWidget(covariant _SettingTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setting.value != widget.setting.value) {
      _controller.text = widget.setting.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.setting.key, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (widget.setting.description.isNotEmpty)
              Text(widget.setting.description, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await widget.onSave(_controller.text.trim());
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
