import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../admin/domain/admin_models.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/support_models.dart';
import '../support_providers.dart';

class SupportHandlersScreen extends ConsumerStatefulWidget {
  const SupportHandlersScreen({super.key});

  @override
  ConsumerState<SupportHandlersScreen> createState() => _SupportHandlersScreenState();
}

class _SupportHandlersScreenState extends ConsumerState<SupportHandlersScreen> {
  final _searchCtrl = TextEditingController();
  final Set<int> _selected = {};
  bool _bootstrapped = false;
  bool _saving = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _bootstrapFromHandlers(List<SupportHandler> handlers) {
    if (_bootstrapped) return;
    _bootstrapped = true;
    _selected
      ..clear()
      ..addAll(handlers.map((h) => h.employeeId).where((id) => id > 0));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(supportRepositoryProvider).setHandlers(_selected.toList()..sort());
      ref.invalidate(supportHandlersProvider);
      ref.invalidate(supportCapabilitiesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selected.isEmpty
                ? 'Cleared. Tickets will notify Admins/HR until you assign again.'
                : 'Assigned ${_selected.length} employee(s) to receive Support tickets.',
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final canManage = Permissions.canManageSupportHandlers(
      auth.user?.role,
      companyAdminGranted: auth.user?.companyAdminGranted ?? false,
    );
    final handlersAsync = ref.watch(supportHandlersProvider);
    final namesAsync = ref.watch(employeeNamesProvider);

    handlersAsync.whenData(_bootstrapFromHandlers);

    if (!canManage) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Support handlers'),
          leading: const AppBackButton(fallbackLocation: '/support'),
        ),
        body: const Center(child: Text('Only Admin can assign Support handlers.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('IT Support assignees'),
        leading: const AppBackButton(fallbackLocation: '/support'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Choose which employees receive new Support tickets and can work the IT queue.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in _selected)
                    Chip(
                      label: Text(_labelFor(
                        id,
                        namesAsync.asData?.value,
                        handlersAsync.asData?.value,
                      )),
                      onDeleted: () => setState(() => _selected.remove(id)),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search employees…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: namesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (names) {
                final employees = names
                    .where((n) => n.employeeId != null && n.employeeId! > 0)
                    .where((n) {
                      if (_query.isEmpty) return true;
                      final hay = [
                        n.fullName,
                        n.employeeCode,
                        n.designationName,
                      ].whereType<String>().join(' ').toLowerCase();
                      return hay.contains(_query);
                    })
                    .toList();
                if (employees.isEmpty) {
                  return const Center(child: Text('No employees found.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  itemCount: employees.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final emp = employees[i];
                    final id = emp.employeeId!;
                    final checked = _selected.contains(id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        });
                      },
                      title: Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        [
                          if (emp.employeeCode != null && emp.employeeCode!.isNotEmpty) emp.employeeCode,
                          if (emp.designationName != null && emp.designationName!.isNotEmpty)
                            emp.designationName,
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(
    int id,
    List<EmployeeNameOption>? names,
    List<SupportHandler>? handlers,
  ) {
    for (final n in names ?? const <EmployeeNameOption>[]) {
      if (n.employeeId == id) {
        final code = n.employeeCode;
        if (code != null && code.isNotEmpty) return '${n.fullName} ($code)';
        return n.fullName;
      }
    }
    for (final h in handlers ?? const <SupportHandler>[]) {
      if (h.employeeId == id) return h.displayLabel;
    }
    return 'Employee #$id';
  }
}
