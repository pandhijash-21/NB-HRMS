import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/project_repository.dart';
import '../../domain/structure_models.dart';
import '../../domain/pricing_component_models.dart';

class _TaxRow {
  final TextEditingController nameCtrl;
  final TextEditingController percentCtrl;
  final TextEditingController amountCtrl;

  _TaxRow({required String name, required double percent, double amount = 0.0})
      : nameCtrl = TextEditingController(text: name),
        percentCtrl = TextEditingController(
          text: percent == percent.roundToDouble()
              ? percent.toStringAsFixed(0)
              : percent.toStringAsFixed(2),
        ),
        amountCtrl = TextEditingController(
          text: amount == amount.roundToDouble()
              ? amount.toStringAsFixed(0)
              : amount.toStringAsFixed(2),
        );

  void dispose() {
    nameCtrl.dispose();
    percentCtrl.dispose();
    amountCtrl.dispose();
  }
}

class _MaintenanceRow {
  final TextEditingController nameCtrl;
  final TextEditingController ratePerSqftCtrl;
  final TextEditingController amountCtrl;
  bool isPerSqft;

  _MaintenanceRow({
    required String name,
    double? ratePerSqft,
    double amount = 0.0,
    this.isPerSqft = true,
  })  : nameCtrl = TextEditingController(text: name),
        ratePerSqftCtrl = TextEditingController(
          text: ratePerSqft != null
              ? (ratePerSqft == ratePerSqft.roundToDouble()
                  ? ratePerSqft.toStringAsFixed(0)
                  : ratePerSqft.toStringAsFixed(2))
              : '',
        ),
        amountCtrl = TextEditingController(
          text: amount == amount.roundToDouble()
              ? amount.toStringAsFixed(0)
              : amount.toStringAsFixed(2),
        );

  void dispose() {
    nameCtrl.dispose();
    ratePerSqftCtrl.dispose();
    amountCtrl.dispose();
  }
}

class _OtherChargeRow {
  final TextEditingController nameCtrl;
  final TextEditingController docCountCtrl;
  final TextEditingController feePerDocCtrl;
  final TextEditingController amountCtrl;
  bool isDocsMode;

  _OtherChargeRow({
    required String name,
    int? docCount,
    double? feePerDoc,
    double amount = 0.0,
    this.isDocsMode = false,
  })  : nameCtrl = TextEditingController(text: name),
        docCountCtrl = TextEditingController(text: docCount != null ? '$docCount' : ''),
        feePerDocCtrl = TextEditingController(
          text: feePerDoc != null
              ? (feePerDoc == feePerDoc.roundToDouble()
                  ? feePerDoc.toStringAsFixed(0)
                  : feePerDoc.toStringAsFixed(2))
              : '',
        ),
        amountCtrl = TextEditingController(
          text: amount == amount.roundToDouble()
              ? amount.toStringAsFixed(0)
              : amount.toStringAsFixed(2),
        );

  void dispose() {
    nameCtrl.dispose();
    docCountCtrl.dispose();
    feePerDocCtrl.dispose();
    amountCtrl.dispose();
  }
}

