import 'package:flutter/material.dart';

import '../../domain/salary_models.dart';

enum _UiRuleType { fixed, sum, percentage, conditional }

class _RefOption {
  const _RefOption({required this.key, required this.label, required this.group});
  final String key;
  final String label;
  final String group; // earnings | deductions | computed
}

class _CondRow {
  _CondRow({
    required this.comparator,
    required this.referenceColumnIdentifier,
    required this.thresholdValue,
    required this.resultType,
    required this.resultValue,
    required this.resultReferenceColumns,
    required this.sortOrder,
    required this.isElseFallback,
  });

  String comparator;
  String referenceColumnIdentifier;
  num thresholdValue;
  String resultType; // FIXED_AMOUNT | PERCENTAGE_OF_COLUMN
  num resultValue;
  List<SalaryRuleReferenceColumn> resultReferenceColumns;
  int sortOrder;
  bool isElseFallback;
}

const _comparators = [
  ('GREATER_THAN', '>'),
  ('LESS_THAN', '<'),
  ('GREATER_THAN_OR_EQUAL', '≥'),
  ('LESS_THAN_OR_EQUAL', '≤'),
  ('EQUAL', '='),
];

const _earningCrossRef = {'gratuity', 'provident_fund'};
const _totalRows = {'gross_pay', 'total_deductions', 'net_pay'};

/// Full rule editor matching web RuleEditorDrawer + reference screenshots.
class SalaryRuleEditorSheet extends StatefulWidget {
  const SalaryRuleEditorSheet({
    super.key,
    required this.column,
    this.existingRule,
    required this.allColumns,
    required this.ruleEditorEnabled,
    required this.onSave,
    this.defaultFixedValue,
    this.employeeMode = false,
    this.employeeLabel,
  });

  final PayCommissionColumn column;
  final SalaryRule? existingRule;
  final List<PayCommissionColumn> allColumns;
  final bool ruleEditorEnabled;
  final Future<void> Function(Map<String, dynamic> body) onSave;
  final num? defaultFixedValue;
  final bool employeeMode;
  final String? employeeLabel;

  static Future<void> show(
    BuildContext context, {
    required PayCommissionColumn column,
    SalaryRule? existingRule,
    required List<PayCommissionColumn> allColumns,
    required bool ruleEditorEnabled,
    required Future<void> Function(Map<String, dynamic> body) onSave,
    num? defaultFixedValue,
    bool employeeMode = false,
    String? employeeLabel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SalaryRuleEditorSheet(
        column: column,
        existingRule: existingRule,
        allColumns: allColumns,
        ruleEditorEnabled: ruleEditorEnabled,
        onSave: onSave,
        defaultFixedValue: defaultFixedValue,
        employeeMode: employeeMode,
        employeeLabel: employeeLabel,
      ),
    );
  }

  @override
  State<SalaryRuleEditorSheet> createState() => _SalaryRuleEditorSheetState();
}

class _SalaryRuleEditorSheetState extends State<SalaryRuleEditorSheet> {
  late _UiRuleType _ruleType;
  final _fixedCtrl = TextEditingController();
  final _percentageCtrl = TextEditingController(text: '100');
  List<SalaryRuleReferenceColumn> _sumRefs = [];
  List<_CondRow> _conditions = [];
  bool _saving = false;

  List<_RefOption> get _referenceOptions =>
      _buildReferenceOptions(widget.allColumns, widget.column);

  List<_RefOption> get _sumColumnOptions => _referenceOptions
      .where((o) =>
          o.group != 'computed' ||
          o.key == 'EARNING::gross_pay' ||
          o.key == 'DEDUCTION::total_deductions')
      .toList();

  @override
  void initState() {
    super.initState();
    _initFromRule();
  }

