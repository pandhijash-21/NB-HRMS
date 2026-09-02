import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../../admin/domain/admin_models.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../rbac/presentation/rbac_providers.dart';
import '../../domain/org_tree_models.dart';
import '../org_tree_providers.dart';
import '../widgets/org_graph_view.dart';
import '../widgets/org_tree_chrome.dart';
import '../widgets/org_tree_outline.dart';

class EmployeeTreeScreen extends ConsumerStatefulWidget {
  const EmployeeTreeScreen({super.key});

  @override
  ConsumerState<EmployeeTreeScreen> createState() => _EmployeeTreeScreenState();
}

class _EmployeeTreeScreenState extends ConsumerState<EmployeeTreeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _search.addListener(() => setState(() => _query = _search.text));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(orgTreeListProvider);
    ref.invalidate(selectedOrgTreeProvider);
    ref.invalidate(activeOrgTreeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = Permissions.isAdmin(ref.watch(authNotifierProvider).user?.role);
    final treeAsync = ref.watch(selectedOrgTreeProvider);
    final listAsync = ref.watch(orgTreeListProvider);
    final gold = isDark ? const Color(0xFFC5A059) : const Color(0xFF1D4ED8);
    final fg = isDark ? Colors.white : const Color(0xFF212F3D);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        leading: const AppBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employee tree',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: fg, letterSpacing: -0.4),
            ),
            treeAsync.maybeWhen(
              data: (t) => Text(
                t == null
                    ? 'No published tree yet'
                    : t.isActive
                        ? 'Live · ${t.groupingLabel}'
                        : t.groupingLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF64748B),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          HeaderActionButton(
            tooltip: 'Refresh',
            label: 'Refresh',
            icon: Icon(Icons.refresh_rounded, size: 18, color: fg),
            onPressed: _refresh,
          ),
          if (isAdmin)
            HeaderActionButton(
              tooltip: 'Generate tree',
              label: 'Generate',
              icon: Icon(Icons.auto_awesome_rounded, size: 18, color: gold),
              onPressed: () => _openGenerate(context),
            ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: gold,
          unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF64748B),
          indicatorColor: gold,
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_rounded, size: 18), text: 'Tree'),
            Tab(icon: Icon(Icons.hub_rounded, size: 18), text: 'Graph'),
            Tab(icon: Icon(Icons.support_agent_rounded, size: 18), text: 'Contacts'),
          ],
        ),
      ),
      body: Column(
        children: [
          _Toolbar(
            isDark: isDark,
            isAdmin: isAdmin,
            listAsync: listAsync,
            selectedId: ref.watch(selectedOrgTreeIdProvider),
            search: _search,
            onSelect: (id) => ref.read(selectedOrgTreeIdProvider.notifier).set(id),
            onPublish: isAdmin ? _publish : null,
            onRename: isAdmin ? _rename : null,
            onRegenerate: isAdmin ? _regenerate : null,
            onDelete: isAdmin ? _delete : null,
          ),
          Expanded(
            child: treeAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load tree',
                subtitle: e.toString(),
                actionLabel: 'Retry',
                onAction: _refresh,
              ),
              data: (tree) {
                if (tree == null) {
                  return _EmptyState(
                    icon: Icons.account_tree_outlined,
                    title: 'No employee tree yet',
                    subtitle: isAdmin
                        ? 'Generate a department → lead → team map from live users. Only Admin can publish or edit it.'
                        : 'Admin has not published an employee tree yet.',
                    actionLabel: isAdmin ? 'Generate tree' : null,
                    onAction: isAdmin ? () => _openGenerate(context) : null,
                  );
                }
                return TabBarView(
                  controller: _tabs,
                  children: [
                    OrgTreeOutline(root: tree.snapshot.root, query: _query),
                    OrgGraphView(root: tree.snapshot.root, query: _query),
                    _ContactsTab(tree: tree, isAdmin: isAdmin, query: _query),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGenerate(BuildContext context) async {
    final created = await showModalBottomSheet<OrgTreeSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GenerateSheet(),
    );
    if (created == null) return;
    ref.read(selectedOrgTreeIdProvider.notifier).set(created.id);
    await _refresh();
  }

  Future<void> _publish(OrgTreeSummary tree) async {
    try {
      await ref.read(orgTreeRepositoryProvider).update(tree.id, isActive: true);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tree published for everyone')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _rename(OrgTreeSummary tree) async {
    final ctrl = TextEditingController(text: tree.name);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename tree'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (next == null || next.isEmpty) return;
    try {
      await ref.read(orgTreeRepositoryProvider).update(tree.id, name: next);
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _regenerate(OrgTreeSummary tree) async {
    try {
      await ref.read(orgTreeRepositoryProvider).regenerate(tree.id);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tree regenerated from current users')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(OrgTreeSummary tree) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this tree?'),
        content: Text('“${tree.name}” will be removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDA1E28)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(orgTreeRepositoryProvider).delete(tree.id);
      ref.read(selectedOrgTreeIdProvider.notifier).set(null);
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.isDark,
    required this.isAdmin,
    required this.listAsync,
    required this.selectedId,
    required this.search,
    required this.onSelect,
    this.onPublish,
    this.onRename,
    this.onRegenerate,
    this.onDelete,
  });

  final bool isDark;
  final bool isAdmin;
  final AsyncValue<List<OrgTreeSummary>> listAsync;
  final String? selectedId;
  final TextEditingController search;
  final ValueChanged<String?> onSelect;
  final Future<void> Function(OrgTreeSummary tree)? onPublish;
  final Future<void> Function(OrgTreeSummary tree)? onRename;
  final Future<void> Function(OrgTreeSummary tree)? onRegenerate;
  final Future<void> Function(OrgTreeSummary tree)? onDelete;

  @override
  Widget build(BuildContext context) {
    final trees = listAsync.asData?.value ?? const <OrgTreeSummary>[];
    final selected = trees.where((t) => t.id == selectedId).firstOrNull ??
        trees.where((t) => t.isActive).firstOrNull ??
        (trees.isNotEmpty ? trees.first : null);
    final wide = MediaQuery.sizeOf(context).width >= 840;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171412) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.14) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: wide ? 280 : double.infinity,
            child: TextField(
              controller: search,
              decoration: InputDecoration(
                hintText: 'Search people, departments, contacts…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          if (trees.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 260 : 420),
              child: DropdownButtonFormField<String>(
                value: selected?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Saved tree',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  for (final t in trees)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text(
                        '${t.isActive ? '● ' : ''}${t.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: onSelect,
              ),
            ),
          if (isAdmin && selected != null) ...[
            _MiniAction(
              icon: Icons.campaign_rounded,
              label: selected.isActive ? 'Published' : 'Publish',
              onTap: selected.isActive ? null : () => onPublish?.call(selected),
            ),
            _MiniAction(
              icon: Icons.edit_rounded,
              label: 'Rename',
              onTap: () => onRename?.call(selected),
            ),
            _MiniAction(
              icon: Icons.sync_rounded,
              label: 'Rebuild',
              onTap: () => onRegenerate?.call(selected),
            ),
            _MiniAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              danger: true,
              onTap: () => onDelete?.call(selected),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = danger
        ? const Color(0xFFEF4444)
        : (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF334155));
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB))
                      .withValues(alpha: 0.14),
                ),
                child: Icon(icon, size: 36, color: isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB)),
              ),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? const Color(0xFFD6CBB4) : const Color(0xFF64748B), height: 1.4),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerateSheet extends ConsumerStatefulWidget {
  const _GenerateSheet();

  @override
  ConsumerState<_GenerateSheet> createState() => _GenerateSheetState();
}

class _GenerateSheetState extends ConsumerState<_GenerateSheet> {
  final _name = TextEditingController(text: 'Company tree');
  String _grouping = 'DEPARTMENT_LEAD';
  bool _publish = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tree = await ref.read(orgTreeRepositoryProvider).create(
            name: _name.text.trim().isEmpty ? 'Employee tree' : _name.text.trim(),
            grouping: _grouping,
            publish: _publish,
          );
      if (mounted) Navigator.pop(context, tree);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1816) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text('Generate employee tree', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Builds a live map from users: department → lead → people on that team. Only Admin can generate, edit, or delete.',
                style: TextStyle(color: isDark ? const Color(0xFFD6CBB4) : const Color(0xFF64748B), height: 1.35),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tree name'),
              ),
              const SizedBox(height: 14),
              Text('Priority layout', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155))),
              const SizedBox(height: 8),
              _LayoutChoice(
                selected: _grouping == 'DEPARTMENT_LEAD',
                title: 'Department → lead → team',
                subtitle: 'Teams grouped by department, with leads and the people under them',
                icon: Icons.hub_rounded,
                onTap: () => setState(() => _grouping = 'DEPARTMENT_LEAD'),
              ),
              const SizedBox(height: 8),
              _LayoutChoice(
                selected: _grouping == 'REPORTING_CHAIN',
                title: 'Reporting chain',
                subtitle: 'Who reports to whom, from the top down',
                icon: Icons.device_hub_rounded,
                onTap: () => setState(() => _grouping = 'REPORTING_CHAIN'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publish for everyone'),
                subtitle: const Text('Staff can view this tree immediately'),
                value: _publish,
                onChanged: (v) => setState(() => _publish = v),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_busy ? 'Generating…' : 'Generate tree'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayoutChoice extends StatelessWidget {
  const _LayoutChoice({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFFC5A059) : const Color(0xFF2563EB);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? accent.withValues(alpha: isDark ? 0.14 : 0.08) : Colors.transparent,
          border: Border.all(color: selected ? accent : (isDark ? Colors.white12 : const Color(0xFFD6DEE4))),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFD6CBB4) : const Color(0xFF64748B))),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: accent),
          ],
        ),
      ),
    );
  }
}

