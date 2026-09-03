import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/tender_models.dart';
import '../project_providers.dart';
import '../tender_providers.dart';
import '../work_order_providers.dart';

class TenderApplicationFormScreen extends ConsumerStatefulWidget {
  const TenderApplicationFormScreen({super.key});

  @override
  ConsumerState<TenderApplicationFormScreen> createState() => _TenderApplicationFormScreenState();
}

class _TenderApplicationFormScreenState extends ConsumerState<TenderApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appNoCtrl = TextEditingController();
  final _createdByCtrl = TextEditingController();
  final _df = DateFormat('dd/MM/yyyy');

  DateTime _applicationDate = DateTime.now();
  String? _projectId;
  String? _tenderId;
  String? _activityKey;
  String? _activityId;
  String? _activityName;
  String? _contractorId;
  List<ErpTender> _projectTenders = [];
  List<TenderActivityOption> _activities = [];
  bool _loadingTenders = false;
  bool _loadingActivities = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = ref.read(authNotifierProvider).user?.name;
      if (name != null && _createdByCtrl.text.isEmpty) {
        _createdByCtrl.text = name;
      }
    });
  }

  @override
  void dispose() {
    _appNoCtrl.dispose();
    _createdByCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {bool required = false, String? hint}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _applicationDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() => _applicationDate = picked);
  }

  Future<void> _onProjectChanged(String? id) async {
    setState(() {
      _projectId = id;
      _tenderId = null;
      _activityKey = null;
      _activityId = null;
      _activityName = null;
      _projectTenders = [];
      _activities = [];
      _loadingTenders = id != null;
    });
    if (id == null) return;
    try {
      final tenders = await ref.read(tenderRepositoryProvider).list(projectId: id);
      if (!mounted) return;
      setState(() {
        _projectTenders = tenders;
        _loadingTenders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTenders = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _onTenderChanged(String? id) async {
    setState(() {
      _tenderId = id;
      _activityKey = null;
      _activityId = null;
      _activityName = null;
      _activities = [];
      _loadingActivities = id != null;
    });
    if (id == null) return;
    try {
      final tender = await ref.read(tenderRepositoryProvider).getById(id);
      if (!mounted) return;
      final seen = <String>{};
      final acts = <TenderActivityOption>[];
      for (final line in tender.lines) {
        final key = (line.activityId?.isNotEmpty == true)
            ? line.activityId!
            : line.activityName;
        if (key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        acts.add(TenderActivityOption(id: line.activityId, name: line.activityName));
      }
      setState(() {
        _activities = acts;
        _loadingActivities = false;
        if (_projectId == null && tender.projectId.isNotEmpty) {
          _projectId = tender.projectId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingActivities = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_projectId == null ||
        _tenderId == null ||
        _activityName == null ||
        _contractorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project, tender, activity and contractor are required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(tenderRepositoryProvider).createApplication({
        'applicationNo': _appNoCtrl.text.trim(),
        'applicationDate': _applicationDate.toIso8601String(),
        'createdByName': _createdByCtrl.text.trim().isEmpty ? null : _createdByCtrl.text.trim(),
        'projectId': _projectId,
        'tenderId': _tenderId,
        'activityId': _activityId,
        'activityName': _activityName,
        'contractorId': _contractorId,
      });
      ref.invalidate(tenderApplicationListProvider);
      ref.invalidate(tenderListProvider);
      if (mounted) context.go('/erp/tender-applications');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsListProvider);
    final contractorsAsync = ref.watch(erpContractorsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Tender Application'),
        leading: const AppBackButton(fallbackLocation: '/erp/tender-applications'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final wide = c.maxWidth >= 720;
                          final gap = wide ? 12.0 : 10.0;
                          final children = [
                            InkWell(
                              onTap: _pickDate,
                              child: InputDecorator(
                                decoration: _dec('Application Date'),
                                child: Text(_df.format(_applicationDate)),
                              ),
                            ),
                            TextFormField(
                              controller: _appNoCtrl,
                              decoration: _dec('Tender Application No', required: true, hint: 'e.g. APN00001'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            TextFormField(
                              controller: _createdByCtrl,
                              decoration: _dec('Tender Application Created By'),
                            ),
                            projectsAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text('$e'),
                              data: (projects) => DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _projectId,
                                decoration: _dec('Project', required: true),
                                hint: const Text('Select Project'),
                                items: projects
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p.id,
                                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _onProjectChanged,
                                validator: (v) => v == null ? 'Required' : null,
                              ),
                            ),
                            if (_loadingTenders)
                              const LinearProgressIndicator()
                            else
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _tenderId,
                                decoration: _dec('Project Tenders', required: true),
                                hint: const Text('Select Tender'),
                                items: _projectTenders
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t.id,
                                        child: Text(t.tenderNo, overflow: TextOverflow.ellipsis),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _projectId == null ? null : _onTenderChanged,
                                validator: (v) => v == null ? 'Required' : null,
                              ),
                            if (_loadingActivities)
                              const LinearProgressIndicator()
                            else
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _activityKey,
                                decoration: _dec('Activity', required: true),
                                hint: const Text('Select Activity'),
                                items: _activities
                                    .map(
                                      (a) {
                                        final key = (a.id?.isNotEmpty == true) ? a.id! : a.name;
                                        return DropdownMenuItem(
                                          value: key,
                                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                                        );
                                      },
                                    )
                                    .toList(),
                                onChanged: _tenderId == null
                                    ? null
                                    : (key) {
                                        final a = _activities.firstWhere(
                                          (x) => ((x.id?.isNotEmpty == true) ? x.id! : x.name) == key,
                                        );
                                        setState(() {
                                          _activityKey = key;
                                          _activityId = a.id;
                                          _activityName = a.name;
                                        });
                                      },
                                validator: (v) => v == null ? 'Required' : null,
                              ),
                            contractorsAsync.when(
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text('$e'),
                              data: (contractors) {
                                final active = contractors.where((c) => c.isActive).toList();
                                return DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _contractorId,
                                  decoration: _dec('Contractor', required: true),
                                  hint: const Text('Select Contractor'),
                                  items: active
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() => _contractorId = v),
                                  validator: (v) => v == null ? 'Required' : null,
                                );
                              },
                            ),
                          ];

                          if (!wide) {
                            return Column(
                              children: [
                                for (var i = 0; i < children.length; i++) ...[
                                  if (i > 0) SizedBox(height: gap),
                                  children[i],
                                ],
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: children[0]),
                                  SizedBox(width: gap),
                                  Expanded(child: children[1]),
                                  SizedBox(width: gap),
                                  Expanded(child: children[2]),
                                  SizedBox(width: gap),
                                  Expanded(child: children[3]),
                                ],
                              ),
                              SizedBox(height: gap),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: children[4]),
                                  SizedBox(width: gap),
                                  Expanded(child: children[5]),
                                  SizedBox(width: gap),
                                  Expanded(child: children[6]),
                                  SizedBox(width: gap),
                                  const Expanded(child: SizedBox()),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1816) : Colors.white,
                border: Border(
                  top: BorderSide(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Row(
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1e3a5f),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _saving ? null : () => context.go('/erp/tender-applications'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
