import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/boq_models.dart';
import '../../domain/structure_models.dart';
import '../../domain/tender_models.dart';
import '../../domain/work_order_models.dart';
import '../boq_providers.dart';
import '../project_providers.dart';
import '../tender_providers.dart';
import '../work_order_providers.dart';
import '../widgets/work_order_location_picker.dart';

class TenderFormScreen extends ConsumerStatefulWidget {
  const TenderFormScreen({super.key, this.id});

  final String? id;
  bool get isEdit => id != null && id!.isNotEmpty;

  @override
  ConsumerState<TenderFormScreen> createState() => _TenderFormScreenState();
}

class _TenderFormScreenState extends ConsumerState<TenderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenderNoCtrl = TextEditingController();
  final _createdByCtrl = TextEditingController();
  final _df = DateFormat('dd/MM/yyyy');

  DateTime _tenderDate = DateTime.now();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _projectId;
  String? _boqId;
  String? _activityId;
  String? _activityName;
  List<ErpTenderLine> _lines = [];
  List<TenderActivityOption> _boqActivities = [];
  bool _hydrated = false;
  bool _saving = false;
  bool _adding = false;

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
    _tenderNoCtrl.dispose();
    _createdByCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(
    String label, {
    bool required = false,
    Widget? suffix,
    String? hint,
  }) {
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
      suffixIcon: suffix,
    );
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _onProjectChanged(String? id) async {
    setState(() {
      _projectId = id;
      _boqId = null;
      _activityId = null;
      _activityName = null;
      _boqActivities = [];
    });
  }

  Future<void> _onBoqChanged(String? id) async {
    setState(() {
      _boqId = id;
      _activityId = null;
      _activityName = null;
      _boqActivities = [];
    });
    if (id == null || id.isEmpty) return;
    try {
      final acts = await ref.read(tenderRepositoryProvider).activitiesFromBoq(id);
      if (!mounted) return;
      setState(() => _boqActivities = acts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _addActivityLines() async {
    if (_projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a project first')));
      return;
    }
    if (_activityId == null && (_activityName == null || _activityName!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an activity')));
      return;
    }
    setState(() => _adding = true);
    try {
      final preview = await ref.read(tenderRepositoryProvider).previewLines(
            boqId: _boqId,
            activityId: _activityId,
          );
      if (!mounted) return;
      if (preview.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tasks found for this activity')));
        return;
      }
      setState(() {
        final aid = _activityId;
        _lines = [
          ..._lines.where((l) => aid == null ? l.activityName != _activityName : l.activityId != aid),
          ...preview,
        ];
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a project')));
      return;
    }
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select start and last dates')));
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Last date must be on/after start date')));
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one activity line')));
      return;
    }

    setState(() => _saving = true);
    try {
      final body = {
        'tenderNo': _tenderNoCtrl.text.trim(),
        'tenderDate': _tenderDate.toIso8601String(),
        'createdByName': _createdByCtrl.text.trim(),
        'projectId': _projectId,
        if (_boqId != null) 'boqId': _boqId,
        'startDate': _startDate!.toIso8601String(),
        'endDate': _endDate!.toIso8601String(),
        'status': 'OPEN',
        'lines': _lines.asMap().entries.map((e) {
          final map = e.value.toJson();
          map['sortOrder'] = e.key;
          map['amount'] = e.value.computedAmount;
          return map;
        }).toList(),
      };

      final repo = ref.read(tenderRepositoryProvider);
      if (widget.isEdit) {
        await repo.update(widget.id!, body);
      } else {
        await repo.create(body);
      }
      ref.invalidate(tenderListProvider);
      if (mounted) context.go('/erp/tenders');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _hydrate(ErpTender t) {
    _tenderNoCtrl.text = t.tenderNo;
    _createdByCtrl.text = t.createdByName ?? _createdByCtrl.text;
    _tenderDate = t.tenderDate;
    _startDate = t.startDate;
    _endDate = t.endDate;
    _projectId = t.projectId;
    _boqId = t.boqId;
    _lines = List.of(t.lines);
    _hydrated = true;
    if (_boqId != null) {
      ref.read(tenderRepositoryProvider).activitiesFromBoq(_boqId!).then((acts) {
        if (mounted) setState(() => _boqActivities = acts);
      });
    }
  }

  Widget _sectionCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required String placeholder,
    required VoidCallback onTap,
    bool required = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _dec(
          label,
          required: required,
          suffix: const Icon(Icons.calendar_month_outlined, size: 18),
        ),
        child: Text(
          value == null ? placeholder : _df.format(value),
          style: TextStyle(
            color: value == null ? Theme.of(context).hintColor : const Color(0xFF0F172A),
            fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _activityDropdown(AsyncValue<List<ErpActivity>> activitiesAsync) {
    if (_boqId != null) {
      final items = <DropdownMenuItem<String>>[
        for (final a in _boqActivities)
          if (a.id != null)
            DropdownMenuItem<String>(
              value: a.id,
              child: Text(a.name, overflow: TextOverflow.ellipsis),
            ),
      ];
      return DropdownButtonFormField<String>(
        value: _activityId,
        isExpanded: true,
        decoration: _dec('Activity', required: true, hint: 'Select activity from BOQ'),
        items: items,
        onChanged: (v) {
          final opt = _boqActivities.where((a) => a.id == v).firstOrNull;
          setState(() {
            _activityId = v;
            _activityName = opt?.name;
          });
        },
      );
    }
    return activitiesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (acts) {
        final items = <DropdownMenuItem<String>>[
          for (final a in acts)
            DropdownMenuItem<String>(
              value: a.id,
              child: Text(a.name, overflow: TextOverflow.ellipsis),
            ),
        ];
        return DropdownButtonFormField<String>(
          value: _activityId,
          isExpanded: true,
          decoration: _dec('Activity', required: true, hint: 'Select activity'),
          items: items,
          onChanged: (v) {
            final opt = acts.where((a) => a.id == v).firstOrNull;
            setState(() {
              _activityId = v;
              _activityName = opt?.name;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsListProvider);
    final activitiesAsync = ref.watch(erpActivitiesProvider);
    final boqsAsync = _projectId == null
        ? const AsyncValue<List<ErpBoq>>.data([])
        : ref.watch(boqListProvider);
    final towers = _projectId == null
        ? const <ErpProjectTower>[]
        : (ref.watch(projectTowersProvider(_projectId!)).asData?.value ?? const <ErpProjectTower>[]);

    if (widget.isEdit) {
      ref.listen(tenderDetailProvider(widget.id!), (prev, next) {
        next.whenData((t) {
          if (_hydrated || !mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _hydrated) return;
            setState(() => _hydrate(t));
          });
        });
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectBoqs = boqsAsync.asData?.value.where((b) => b.projectId == _projectId).toList() ?? [];
    final total = _lines.fold(0.0, (s, l) => s + l.computedAmount);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Tender' : 'New Tender'),
        leading: const AppBackButton(fallbackLocation: '/erp/tenders'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _sectionCard(
              isDark: isDark,
              title: 'Tender details',
              subtitle: 'Basic info for this tender',
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 860;
                  final fields = <Widget>[
                    InputDecorator(
                      decoration: _dec('Date'),
                      child: Text(_df.format(_tenderDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    TextFormField(
                      controller: _tenderNoCtrl,
                      decoration: _dec('Tender Id', required: true, hint: 'e.g. TDNBR00001'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _createdByCtrl,
                      readOnly: true,
                      decoration: _dec('Created By'),
                    ),
                    projectsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('$e'),
                      data: (projects) {
                        final items = <DropdownMenuItem<String>>[
                          for (final p in projects)
                            DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(p.name, overflow: TextOverflow.ellipsis),
                            ),
                        ];
                        return DropdownButtonFormField<String>(
                          value: _projectId,
                          isExpanded: true,
                          decoration: _dec('Project', required: true, hint: 'Select project'),
                          items: items,
                          onChanged: _onProjectChanged,
                          validator: (v) => v == null ? 'Required' : null,
                        );
                      },
                    ),
                    _dateField(
                      label: 'Start Date',
                      value: _startDate,
                      placeholder: 'Select start date',
                      required: true,
                      onTap: () => _pickDate(start: true),
                    ),
                    _dateField(
                      label: 'Last Date',
                      value: _endDate,
                      placeholder: 'Select end date',
                      required: true,
                      onTap: () => _pickDate(start: false),
                    ),
                  ];

                  if (wide) {
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < 4; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(child: fields[i]),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: fields[4]),
                            const SizedBox(width: 12),
                            Expanded(child: fields[5]),
                            const SizedBox(width: 12),
                            const Expanded(child: SizedBox()),
                            const SizedBox(width: 12),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (final f in fields) ...[f, const SizedBox(height: 10)],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              isDark: isDark,
              title: 'Scope & activities',
              subtitle: _boqId == null
                  ? 'Optional BOQ · activities from general catalog'
                  : 'Activities loaded from selected BOQ',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563eb).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _boqId == null ? 'No BOQ' : 'BOQ linked',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563eb)),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 860;
                  final boqField = DropdownButtonFormField<String?>(
                    value: _boqId,
                    isExpanded: true,
                    decoration: _dec(
                      'Project BOQ',
                      hint: _projectId == null ? 'Select project first' : 'Optional',
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(value: null, child: Text('No BOQ (general activities)')),
                      for (final b in projectBoqs)
                        DropdownMenuItem<String?>(
                          value: b.id,
                          child: Text('${b.boqNo} — ${b.title}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _projectId == null ? null : _onBoqChanged,
                  );
                  final activityField = _activityDropdown(activitiesAsync);
                  final addBtn = SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: _adding ? null : _addActivityLines,
                      icon: _adding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: Text(_adding ? 'Adding…' : 'Add lines'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563eb),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: boqField),
                        const SizedBox(width: 12),
                        Expanded(flex: 5, child: activityField),
                        const SizedBox(width: 12),
                        addBtn,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      boqField,
                      const SizedBox(height: 10),
                      activityField,
                      const SizedBox(height: 12),
                      addBtn,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            if (_lines.isEmpty)
              _sectionCard(
                isDark: isDark,
                title: 'Line items',
                subtitle: 'Select an activity and click Add lines',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252220) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.table_rows_outlined, size: 32, color: Theme.of(context).hintColor),
                      const SizedBox(height: 8),
                      Text(
                        'No lines yet',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'BOQ tasks or activity subtasks will appear here',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              )
            else
              _LinesTable(
                lines: _lines,
                towers: towers,
                total: total,
                onAmountChanged: (i, amount) {
                  setState(() => _lines[i] = _lines[i].copyWith(amount: amount));
                },
                onRateChanged: (i, rate) {
                  setState(() {
                    final l = _lines[i];
                    final amt = l.quantity != null ? l.quantity! * rate : rate;
                    _lines[i] = l.copyWith(rate: rate, amount: amt);
                  });
                },
                onRemove: (i) => setState(() => _lines.removeAt(i)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B18) : Colors.white,
            border: Border(
              top: BorderSide(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_saving ? 'Saving…' : 'Submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => context.go('/erp/tenders'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              if (_lines.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252220) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_lines.length} lines',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Total  ${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinesTable extends StatelessWidget {
  const _LinesTable({
    required this.lines,
    required this.towers,
    required this.total,
    required this.onAmountChanged,
    required this.onRateChanged,
    required this.onRemove,
  });

  final List<ErpTenderLine> lines;
  final List<ErpProjectTower> towers;
  final double total;
  final void Function(int index, double amount) onAmountChanged;
  final void Function(int index, double rate) onRateChanged;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF252220) : const Color(0xFFF1F5F9);
    const headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 11,
      color: Color(0xFF64748B),
      letterSpacing: 0.2,
    );
    const cellStyle = TextStyle(fontSize: 12.5, color: Color(0xFF0F172A));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Line items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      SizedBox(height: 2),
                      Text(
                        'Edit rate or amount as needed before submit',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${lines.length} rows',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowHeight: 42,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 60,
                    columnSpacing: 18,
                    horizontalMargin: 16,
                    headingRowColor: WidgetStateProperty.all(headerBg),
                    columns: const [
                      DataColumn(label: Text('#', style: headerStyle)),
                      DataColumn(label: Text('Activity', style: headerStyle)),
                      DataColumn(label: Text('Task', style: headerStyle)),
                      DataColumn(label: Text('Description', style: headerStyle)),
                      DataColumn(label: Text('Block', style: headerStyle)),
                      DataColumn(label: Text('Floor', style: headerStyle)),
                      DataColumn(label: Text('Units', style: headerStyle)),
                      DataColumn(label: Text('Qty', style: headerStyle)),
                      DataColumn(label: Text('Unit', style: headerStyle)),
                      DataColumn(label: Text('Rate', style: headerStyle)),
                      DataColumn(label: Text('Amount', style: headerStyle)),
                      DataColumn(label: Text('', style: headerStyle)),
                    ],
                    rows: [
                      for (var i = 0; i < lines.length; i++)
                        DataRow(
                          color: WidgetStateProperty.all(
                            i.isEven
                                ? (isDark ? const Color(0xFF1E1B18) : Colors.white)
                                : (isDark ? const Color(0xFF252220) : const Color(0xFFF8FAFC)),
                          ),
                          cells: [
                            DataCell(Text('${i + 1}', style: cellStyle.copyWith(fontWeight: FontWeight.w600))),
                            DataCell(Text(lines[i].activityName, style: cellStyle.copyWith(fontWeight: FontWeight.w600))),
                            DataCell(Text(lines[i].taskName, style: cellStyle)),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  lines[i].taskDescription?.trim().isNotEmpty == true
                                      ? lines[i].taskDescription!
                                      : '—',
                                  style: cellStyle.copyWith(color: const Color(0xFF64748B)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(
                              LocationSelection(
                                towerIds: lines[i].towerIds,
                                floorNos: lines[i].floorNos,
                                unitIds: lines[i].unitIds,
                              ).towerLabel(towers),
                              style: cellStyle.copyWith(color: const Color(0xFF2563eb), fontWeight: FontWeight.w600),
                            )),
                            DataCell(Text(
                              LocationSelection(
                                towerIds: lines[i].towerIds,
                                floorNos: lines[i].floorNos,
                                unitIds: lines[i].unitIds,
                              ).floorLabel(),
                              style: cellStyle,
                            )),
                            DataCell(Text(
                              LocationSelection(
                                towerIds: lines[i].towerIds,
                                floorNos: lines[i].floorNos,
                                unitIds: lines[i].unitIds,
                              ).unitLabel(),
                              style: cellStyle,
                            )),
                            DataCell(Text(
                              lines[i].quantity?.toStringAsFixed(2) ?? '—',
                              style: cellStyle.copyWith(fontWeight: FontWeight.w600),
                            )),
                            DataCell(Text(lines[i].unitCode ?? '—', style: cellStyle)),
                            DataCell(
                              SizedBox(
                                width: 96,
                                child: TextFormField(
                                  key: ValueKey('rate-$i-${lines[i].boqTaskId ?? lines[i].taskName}'),
                                  initialValue: lines[i].rate?.toStringAsFixed(2) ?? '',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  style: cellStyle.copyWith(fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF2A2622) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                  onChanged: (v) {
                                    final n = double.tryParse(v);
                                    if (n != null) onRateChanged(i, n);
                                  },
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  key: ValueKey('amt-$i-${lines[i].boqTaskId ?? lines[i].taskName}-${lines[i].rate}'),
                                  initialValue: lines[i].computedAmount.toStringAsFixed(2),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  style: cellStyle.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0f766e),
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: const Color(0xFFCCFBF1).withValues(alpha: isDark ? 0.15 : 0.55),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: const Color(0xFF99F6E4).withValues(alpha: 0.8)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                  onChanged: (v) {
                                    final n = double.tryParse(v);
                                    if (n != null) onAmountChanged(i, n);
                                  },
                                ),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () => onRemove(i),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252220) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Grand total',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).hintColor),
                ),
                const Spacer(),
                Text(
                  total.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0f766e)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