class _ContactsTab extends ConsumerWidget {
  const _ContactsTab({required this.tree, required this.isAdmin, this.query = ''});

  final OrgTreeSummary tree;
  final bool isAdmin;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = query.trim().toLowerCase();
    final contacts = q.isEmpty
        ? tree.contacts
        : tree.contacts.where((c) {
            final hay = [
              c.moduleName,
              c.employeeName,
              c.designation,
              c.department,
              c.note,
            ].whereType<String>().join(' ').toLowerCase();
            return hay.contains(q);
          }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Who to contact',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Text(
          'Permission owners for this organization. Ask these people when you need access or approvals.',
          style: TextStyle(color: isDark ? const Color(0xFFD6CBB4) : const Color(0xFF64748B), height: 1.35),
        ),
        const SizedBox(height: 16),
        if (isAdmin)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => _editContacts(context, ref),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit contacts'),
            ),
          ),
        const SizedBox(height: 12),
        if (tree.contacts.isEmpty)
          _EmptyState(
            icon: Icons.support_agent_outlined,
            title: 'No contacts mapped yet',
            subtitle: isAdmin
                ? 'Assign a person to each permission module so staff know who to reach.'
                : 'Admin has not mapped permission contacts yet.',
          )
        else if (contacts.isEmpty)
          _EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No matching contacts',
            subtitle: 'Try a different name, permission, or department.',
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 600 ? 2 : 1);
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final contact in contacts)
                    SizedBox(
                      width: cols == 1 ? c.maxWidth : (c.maxWidth - 12 * (cols - 1)) / cols,
                      child: _ContactCard(
                        contact: contact,
                        onDelete: isAdmin ? () => _deleteContact(context, ref, contact) : null,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<void> _editContacts(BuildContext context, WidgetRef ref) async {
    List<({String key, String name})> modules;
    try {
      final loaded = await ref.read(systemModulesProvider.future);
      modules = loaded.map((m) => (key: m.key, name: m.name)).toList();
    } catch (_) {
      modules = const [
        (key: 'PERSONAL_INFO', name: 'Personal Information'),
        (key: 'LEAVE', name: 'Leave Management'),
        (key: 'ATTENDANCE', name: 'Attendance'),
        (key: 'PAYROLL', name: 'Payroll'),
        (key: 'SALARY', name: 'Salary Management'),
        (key: 'USER_MGMT', name: 'User Management'),
        (key: 'ROLE_MGMT', name: 'Role Management'),
        (key: 'REIMBURSEMENTS', name: 'Reimbursements'),
        (key: 'RECRUITMENT', name: 'Recruitment'),
        (key: 'DOCUMENTS', name: 'Documents'),
      ];
    }
    final builtInKeys = {for (final m in modules) m.key};
    if (tree.contacts.isNotEmpty) {
      modules = [
        for (final c in tree.contacts) (key: c.moduleKey, name: c.moduleName),
      ];
    }
    final names = await ref.read(employeeNamesProvider.future);
    if (!context.mounted) return;
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactsEditor(
        tree: tree,
        modules: modules,
        builtInKeys: builtInKeys,
        people: names,
      ),
    );
    if (result == null) return;
    try {
      await ref.read(orgTreeRepositoryProvider).setContacts(tree.id, result);
      ref.invalidate(selectedOrgTreeProvider);
      ref.invalidate(orgTreeListProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteContact(BuildContext context, WidgetRef ref, OrgTreeContact contact) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this permission?'),
        content: Text('“${contact.moduleName}” will be removed from who to contact.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDA1E28)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final remaining = tree.contacts
        .where((c) => c.moduleKey != contact.moduleKey)
        .map(
          (c) => {
            'moduleKey': c.moduleKey,
            'moduleName': c.moduleName,
            'employeeId': c.employeeId,
            'note': c.note,
          },
        )
        .toList();
    try {
      await ref.read(orgTreeRepositoryProvider).setContacts(tree.id, remaining);
      ref.invalidate(selectedOrgTreeProvider);
      ref.invalidate(orgTreeListProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact, this.onDelete});
  final OrgTreeContact contact;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dummy = OrgTreeNode(
      id: 'c:${contact.moduleKey}',
      kind: 'lead',
      title: contact.employeeName ?? 'Unassigned',
      photoUrl: contact.photoUrl,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.16) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          OrgAvatar(node: dummy, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.moduleName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.25),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.employeeName ?? 'Nobody assigned',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF334155),
                  ),
                ),
                if (contact.designation != null || contact.department != null)
                  Text(
                    [contact.designation, contact.department].whereType<String>().join(' · '),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                  ),
                if (contact.note != null && contact.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 13,
                          color: isDark ? const Color(0xFFC5A059) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            contact.note!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFD6CBB4) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete permission',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
            ),
        ],
      ),
    );
  }
}

