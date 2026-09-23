import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../data/purchase_repository.dart';
import '../../domain/purchase_models.dart';

/// Purchase module hub: default approver, pending approvals, approved PRs.
class PurchaseHomeScreen extends StatefulWidget {
  const PurchaseHomeScreen({super.key});

  @override
  State<PurchaseHomeScreen> createState() => _PurchaseHomeScreenState();
}

class _PurchaseHomeScreenState extends State<PurchaseHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  ErpPurchaseSettings? _settings;
  List<ErpPurchaseRequest> _pending = [];
  List<ErpPurchaseRequest> _approved = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<PurchaseRepository>();
      final settings = await repo.getSettings();
      final pending = await repo.listRequests(status: 'PENDING');
      final approved = await repo.listRequests(status: 'APPROVED');
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _pending = pending;
        _approved = approved;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveApprover(int? employeeId) async {
    try {
      final settings = await context.read<PurchaseRepository>().updateSettings(
            defaultApproverEmployeeId: employeeId,
          );
      if (!mounted) return;
      setState(() => _settings = settings);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default PR approver saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _approve(ErpPurchaseRequest pr) async {
    try {
      await context.read<PurchaseRepository>().approveRequest(pr.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reject(ErpPurchaseRequest pr) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Purchase Request'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Reject')),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await context.read<PurchaseRepository>().rejectRequest(pr.id, reason: reason.isEmpty ? null : reason);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Purchase'),
        leading: const AppBackButton(fallbackLocation: '/erp/home'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Settings'),
            Tab(text: 'Approvals'),
            Tab(text: 'Approved PRs'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _SettingsTab(
                      settings: _settings,
                      onSave: _saveApprover,
                    ),
                    _RequestList(
                      items: _pending,
                      emptyLabel: 'No pending purchase requests.',
                      trailingBuilder: (pr) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(onPressed: () => _reject(pr), child: const Text('Reject')),
                          FilledButton(onPressed: () => _approve(pr), child: const Text('Approve')),
                        ],
                      ),
                    ),
                    _RequestList(
                      items: _approved,
                      emptyLabel: 'No approved purchase requests yet.',
                    ),
                  ],
                ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({required this.settings, required this.onSave});

  final ErpPurchaseSettings? settings;
  final ValueChanged<int?> onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNames = ref.watch(employeeNamesProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Default Purchase Request Approver',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Selected once here and reused for every new purchase request submission.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        asyncNames.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Failed to load employees: $e'),
          data: (names) {
            final employees = names.where((n) => n.type == 'EMPLOYEE' && n.employeeId != null).toList();
            return DropdownButtonFormField<int>(
              value: settings?.defaultApproverEmployeeId,
              decoration: const InputDecoration(
                labelText: 'Approver (search by name)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int>(value: null, child: Text('Select employee')),
                ...employees.map(
                  (e) => DropdownMenuItem<int>(
                    value: e.employeeId,
                    child: Text(e.displayLabel),
                  ),
                ),
              ],
              onChanged: onSave,
            );
          },
        ),
        if (settings?.defaultApproverName != null) ...[
          const SizedBox(height: 12),
          Text('Current: ${settings!.defaultApproverName}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.items,
    required this.emptyLabel,
    this.trailingBuilder,
  });

  final List<ErpPurchaseRequest> items;
  final String emptyLabel;
  final Widget Function(ErpPurchaseRequest pr)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(emptyLabel));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final pr = items[i];
        return Card(
          child: ListTile(
            title: Text('${pr.prNumber} · ${pr.status}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              [
                DateFormat('dd/MM/yyyy').format(pr.prDate),
                if (pr.projectName != null) pr.projectName!,
                if (pr.vendorName != null) pr.vendorName!,
                if (pr.requestedByName != null) 'By ${pr.requestedByName}',
                '${pr.lines.length} line(s)',
              ].join(' · '),
            ),
            isThreeLine: true,
            trailing: trailingBuilder?.call(pr),
          ),
        );
      },
    );
  }
}