  void _initFromRule() {
    final prior = _sumColumnOptions;
    final refs = _defaultSumRefs(widget.column, prior);
    final firstRef = _referenceOptions.isNotEmpty
        ? _referenceOptions.first.key
        : (refs.isNotEmpty ? refs.first.columnIdentifier : 'EARNING::basic');

    if (!widget.ruleEditorEnabled) {
      _ruleType = _UiRuleType.fixed;
      _fixedCtrl.text = widget.existingRule?.fixedDefaultValue ??
          widget.defaultFixedValue?.toString() ??
          '0';
      _sumRefs = refs;
      return;
    }

    final rule = widget.existingRule;
    if (rule != null) {
      final pct = num.tryParse(rule.percentageValue ?? '') ?? 0;
      final isSum =
          rule.ruleType == SalaryRuleType.percentage &&
          pct == 100 &&
          rule.percentageReferenceColumns.isNotEmpty;

      if (rule.ruleType == SalaryRuleType.fixed) {
        _ruleType = _UiRuleType.fixed;
      } else if (rule.ruleType == SalaryRuleType.conditional) {
        _ruleType = _UiRuleType.conditional;
      } else {
        _ruleType = isSum ? _UiRuleType.sum : _UiRuleType.percentage;
      }

      _fixedCtrl.text = rule.fixedDefaultValue ?? '';
      _percentageCtrl.text = rule.percentageValue ?? '100';
      _sumRefs = rule.percentageReferenceColumns.isNotEmpty
          ? List.from(rule.percentageReferenceColumns)
          : refs;

      if (rule.conditions.isNotEmpty) {
        _conditions = rule.conditions.map((c) {
          var resultRefs = c.resultReferenceColumns;
          if (resultRefs.isEmpty && c.resultReferenceColumnIdentifier != null) {
            resultRefs = [
              SalaryRuleReferenceColumn(
                columnIdentifier: c.resultReferenceColumnIdentifier!,
              ),
            ];
          }
          return _CondRow(
            comparator: c.comparator,
            referenceColumnIdentifier: c.referenceColumnIdentifier,
            thresholdValue: num.tryParse(c.thresholdValue) ?? 0,
            resultType: c.resultType,
            resultValue: num.tryParse(c.resultValue) ?? 0,
            resultReferenceColumns: List.from(resultRefs),
            sortOrder: c.sortOrder,
            isElseFallback: c.isElseFallback,
          );
        }).toList();
      } else {
        _conditions = _defaultConditions(firstRef);
      }
      return;
    }

    final id = widget.column.columnIdentifier;
    final isMirror = widget.column.category == SalaryColumnCategory.deduction &&
        _earningCrossRef.contains(id);
    _ruleType = isMirror
        ? _UiRuleType.percentage
        : (id == 'new_basic' ||
                id == 'gross_pay' ||
                id == 'total_deductions' ||
                id == 'net_pay')
            ? _UiRuleType.sum
            : _UiRuleType.fixed;
    _fixedCtrl.text = widget.defaultFixedValue?.toString() ?? '';
    _percentageCtrl.text = '100';
    _sumRefs = refs;
    _conditions = _defaultConditions(firstRef);
  }

  List<_CondRow> _defaultConditions(String firstRef) {
    final elseRefs = widget.column.category == SalaryColumnCategory.deduction
        ? [const SalaryRuleReferenceColumn(columnIdentifier: 'EARNING::new_basic')]
        : [SalaryRuleReferenceColumn(columnIdentifier: firstRef)];
    return [
      _CondRow(
        comparator: 'GREATER_THAN_OR_EQUAL',
        referenceColumnIdentifier: firstRef,
        thresholdValue: 0,
        resultType: 'FIXED_AMOUNT',
        resultValue: 0,
        resultReferenceColumns: [],
        sortOrder: 0,
        isElseFallback: false,
      ),
      _CondRow(
        comparator: 'EQUAL',
        referenceColumnIdentifier: firstRef,
        thresholdValue: 0,
        resultType: 'PERCENTAGE_OF_COLUMN',
        resultValue: 0,
        resultReferenceColumns: elseRefs,
        sortOrder: 1,
        isElseFallback: true,
      ),
    ];
  }

  String _columnLabel(String refKey) {
    final fromOpt = _referenceOptions.where((o) => o.key == refKey).toList();
    if (fromOpt.isNotEmpty) return fromOpt.first.label;
    final bare = refKey.contains('::') ? refKey.split('::').last : refKey;
    for (final c in widget.allColumns) {
      if (c.columnIdentifier == bare) return c.displayName;
    }
    return bare;
  }

