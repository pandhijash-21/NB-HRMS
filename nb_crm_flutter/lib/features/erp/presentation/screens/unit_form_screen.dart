import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../domain/structure_models.dart';
import '../project_providers.dart';

class UnitFormScreen extends ConsumerStatefulWidget {
  const UnitFormScreen({
    super.key,
    required this.projectId,
    required this.towerId,
    required this.unitId,
  });

  final String projectId;
  final String towerId;
  final String unitId;

  @override
  ConsumerState<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends ConsumerState<UnitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _unitNo = TextEditingController();
  final _floorNo = TextEditingController();
  final _superBuiltUp = TextEditingController();
  final _carpet = TextEditingController();
  final _builtUp = TextEditingController();
  final _balcony = TextEditingController();
  final _terrace = TextEditingController();
  final _plot = TextEditingController();
  final _parking = TextEditingController();
  final _plc = TextEditingController();
  final _baseRate = TextEditingController();
  final _totalValue = TextEditingController();
  final _remarks = TextEditingController();

  String? _unitTypeCode;
  String? _areaUnitCode = 'SQ_FT';
  String? _statusCode = 'AVAILABLE';
  String? _facingCode;
  String? _categoryCode;
  bool _more = true;
  bool _saving = false;
  bool _hydrated = false;
  bool _updatingTotal = false;

  @override
  void initState() {
    super.initState();
    _superBuiltUp.addListener(_recalcTotal);
    _baseRate.addListener(_recalcTotal);
  }

  @override
  void dispose() {
    _superBuiltUp.removeListener(_recalcTotal);
    _baseRate.removeListener(_recalcTotal);
    _unitNo.dispose();
    _floorNo.dispose();
    _superBuiltUp.dispose();
    _carpet.dispose();
    _builtUp.dispose();
    _balcony.dispose();
    _terrace.dispose();
    _plot.dispose();
    _parking.dispose();
    _plc.dispose();
    _baseRate.dispose();
    _totalValue.dispose();
    _remarks.dispose();
    super.dispose();
  }

  void _recalcTotal() {
    if (_updatingTotal) return;
    final area = double.tryParse(_superBuiltUp.text.trim());
    final rate = double.tryParse(_baseRate.text.trim());
    if (area == null || rate == null) return;
    final total = area * rate;
    final next = total == total.roundToDouble()
        ? total.toStringAsFixed(0)
        : total.toStringAsFixed(2);
    if (_totalValue.text == next) return;
    _updatingTotal = true;
    _totalValue.text = next;
    _updatingTotal = false;
  }

