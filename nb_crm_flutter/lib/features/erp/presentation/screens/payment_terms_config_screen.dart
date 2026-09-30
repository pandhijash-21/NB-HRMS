import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_back_button.dart';
import '../../data/project_repository.dart';
import '../../domain/structure_models.dart';

class PaymentTermsConfigScreen extends StatefulWidget {
  const PaymentTermsConfigScreen({super.key});

  @override
  State<PaymentTermsConfigScreen> createState() => _PaymentTermsConfigScreenState();
}

class _PaymentTermsConfigScreenState extends State<PaymentTermsConfigScreen> {
  List<ErpPaymentPlan> _plans = [];
  String? _selectedPlanId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  ErpPaymentPlan? get _currentPlan {
    if (_plans.isEmpty) return null;
    if (_selectedPlanId != null) {
      final found = _plans.where((p) => p.id == _selectedPlanId).firstOrNull;
      if (found != null) return found;
    }
    final def = _plans.where((p) => p.isDefault).firstOrNull;
    return def ?? _plans.first;
  }

  Future<void> _loadPlans([String? selectId]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<ProjectRepository>();
      final list = await repo.listPaymentPlans(includeInactive: true);
      if (mounted) {
        setState(() {
          _plans = list;
          if (selectId != null && list.any((p) => p.id == selectId)) {
            _selectedPlanId = selectId;
          } else if (_selectedPlanId == null || !list.any((p) => p.id == _selectedPlanId)) {
            final def = list.where((p) => p.isDefault).firstOrNull;
            _selectedPlanId = def?.id ?? (list.isNotEmpty ? list.first.id : null);
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // Dialog to Add a new Payment Plan
  void _showAddPlanDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isDefault = false;
    String preset = '20_80'; // Default preset
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.add_chart_rounded, color: Color(0xFF2563eb)),
                  SizedBox(width: 10),
                  Text('Create Payment Plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configure a distinct payment structure (e.g. 20:80 Plan, Construction Linked, Down Payment).',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Plan Name *',
                            hintText: 'e.g., 20:80 Booking Scheme, Regular 5-Stage Plan',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Plan Name is required' : null,
                          onChanged: (v) {
                            if (codeCtrl.text.isEmpty || codeCtrl.text == codeCtrl.text.toUpperCase()) {
                              final autoCode = v.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
                              codeCtrl.text = autoCode;
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Plan Code *',
                            hintText: 'e.g., PLAN_20_80, REGULAR_PLAN',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Code is required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: descCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            hintText: 'Brief summary of milestone criteria & buyer payment timeline',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Initial Milestones Template:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        RadioListTile<String>(
                          value: '20_80',
                          groupValue: preset,
                          dense: true,
                          title: const Text('20:80 Plan (2 terms: 20% on booking, 80% within 3 mo)'),
                          subtitle: const Text('Popular upfront booking scheme with balance in 3 months', style: TextStyle(fontSize: 11)),
                          onChanged: (v) => setDlgState(() => preset = v!),
                        ),
                        RadioListTile<String>(
                          value: 'regular_5',
                          groupValue: preset,
                          dense: true,
                          title: const Text('Standard 5-Stage Construction Linked'),
                          subtitle: const Text('10% booking, 20% plinth, 20% 1st slab, 25% structure, 25% possession', style: TextStyle(fontSize: 11)),
                          onChanged: (v) => setDlgState(() => preset = v!),
                        ),
                        RadioListTile<String>(
                          value: 'empty',
                          groupValue: preset,
                          dense: true,
                          title: const Text('Blank Plan (Add custom terms manually)'),
                          subtitle: const Text('Start with 0 terms and add your own specific milestones', style: TextStyle(fontSize: 11)),
                          onChanged: (v) => setDlgState(() => preset = v!),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: isDefault,
                          title: const Text('Set as default plan for new units', style: TextStyle(fontSize: 13)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setDlgState(() => isDefault = v ?? false),
                        ),
                      ],
                    ),
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
                  label: const Text('Create Plan'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final name = nameCtrl.text.trim();
                    final code = codeCtrl.text.trim().toUpperCase();
                    final desc = descCtrl.text.trim();
                    Navigator.pop(dlgContext);

                    List<Map<String, dynamic>> termsPayload = [];
                    if (preset == '20_80') {
                      termsPayload = [
                        {'name': 'On Booking', 'percentPayment': 20.0, 'lastDayMonths': 0.0, 'sequence': 0},
                        {'name': 'Within 3 Months', 'percentPayment': 80.0, 'lastDayMonths': 3.0, 'sequence': 1},
                      ];
                    } else if (preset == 'regular_5') {
                      termsPayload = [
                        {'name': 'On Booking / Agreement', 'percentPayment': 10.0, 'lastDayMonths': 0.0, 'sequence': 0},
                        {'name': 'On Completion of Plinth Level', 'percentPayment': 20.0, 'lastDayMonths': 2.0, 'sequence': 1},
                        {'name': 'On Casting of First Slab', 'percentPayment': 20.0, 'lastDayMonths': 4.0, 'sequence': 2},
                        {'name': 'On Completion of Structure', 'percentPayment': 25.0, 'lastDayMonths': 8.0, 'sequence': 3},
                        {'name': 'On Possession / Handover', 'percentPayment': 25.0, 'lastDayMonths': 12.0, 'sequence': 4},
                      ];
                    }

                    try {
                      final repo = context.read<ProjectRepository>();
                      final created = await repo.createPaymentPlan({
                        'name': name,
                        'code': code,
                        'description': desc.isNotEmpty ? desc : null,
                        'isDefault': isDefault,
                        if (termsPayload.isNotEmpty) 'terms': termsPayload,
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Payment Plan "$name" created successfully!'),
                            backgroundColor: const Color(0xFF10b981),
                          ),
                        );
                      }
                      _loadPlans(created.id);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to create plan: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog to Edit Plan details
  void _showEditPlanDialog(ErpPaymentPlan plan) {
    final nameCtrl = TextEditingController(text: plan.name);
    final codeCtrl = TextEditingController(text: plan.code);
    final descCtrl = TextEditingController(text: plan.description ?? '');
    bool isDefault = plan.isDefault;
    bool isActive = plan.isActive;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: Color(0xFF2563eb)),
                  SizedBox(width: 10),
                  Text('Edit Payment Plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Plan Name *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Plan Name is required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Plan Code *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Code is required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: descCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: isDefault,
                          title: const Text('Default plan for new units', style: TextStyle(fontSize: 13)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setDlgState(() => isDefault = v ?? false),
                        ),
                        CheckboxListTile(
                          value: isActive,
                          title: const Text('Active', style: TextStyle(fontSize: 13)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setDlgState(() => isActive = v ?? false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dlgContext), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563eb)),
                  child: const Text('Save Changes'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(dlgContext);
                    try {
                      final repo = context.read<ProjectRepository>();
                      await repo.updatePaymentPlan(plan.id, {
                        'name': nameCtrl.text.trim(),
                        'code': codeCtrl.text.trim().toUpperCase(),
                        'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                        'isDefault': isDefault,
                        'isActive': isActive,
                      });
                      _loadPlans(plan.id);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update plan: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Duplicate Plan
  Future<void> _duplicatePlan(ErpPaymentPlan plan) async {
    try {
      final repo = context.read<ProjectRepository>();
      final cloned = await repo.duplicatePaymentPlan(plan.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Duplicated "${plan.name}" as "${cloned.name}"'),
            backgroundColor: const Color(0xFF10b981),
          ),
        );
      }
      _loadPlans(cloned.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to duplicate plan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Delete Plan
  Future<void> _deletePlan(ErpPaymentPlan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${plan.name}"?'),
        content: Text(
          'Are you sure you want to delete this payment plan and its ${plan.terms.length} milestone terms? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Plan'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final repo = context.read<ProjectRepository>();
      await repo.deletePaymentPlan(plan.id);
      _selectedPlanId = null;
      _loadPlans();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Add / Edit Term inside the current plan
  void _showAddEditTermDialog(ErpPaymentPlan plan, [ErpPaymentTerm? term]) {
    final isEdit = term != null;
    final nameCtrl = TextEditingController(text: term?.name ?? '');
    final percentCtrl = TextEditingController(
      text: term != null
          ? (term.percentPayment == term.percentPayment.roundToDouble()
              ? term.percentPayment.toStringAsFixed(0)
              : term.percentPayment.toStringAsFixed(2))
          : '',
    );
    final monthsCtrl = TextEditingController(
      text: term != null
          ? (term.lastDayMonths == term.lastDayMonths.roundToDouble()
              ? term.lastDayMonths.toStringAsFixed(0)
              : term.lastDayMonths.toStringAsFixed(2))
          : '',
    );
    final formKey = GlobalKey<FormState>();

    // Suggest remaining % to reach 100%
    final currentOtherSum = plan.terms.where((t) => t.id != term?.id).fold<double>(0.0, (s, t) => s + t.percentPayment);
    final remainingFor100 = (100.0 - currentOtherSum).clamp(0.0, 100.0);

    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                color: const Color(0xFF2563eb),
              ),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Edit Milestone Term' : 'Add Milestone Term',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Milestone for "${plan.name}" (Allocated so far: ${currentOtherSum.toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    // Quick presets for name
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        'On Booking',
                        'Within 3 Months',
                        'On Plinth Level',
                        'On 1st Slab',
                        'On Possession',
                      ].map((presetName) {
                        return ActionChip(
                          label: Text(presetName, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            nameCtrl.text = presetName;
                            if (presetName == 'On Booking') {
                              monthsCtrl.text = '0';
                            } else if (presetName == 'Within 3 Months') {
                              monthsCtrl.text = '3';
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Milestone Name *',
                        hintText: 'e.g., On Booking, Within 3 Months',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Milestone Name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: percentCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Percent Payment (%) *',
                        hintText: 'e.g., 20, 80',
                        helperText: remainingFor100 > 0 ? 'Remaining to 100%: ${remainingFor100.toStringAsFixed(1)}%' : null,
                        suffixText: '%',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) {
                        final n = double.tryParse(v?.trim() ?? '');
                        if (n == null || n <= 0 || n > 100) {
                          return 'Enter valid percentage between 0 and 100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: monthsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Payment Due Timeline (Months) *',
                        hintText: 'e.g., 0 for booking, 3 for 3 months',
                        helperText: 'Number of months from booking/agreement date (0 = immediate)',
                        suffixText: 'months',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) {
                        final n = double.tryParse(v?.trim() ?? '');
                        if (n == null || n < 0) {
                          return 'Enter valid duration (e.g. 0, 1, 3, 6)';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
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
              label: Text(isEdit ? 'Save Changes' : 'Add Milestone'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final name = nameCtrl.text.trim();
                final percent = double.parse(percentCtrl.text.trim());
                final months = double.parse(monthsCtrl.text.trim());
                Navigator.pop(dlgContext);

                try {
                  final repo = context.read<ProjectRepository>();
                  if (isEdit) {
                    await repo.updatePaymentTerm(term.id, {
                      'planId': plan.id,
                      'name': name,
                      'percentPayment': percent,
                      'lastDayMonths': months,
                    });
                  } else {
                    await repo.createPaymentTerm({
                      'planId': plan.id,
                      'name': name,
                      'percentPayment': percent,
                      'lastDayMonths': months,
                      'sequence': plan.terms.length,
                    });
                  }
                  _loadPlans(plan.id);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Delete term
  Future<void> _deleteTerm(ErpPaymentPlan plan, ErpPaymentTerm term) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Milestone Term?'),
        content: Text('Are you sure you want to remove "${term.name}" (${term.percentPayment}%) from "${plan.name}"?'),
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
      final repo = context.read<ProjectRepository>();
      await repo.deletePaymentTerm(term.id);
      _loadPlans(plan.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = _currentPlan;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        leading: const AppBackButton(fallbackLocation: '/erp/configurations'),
        title: const Text(
          'Payment Plans Configuration',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC5A059)),
            tooltip: 'Refresh',
            onPressed: () => _loadPlans(_selectedPlanId),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: () => _loadPlans(_selectedPlanId), child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    // Plan Selector Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Plans',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${_plans.length} plan${_plans.length == 1 ? '' : 's'} configured for unit bookings',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563eb),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('+ New Plan'),
                          onPressed: _showAddPlanDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Plans Cards Carousel / Horizontal Selector
                    SizedBox(
                      height: 128,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _plans.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (ctx, idx) {
                          final p = _plans[idx];
                          final isSelected = p.id == current?.id;
                          final isBalanced = p.isValid100;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedPlanId = p.id;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 250,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                                    : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2563eb)
                                      : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF2563eb).withValues(alpha: 0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isSelected ? const Color(0xFF2563eb) : null,
                                          ),
                                        ),
                                      ),
                                      if (p.isDefault)
                                        Container(
                                          margin: const EdgeInsets.only(left: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                                              SizedBox(width: 2),
                                              Text(
                                                'DEFAULT',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFF59E0B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    '${p.terms.length} milestone term${p.terms.length == 1 ? '' : 's'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isBalanced
                                              ? const Color(0xFF10b981).withValues(alpha: 0.12)
                                              : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${p.totalPercent}% ${isBalanced ? '✓ Balanced' : '⚠'}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isBalanced ? const Color(0xFF10b981) : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                                          padding: EdgeInsets.zero,
                                        onSelected: (action) {
                                          if (action == 'edit') {
                                            _showEditPlanDialog(p);
                                          } else if (action == 'duplicate') {
                                            _duplicatePlan(p);
                                          } else if (action == 'setDefault') {
                                            context.read<ProjectRepository>().updatePaymentPlan(p.id, {'isDefault': true}).then((_) => _loadPlans(p.id));
                                          } else if (action == 'delete') {
                                            _deletePlan(p);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit Plan')]),
                                          ),
                                          const PopupMenuItem(
                                            value: 'duplicate',
                                            child: Row(children: [Icon(Icons.copy_rounded, size: 16), SizedBox(width: 8), Text('Duplicate Plan')]),
                                          ),
                                          if (!p.isDefault)
                                            const PopupMenuItem(
                                              value: 'setDefault',
                                              child: Row(children: [Icon(Icons.star_outline_rounded, size: 16), SizedBox(width: 8), Text('Set as Default')]),
                                            ),
                                          if (_plans.length > 1)
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete Plan', style: TextStyle(color: Colors.red))]),
                                            ),
                                        ],
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
                    ),
                    const SizedBox(height: 24),

                    // Active Plan Banner & Milestone Management
                    if (current != null) ...[
                      // Plan Detail Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            current.name,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563eb).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              current.code,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF2563eb),
                                              ),
                                            ),
                                          ),
                                          if (current.isDefault) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Default for Bookings',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFF59E0B),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (current.description != null && current.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          current.description!,
                                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      label: const Text('Edit Details'),
                                      onPressed: () => _showEditPlanDialog(current),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563eb),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.add_rounded, size: 18),
                                      label: const Text('Add Milestone'),
                                      onPressed: () => _showAddEditTermDialog(current),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Total Allocation Progress Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Milestone Allocation: ${current.totalPercent}% of 100%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: current.isValid100
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                                Text(
                                  current.isValid100
                                      ? '✓ 100% Balanced'
                                      : '${(100.0 - current.totalPercent).abs().toStringAsFixed(1)}% ${current.totalPercent < 100 ? 'Remaining' : 'Excess'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: current.isValid100
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (current.totalPercent / 100.0).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  current.isValid100
                                      ? const Color(0xFF10B981)
                                      : (current.totalPercent > 100 ? Colors.red : const Color(0xFFF59E0B)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Milestones List Table
                      if (current.terms.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.timeline_rounded, size: 54, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  'No milestones configured for "${current.name}".',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Add payment terms such as "20% on booking", "80% within 3 months".',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Add Milestone Term'),
                                  onPressed: () => _showAddEditTermDialog(current),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          'Milestone Terms (${current.terms.length})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(current.terms.length, (idx) {
                          final term = current.terms[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF2563eb).withValues(alpha: 0.12),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(
                                        color: Color(0xFF2563eb),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          term.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2563eb).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${term.percentPayment}% Payment',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF2563eb),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                term.lastDayMonths == 0
                                                    ? 'On Booking / Immediate'
                                                    : 'Within ${term.lastDayMonths} month${term.lastDayMonths == 1 ? '' : 's'}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF2563eb)),
                                    tooltip: 'Edit Milestone',
                                    onPressed: () => _showAddEditTermDialog(current, term),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                    tooltip: 'Delete Milestone',
                                    onPressed: () => _deleteTerm(current, term),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ],
                ),
    );
  }
}
