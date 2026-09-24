import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../domain/reimbursement_models.dart';
import '../reimbursements_providers.dart';

/// Admin builder: configure reimbursement types + dynamic fields + ₹/km + approver.
class ReimbursementTypesAdminScreen extends ConsumerWidget {
  const ReimbursementTypesAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typesAsync = ref.watch(adminReimbursementTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reimbursement types'),
        leading: const AppBackButton(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New type'),
        backgroundColor: AppColors.bronze,
      ),
      body: typesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (types) {
          if (types.isEmpty) {
            return const Center(child: Text('No types yet. Create Fuel or another type.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: types.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final t = types[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openEditor(context, ref, existing: t),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Switch(
                              value: t.isActive,
                              onChanged: (v) async {
                                await ref
                                    .read(reimbursementsRepositoryProvider)
                                    .updateType(t.id, {'isActive': v});
                                ref.invalidate(adminReimbursementTypesProvider);
                                ref.invalidate(activeReimbursementTypesProvider);
                              },
                            ),
                          ],
                        ),
                        Text(
                          t.amountMode == ReimbursementAmountMode.kmRate
                              ? '₹${t.ratePerUnit?.toStringAsFixed(2) ?? "—"} / km · ${t.fields.length} fields'
                              : 'Manual amount · ${t.fields.length} fields',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        if (t.approverName != null && t.approverName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Approver: ${t.approverName}',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (t.description != null && t.description!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(t.description!, style: const TextStyle(fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    ReimbursementType? existing,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TypeEditorPage(existing: existing),
      ),
    );
    ref.invalidate(adminReimbursementTypesProvider);
    ref.invalidate(activeReimbursementTypesProvider);
  }
}

class _DraftField {
  _DraftField({
    required this.label,
    required this.fieldKind,
    this.requiresProof = false,
    this.isRequired = true,
  });

  String label;
  ReimbursementFieldKind fieldKind;
  bool requiresProof;
  bool isRequired;
}

class _TypeEditorPage extends ConsumerStatefulWidget {
  const _TypeEditorPage({this.existing});

  final ReimbursementType? existing;

  @override
  ConsumerState<_TypeEditorPage> createState() => _TypeEditorPageState();
}

class _TypeEditorPageState extends ConsumerState<_TypeEditorPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '10');
  ReimbursementAmountMode _mode = ReimbursementAmountMode.kmRate;
  String? _approverUserId;
  final List<_DraftField> _fields = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _descCtrl.text = e.description ?? '';
      _mode = e.amountMode;
      _rateCtrl.text = (e.ratePerUnit ?? 10).toString();
      _approverUserId = e.approverUserId;
      for (final f in e.fields) {
        _fields.add(
          _DraftField(
            label: f.label,
            fieldKind: f.fieldKind,
            requiresProof: f.requiresProof,
            isRequired: f.isRequired,
          ),
        );
      }
    } else {
      _fields.addAll([
        _DraftField(
          label: 'Opening km',
          fieldKind: ReimbursementFieldKind.kmOpening,
          requiresProof: true,
        ),
        _DraftField(
          label: 'Closing km',
          fieldKind: ReimbursementFieldKind.kmClosing,
          requiresProof: true,
        ),
      ]);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    if (_approverUserId == null || _approverUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select who approves this type')),
      );
      return;
    }
    if (_fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one field')),
      );
      return;
    }
    for (final f in _fields) {
      if (f.label.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Every field needs a label')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(reimbursementsRepositoryProvider);
      final fieldMaps = _fields
          .asMap()
          .entries
          .map(
            (e) => {
              'label': e.value.label.trim(),
              'fieldKind': e.value.fieldKind.api,
              'requiresProof': e.value.requiresProof,
              'isRequired': e.value.isRequired,
              'sortOrder': e.key + 1,
            },
          )
          .toList();

      if (widget.existing == null) {
        await repo.createType({
          'name': name,
          'code': name,
          'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'amountMode': _mode.api,
          'ratePerUnit': _mode == ReimbursementAmountMode.kmRate
              ? double.tryParse(_rateCtrl.text.trim())
              : null,
          'approverUserId': _approverUserId,
          'fields': fieldMaps,
        });
      } else {
        await repo.updateType(widget.existing!.id, {
          'name': name,
          'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'amountMode': _mode.api,
          'ratePerUnit': _mode == ReimbursementAmountMode.kmRate
              ? double.tryParse(_rateCtrl.text.trim())
              : null,
          'approverUserId': _approverUserId,
        });
        await repo.replaceFields(widget.existing!.id, fieldMaps);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final namesAsync = ref.watch(employeeNamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New type' : 'Edit type'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Type name *',
              hintText: 'e.g. Fuel',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          namesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load employees: $e'),
            data: (names) {
              final withUser = names.where((n) => n.userId.isNotEmpty).toList();
              final validIds = withUser.map((n) => n.userId).toSet();
              final value =
                  _approverUserId != null && validIds.contains(_approverUserId)
                      ? _approverUserId
                      : null;
              return DropdownButtonFormField<String>(
                value: value,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Who approves *',
                  helperText: 'Staff claims for this type go to this person',
                  border: OutlineInputBorder(),
                ),
                items: withUser
                    .map(
                      (n) => DropdownMenuItem(
                        value: n.userId,
                        child: Text(n.displayLabel, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _approverUserId = v),
                validator: (v) => v == null ? 'Required' : null,
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReimbursementAmountMode>(
            value: _mode,
            decoration: const InputDecoration(
              labelText: 'Amount calculation',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: ReimbursementAmountMode.kmRate,
                child: Text('Opening/closing km × ₹/km'),
              ),
              DropdownMenuItem(
                value: ReimbursementAmountMode.manual,
                child: Text('Manual amount'),
              ),
            ],
            onChanged: (v) => setState(() => _mode = v ?? ReimbursementAmountMode.kmRate),
          ),
          if (_mode == ReimbursementAmountMode.kmRate) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '₹ per km *',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Fields',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _fields.add(
                      _DraftField(
                        label: '',
                        fieldKind: ReimbursementFieldKind.number,
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add field'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._fields.asMap().entries.map((entry) {
            final i = entry.key;
            final f = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: f.label,
                            decoration: const InputDecoration(
                              labelText: 'Label',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) => f.label = v,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => setState(() => _fields.removeAt(i)),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ReimbursementFieldKind>(
                      value: f.fieldKind,
                      decoration: const InputDecoration(
                        labelText: 'Kind',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: ReimbursementFieldKind.values
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k.label)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => f.fieldKind = v ?? f.fieldKind),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Requires proof'),
                      subtitle: const Text('Applicant must upload a file for this field'),
                      value: f.requiresProof,
                      onChanged: (v) => setState(() => f.requiresProof = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Required'),
                      value: f.isRequired,
                      onChanged: (v) => setState(() => f.isRequired = v),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