class UnitFormScreen extends StatefulWidget {
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
  State<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends State<UnitFormScreen> {
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
  final _frc = TextEditingController();
  final _developmentCharge = TextEditingController();
  final _baseRate = TextEditingController();
  final _totalUnitValue = TextEditingController();
  final _totalValue = TextEditingController();
  final _remarks = TextEditingController();

  final List<_TaxRow> _taxes = [];
  final List<_MaintenanceRow> _maintenance = [];
  final List<_OtherChargeRow> _otherCharges = [];
  List<ErpPaymentTerm> _paymentTerms = [];
  List<ErpPaymentPlan> _paymentPlans = [];
  String? _selectedPlanId;
  List<ErpPricingComponent> _pricingComponents = [];
  bool _enableMaintenance = true;

  bool _isDuplex = false;
  bool _absorbUpperFloor = true;
  String? _unitTypeCode;
  String? _areaUnitCode = 'SQ_FT';
  String? _statusCode = 'AVAILABLE';
  String? _facingCode;
  String? _categoryCode;
  bool _more = true;
  bool _saving = false;
  bool _applyingBatch = false;
  bool _hydrated = false;
  bool _loading = true;
  bool _loadingTerms = false;
  String? _loadError;
  bool _updatingTotal = false;
  bool _devChargeIsPerSqft = true; // GEB/AMC is super built up x value
  bool _frcIsPerSqft = true;
  bool _plcIsPerSqft = true; // PLC is also super built up x base value

  ErpProjectTower? _tower;
  List<ErpProjectUnit> _otherUnits = [];

  @override
  void initState() {
    super.initState();
    _superBuiltUp.addListener(_recalcAllPricing);
    _baseRate.addListener(_recalcAllPricing);
    _frc.addListener(_recalcAllPricing);
    _developmentCharge.addListener(_recalcAllPricing);
    _plc.addListener(_recalcAllPricing);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      final repo = context.read<ProjectRepository>();
      final results = await Future.wait([
        repo.getTower(widget.projectId, widget.towerId),
        repo.getPricingComponents(includeInactive: true).catchError((_) => <ErpPricingComponent>[]),
        repo.listPaymentPlans(includeInactive: false).catchError((_) => <ErpPaymentPlan>[]),
      ]);
      final tower = results[0] as ErpProjectTower;
      final pricingComps = results[1] as List<ErpPricingComponent>;
      final paymentPlans = results[2] as List<ErpPaymentPlan>;

      ErpProjectUnit? unit;
      for (final u in tower.units) {
        if (u.id == widget.unitId) {
          unit = u;
          break;
        }
      }
      if (unit != null) {
        if (mounted) {
          setState(() {
            _tower = tower;
            _pricingComponents = pricingComps;
            _paymentPlans = paymentPlans;
            _otherUnits = tower.units.where((u) => u.id != widget.unitId).toList();
            _hydrate(unit!);
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
            _loadError = 'Unit not found in tower';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _superBuiltUp.removeListener(_recalcAllPricing);
    _baseRate.removeListener(_recalcAllPricing);
    _frc.removeListener(_recalcAllPricing);
    _developmentCharge.removeListener(_recalcAllPricing);
    _plc.removeListener(_recalcAllPricing);

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
    _frc.dispose();
    _developmentCharge.dispose();
    _baseRate.dispose();
    _totalUnitValue.dispose();
    _totalValue.dispose();
    _remarks.dispose();

    for (final t in _taxes) {
      t.dispose();
    }
    for (final m in _maintenance) {
      m.dispose();
    }
    for (final o in _otherCharges) {
      o.dispose();
    }
    super.dispose();
  }

  void _recalcAllPricing() {
    if (_updatingTotal) return;
    _updatingTotal = true;

    final area = double.tryParse(_superBuiltUp.text.trim()) ?? 0.0;
    final rate = double.tryParse(_baseRate.text.trim()) ?? 0.0;
    final frc = double.tryParse(_frc.text.trim()) ?? 0.0;
    final devCharge = double.tryParse(_developmentCharge.text.trim()) ?? 0.0;
    final plc = double.tryParse(_plc.text.trim()) ?? 0.0;

    // Check configured formula types
    final frcConfig = _pricingComponents.where((c) => c.code == 'FRC').firstOrNull;
    final frcIsAreaBsv = frcConfig?.formulaType == 'AREA_BSV';
    final frcIsFixed = frcConfig?.formulaType == 'FIXED';

    final plcConfig = _pricingComponents.where((c) => c.code == 'PLC').firstOrNull;
    final plcIsAreaBsv = plcConfig?.formulaType == 'AREA_BSV';
    final plcIsFixed = plcConfig?.formulaType == 'FIXED';

    // Total Unit Value = (Super built up x Base Rate) + FRC + Dev Charge + PLC
    final bsvTotal = area * rate;
    final devTotal = _devChargeIsPerSqft ? (area * devCharge) : devCharge;
    final frcTotal = frcIsAreaBsv
        ? (area * rate)
        : (frcIsFixed ? frc : (_frcIsPerSqft ? (area * frc) : frc));
    final plcTotal = plcIsAreaBsv
        ? (area * rate)
        : (plcIsFixed ? plc : (_plcIsPerSqft ? (area * plc) : plc));

    final unitVal = bsvTotal + frcTotal + devTotal + plcTotal;
    final unitValStr = unitVal == unitVal.roundToDouble()
        ? unitVal.toStringAsFixed(0)
        : unitVal.toStringAsFixed(2);
    _totalUnitValue.text = unitValStr;

    // Taxes: Calculated on basis of Total Unit Value
    double taxTotal = 0.0;
    for (final t in _taxes) {
      final pct = double.tryParse(t.percentCtrl.text.trim()) ?? 0.0;
      final amt = double.parse(((pct / 100.0) * unitVal).toStringAsFixed(2));
      t.amountCtrl.text = amt == amt.roundToDouble()
          ? amt.toStringAsFixed(0)
          : amt.toStringAsFixed(2);
      taxTotal += amt;
    }

    // Maintenance: Running (Amount x Sqft) and Deposit (Amount x Sqft)
    double maintTotal = 0.0;
    if (_enableMaintenance) {
      for (final m in _maintenance) {
        if (m.isPerSqft) {
          final rSqft = double.tryParse(m.ratePerSqftCtrl.text.trim()) ?? 0.0;
          final amt = double.parse((rSqft * area).toStringAsFixed(2));
          m.amountCtrl.text = amt == amt.roundToDouble()
              ? amt.toStringAsFixed(0)
              : amt.toStringAsFixed(2);
          maintTotal += amt;
        } else {
          maintTotal += double.tryParse(m.amountCtrl.text.trim()) ?? 0.0;
        }
      }
    }

    // Other Charges: Advocate fees (number of docs x fees)
    double otherTotal = 0.0;
    for (final o in _otherCharges) {
      if (o.isDocsMode) {
        final docs = int.tryParse(o.docCountCtrl.text.trim()) ?? 0;
        final fee = double.tryParse(o.feePerDocCtrl.text.trim()) ?? 0.0;
        final amt = docs * fee;
        o.amountCtrl.text = amt == amt.roundToDouble()
            ? amt.toStringAsFixed(0)
            : amt.toStringAsFixed(2);
        otherTotal += amt;
      } else {
        otherTotal += double.tryParse(o.amountCtrl.text.trim()) ?? 0.0;
      }
    }

    // Final Total value is sum of all
    final grandTotal = unitVal + taxTotal + maintTotal + otherTotal;
    final grandTotalStr = grandTotal == grandTotal.roundToDouble()
        ? grandTotal.toStringAsFixed(0)
        : grandTotal.toStringAsFixed(2);
    _totalValue.text = grandTotalStr;

    _updatingTotal = false;

    if (mounted) {
      setState(() {});
    }
  }

  String _formatCurrency(double value, {bool includeSymbol = true}) {
    try {
      final formatter = NumberFormat.currency(
        locale: 'en_IN',
        symbol: includeSymbol ? '₹ ' : '',
        decimalDigits: value == value.roundToDouble() ? 0 : 2,
      );
      return formatter.format(value);
    } catch (_) {
      final s = value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
      return includeSymbol ? '₹ $s' : s;
    }
  }

  String _formatNum(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  String _num(double? v) => v == null
      ? ''
      : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2));

  void _hydrate(ErpProjectUnit u) {
    if (_hydrated) return;
    _hydrated = true;
    _isDuplex = u.isDuplex;
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
    _frc.text = _num(u.frc);
    _developmentCharge.text = _num(u.developmentCharge);
    _baseRate.text = _num(u.baseRate);
    _totalUnitValue.text = _num(u.totalUnitValue ?? u.totalValue);
    _totalValue.text = _num(u.grandTotal ?? u.totalValue);
    _remarks.text = u.remarks ?? '';
    _unitTypeCode = u.unitTypeCode;
    _areaUnitCode = u.areaUnitCode ?? 'SQ_FT';
    _statusCode = u.statusCode ?? 'AVAILABLE';
    _facingCode = u.facingCode;
    _categoryCode = u.categoryCode;

    // Active maintenance check
    final activeMaintComps = _pricingComponents.where((c) => c.category == 'MAINTENANCE' && c.isActive).toList();
    if (_pricingComponents.isNotEmpty && activeMaintComps.isEmpty) {
      _enableMaintenance = false;
    } else {
      _enableMaintenance = true;
    }

    // Taxes
    _taxes.clear();
    if (u.taxes.isNotEmpty) {
      for (final t in u.taxes) {
        _taxes.add(_createTaxRow(t.name, t.ratePercent, t.amount));
      }
    } else {
      final activeTaxes = _pricingComponents.where((c) => c.category == 'TAX' && c.isActive).toList();
      if (activeTaxes.isNotEmpty) {
        for (final t in activeTaxes) {
          _taxes.add(_createTaxRow(t.name, t.defaultRate ?? 0.0));
        }
      } else {
        // By default have following taxes per unit:
        // GST: 5%, Stamp Duty: 4.9%, Registration: 1%
        _taxes.add(_createTaxRow('GST', 5.0));
        _taxes.add(_createTaxRow('Stamp Duty', 4.9));
        _taxes.add(_createTaxRow('Registration', 1.0));
      }
    }

    // Maintenance
    _maintenance.clear();
    if (u.maintenance.isNotEmpty) {
      for (final m in u.maintenance) {
        _maintenance.add(_createMaintenanceRow(
          m.name,
          m.ratePerSqft,
          m.amount,
          isPerSqft: m.calculationType != 'FIXED',
        ));
      }
    } else if (_enableMaintenance) {
      if (activeMaintComps.isNotEmpty) {
        for (final m in activeMaintComps) {
          _maintenance.add(_createMaintenanceRow(
            m.name,
            m.defaultRate,
            0.0,
            isPerSqft: m.formulaType != 'FIXED',
          ));
        }
      } else {
        // By default: Running maintenance (Amount x Sqft), Maintenance Deposit (Amount x Sqft)
        _maintenance.add(_createMaintenanceRow('Running Maintenance', 3.0, 0.0, isPerSqft: true));
        _maintenance.add(_createMaintenanceRow('Maintenance Deposit', 50.0, 0.0, isPerSqft: true));
      }
    }

    // Other Charges
    _otherCharges.clear();
    if (u.otherCharges.isNotEmpty) {
      for (final o in u.otherCharges) {
        _otherCharges.add(_createOtherChargeRow(
          o.name,
          o.docCount,
          o.feePerDoc,
          o.amount,
          isDocsMode: o.docCount != null && o.feePerDoc != null,
        ));
      }
    } else {
      final activeOther = _pricingComponents.where((c) => c.category == 'OTHER_CHARGE' && c.isActive).toList();
      if (activeOther.isNotEmpty) {
        for (final o in activeOther) {
          _otherCharges.add(_createOtherChargeRow(
            o.name,
            o.formulaType == 'DOCS_MULTIPLIER' ? 2 : null,
            o.formulaType == 'DOCS_MULTIPLIER' ? (o.defaultRate ?? 5000.0) : null,
            o.defaultRate ?? 0.0,
            isDocsMode: o.formulaType == 'DOCS_MULTIPLIER',
          ));
        }
      } else {
        // Advocate fees: number of docs x fees
        _otherCharges.add(_createOtherChargeRow(
          'Advocate Fees',
          2,
          5000.0,
          10000.0,
          isDocsMode: true,
        ));
      }
    }

    // Payment terms
    if (u.paymentTerms.isNotEmpty) {
      _paymentTerms = List.from(u.paymentTerms);
      if (_paymentPlans.isNotEmpty) {
        final termPlanId = _paymentTerms.firstWhere((t) => t.planId != null, orElse: () => _paymentTerms.first).planId;
        if (termPlanId != null && _paymentPlans.any((p) => p.id == termPlanId)) {
          _selectedPlanId = termPlanId;
        }
      }
    } else if (_paymentPlans.isNotEmpty) {
      final def = _paymentPlans.where((p) => p.isDefault).firstOrNull ?? _paymentPlans.first;
      _selectedPlanId = def.id;
      _paymentTerms = List.from(def.terms);
    }

    _recalcAllPricing();
  }

  _TaxRow _createTaxRow(String name, double percent, [double amount = 0.0]) {
    final row = _TaxRow(name: name, percent: percent, amount: amount);
    row.percentCtrl.addListener(_recalcAllPricing);
    return row;
  }

  _MaintenanceRow _createMaintenanceRow(
    String name,
    double? ratePerSqft,
    double amount, {
    bool isPerSqft = true,
  }) {
    final row = _MaintenanceRow(
      name: name,
      ratePerSqft: ratePerSqft,
      amount: amount,
      isPerSqft: isPerSqft,
    );
    row.ratePerSqftCtrl.addListener(_recalcAllPricing);
    row.amountCtrl.addListener(_recalcAllPricing);
    return row;
  }

  _OtherChargeRow _createOtherChargeRow(
    String name,
    int? docCount,
    double? feePerDoc,
    double amount, {
    bool isDocsMode = false,
  }) {
    final row = _OtherChargeRow(
      name: name,
      docCount: docCount,
      feePerDoc: feePerDoc,
      amount: amount,
      isDocsMode: isDocsMode,
    );
    row.docCountCtrl.addListener(_recalcAllPricing);
    row.feePerDocCtrl.addListener(_recalcAllPricing);
    row.amountCtrl.addListener(_recalcAllPricing);
    return row;
  }

  void _autofillFromUnit(ErpProjectUnit u) {
    setState(() {
      _isDuplex = u.isDuplex;
      _unitTypeCode = u.unitTypeCode;
      _areaUnitCode = u.areaUnitCode ?? 'SQ_FT';
      _statusCode = u.statusCode ?? 'AVAILABLE';
      _facingCode = u.facingCode;
      _categoryCode = u.categoryCode;
      _superBuiltUp.text = _num(u.superBuiltUp);
      _carpet.text = _num(u.carpetArea);
      _builtUp.text = _num(u.builtUpArea);
      _balcony.text = _num(u.balconyArea);
      _terrace.text = _num(u.terraceArea);
      _plot.text = _num(u.plotArea);
      _parking.text = u.parkingAllocation ?? '';
      _plc.text = _num(u.plc);
      _frc.text = _num(u.frc);
      _developmentCharge.text = _num(u.developmentCharge);
      _baseRate.text = _num(u.baseRate);
      _remarks.text = u.remarks ?? '';

      if (u.taxes.isNotEmpty) {
        for (final t in _taxes) {
          t.dispose();
        }
        _taxes.clear();
        for (final t in u.taxes) {
          _taxes.add(_createTaxRow(t.name, t.ratePercent, t.amount));
        }
      }

      if (u.maintenance.isNotEmpty) {
        for (final m in _maintenance) {
          m.dispose();
        }
        _maintenance.clear();
        for (final m in u.maintenance) {
          _maintenance.add(_createMaintenanceRow(
            m.name,
            m.ratePerSqft,
            m.amount,
            isPerSqft: m.calculationType != 'FIXED',
          ));
        }
      }

      if (u.otherCharges.isNotEmpty) {
        for (final o in _otherCharges) {
          o.dispose();
        }
        _otherCharges.clear();
        for (final o in u.otherCharges) {
          _otherCharges.add(_createOtherChargeRow(
            o.name,
            o.docCount,
            o.feePerDoc,
            o.amount,
            isDocsMode: o.docCount != null && o.feePerDoc != null,
          ));
        }
      }

      if (u.paymentTerms.isNotEmpty) {
        _paymentTerms = List.from(u.paymentTerms);
      }
    });

    _recalcAllPricing();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Autofilled configuration & pricing from Unit ${u.unitNo}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _fetchPaymentTermsFromConfig([String? planId]) async {
    setState(() => _loadingTerms = true);
    try {
      final repo = context.read<ProjectRepository>();
      final plans = await repo.listPaymentPlans(includeInactive: false);
      if (mounted) {
        setState(() {
          _paymentPlans = plans;
          if (planId != null && plans.any((p) => p.id == planId)) {
            _selectedPlanId = planId;
            final plan = plans.firstWhere((p) => p.id == planId);
            _paymentTerms = List.from(plan.terms);
          } else if (_selectedPlanId != null && plans.any((p) => p.id == _selectedPlanId)) {
            final plan = plans.firstWhere((p) => p.id == _selectedPlanId);
            _paymentTerms = List.from(plan.terms);
          } else if (plans.isNotEmpty) {
            final def = plans.where((p) => p.isDefault).firstOrNull ?? plans.first;
            _selectedPlanId = def.id;
            _paymentTerms = List.from(def.terms);
          }
          _loadingTerms = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${_paymentTerms.length} milestone terms from plan'),
            backgroundColor: const Color(0xFF10b981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTerms = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch terms: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyPaymentPlan(String planId) {
    final plan = _paymentPlans.where((p) => p.id == planId).firstOrNull;
    if (plan == null) return;
    setState(() {
      _selectedPlanId = planId;
      _paymentTerms = List.from(plan.terms);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied "${plan.name}" (${plan.terms.length} milestones)'),
        backgroundColor: const Color(0xFF10b981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addCustomMilestoneDialog() {
    final nameCtrl = TextEditingController();
    final pctCtrl = TextEditingController();
    final monthsCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Add Milestone to Unit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Milestone Name *', border: OutlineInputBorder(), isDense: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pctCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Percent (%) *', suffixText: '%', border: OutlineInputBorder(), isDense: true),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0 || n > 100) return 'Enter 0 to 100';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: monthsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Due Within (Months) *', suffixText: 'months', border: OutlineInputBorder(), isDense: true),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n < 0) return 'Enter valid months';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final name = nameCtrl.text.trim();
              final pct = double.parse(pctCtrl.text.trim());
              final mo = double.parse(monthsCtrl.text.trim());
              Navigator.pop(ctx);
              setState(() {
                _paymentTerms.add(ErpPaymentTerm(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  planId: _selectedPlanId,
                  name: name,
                  percentPayment: pct,
                  lastDayMonths: mo,
                  sequence: _paymentTerms.length,
                ));
              });
            },
            child: const Text('Add Milestone'),
          ),
        ],
      ),
    );
  }

  void _addTaxDialog() {
    final nameCtrl = TextEditingController();
    final pctCtrl = TextEditingController(text: '1.0');
    final activeTaxes = _pricingComponents.where((c) => c.category == 'TAX' && c.isActive).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Tax'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeTaxes.isNotEmpty) ...[
                const Text('Pick from configured taxes:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: activeTaxes.map((c) => ActionChip(
                    label: Text('${c.name} (${c.defaultRate ?? 0}%)', style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      setDlgState(() {
                        nameCtrl.text = c.name;
                        if (c.defaultRate != null) {
                          pctCtrl.text = '${c.defaultRate}';
                        }
                      });
                    },
                  )).toList(),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tax Name *',
                  hintText: 'e.g. Cess, TDS, Municipal Tax',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pctCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Rate Percent (%) *',
                  hintText: 'e.g. 1.0, 2.5',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final pct = double.tryParse(pctCtrl.text.trim()) ?? 0.0;
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                setState(() {
                  _taxes.add(_createTaxRow(name, pct));
                });
                _recalcAllPricing();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _addMaintenanceDialog() {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '2.0');
    final activeMaint = _pricingComponents.where((c) => c.category == 'MAINTENANCE' && c.isActive).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Maintenance Charge'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeMaint.isNotEmpty) ...[
                const Text('Pick from configured maintenance:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: activeMaint.map((c) => ActionChip(
                    label: Text('${c.name} (${c.defaultRate != null ? '₹${c.defaultRate}' : ''})', style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      setDlgState(() {
                        nameCtrl.text = c.name;
                        if (c.defaultRate != null) {
                          rateCtrl.text = '${c.defaultRate}';
                        }
                      });
                    },
                  )).toList(),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Charge Name *',
                  hintText: 'e.g. Sinking Fund, Club Maintenance',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Rate per Sq.Ft (₹) *',
                  hintText: 'e.g. 2.0 or 5.0',
                  suffixText: '₹/sq.ft',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final r = double.tryParse(rateCtrl.text.trim()) ?? 0.0;
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                setState(() {
                  _maintenance.add(_createMaintenanceRow(name, r, 0.0, isPerSqft: true));
                });
                _recalcAllPricing();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _addOtherChargeDialog() {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final activeOther = _pricingComponents.where((c) => c.category == 'OTHER_CHARGE' && c.isActive).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Other Charge'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeOther.isNotEmpty) ...[
                const Text('Pick from configured charges:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: activeOther.map((c) => ActionChip(
                    label: Text(c.name, style: const TextStyle(fontSize: 11)),
                    onPressed: () {
                      setDlgState(() {
                        nameCtrl.text = c.name;
                        if (c.defaultRate != null) {
                          amtCtrl.text = '${c.defaultRate}';
                        }
                      });
                    },
                  )).toList(),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Charge Name *',
                  hintText: 'e.g. Electricity Meter, Gas Line, Legal',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹) *',
                  hintText: 'e.g. 25000',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                setState(() {
                  _otherCharges.add(_createOtherChargeRow(name, null, null, amt, isDocsMode: false));
                });
                _recalcAllPricing();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildPriceInputWithSubtotal({
    required TextEditingController controller,
    required String label,
    required String subtotalName,
    required double subtotalValue,
    required String calculationNote,
    required bool isDark,
    bool isRequired = false,
    String? hint,
    String? helper,
    IconData? icon,
    Color accentColor = const Color(0xFF2563eb),
    Widget? modeSelector,
  }) {
    final text = controller.text.trim();
    final hasInput = text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isRequired ? '$label *' : label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            if (modeSelector != null) modeSelector,
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(
            hintText: hint,
            helperText: hasInput ? null : helper,
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: icon != null ? Icon(icon, size: 18, color: accentColor) : null,
          ),
          validator: isRequired ? _req : null,
        ),
        if (hasInput) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 15, color: accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      children: [
                        TextSpan(
                          text: '$subtotalName: ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: _formatCurrency(subtotalValue),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            fontSize: 13,
                          ),
                        ),
                        if (calculationNote.isNotEmpty)
                          TextSpan(
                            text: '  $calculationNote',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Map<String, dynamic> _buildPayload() {
    final unitVal = double.tryParse(_totalUnitValue.text.trim());
    final grandVal = double.tryParse(_totalValue.text.trim());
    return {
      'unitNo': _unitNo.text.trim(),
      'unitTypeCode': _unitTypeCode,
      'floorNo': int.tryParse(_floorNo.text.trim()),
      'isDuplex': _isDuplex,
      'absorbUpperFloor': _absorbUpperFloor,
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
      'frc': double.tryParse(_frc.text.trim()),
      'developmentCharge': double.tryParse(_developmentCharge.text.trim()),
      'baseRate': double.tryParse(_baseRate.text.trim()),
      'totalUnitValue': unitVal,
      'totalValue': grandVal ?? unitVal,
      'grandTotal': grandVal,
      'taxes': _taxes.map((t) => {
            'name': t.nameCtrl.text.trim(),
            'ratePercent': double.tryParse(t.percentCtrl.text.trim()) ?? 0.0,
            'amount': double.tryParse(t.amountCtrl.text.trim()) ?? 0.0,
          }).toList(),
      'maintenance': _enableMaintenance
          ? _maintenance.map((m) => {
                'name': m.nameCtrl.text.trim(),
                'ratePerSqft': m.isPerSqft ? double.tryParse(m.ratePerSqftCtrl.text.trim()) : null,
                'amount': double.tryParse(m.amountCtrl.text.trim()) ?? 0.0,
                'calculationType': m.isPerSqft ? 'PER_SQFT' : 'FIXED',
              }).toList()
          : [],
      'otherCharges': _otherCharges.map((o) => {
            'name': o.nameCtrl.text.trim(),
            'docCount': o.isDocsMode ? int.tryParse(o.docCountCtrl.text.trim()) : null,
            'feePerDoc': o.isDocsMode ? double.tryParse(o.feePerDocCtrl.text.trim()) : null,
            'amount': double.tryParse(o.amountCtrl.text.trim()) ?? 0.0,
          }).toList(),
      'paymentTerms': _paymentTerms.map((p) => {
            'id': p.id,
            if (p.planId != null || _selectedPlanId != null) 'planId': p.planId ?? _selectedPlanId,
            'name': p.name,
            'percentPayment': p.percentPayment,
            'lastDayMonths': p.lastDayMonths,
            'sequence': p.sequence,
            'amount': double.parse(
              ((p.percentPayment / 100.0) * (grandVal ?? unitVal ?? 0.0)).toStringAsFixed(2),
            ),
          }).toList(),
      'remarks': _remarks.text.trim(),
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = _buildPayload();
    try {
      await context.read<ProjectRepository>().updateUnit(
            projectId: widget.projectId,
            towerId: widget.towerId,
            unitId: widget.unitId,
            body: body,
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

  Future<void> _deleteThisUnit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Unit'),
        content: Text(
          'Are you sure you want to delete Unit ${_unitNo.text} from Floor ${_floorNo.text}? This will adjust the tower\'s total unit count.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await context.read<ProjectRepository>().deleteUnit(
            projectId: widget.projectId,
            towerId: widget.towerId,
            unitId: widget.unitId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unit ${_unitNo.text} deleted successfully')),
      );
      context.go('/erp/structure/${widget.projectId}/towers/${widget.towerId}/units');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _showBatchApplyDialog() {
    if (_tower == null) return;
    final currentFloor = int.tryParse(_floorNo.text.trim()) ?? 0;
    int scope = 0; // 0 = same floor, 1 = selected floors, 2 = whole tower
    final allFloors = <int>{for (final u in _tower!.units) u.floorNo}.toList()..sort();
    final selectedFloors = <int>{currentFloor};
    bool absorbDuplex = _isDuplex && _absorbUpperFloor;

    String floorLabel(int f) {
      if (f == 0) return 'Ground (0)';
      if (f < 0) return 'Basement ($f)';
      return 'Floor $f';
    }

    showDialog(
      context: context,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.copy_all_rounded, color: Color(0xFF2563eb)),
                  SizedBox(width: 10),
                  Text('Apply Configuration to Other Units', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Apply this unit\'s areas, rate, FRC, dev charges, PLC, taxes, maintenance, other charges, and specs to other units:',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      RadioListTile<int>(
                        value: 0,
                        groupValue: scope,
                        title: Text('All other units on Floor $currentFloor'),
                        subtitle: Text('Updates remaining units on ${floorLabel(currentFloor)} with SAME configuration'),
                        onChanged: (v) => setDlgState(() => scope = v!),
                      ),
                      RadioListTile<int>(
                        value: 1,
                        groupValue: scope,
                        title: const Text('Selected Floors'),
                        subtitle: const Text('Apply SAME configuration across specific floors'),
                        onChanged: (v) => setDlgState(() => scope = v!),
                      ),
                      if (scope == 1) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: allFloors.map((fl) {
                              final sel = selectedFloors.contains(fl);
                              return FilterChip(
                                label: Text(floorLabel(fl)),
                                selected: sel,
                                onSelected: (s) {
                                  setDlgState(() {
                                    if (s) {
                                      selectedFloors.add(fl);
                                    } else {
                                      selectedFloors.remove(fl);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      RadioListTile<int>(
                        value: 2,
                        groupValue: scope,
                        title: const Text('All units in this Tower'),
                        subtitle: const Text('Apply SAME configuration to all units in this tower'),
                        onChanged: (v) => setDlgState(() => scope = v!),
                      ),
                      if (_isDuplex) ...[
                        const Divider(),
                        CheckboxListTile(
                          value: absorbDuplex,
                          title: const Text('Link 2 floors as single duplex unit'),
                          subtitle: const Text(
                            'Keeps all floors intact. Upper floor units are named like 101-2, auto-occupied, and paired with the lower floor as a single duplex unit.',
                          ),
                          onChanged: (v) => setDlgState(() => absorbDuplex = v ?? true),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563eb),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Apply to Units'),
                  onPressed: () async {
                    Navigator.pop(dlgContext);
                    await _executeBatchApply(
                      scope: scope == 0 ? 'SAME_FLOOR' : (scope == 1 ? 'FLOOR_RANGE' : 'ALL_TOWER'),
                      floors: scope == 1 ? selectedFloors.toList() : null,
                      absorbUpperFloors: absorbDuplex,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executeBatchApply({
    required String scope,
    List<int>? floors,
    required bool absorbUpperFloors,
  }) async {
    setState(() => _applyingBatch = true);
    final unitData = _buildPayload();
    try {
      await context.read<ProjectRepository>().batchApplyUnits(
            projectId: widget.projectId,
            towerId: widget.towerId,
            body: {
              'scope': scope,
              'currentFloor': int.tryParse(_floorNo.text.trim()) ?? 0,
              if (floors != null) 'floors': floors,
              if (floors != null) 'targetFloorNos': floors,
              if (scope == 'ALL_TOWER') 'allUnits': true,
              'absorbUpperFloors': absorbUpperFloors,
              'unitData': unitData,
              'data': unitData,
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration and pricing successfully applied to selected units!'),
          backgroundColor: Color(0xFF10b981),
        ),
      );
      context.go('/erp/structure/${widget.projectId}/towers/${widget.towerId}/units');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Batch apply failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _applyingBatch = false);
    }
  }

  Widget _grid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final count = w < 600 ? 1 : (w < 900 ? 2 : 3);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += count) {
          final chunk = children.skip(i).take(count).toList();
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = 0; j < chunk.length; j++) ...[
                    if (j > 0) const SizedBox(width: 12),
                    Expanded(child: chunk[j]),
                  ],
                  for (var k = chunk.length; k < count; k++) ...[
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(
          _unitNo.text.isEmpty ? 'Configure Unit' : 'Unit ${_unitNo.text} Configuration',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: AppBackButton(
          fallbackLocation: '/erp/structure/${widget.projectId}/towers/${widget.towerId}/units',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Delete Unit',
            onPressed: _loading ? null : _deleteThisUnit,
          ),
          IconButton(
            icon: const Icon(Icons.copy_all_rounded, color: Color(0xFF2563eb)),
            tooltip: 'Apply to other units',
            onPressed: _loading ? null : _showBatchApplyDialog,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563eb),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? 'Saving…' : 'Save Unit'),
              onPressed: (_saving || _applyingBatch || _loading) ? null : _save,
            ),
          ),
        ],
      ),
      body: () {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_loadError != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $_loadError', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _loadData, child: const Text('Retry')),
              ],
            ),
          );
        }

        final unitValNum = double.tryParse(_totalUnitValue.text.trim()) ?? 0.0;
        final grandTotalNum = double.tryParse(_totalValue.text.trim()) ?? 0.0;

        final areaNum = double.tryParse(_superBuiltUp.text.trim()) ?? 0.0;
        final baseRateNum = double.tryParse(_baseRate.text.trim()) ?? 0.0;
        final frcNum = double.tryParse(_frc.text.trim()) ?? 0.0;
        final devNum = double.tryParse(_developmentCharge.text.trim()) ?? 0.0;
        final plcNum = double.tryParse(_plc.text.trim()) ?? 0.0;

        final bsvSubtotal = areaNum * baseRateNum;
        final devSubtotal = _devChargeIsPerSqft ? (areaNum * devNum) : devNum;
        final frcSubtotal = _frcIsPerSqft ? (areaNum * frcNum) : frcNum;
        final plcSubtotal = _plcIsPerSqft ? (areaNum * plcNum) : plcNum;

        double sumTaxes = 0.0;
        for (final t in _taxes) {
          sumTaxes += double.tryParse(t.amountCtrl.text.trim()) ?? 0.0;
        }

        double sumMaint = 0.0;
        for (final m in _maintenance) {
          sumMaint += double.tryParse(m.amountCtrl.text.trim()) ?? 0.0;
        }

        double sumOther = 0.0;
        for (final o in _otherCharges) {
          sumOther += double.tryParse(o.amountCtrl.text.trim()) ?? 0.0;
        }

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // Autofill Banner Card
              if (_otherUnits.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF2563eb), size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Autofill from configured unit:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isDense: true,
                            hint: const Text('Select unit to copy config & pricing (SAME)'),
                            items: _otherUnits.map((u) {
                              return DropdownMenuItem<String>(
                                value: u.id,
                                child: Text('Unit ${u.unitNo} (Floor ${u.floorNo}) — ${u.unitTypeCode ?? 'Configured'}'),
                              );
                            }).toList(),
                            onChanged: (id) {
                              if (id == null) return;
                              final match = _otherUnits.firstWhere((u) => u.id == id);
                              _autofillFromUnit(match);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // CARD 1: Unit Identification & Structure
              _card(
                'Unit Structure & Duplex Configuration',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: _isDuplex
                            ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFDBEAFE))
                            : (isDark ? const Color(0xFF2A2825) : const Color(0xFFF1F5F9)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _isDuplex ? const Color(0xFF2563eb) : Colors.transparent,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.layers_rounded,
                                    color: _isDuplex ? const Color(0xFF2563eb) : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Duplex Unit (2 Consecutive Floors)',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                _isDuplex
                                    ? 'Occupies Floor ${_floorNo.text} & Floor ${(int.tryParse(_floorNo.text) ?? 0) + 1}. Double-height hall — upper floor area belongs to this flat.'
                                    : 'Mark this if unit is a 2-floor duplex/penthouse occupying 2 consecutive floor levels.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : const Color(0xFF607D8B),
                                ),
                              ),
                              value: _isDuplex,
                              activeThumbColor: const Color(0xFF2563eb),
                              onChanged: (v) => setState(() => _isDuplex = v),
                            ),
                            if (_isDuplex)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                                child: CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'Auto-occupy upper floor as duplex continuation (Floor ${(int.tryParse(_floorNo.text) ?? 0) + 1})',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    'Upper flat is kept on Floor ${(int.tryParse(_floorNo.text) ?? 0) + 1}, named ${_unitNo.text.isEmpty ? "101-2" : "${_unitNo.text}-2"}, and marked auto-occupied.',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  value: _absorbUpperFloor,
                                  activeColor: const Color(0xFF2563eb),
                                  onChanged: (v) => setState(() => _absorbUpperFloor = v ?? true),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    _grid([
                      TextFormField(
                        controller: _unitNo,
                        decoration: _dec('Unit No'),
                        validator: _req,
                      ),
                      lookupDropdown(
                        context: context,
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
                          helper: _isDuplex
                              ? 'Base floor (occupies Floor ${_floorNo.text} + Floor ${(int.tryParse(_floorNo.text) ?? 0) + 1})'
                              : '0 = Ground, 1+ = upper floors, -1 = Basement',
                        ),
                        validator: _req,
                      ),
                      TextFormField(
                        controller: _superBuiltUp,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: _dec('Super Built-up Area'),
                        validator: _req,
                      ),
                      TextFormField(
                        controller: _carpet,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: _dec('Carpet Area (RERA)'),
                        validator: _req,
                      ),
                      lookupDropdown(
                        context: context,
                        category: 'PROJECT_AREA_UNIT',
                        label: 'Area Unit',
                        value: _areaUnitCode,
                        required: true,
                        onChanged: (v) => setState(() => _areaUnitCode = v),
                      ),
                      lookupDropdown(
                        context: context,
                        category: 'PROJECT_UNIT_STATUS',
                        label: 'Unit Status',
                        value: _statusCode,
                        required: true,
                        onChanged: (v) => setState(() => _statusCode = v),
                      ),
                    ]),
                  ],
                ),
              ),

              // CARD 2: Base Pricing & Total Unit Value Formula
              _card(
                'Pricing & Base Charges',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.functions_rounded, color: Color(0xFF2563eb), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Total Unit Value = ',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563eb)),
                                  ),
                                  TextSpan(
                                    text: () {
                                      final frcConfig = _pricingComponents.where((c) => c.code == 'FRC').firstOrNull;
                                      final frcIsAreaBsv = frcConfig?.formulaType == 'AREA_BSV';
                                      final frcTxt = frcIsAreaBsv ? 'Area × Base Rate' : (_frcIsPerSqft ? 'Area × FRC Rate' : 'Fixed FRC');

                                      final plcConfig = _pricingComponents.where((c) => c.code == 'PLC').firstOrNull;
                                      final plcIsAreaBsv = plcConfig?.formulaType == 'AREA_BSV';
                                      final plcTxt = plcIsAreaBsv ? 'Area × Base Rate' : (_plcIsPerSqft ? 'Area × PLC Rate' : 'Fixed PLC');

                                      return 'BSV (Area × Base Rate) + FRC ($frcTxt) + GEB/AMC (Area × Dev Rate) + PLC ($plcTxt)';
                                    }(),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              await context.push('/erp/configurations/pricing-formulas');
                              _loadData();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune_rounded, size: 14, color: Color(0xFF8B5CF6)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Config Formulas',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _grid([
                      _buildPriceInputWithSubtotal(
                        controller: _baseRate,
                        label: 'Base Rate (BSV) (₹/sq.ft)',
                        subtotalName: 'Total BSV',
                        subtotalValue: bsvSubtotal,
                        calculationNote: areaNum > 0
                            ? '(${_formatNum(areaNum)} sq.ft × ${_formatCurrency(baseRateNum)}/sq.ft)'
                            : '(Enter Super Built-up area above)',
                        isDark: isDark,
                        isRequired: true,
                        hint: 'e.g. 5000',
                        icon: Icons.currency_rupee_rounded,
                        accentColor: const Color(0xFF2563eb),
                      ),
                      _buildPriceInputWithSubtotal(
                        controller: _frc,
                        label: 'FRC (Floor Unit Charge)',
                        subtotalName: 'Total FRC',
                        subtotalValue: frcSubtotal,
                        calculationNote: () {
                          final frcConfig = _pricingComponents.where((c) => c.code == 'FRC').firstOrNull;
                          if (frcConfig?.formulaType == 'AREA_BSV' && areaNum > 0) {
                            return '(${_formatNum(areaNum)} sq.ft × ${_formatCurrency(baseRateNum)} BSV Rate)';
                          }
                          return _frcIsPerSqft && areaNum > 0
                              ? '(${_formatNum(areaNum)} sq.ft × ${_formatCurrency(frcNum)}/sq.ft)'
                              : (_frcIsPerSqft ? '(Enter Super Built-up area above)' : 'Fixed charge');
                        }(),
                        isDark: isDark,
                        isRequired: false,
                        hint: '0',
                        helper: 'Floor rise charge amount',
                        icon: Icons.stairs_rounded,
                        accentColor: const Color(0xFF7C3AED),
                        modeSelector: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() => _frcIsPerSqft = true);
                                _recalcAllPricing();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _frcIsPerSqft ? const Color(0xFF7C3AED) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '₹/sq.ft',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _frcIsPerSqft ? Colors.white : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                setState(() => _frcIsPerSqft = false);
                                _recalcAllPricing();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: !_frcIsPerSqft ? const Color(0xFF7C3AED) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Fixed ₹',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: !_frcIsPerSqft ? Colors.white : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildPriceInputWithSubtotal(
                        controller: _developmentCharge,
                        label: 'Dev Charge (GEB / AMC) (₹/sq.ft)',
                        subtotalName: 'Total GEB/AMC',
                        subtotalValue: devSubtotal,
                        calculationNote: areaNum > 0
                            ? '(${_formatNum(areaNum)} sq.ft × ${_formatCurrency(devNum)}/sq.ft)'
                            : '(Enter Super Built-up area above)',
                        isDark: isDark,
                        isRequired: false,
                        hint: '0',
                        helper: 'GEB / AMC infrastructure charge',
                        icon: Icons.electrical_services_rounded,
                        accentColor: const Color(0xFF0D9488),
                        modeSelector: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() => _devChargeIsPerSqft = true);
                                _recalcAllPricing();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _devChargeIsPerSqft ? const Color(0xFF0D9488) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '₹/sq.ft',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _devChargeIsPerSqft ? Colors.white : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                setState(() => _devChargeIsPerSqft = false);
                                _recalcAllPricing();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: !_devChargeIsPerSqft ? const Color(0xFF0D9488) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Fixed ₹',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: !_devChargeIsPerSqft ? Colors.white : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildPriceInputWithSubtotal(
                        controller: _plc,
                        label: 'PLC (Preferential Location Charge) (₹/sq.ft)',
                        subtotalName: 'Total PLC',
                        subtotalValue: plcSubtotal,
                        calculationNote: () {
                          final plcConfig = _pricingComponents.where((c) => c.code == 'PLC').firstOrNull;
                          if (plcConfig?.formulaType == 'AREA_BSV' && areaNum > 0) {
                            return '(${_formatNum(areaNum)} sq.ft × ${_formatCurrency(baseRateNum)} BSV Rate)';
                          }
                          return _plcIsPerSqft && areaNum > 0
                              ? '(${_formatNum(areaNum)} sq.ft × ${_formatCurrency(plcNum)}/sq.ft)'
                              : (_plcIsPerSqft ? '(Enter Super Built-up area above)' : 'Fixed location premium');
                        }(),
                        isDark: isDark,
                        isRequired: false,
                        hint: '0',
                        helper: 'Corner / Garden / Pool charge (₹/sq.ft)',
                        icon: Icons.landscape_rounded,
                        accentColor: const Color(0xFFEA580C),
                        modeSelector: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() => _plcIsPerSqft = true);
                                _recalcAllPricing();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _plcIsPerSqft ? const Color(0xFFEA580C) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '₹/sq.ft',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _plcIsPerSqft ? Colors.white : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                setState(() => _plcIsPerSqft = false);
                                _recalcAllPricing();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: !_plcIsPerSqft ? const Color(0xFFEA580C) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Fixed ₹',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: !_plcIsPerSqft ? Colors.white : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563eb).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2563eb), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Total Unit Value:',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                ],
                              ),
                              Text(
                                _formatCurrency(unitValNum),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: Color(0xFF2563eb),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Breakdown: BSV: ${_formatCurrency(bsvSubtotal)} • FRC: ${_formatCurrency(frcSubtotal)} • GEB/AMC: ${_formatCurrency(devSubtotal)} • PLC: ${_formatCurrency(plcSubtotal)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // CARD 3: Taxes Section (Calculated on Total Unit Value)
              _card(
                'Taxes (Calculated on Total Unit Value)',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Calculated automatically on basis of Total Unit Value:',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Tax'),
                          onPressed: _addTaxDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_taxes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No taxes configured.'),
                      )
                    else
                      ...List.generate(_taxes.length, (idx) {
                        final t = _taxes[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: t.nameCtrl,
                                  decoration: _dec('Tax Name', required: false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: t.percentCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  decoration: _dec('Rate %', required: false, hint: '5'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: t.amountCtrl,
                                  readOnly: true,
                                  decoration: _dec('Amount (₹)', required: false),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                tooltip: 'Remove Tax',
                                onPressed: () {
                                  setState(() {
                                    final removed = _taxes.removeAt(idx);
                                    removed.dispose();
                                  });
                                  _recalcAllPricing();
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal Taxes:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            '₹ ${sumTaxes.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // CARD 4: Maintenance Section
              _card(
                'Maintenance',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch.adaptive(
                              value: _enableMaintenance,
                              activeThumbColor: const Color(0xFFC5A059),
                              onChanged: (val) {
                                setState(() => _enableMaintenance = val);
                                _recalcAllPricing();
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _enableMaintenance
                                  ? 'Include Maintenance in Total'
                                  : 'Maintenance Excluded (Not charged)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _enableMaintenance
                                    ? (isDark ? Colors.white70 : const Color(0xFF1E293B))
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        if (_enableMaintenance)
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Maintenance'),
                            onPressed: _addMaintenanceDialog,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_enableMaintenance)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.remove_circle_outline_rounded, size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Maintenance charges are excluded for this unit. Toggle switch above to re-include.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_maintenance.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No maintenance configured.'),
                      )
                    else
                      ...List.generate(_maintenance.length, (idx) {
                        final m = _maintenance[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: m.nameCtrl,
                                  decoration: _dec('Maintenance Item', required: false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (m.isPerSqft) ...[
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: m.ratePerSqftCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                    decoration: _dec('Rate ₹/sq.ft', required: false, hint: 'e.g. 3'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: m.amountCtrl,
                                  readOnly: m.isPerSqft,
                                  decoration: _dec('Amount (₹)', required: false),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                tooltip: 'Remove Maintenance',
                                onPressed: () {
                                  setState(() {
                                    final removed = _maintenance.removeAt(idx);
                                    removed.dispose();
                                  });
                                  _recalcAllPricing();
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal Maintenance:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            _enableMaintenance
                                ? '₹ ${sumMaint.toStringAsFixed(2)}'
                                : '₹ 0.00 (Excluded)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _enableMaintenance ? null : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // CARD 5: Other Charges Section
              _card(
                'Other Charges',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Advocate fees (number of docs x fees) & other charges:',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Charge'),
                          onPressed: _addOtherChargeDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_otherCharges.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No other charges configured.'),
                      )
                    else
                      ...List.generate(_otherCharges.length, (idx) {
                        final o = _otherCharges[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: o.nameCtrl,
                                  decoration: _dec('Charge Name', required: false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (o.isDocsMode) ...[
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: o.docCountCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: _dec('No of Docs', required: false, hint: '2'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: o.feePerDocCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                    decoration: _dec('Fee/Doc (₹)', required: false, hint: '5000'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: o.amountCtrl,
                                  readOnly: o.isDocsMode,
                                  decoration: _dec('Amount (₹)', required: false),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                tooltip: 'Remove Charge',
                                onPressed: () {
                                  setState(() {
                                    final removed = _otherCharges.removeAt(idx);
                                    removed.dispose();
                                  });
                                  _recalcAllPricing();
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal Other Charges:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            '₹ ${sumOther.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // CARD 6: TOTAL VALUE SUMMARY (Sum of All)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E3A8A), const Color(0xFF0F172A)]
                        : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF2563eb).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: Color(0xFF2563eb), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Total Commercial Value (Sum of All)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _summaryRow('Total Unit Value:', _formatCurrency(unitValNum), isDark),
                    _summaryRow('+ Total Taxes:', _formatCurrency(sumTaxes), isDark),
                    _summaryRow('+ Total Maintenance:', _formatCurrency(sumMaint), isDark),
                    _summaryRow('+ Total Other Charges:', _formatCurrency(sumOther), isDark),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL VALUE (All-Inclusive):',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Text(
                          _formatCurrency(grandTotalNum),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Color(0xFF2563eb),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // CARD 7: Payment Terms (Plan selection & Milestone Breakdown)
              _card(
                'Payment Terms & Milestone Schedule',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Payment Plan for this unit booking:',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              if (_paymentPlans.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _paymentPlans.map((plan) {
                                    final isSelected = _selectedPlanId == plan.id;
                                    return ChoiceChip(
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(plan.name, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${plan.terms.length} terms',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      selected: isSelected,
                                      selectedColor: const Color(0xFF2563eb),
                                      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                                      onSelected: (selected) {
                                        if (selected) {
                                          _applyPaymentPlan(plan.id);
                                        }
                                      },
                                    );
                                  }).toList(),
                                )
                              else
                                const Text(
                                  'No preconfigured plans found. Click "Fetch config" to load.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Milestone'),
                              onPressed: _addCustomMilestoneDialog,
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF10b981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _loadingTerms
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.sync_rounded, size: 16),
                              label: const Text('Fetch config'),
                              onPressed: _loadingTerms ? null : () => _fetchPaymentTermsFromConfig(_selectedPlanId),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_paymentTerms.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 22),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'No payment milestone terms selected. Choose a plan above or click "Fetch config" to load milestone payment terms.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            if (_paymentPlans.isNotEmpty)
                              FilledButton(
                                onPressed: () => _applyPaymentPlan(_paymentPlans.first.id),
                                child: Text('Apply ${_paymentPlans.first.name}'),
                              ),
                          ],
                        ),
                      )
                    else ...[
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(4),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(3),
                          4: FlexColumnWidth(3),
                          5: FixedColumnWidth(40),
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2825) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            children: const [
                              Padding(padding: EdgeInsets.all(8), child: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Milestone Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('% Share', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Due Timeline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Milestone ₹', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              SizedBox(),
                            ],
                          ),
                          ...List.generate(_paymentTerms.length, (idx) {
                            final term = _paymentTerms[idx];
                            final termAmt = (term.percentPayment / 100.0) * grandTotalNum;
                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(8), child: Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                Padding(padding: const EdgeInsets.all(8), child: Text(term.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563eb).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${term.percentPayment}%',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2563eb)),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    term.lastDayMonths == 0 ? 'On Booking' : 'Within ${term.lastDayMonths} mo',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    '₹ ${termAmt.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF10b981)),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                  tooltip: 'Remove',
                                  onPressed: () {
                                    setState(() {
                                      _paymentTerms.removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Percentage: ${_paymentTerms.fold<double>(0, (s, e) => s + e.percentPayment).toStringAsFixed(1)}% / 100%',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: (_paymentTerms.fold<double>(0, (s, e) => s + e.percentPayment) - 100.0).abs() < 0.01
                                    ? const Color(0xFF10b981)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                            Text(
                              'Total Milestones: ₹ ${grandTotalNum.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF10b981)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // CARD 8: More Details
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
                              'Facing, Balcony, Terrace, Plot, Parking, Category, Remarks',
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
                          context: context,
                          category: 'PROJECT_UNIT_FACING',
                          label: 'Facing',
                          value: _facingCode,
                          required: true,
                          onChanged: (v) => setState(() => _facingCode = v),
                        ),
                        lookupDropdown(
                          context: context,
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
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarks,
                        maxLines: 2,
                        decoration: _dec('Remarks', required: false),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }(),
    );
  }

  Widget _summaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF475569))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
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