class _ContactsEditor extends StatefulWidget {
  const _ContactsEditor({
    required this.tree,
    required this.modules,
    required this.builtInKeys,
    required this.people,
  });

  final OrgTreeSummary tree;
  final List<({String key, String name})> modules;
  final Set<String> builtInKeys;
  final List<EmployeeNameOption> people;

  @override
  State<_ContactsEditor> createState() => _ContactsEditorState();
}

class _ContactsEditorState extends State<_ContactsEditor> {
  late List<({String key, String name})> _modules;
  late Map<String, int?> _assigned;
  late Map<String, String> _notes;

  @override
  void initState() {
    super.initState();
    _modules = List.of(widget.modules);
    _assigned = {for (final m in _modules) m.key: null};
    _notes = {for (final m in _modules) m.key: ''};
    for (final c in widget.tree.contacts) {
      _assigned[c.moduleKey] = c.employeeId;
      _notes[c.moduleKey] = c.note ?? '';
    }
  }

  String _uniqueKey(String name) {
    final base = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    var key = 'CUSTOM_${base.isEmpty ? 'PERMISSION' : base}';
    final used = {for (final m in _modules) m.key};
    if (!used.contains(key)) return key;
    var i = 2;
    while (used.contains('${key}_$i')) {
      i++;
    }
    return '${key}_$i';
  }

