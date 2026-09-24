import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../../admin/domain/admin_models.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/reimbursement_models.dart';
import '../reimbursements_providers.dart';

class ReimbursementApplyScreen extends ConsumerStatefulWidget {
  const ReimbursementApplyScreen({super.key, this.onBehalf = false});

  /// When true, Admin/HR picks employee + date; claim auto-approves.
  final bool onBehalf;

  @override
  ConsumerState<ReimbursementApplyScreen> createState() => _ReimbursementApplyScreenState();
}

class _FieldState {
  final TextEditingController ctrl = TextEditingController();
  String? proofUrl;
  String? proofName;
  bool uploading = false;
  DateTime? date;

  void dispose() => ctrl.dispose();
}

class _ReimbursementApplyScreenState extends ConsumerState<ReimbursementApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  ReimbursementType? _type;
  final Map<String, _FieldState> _fields = {};
  DateTime _claimDate = DateTime.now();
  EmployeeNameOption? _employee;
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _selectType(ReimbursementType t) {
    for (final f in _fields.values) {
      f.dispose();
    }
    _fields.clear();
    for (final f in t.fields) {
      _fields[f.key] = _FieldState();
    }
    setState(() {
      _type = t;
      if (_titleCtrl.text.trim().isEmpty) _titleCtrl.text = t.name;
    });
  }

  double? get _opening {
    final t = _type;
    if (t == null) return null;
    for (final f in t.fields) {
      if (f.fieldKind == ReimbursementFieldKind.kmOpening) {
        return double.tryParse(_fields[f.key]?.ctrl.text.trim() ?? '');
      }
    }
    return null;
  }

  double? get _closing {
    final t = _type;
    if (t == null) return null;
    for (final f in t.fields) {
      if (f.fieldKind == ReimbursementFieldKind.kmClosing) {
        return double.tryParse(_fields[f.key]?.ctrl.text.trim() ?? '');
      }
    }
    return null;
  }

  double? get _previewAmount {
    final t = _type;
    if (t == null) return null;
    if (t.amountMode == ReimbursementAmountMode.kmRate) {
      final o = _opening;
      final c = _closing;
      final rate = t.ratePerUnit ?? 0;
      if (o == null || c == null || c < o || rate <= 0) return null;
      return ((c - o) * rate * 100).round() / 100;
    }
    return double.tryParse(_amountCtrl.text.trim());
  }

  Future<void> _pickProof(ReimbursementFieldDef def) async {
    final auth = ref.read(authNotifierProvider);
    final employeeId = widget.onBehalf
        ? _employee?.employeeId
        : auth.user?.employeeId;
    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.onBehalf
                ? 'Select an employee first'
                : 'Employee profile not linked',
          ),
        ),
      );
      return;
    }
    final state = _fields[def.key];
    if (state == null) return;
    final picked = await pickFileFromDevice(imagesOnly: true);
    if (picked == null) return;
    setState(() => state.uploading = true);
    try {
      final url = await ref.read(reimbursementsRepositoryProvider).uploadProof(
            employeeId: employeeId,
            bytes: picked.bytes,
            filename: picked.name,
          );
      if (!mounted) return;
      setState(() {
        state.proofUrl = url;
        state.proofName = picked.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => state.uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final type = _type;
    if (type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a reimbursement type')),
      );
      return;
    }
    if (widget.onBehalf && (_employee?.employeeId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an employee')),
      );
      return;
    }

    for (final f in type.fields) {
      final st = _fields[f.key];
      if (f.requiresProof && (st?.proofUrl == null || st!.proofUrl!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proof required for ${f.label}')),
        );
        return;
      }
    }

    final values = <Map<String, dynamic>>[];
    for (final f in type.fields) {
      final st = _fields[f.key]!;
      Object? value;
      if (f.fieldKind == ReimbursementFieldKind.date) {
        value = st.date?.toIso8601String().substring(0, 10);
      } else if (f.fieldKind == ReimbursementFieldKind.file) {
        value = st.proofUrl;
      } else {
        value = st.ctrl.text.trim();
      }
      values.add({
        'fieldKey': f.key,
        'value': value,
        if (st.proofUrl != null) 'proofUrl': st.proofUrl,
      });
    }

    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'typeId': type.id,
        'claimDate': _claimDate.toIso8601String().substring(0, 10),
        'title': _titleCtrl.text.trim().isEmpty ? type.name : _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'values': values,
        if (type.amountMode == ReimbursementAmountMode.manual)
          'amount': double.tryParse(_amountCtrl.text.trim()),
        if (widget.onBehalf) ...{
          'employeeId': _employee!.employeeId,
          'onBehalf': true,
        },
      };
      final claim = await ref.read(reimbursementsRepositoryProvider).apply(body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.onBehalf
                ? 'Applied & auto-approved · ${claim.claimNo} · ₹${claim.amount.toStringAsFixed(2)}'
                    ' → ${_claimDate.month}/${_claimDate.year} salary'
                : 'Submitted · ${claim.claimNo} (pending approver)',
          ),
        ),
      );
      ref.invalidate(myReimbursementsProvider);
      ref.invalidate(pendingReimbursementsProvider);
      ref.invalidate(adminReimbursementsProvider);
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(activeReimbursementTypesProvider);
    final namesAsync = widget.onBehalf ? ref.watch(employeeNamesProvider) : null;
    final preview = _previewAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onBehalf ? 'Apply on behalf' : 'Apply reimbursement'),
        leading: const AppBackButton(),
      ),
      body: typesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (types) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.onBehalf) ...[
                  namesAsync!.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Could not load employees: $e'),
                    data: (names) {
                      final options = names.where((n) => n.employeeId != null).toList();
                      return DropdownButtonFormField<int>(
                        value: _employee?.employeeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Employee *',
                          border: OutlineInputBorder(),
                          helperText: 'Who this reimbursement is for',
                        ),
                        items: options
                            .map(
                              (n) => DropdownMenuItem<int>(
                                value: n.employeeId,
                                child: Text(n.displayLabel, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          final match = options.where((n) => n.employeeId == id).firstOrNull;
                          setState(() => _employee = match);
                        },
                        validator: (v) => v == null ? 'Select an employee' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Claim date *'),
                  subtitle: Text(
                    '${_claimDate.day.toString().padLeft(2, '0')}-'
                    '${_claimDate.month.toString().padLeft(2, '0')}-'
                    '${_claimDate.year}'
                    '${widget.onBehalf ? '  ·  posts to this month\'s salary' : '  ·  salary month'}',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _claimDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 366)),
                    );
                    if (picked != null) setState(() => _claimDate = picked);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ReimbursementType>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: types
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.name),
                        ),
                      )
                      .toList(),
                  onChanged: (t) {
                    if (t != null) _selectType(t);
                  },
                  validator: (v) => v == null ? 'Required' : null,
                ),
                if (_type != null) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._type!.fields.map(_buildField),
                  if (_type!.amountMode == ReimbursementAmountMode.manual) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹) *',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final n = double.tryParse(v?.trim() ?? '');
                        if (n == null || n <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                  ],
                  if (preview != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.bronze.withValues(alpha: 0.15),
                            AppColors.bronze.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Amount preview',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${preview.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                          if (_type!.amountMode == ReimbursementAmountMode.kmRate &&
                              _opening != null &&
                              _closing != null)
                            Text(
                              '${(_closing! - _opening!).toStringAsFixed(1)} km × ₹${_type!.ratePerUnit?.toStringAsFixed(2) ?? "—"}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.bronze,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            widget.onBehalf ? 'Apply & auto-approve' : 'Submit for Admin approval',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildField(ReimbursementFieldDef def) {
    final st = _fields[def.key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (def.fieldKind == ReimbursementFieldKind.date)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${def.label}${def.isRequired ? " *" : ""}'),
              subtitle: Text(
                st.date == null
                    ? 'Tap to pick'
                    : '${st.date!.day.toString().padLeft(2, '0')}-'
                        '${st.date!.month.toString().padLeft(2, '0')}-'
                        '${st.date!.year}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: st.date ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => st.date = picked);
              },
            )
          else if (def.fieldKind != ReimbursementFieldKind.file)
            TextFormField(
              controller: st.ctrl,
              keyboardType: [
                ReimbursementFieldKind.number,
                ReimbursementFieldKind.kmOpening,
                ReimbursementFieldKind.kmClosing,
                ReimbursementFieldKind.amount,
              ].contains(def.fieldKind)
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: '${def.label}${def.isRequired ? " *" : ""}',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (!def.isRequired) return null;
                if (v == null || v.trim().isEmpty) return 'Required';
                return null;
              },
            ),
          if (def.requiresProof || def.fieldKind == ReimbursementFieldKind.file) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: st.uploading ? null : () => _pickProof(def),
              icon: st.uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(st.proofUrl != null ? Icons.check_circle : Icons.attach_file),
              label: Text(
                st.proofUrl != null
                    ? (st.proofName ?? 'Proof attached')
                    : 'Upload proof${def.requiresProof ? " *" : ""}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