  String get _preview {
    String label(String id) => _columnLabel(id);
    switch (_ruleType) {
      case _UiRuleType.fixed:
        return 'Fixed: ₹${num.tryParse(_fixedCtrl.text) ?? 0}';
      case _UiRuleType.sum:
        final parts = _sumRefs.map((r) {
          final lbl = label(r.columnIdentifier);
          if (r.weight == 1) return lbl;
          if (r.weight == -1) return '− $lbl';
          return '${r.weight} × $lbl';
        }).toList();
        return parts.isEmpty ? '' : parts.join(' ');
      case _UiRuleType.percentage:
        final pct = num.tryParse(_percentageCtrl.text) ?? 0;
        final parts = _sumRefs.map((r) => label(r.columnIdentifier)).toList();
        final base = parts.length > 1 ? '(${parts.join(' + ')})' : (parts.isEmpty ? '' : parts.first);
        return '$pct% of $base';
      case _UiRuleType.conditional:
        final sorted = [..._conditions]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return sorted.map((c) {
          if (c.isElseFallback) {
            return 'Else → ${_formatPayAmount(c)}';
          }
          String sym = c.comparator;
          for (final pair in _comparators) {
            if (pair.$1 == c.comparator) {
              sym = pair.$2;
              break;
            }
          }
          return 'If ${label(c.referenceColumnIdentifier)} $sym ₹${c.thresholdValue} → ${_formatPayAmount(c)}';
        }).join(' | ');
    }
  }

  String _formatPayAmount(_CondRow c) {
    if (c.resultType == 'FIXED_AMOUNT') return '₹${c.resultValue}';
    final parts = c.resultReferenceColumns.map((r) => _columnLabel(r.columnIdentifier));
    final base = parts.length > 1 ? '(${parts.join(' + ')})' : (parts.isEmpty ? '' : parts.first);
    return '${c.resultValue}% of $base';
  }

  Map<String, dynamic> _buildPayload() {
    switch (_ruleType) {
      case _UiRuleType.fixed:
        return {
          'rule_type': 'FIXED',
          'default_value': num.tryParse(_fixedCtrl.text) ?? 0,
        };
      case _UiRuleType.sum:
        return {
          'rule_type': 'PERCENTAGE',
          'percentage_value': 100,
          'percentage_reference_columns': _sumRefs
              .where((r) => r.columnIdentifier.isNotEmpty)
              .map((r) => r.toJson())
              .toList(),
        };
      case _UiRuleType.percentage:
        return {
          'rule_type': 'PERCENTAGE',
          'percentage_value': num.tryParse(_percentageCtrl.text) ?? 0,
          'percentage_reference_columns': _sumRefs
              .where((r) => r.columnIdentifier.isNotEmpty)
              .map((r) => r.toJson())
              .toList(),
        };
      case _UiRuleType.conditional:
        return {
          'rule_type': 'CONDITIONAL',
          'conditions': _conditions.map((c) {
            return {
              'comparator': c.comparator,
              'reference_column_identifier': c.referenceColumnIdentifier,
              'threshold_value': c.thresholdValue,
              'result_type': c.resultType,
              'result_value': c.resultValue,
              'result_reference_column_identifier': c.resultType == 'PERCENTAGE_OF_COLUMN'
                  ? (c.resultReferenceColumns.isNotEmpty
                      ? c.resultReferenceColumns.first.columnIdentifier
                      : null)
                  : null,
              'result_reference_columns': c.resultType == 'PERCENTAGE_OF_COLUMN'
                  ? c.resultReferenceColumns.map((r) => r.toJson()).toList()
                  : null,
              'sort_order': c.sortOrder,
              'is_else_fallback': c.isElseFallback,
            };
          }).toList(),
        };
    }
  }

