import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/realtime/app_event_bus.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../data/purchase_repository.dart';
import '../../domain/purchase_models.dart';

/// Purchase module hub: PR/CS approvers, pending approvals, approved PRs → quotations.
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
  StreamSubscription<ErpRealtimeEvent>? _erpSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
    _erpSub = AppEventBus.instance.on<ErpRealtimeEvent>().listen((event) {
      if (event.module == 'purchase' || event.module == 'erp') {
        _silentReload();
      }
    });
  }

  @override
  void dispose() {
    _erpSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _silentReload() async {
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
      });
    } catch (_) {}
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

  Future<void> _savePrApprover(int? employeeId) async {
    try {
      final settings = await context.read<PurchaseRepository>().updateSettings(
            defaultApproverEmployeeId: employeeId,
            updatePrApprover: true,
          );
      if (!mounted) return;
      setState(() => _settings = settings);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PR approver saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _saveCsApprover(int? employeeId) async {
    try {
      final settings = await context.read<PurchaseRepository>().updateSettings(
            csApproverEmployeeId: employeeId,
            updateCsApprover: true,
          );
      if (!mounted) return;
      setState(() => _settings = settings);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comparison Sheet (PO) approver saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editDefaultPoTerms() async {
    final current = _settings?.defaultPoTerms ?? const <String>[];
    final ctrl = TextEditingController(text: current.join('\n'));
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Default PO Terms & Conditions'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Copied onto new Purchase Orders when a Comparison Sheet is approved. One term per line.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 14,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  labelText: 'Default Terms & Conditions',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    try {
      final terms = ctrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final settings = await context.read<PurchaseRepository>().updateSettings(
            defaultPoTerms: terms,
            updateDefaultPoTerms: true,
          );
      if (!mounted) return;
      setState(() => _settings = settings);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default PO Terms & Conditions saved')),
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
    if (reason == null || !mounted) return;
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
            Tab(text: 'PR Approvals'),
            Tab(text: 'Quotations / CS'),
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
                      onSavePrApprover: _savePrApprover,
                      onSaveCsApprover: _saveCsApprover,
                      onEditDefaultPoTerms: _editDefaultPoTerms,
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
                      onTap: (pr) => context.push('/erp/purchase/requests/${pr.id}/quotations'),
                      trailingBuilder: (pr) => const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({
    required this.settings,
    required this.onSavePrApprover,
    required this.onSaveCsApprover,
    required this.onEditDefaultPoTerms,
  });

  final ErpPurchaseSettings? settings;
  final ValueChanged<int?> onSavePrApprover;
  final ValueChanged<int?> onSaveCsApprover;
  final VoidCallback onEditDefaultPoTerms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNames = ref.watch(employeeNamesProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Purchase Request Approver',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Approves Store purchase requests (PR submit → approve).',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        asyncNames.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Failed to load employees: $e'),
          data: (names) {
            final employees =
                names.where((n) => n.type == 'EMPLOYEE' && n.employeeId != null).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: settings?.defaultApproverEmployeeId,
                  decoration: const InputDecoration(
                    labelText: 'PR Approver',
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
                  onChanged: onSavePrApprover,
                ),
                if (settings?.defaultApproverName != null) ...[
                  const SizedBox(height: 8),
                  Text('Current: ${settings!.defaultApproverName}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 28),
                const Text(
                  'Comparison Sheet / Final PO Approver',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selects the winning vendor quotation on the Comparison Sheet and creates the final Purchase Order. Can be a different person from the PR approver.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: settings?.csApproverEmployeeId,
                  decoration: const InputDecoration(
                    labelText: 'CS / PO Approver',
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
                  onChanged: onSaveCsApprover,
                ),
                if (settings?.csApproverName != null) ...[
                  const SizedBox(height: 8),
                  Text('Current: ${settings!.csApproverName}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 28),
                const Text(
                  'Default PO Terms & Conditions',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Applied to new Purchase Orders created from Comparison Sheet approval. You can still edit TnC on each PO before printing.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onEditDefaultPoTerms,
                  icon: const Icon(Icons.article_outlined),
                  label: Text(
                    settings?.defaultPoTerms.isNotEmpty == true
                        ? 'Edit default TnC (${settings!.defaultPoTerms.length} lines)'
                        : 'Set default TnC',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.items,
    required this.emptyLabel,
    this.trailingBuilder,
    this.onTap,
  });

  final List<ErpPurchaseRequest> items;
  final String emptyLabel;
  final Widget Function(ErpPurchaseRequest pr)? trailingBuilder;
  final ValueChanged<ErpPurchaseRequest>? onTap;

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
            onTap: onTap == null ? null : () => onTap!(pr),
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