  Future<void> _addPermission() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add permission'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Permission name',
            hintText: 'e.g. Travel, IT support, Vendor payments',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final exists = _modules.any((m) => m.name.toLowerCase() == name.toLowerCase());
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('“$name” is already in the list')),
        );
      }
      return;
    }
    final key = _uniqueKey(name);
    setState(() {
      _modules = [..._modules, (key: key, name: name)];
      _assigned[key] = null;
      _notes[key] = '';
    });
  }

  void _removePermission(String key) {
    setState(() {
      _modules = _modules.where((m) => m.key != key).toList();
      _assigned.remove(key);
      _notes.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final people = widget.people.where((p) => p.employeeId != null).toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1816) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Permission contacts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    TextButton.icon(
                      onPressed: _addPermission,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: () {
                        final payload = _modules.map((m) {
                          return {
                            'moduleKey': m.key,
                            'moduleName': m.name,
                            'employeeId': _assigned[m.key],
                            'note': _notes[m.key],
                          };
                        }).toList();
                        Navigator.pop(context, payload);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  itemCount: _modules.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == _modules.length) {
                      return OutlinedButton.icon(
                        onPressed: _addPermission,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add another permission'),
                      );
                    }
                    final m = _modules[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.25)),
                                ),
                                IconButton(
                                    tooltip: 'Delete permission',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _removePermission(m.key),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int?>(
                              value: people.any((p) => p.employeeId == _assigned[m.key])
                                  ? _assigned[m.key]
                                  : null,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Contact person', isDense: true),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('Unassigned')),
                                for (final p in people)
                                  DropdownMenuItem<int?>(
                                    value: p.employeeId,
                                    child: Text(p.displayLabel, overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _assigned[m.key] = v),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: _notes[m.key],
                              decoration: const InputDecoration(
                                labelText: 'Contact number (optional)',
                                hintText: 'e.g. +91 98765 43210',
                                prefixIcon: Icon(Icons.phone_outlined, size: 18),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.phone,
                              onChanged: (v) => _notes[m.key] = v,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