  Future<void> _save() async {
    if ((_ruleType == _UiRuleType.sum || _ruleType == _UiRuleType.percentage) &&
        _sumRefs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one column to the formula.')),
      );
      return;
    }
    if (_ruleType == _UiRuleType.conditional) {
      for (final c in _conditions) {
        if (c.resultType == 'PERCENTAGE_OF_COLUMN' &&
            c.resultReferenceColumns.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                c.isElseFallback
                    ? 'Else branch: add at least one column for the percentage.'
                    : 'Each percentage result must specify at least one column.',
              ),
            ),
          );
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(_buildPayload());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addCondition() {
    final firstRef =
        _referenceOptions.isNotEmpty ? _referenceOptions.first.key : 'EARNING::basic';
    final nonElse = _conditions.where((c) => !c.isElseFallback).toList();
    final elseRow = _conditions.where((c) => c.isElseFallback).toList();
    final updated = [
      ...nonElse,
      _CondRow(
        comparator: 'GREATER_THAN_OR_EQUAL',
        referenceColumnIdentifier: firstRef,
        thresholdValue: 0,
        resultType: 'FIXED_AMOUNT',
        resultValue: 0,
        resultReferenceColumns: [],
        sortOrder: nonElse.length,
        isElseFallback: false,
      ),
    ];
    if (elseRow.isNotEmpty) {
      updated.add(elseRow.first..sortOrder = updated.length);
    }
    setState(() => _conditions = updated);
  }

