import 'package:flutter/material.dart';

import '../../domain/salary_models.dart';

enum _UiRuleType { fixed, sum, percentage, conditional }

class SalaryRuleEditorSheet extends StatefulWidget {
  const SalaryRuleEditorSheet({
    super.key,
    required this.column,
    this.existingRule,
    required this.allColumns,
    required this.ruleEditorEnabled,
    required this.onSave,
    this.defaultFixedValue,
  });

  final PayCommissionColumn column;
  final SalaryRule? existingRule;
  final List<PayCommissionColumn> allColumns;
  final bool ruleEditorEnabled;
  final Future<void> Function(Map<String, dynamic> body) onSave;
  final num? defaultFixedValue;

  static Future<void> show(
    BuildContext context, {
    required PayCommissionColumn column,
    SalaryRule? existingRule,
    required List<PayCommissionColumn> allColumns,
    required bool ruleEditorEnabled,
    required Future<void> Function(Map<String, dynamic> body) onSave,
    num? defaultFixedValue,
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
  String _refColumn = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initFromRule();
  }

  void _initFromRule() {
    final rule = widget.existingRule;
    final prior = _priorColumns();
    _refColumn = prior.isNotEmpty ? prior.first.visibilityKey : 'EARNING::basic';

    if (!widget.ruleEditorEnabled || rule == null) {
      _ruleType = _UiRuleType.fixed;
      _fixedCtrl.text = rule?.fixedDefaultValue ??
          widget.defaultFixedValue?.toString() ??
          '0';
      return;
    }

    if (rule.ruleType == SalaryRuleType.fixed) {
      _ruleType = _UiRuleType.fixed;
      _fixedCtrl.text = rule.fixedDefaultValue ?? '0';
    } else if (rule.ruleType == SalaryRuleType.conditional) {
      _ruleType = _UiRuleType.conditional;
    } else {
      final pct = num.tryParse(rule.percentageValue ?? '') ?? 0;
      final isSum = pct == 100 && rule.percentageReferenceColumns.isNotEmpty;
      _ruleType = isSum ? _UiRuleType.sum : _UiRuleType.percentage;
      _percentageCtrl.text = rule.percentageValue ?? '100';
      if (rule.percentageReferenceColumns.isNotEmpty) {
        _refColumn = rule.percentageReferenceColumns.first.columnIdentifier;
      }
    }
  }

  List<PayCommissionColumn> _priorColumns() {
    return widget.allColumns
        .where((c) => c.evaluationOrder < widget.column.evaluationOrder)
        .toList();
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
          'percentage_reference_columns': [
            {'column_identifier': _refColumn, 'weight': 1},
          ],
        };
      case _UiRuleType.percentage:
        return {
          'rule_type': 'PERCENTAGE',
          'percentage_value': num.tryParse(_percentageCtrl.text) ?? 0,
          'percentage_reference_columns': [
            {'column_identifier': _refColumn, 'weight': 1},
          ],
        };
      case _UiRuleType.conditional:
        return {
          'rule_type': 'CONDITIONAL',
          'conditions': [
            {
              'comparator': 'GREATER_THAN_OR_EQUAL',
              'reference_column_identifier': _refColumn,
              'threshold_value': 0,
              'result_type': 'FIXED_AMOUNT',
              'result_value': num.tryParse(_fixedCtrl.text) ?? 0,
              'sort_order': 0,
              'is_else_fallback': false,
            },
            {
              'comparator': 'EQUAL',
              'reference_column_identifier': _refColumn,
              'threshold_value': 0,
              'result_type': 'FIXED_AMOUNT',
              'result_value': 0,
              'sort_order': 1,
              'is_else_fallback': true,
            },
          ],
        };
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_buildPayload());
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _fixedCtrl.dispose();
    _percentageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prior = _priorColumns();
    final refOptions = prior.isEmpty
        ? ['EARNING::basic']
        : prior.map((c) => c.visibilityKey).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.ruleEditorEnabled
                  ? 'Edit rule — ${widget.column.displayName}'
                  : 'Set amount — ${widget.column.displayName}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 16),
            if (widget.ruleEditorEnabled) ...[
              DropdownButtonFormField<_UiRuleType>(
                initialValue: _ruleType,
                decoration: const InputDecoration(labelText: 'Rule type'),
                items: [
                  DropdownMenuItem(value: _UiRuleType.fixed, child: Text('Fixed amount')),
                  DropdownMenuItem(value: _UiRuleType.sum, child: Text('Sum of column')),
                  DropdownMenuItem(value: _UiRuleType.percentage, child: Text('Percentage of column')),
                  DropdownMenuItem(value: _UiRuleType.conditional, child: Text('Conditional (simple)')),
                ],
                onChanged: (v) => setState(() => _ruleType = v ?? _UiRuleType.fixed),
              ),
              SizedBox(height: 12),
            ],
            if (_ruleType == _UiRuleType.fixed ||
                _ruleType == _UiRuleType.conditional) ...[
              TextField(
                controller: _fixedCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _ruleType == _UiRuleType.conditional
                      ? 'If condition met (₹)'
                      : 'Default amount (₹)',
                ),
              ),
            ],
            if (_ruleType == _UiRuleType.percentage) ...[
              TextField(
                controller: _percentageCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Percentage'),
              ),
            ],
            if (_ruleType == _UiRuleType.sum ||
                _ruleType == _UiRuleType.percentage ||
                _ruleType == _UiRuleType.conditional) ...[
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: refOptions.contains(_refColumn) ? _refColumn : refOptions.first,
                decoration: const InputDecoration(labelText: 'Reference column'),
                items: refOptions
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (v) => setState(() => _refColumn = v ?? _refColumn),
              ),
            ],
            SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