  String _num(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2));

  void _hydrate(ErpProjectUnit u) {
    if (_hydrated) return;
    _hydrated = true;
    _unitNo.text = u.unitNo;
    _floorNo.text = '${u.floorNo}';
    _superBuiltUp.text = _num(u.superBuiltUp);
    _carpet.text = _num(u.carpetArea);
    _builtUp.text = _num(u.builtUpArea);
    _balcony.text = _num(u.balconyArea);
    _terrace.text = _num(u.terraceArea);
    _plot.text = _num(u.plotArea);
    _parking.text = u.parkingAllocation ?? '';
    _plc.text = _num(u.plc);
    _baseRate.text = _num(u.baseRate);
    _totalValue.text = _num(u.totalValue);
    _remarks.text = u.remarks ?? '';
    _unitTypeCode = u.unitTypeCode;
    _areaUnitCode = u.areaUnitCode ?? 'SQ_FT';
    _statusCode = u.statusCode ?? 'AVAILABLE';
    _facingCode = u.facingCode;
    _categoryCode = u.categoryCode;
  }

  InputDecoration _dec(String label, {bool required = true, String? hint, String? helper}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      helperText: helper,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'unitNo': _unitNo.text.trim(),
      'unitTypeCode': _unitTypeCode,
      'floorNo': int.tryParse(_floorNo.text.trim()),
      'superBuiltUp': double.tryParse(_superBuiltUp.text.trim()),
      'carpetArea': double.tryParse(_carpet.text.trim()),
      'areaUnitCode': _areaUnitCode,
      'statusCode': _statusCode,
      'facingCode': _facingCode,
      'categoryCode': _categoryCode,
      'builtUpArea': double.tryParse(_builtUp.text.trim()),
      'balconyArea': double.tryParse(_balcony.text.trim()),
      'terraceArea': double.tryParse(_terrace.text.trim()),
      'plotArea': double.tryParse(_plot.text.trim()),
      'parkingAllocation': _parking.text.trim(),
      'plc': double.tryParse(_plc.text.trim()),
      'baseRate': double.tryParse(_baseRate.text.trim()),
      'totalValue': double.tryParse(_totalValue.text.trim()),
      'remarks': _remarks.text.trim(),
    };
    try {
      await ref.read(projectRepositoryProvider).updateUnit(
            projectId: widget.projectId,
            towerId: widget.towerId,
            unitId: widget.unitId,
            body: body,
          );
      ref.invalidate(
        projectTowerDetailProvider((projectId: widget.projectId, towerId: widget.towerId)),
      );
      if (!mounted) return;
      context.go('/erp/structure/${widget.projectId}/towers/${widget.towerId}/units');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _grid(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 820
                ? 3
                : constraints.maxWidth >= 520
                    ? 2
                    : 1;
        const gap = 12.0;
        final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: fields.map((f) => SizedBox(width: w, child: f)).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final towerAsync = ref.watch(
      projectTowerDetailProvider((projectId: widget.projectId, towerId: widget.towerId)),
    );
    towerAsync.whenData((tower) {
      ErpProjectUnit? unit;
      for (final u in tower.units) {
        if (u.id == widget.unitId) {
          unit = u;
          break;
        }
      }
      if (unit != null && !_hydrated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hydrated) setState(() => _hydrate(unit!));
        });
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(_unitNo.text.isEmpty ? 'Unit details' : _unitNo.text),
        leading: AppBackButton(
          fallbackLocation: '/erp/structure/${widget.projectId}/towers/${widget.towerId}/units',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: towerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (_) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _card(
                'Unit',
                _grid([
                  TextFormField(
                    controller: _unitNo,
                    decoration: _dec('Unit No'),
                    validator: _req,
                  ),
                  lookupDropdown(
                    ref: ref,
                    category: 'PROJECT_UNIT_TYPE',
                    label: 'Unit Type',
                    value: _unitTypeCode,
                    required: true,
                    onChanged: (v) => setState(() => _unitTypeCode = v),
                  ),
                  TextFormField(
                    controller: _floorNo,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?[0-9]'))],
                    decoration: _dec(
                      'Floor No',
                      helper: '0 = Ground, 1+ = upper floors, -1 = Basement',
                    ),
                    validator: _req,
                  ),
                  TextFormField(
                    controller: _superBuiltUp,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: _dec('Super Built-up'),
                    validator: _req,
                  ),
                  TextFormField(
                    controller: _carpet,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: _dec('Carpet (RERA)'),
                    validator: _req,
                  ),
                  lookupDropdown(
                    ref: ref,
                    category: 'PROJECT_AREA_UNIT',
                    label: 'Area Unit',
                    value: _areaUnitCode,
                    required: true,
                    onChanged: (v) => setState(() => _areaUnitCode = v),
                  ),
                  lookupDropdown(
                    ref: ref,
                    category: 'PROJECT_UNIT_STATUS',
                    label: 'Unit Status',
                    value: _statusCode,
                    required: true,
                    onChanged: (v) => setState(() => _statusCode = v),
                  ),
                ]),
              ),
              _card(
                'More details',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _more = !_more),
                      child: Row(
                        children: [
                          Icon(
                            _more ? Icons.expand_less : Icons.expand_more,
                            color: const Color(0xFF2563eb),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Facing, Balcony, Terrace, Plot, Base Rate, PLC, Parking, Category, Remarks',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563eb),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_more) ...[
                      const SizedBox(height: 12),
                      _grid([
                        lookupDropdown(
                          ref: ref,
                          category: 'PROJECT_UNIT_FACING',
                          label: 'Facing',
                          value: _facingCode,
                          required: true,
                          onChanged: (v) => setState(() => _facingCode = v),
                        ),
                        lookupDropdown(
                          ref: ref,
                          category: 'PROJECT_UNIT_CATEGORY',
                          label: 'Unit Category',
                          value: _categoryCode,
                          required: true,
                          onChanged: (v) => setState(() => _categoryCode = v),
                        ),
                        TextFormField(
                          controller: _builtUp,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: _dec('Built-up Area'),
                          validator: _req,
                        ),
                        TextFormField(
                          controller: _balcony,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: _dec('Balcony Area'),
                          validator: _req,
                        ),
                        TextFormField(
                          controller: _terrace,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: _dec('Terrace Area'),
                          validator: _req,
                        ),
                        TextFormField(
                          controller: _plot,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: _dec('Plot Area'),
                          validator: _req,
                        ),
                        TextFormField(
                          controller: _parking,
                          decoration: _dec('Parking Allocation'),
                          validator: _req,
                        ),
                        TextFormField(
                          controller: _plc,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: _dec('PLC (Preferential Location Charges)'),
                          validator: _req,
                        ),
                        TextFormField(
                          controller: _baseRate,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: _dec('Base Rate'),
                          validator: _req,
                        ),
                        TextFormField(
                          controller: _totalValue,
                          readOnly: true,
                          decoration: _dec('Total Unit Value', hint: 'Super built-up × Base rate'),
                          validator: _req,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarks,
                        maxLines: 2,
                        decoration: _dec('Remarks'),
                        validator: _req,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String title, Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withValues(alpha: 0.15)
              : const Color(0xFFCFD8DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != 'More details')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          child,
        ],
      ),
    );
  }
}
