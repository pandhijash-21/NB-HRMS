import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/project_repository.dart';
import '../../domain/structure_models.dart';

/// Forces completion of unit fields required for quotation / final deal / post-sales.
/// Same spirit as the quick-create "+" dialogs — fill gaps, save, return updated unit.
Future<ErpProjectUnit?> showCompleteUnitDetailsDialog({
  required BuildContext context,
  required String projectId,
  required String towerId,
  required ErpProjectUnit unit,
  String? reason,
}) {
  return showDialog<ErpProjectUnit>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CompleteUnitDetailsDialog(
      projectId: projectId,
      towerId: towerId,
      unit: unit,
      reason: reason ??
          'Complete unit details before quotation / final deal / post-sales.',
    ),
  );
}

class _CompleteUnitDetailsDialog extends StatefulWidget {
  const _CompleteUnitDetailsDialog({
    required this.projectId,
    required this.towerId,
    required this.unit,
    required this.reason,
  });

  final String projectId;
  final String towerId;
  final ErpProjectUnit unit;
  final String reason;

  @override
  State<_CompleteUnitDetailsDialog> createState() => _CompleteUnitDetailsDialogState();
}

class _CompleteUnitDetailsDialogState extends State<_CompleteUnitDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _unitNo;
  late final TextEditingController _floorNo;
  late final TextEditingController _superBuiltUp;
  late final TextEditingController _carpet;
  late final TextEditingController _builtUp;
  late final TextEditingController _balcony;
  late final TextEditingController _terrace;
  late final TextEditingController _plot;
  late final TextEditingController _parking;
  late final TextEditingController _baseRate;
  late final TextEditingController _plc;
  late final TextEditingController _frc;
  late final TextEditingController _devCharge;
  late final TextEditingController _remarks;

  String? _unitTypeCode;
  String? _areaUnitCode;
  String? _statusCode;
  String? _facingCode;
  String? _categoryCode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.unit;
    _unitNo = TextEditingController(text: u.unitNo);
    _floorNo = TextEditingController(text: u.floorNo.toString());
    _superBuiltUp = TextEditingController(text: _n(u.superBuiltUp));
    _carpet = TextEditingController(text: _n(u.carpetArea));
    _builtUp = TextEditingController(text: _n(u.builtUpArea));
    _balcony = TextEditingController(text: _n(u.balconyArea));
    _terrace = TextEditingController(text: _n(u.terraceArea));
    _plot = TextEditingController(text: _n(u.plotArea));
    _parking = TextEditingController(text: u.parkingAllocation ?? '');
    _baseRate = TextEditingController(text: _n(u.baseRate));
    _plc = TextEditingController(text: _n(u.plc));
    _frc = TextEditingController(text: _n(u.frc));
    _devCharge = TextEditingController(text: _n(u.developmentCharge));
    _remarks = TextEditingController(text: u.remarks ?? '');
    _unitTypeCode = u.unitTypeCode;
    _areaUnitCode = u.areaUnitCode ?? 'SQ_FT';
    _statusCode = u.statusCode ?? 'AVAILABLE';
    _facingCode = u.facingCode;
    _categoryCode = u.categoryCode;
  }

  String _n(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void dispose() {
    _unitNo.dispose();
    _floorNo.dispose();
    _superBuiltUp.dispose();
    _carpet.dispose();
    _builtUp.dispose();
    _balcony.dispose();
    _terrace.dispose();
    _plot.dispose();
    _parking.dispose();
    _baseRate.dispose();
    _plc.dispose();
    _frc.dispose();
    _devCharge.dispose();
    _remarks.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  double? _d(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_unitTypeCode == null || _unitTypeCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit Type is required')),
      );
      return;
    }
    if (_facingCode == null || _facingCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facing is required')),
      );
      return;
    }
    if (_categoryCode == null || _categoryCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit Category is required')),
      );
      return;
    }
    if (_areaUnitCode == null || _areaUnitCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Area Unit is required')),
      );
      return;
    }
    if (_statusCode == null || _statusCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit Status is required')),
      );
      return;
    }

    final superBuiltUp = _d(_superBuiltUp);
    final carpet = _d(_carpet);
    final builtUp = _d(_builtUp);
    final balcony = _d(_balcony);
    final terrace = _d(_terrace);
    final plot = _d(_plot);
    final baseRate = _d(_baseRate);
    final plc = _d(_plc) ?? 0;
    final frc = _d(_frc) ?? 0;
    final dev = _d(_devCharge) ?? 0;
    if (superBuiltUp == null || carpet == null || builtUp == null ||
        balcony == null || terrace == null || plot == null || baseRate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all area and base rate fields')),
      );
      return;
    }

    final area = superBuiltUp > 0 ? superBuiltUp : carpet;
    final totalUnitValue = (area * baseRate) + plc + frc + dev;
    final u = widget.unit;

    setState(() => _saving = true);
    try {
      final updated = await context.read<ProjectRepository>().updateUnit(
            projectId: widget.projectId,
            towerId: widget.towerId,
            unitId: u.id,
            body: {
              'unitNo': _unitNo.text.trim(),
              'unitTypeCode': _unitTypeCode,
              'floorNo': int.tryParse(_floorNo.text.trim()) ?? u.floorNo,
              'isDuplex': u.isDuplex,
              'superBuiltUp': superBuiltUp,
              'carpetArea': carpet,
              'areaUnitCode': _areaUnitCode,
              'statusCode': _statusCode,
              'facingCode': _facingCode,
              'categoryCode': _categoryCode,
              'builtUpArea': builtUp,
              'balconyArea': balcony,
              'terraceArea': terrace,
              'plotArea': plot,
              'parkingAllocation': _parking.text.trim(),
              'plc': plc,
              'frc': frc,
              'developmentCharge': dev,
              'baseRate': baseRate,
              'totalUnitValue': totalUnitValue,
              'totalValue': totalUnitValue,
              'grandTotal': totalUnitValue,
              'taxes': u.taxes
                  .map((t) => {
                        'name': t.name,
                        'ratePercent': t.ratePercent,
                        'amount': t.amount,
                      })
                  .toList(),
              'maintenance': u.maintenance
                  .map((m) => {
                        'name': m.name,
                        'ratePerSqft': m.ratePerSqft,
                        'amount': m.amount,
                        'calculationType': m.calculationType,
                      })
                  .toList(),
              'otherCharges': u.otherCharges
                  .map((o) => {
                        'name': o.name,
                        'docCount': o.docCount,
                        'feePerDoc': o.feePerDoc,
                        'amount': o.amount,
                      })
                  .toList(),
              'paymentTerms': u.paymentTerms
                  .map((p) => {
                        'name': p.name,
                        'percentPayment': p.percentPayment,
                        'lastDayMonths': p.lastDayMonths,
                        'sequence': p.sequence,
                        if (p.amount != null) 'amount': p.amount,
                      })
                  .toList(),
              'remarks': _remarks.text.trim(),
            },
          );
      if (!mounted) return;
      if (!updated.isComplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Still missing: ${updated.missingCompletenessFields.join(', ')}',
            ),
          ),
        );
        setState(() => _saving = false);
        return;
      }
      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missing = widget.unit.missingCompletenessFields;
    final numFmt = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.add_home_work_rounded, color: Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Complete Unit ${widget.unit.unitNo}'),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.reason, style: const TextStyle(fontSize: 13)),
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Missing: ${missing.join(', ')}',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _unitNo,
                        decoration: const InputDecoration(
                          labelText: 'Unit No *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: _req,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _floorNo,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Floor No *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: _req,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                lookupDropdown(
                  context: context,
                  category: 'PROJECT_UNIT_TYPE',
                  label: 'Unit Type',
                  value: _unitTypeCode,
                  required: true,
                  onChanged: (v) => setState(() => _unitTypeCode = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: lookupDropdown(
                        context: context,
                        category: 'PROJECT_UNIT_FACING',
                        label: 'Facing',
                        value: _facingCode,
                        required: true,
                        onChanged: (v) => setState(() => _facingCode = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: lookupDropdown(
                        context: context,
                        category: 'PROJECT_UNIT_CATEGORY',
                        label: 'Unit Category',
                        value: _categoryCode,
                        required: true,
                        onChanged: (v) => setState(() => _categoryCode = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: lookupDropdown(
                        context: context,
                        category: 'PROJECT_AREA_UNIT',
                        label: 'Area Unit',
                        value: _areaUnitCode,
                        required: true,
                        onChanged: (v) => setState(() => _areaUnitCode = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: lookupDropdown(
                        context: context,
                        category: 'PROJECT_UNIT_STATUS',
                        label: 'Unit Status',
                        value: _statusCode,
                        required: true,
                        onChanged: (v) => setState(() => _statusCode = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _numRow([
                  ('Super Built-up *', _superBuiltUp),
                  ('Carpet (RERA) *', _carpet),
                ], numFmt),
                const SizedBox(height: 10),
                _numRow([
                  ('Built-up *', _builtUp),
                  ('Balcony *', _balcony),
                ], numFmt),
                const SizedBox(height: 10),
                _numRow([
                  ('Terrace *', _terrace),
                  ('Plot *', _plot),
                ], numFmt),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _parking,
                  decoration: const InputDecoration(
                    labelText: 'Parking Allocation *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: _req,
                ),
                const SizedBox(height: 10),
                _numRow([
                  ('Base Rate ₹/sq.ft *', _baseRate),
                  ('PLC *', _plc),
                ], numFmt),
                const SizedBox(height: 10),
                _numRow([
                  ('FRC', _frc),
                  ('Dev Charge', _devCharge),
                ], numFmt),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _remarks,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Remarks *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: _req,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_saving ? 'Saving…' : 'Save & Continue'),
        ),
      ],
    );
  }

  Widget _numRow(List<(String, TextEditingController)> fields, TextInputFormatter fmt) {
    return Row(
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: fields[i].$2,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [fmt],
              decoration: InputDecoration(
                labelText: fields[i].$1,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              validator: fields[i].$1.contains('*') ? _req : null,
            ),
          ),
        ],
      ],
    );
  }
}