  @override
  void dispose() {
    _fixedCtrl.dispose();
    _percentageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.employeeMode
        ? '${widget.column.displayName} — this employee only'
        : widget.column.displayName;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (widget.employeeMode) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'Saved only for ${widget.employeeLabel ?? 'this employee'}. Designation-wide rules are not changed.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.ruleEditorEnabled) ...[
              const Text('Rule Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<_UiRuleType>(
                initialValue: _ruleType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: _UiRuleType.fixed, child: Text('Fixed amount')),
                  DropdownMenuItem(value: _UiRuleType.sum, child: Text('Sum of columns')),
                  DropdownMenuItem(value: _UiRuleType.percentage, child: Text('Percentage of columns')),
                  DropdownMenuItem(value: _UiRuleType.conditional, child: Text('Conditional')),
                ],
                onChanged: (v) => setState(() => _ruleType = v ?? _UiRuleType.fixed),
              ),
              const SizedBox(height: 14),
            ],
            if (_preview.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREVIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_preview, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_ruleType == _UiRuleType.fixed) ...[
              TextField(
                controller: _fixedCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Default Value (₹)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Text(
                'Pre-fills for all employees of this designation; can be overridden per employee.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            if (_ruleType == _UiRuleType.sum) ...[
              Text(
                widget.column.columnIdentifier == 'net_pay'
                    ? 'Combine columns — use weight −1 to subtract deductions from Gross Pay.'
                    : 'Add columns to combine — e.g. New Basic = Basic + Academic Grade Pay',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              _buildColumnPicker(
                refs: _sumRefs,
                onChange: (next) => setState(() => _sumRefs = next),
                options: _sumColumnOptions,
                showWeight: widget.column.columnIdentifier == 'net_pay' ||
                    widget.column.columnIdentifier == 'total_deductions',
              ),
            ],
            if (_ruleType == _UiRuleType.percentage) ...[
              TextField(
                controller: _percentageCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Percentage (%)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _buildColumnPicker(
                refs: _sumRefs,
                onChange: (next) => setState(() => _sumRefs = next),
                options: _referenceOptions,
                showWeight: true,
              ),
            ],
            if (_ruleType == _UiRuleType.conditional) ..._buildConditionalEditor(),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                _saving
                    ? 'Saving…'
                    : (widget.employeeMode ? 'Save for this employee' : 'Save Rule'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConditionalEditor() {
    final ifRows = _conditions.where((c) => !c.isElseFallback).toList();
    final elseRows = _conditions.where((c) => c.isElseFallback).toList();
    return [
      for (var idx = 0; idx < ifRows.length; idx++) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                idx == 0 ? 'IF' : 'ELSE IF',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: ifRows[idx].comparator,
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _comparators
                          .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)))
                          .toList(),
                      onChanged: (v) => setState(() => ifRows[idx].comparator = v ?? ifRows[idx].comparator),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: ifRows[idx].referenceColumnIdentifier,
                      decoration: const InputDecoration(
                        labelText: 'Column',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _referenceOptions
                          .map((o) => DropdownMenuItem(value: o.key, child: Text(o.label, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setState(
                        () => ifRows[idx].referenceColumnIdentifier =
                            v ?? ifRows[idx].referenceColumnIdentifier,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: ifRows[idx].thresholdValue.toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Threshold (₹)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => ifRows[idx].thresholdValue = num.tryParse(v) ?? 0),
              ),
              const Divider(height: 24),
              Text(
                'THEN PAY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              _buildResultEditor(ifRows[idx]),
            ],
          ),
        ),
      ],
      OutlinedButton.icon(
        onPressed: _addCondition,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Condition'),
      ),
      const SizedBox(height: 12),
      for (final elseRow in elseRows)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ELSE (DEFAULT)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Used when no condition above matches.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 8),
              _buildResultEditor(elseRow),
            ],
          ),
        ),
    ];
  }

  Widget _buildResultEditor(_CondRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: row.resultType,
          decoration: const InputDecoration(
            labelText: 'Amount type',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: 'FIXED_AMOUNT', child: Text('Fixed amount (₹)')),
            DropdownMenuItem(value: 'PERCENTAGE_OF_COLUMN', child: Text('Percentage of a column')),
          ],
          onChanged: (v) => setState(() => row.resultType = v ?? row.resultType),
        ),
        const SizedBox(height: 8),
        if (row.resultType == 'FIXED_AMOUNT')
          TextFormField(
            initialValue: row.resultValue.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => row.resultValue = num.tryParse(v) ?? 0),
          )
        else ...[
          TextFormField(
            initialValue: row.resultValue.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Percentage (%)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => row.resultValue = num.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 8),
          Text(
            row.isElseFallback
                ? 'Of column(s) — use "from Earnings" for PF / Gratuity'
                : 'Of column(s)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          _buildColumnPicker(
            refs: row.resultReferenceColumns,
            onChange: (next) => setState(() => row.resultReferenceColumns = next),
            options: _referenceOptions,
          ),
        ],
      ],
    );
  }

  Widget _buildColumnPicker({
    required List<SalaryRuleReferenceColumn> refs,
    required ValueChanged<List<SalaryRuleReferenceColumn>> onChange,
    required List<_RefOption> options,
    bool showWeight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var idx = 0; idx < refs.length; idx++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: options.any((o) => o.key == refs[idx].columnIdentifier)
                      ? refs[idx].columnIdentifier
                      : (options.isNotEmpty ? options.first.key : null),
                  decoration: InputDecoration(
                    labelText: 'Column ${idx + 1}',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: options
                      .map((o) => DropdownMenuItem(
                            value: o.key,
                            child: Text(o.label, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final next = List<SalaryRuleReferenceColumn>.from(refs);
                    next[idx] = SalaryRuleReferenceColumn(
                      columnIdentifier: v,
                      weight: refs[idx].weight,
                    );
                    onChange(next);
                  },
                ),
              ),
              if (showWeight) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    initialValue: refs[idx].weight.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final next = List<SalaryRuleReferenceColumn>.from(refs);
                      next[idx] = SalaryRuleReferenceColumn(
                        columnIdentifier: refs[idx].columnIdentifier,
                        weight: num.tryParse(v) ?? 1,
                      );
                      onChange(next);
                    },
                  ),
                ),
              ],
              if (refs.length > 1)
                IconButton(
                  onPressed: () => onChange(
                    [for (var i = 0; i < refs.length; i++) if (i != idx) refs[i]],
                  ),
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: options.isEmpty
              ? null
              : () {
                  final nextKey = options.length > refs.length
                      ? options[refs.length].key
                      : options.first.key;
                  onChange([
                    ...refs,
                    SalaryRuleReferenceColumn(columnIdentifier: nextKey),
                  ]);
                },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add column'),
        ),
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No prior columns available. Configure earlier columns first (e.g. Basic).',
              style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
            ),
          ),
      ],
    );
  }
}

List<_RefOption> _buildReferenceOptions(
  List<PayCommissionColumn> allColumns,
  PayCommissionColumn forColumn,
) {
  final options = <_RefOption>[];
  final seen = <String>{};

  void add(String key, String label, String group) {
    if (seen.contains(key)) return;
    seen.add(key);
    options.add(_RefOption(key: key, label: label, group: group));
  }

  for (final c in allColumns) {
    if (c.category == forColumn.category &&
        c.columnIdentifier == forColumn.columnIdentifier) {
      continue;
    }

    final isGrossPayRef = c.columnIdentifier == 'gross_pay' &&
        c.category == SalaryColumnCategory.earning &&
        forColumn.columnIdentifier != 'gross_pay';
    final isTotalDedRef = c.columnIdentifier == 'total_deductions' &&
        c.category == SalaryColumnCategory.deduction &&
        forColumn.columnIdentifier != 'total_deductions';

    if (c.evaluationOrder >= forColumn.evaluationOrder &&
        !isGrossPayRef &&
        !isTotalDedRef) {
      continue;
    }

    if (isGrossPayRef) {
      add('EARNING::gross_pay', 'Gross Pay', 'computed');
      continue;
    }
    if (isTotalDedRef) {
      add('DEDUCTION::total_deductions', 'Total Deductions', 'computed');
      continue;
    }
    if (c.columnIdentifier == 'net_pay' || c.columnIdentifier == 'total_deductions') {
      continue;
    }

    final key = c.visibilityKey;
    add(
      key,
      c.displayName,
      c.category == SalaryColumnCategory.earning ? 'earnings' : 'deductions',
    );
  }

  if (forColumn.category == SalaryColumnCategory.deduction) {
    for (final c in allColumns) {
      if (c.category != SalaryColumnCategory.earning) continue;
      if (_totalRows.contains(c.columnIdentifier)) continue;
      if (!_earningCrossRef.contains(c.columnIdentifier)) continue;
      add('EARNING::${c.columnIdentifier}', '${c.displayName} (from Earnings)', 'earnings');
    }
  }

  return options;
}

List<SalaryRuleReferenceColumn> _defaultSumRefs(
  PayCommissionColumn column,
  List<_RefOption> priorOptions,
) {
  SalaryRuleReferenceColumn? find(String key) {
    final hit = priorOptions.where((o) => o.key == key).toList();
    if (hit.isEmpty) return null;
    return SalaryRuleReferenceColumn(columnIdentifier: hit.first.key);
  }

  if (column.columnIdentifier == 'new_basic') {
    final basic = find('EARNING::basic');
    final agp = find('EARNING::academic_grade_pay') ?? find('EARNING::dearness_pay');
    final refs = [basic, agp].whereType<SalaryRuleReferenceColumn>().toList();
    if (refs.isNotEmpty) return refs;
  }

  if (column.category == SalaryColumnCategory.deduction &&
      _earningCrossRef.contains(column.columnIdentifier)) {
    final earningKey = 'EARNING::${column.columnIdentifier}';
    if (priorOptions.any((o) => o.key == earningKey)) {
      return [SalaryRuleReferenceColumn(columnIdentifier: earningKey)];
    }
  }

  if (column.columnIdentifier == 'gross_pay') {
    return priorOptions
        .where((o) => o.group == 'earnings')
        .map((o) => SalaryRuleReferenceColumn(columnIdentifier: o.key))
        .toList();
  }

  if (column.columnIdentifier == 'total_deductions') {
    return priorOptions
        .where((o) => o.group == 'deductions')
        .map((o) => SalaryRuleReferenceColumn(columnIdentifier: o.key))
        .toList();
  }

  if (column.columnIdentifier == 'net_pay') {
    final gross = find('EARNING::gross_pay');
    final totalDed = find('DEDUCTION::total_deductions');
    if (gross != null && totalDed != null) {
      return [
        gross,
        SalaryRuleReferenceColumn(columnIdentifier: totalDed.columnIdentifier, weight: -1),
      ];
    }
  }

  if (priorOptions.isNotEmpty) {
    return [SalaryRuleReferenceColumn(columnIdentifier: priorOptions.first.key)];
  }
  return [const SalaryRuleReferenceColumn(columnIdentifier: 'EARNING::basic')];
}
