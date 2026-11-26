import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/realtime/app_event_bus.dart';
import '../../../../core/widgets/dropdown_with_add.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/boq_repository.dart';
import '../../data/work_order_repository.dart';
import '../../domain/resource_models.dart';
import '../../domain/store_models.dart';
import '../../domain/work_order_lookup_keys.dart';
import '../../domain/work_order_models.dart';

InputDecoration _dec(String label, {bool required = false}) {
  return InputDecoration(
    labelText: required ? '$label *' : label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    isDense: true,
  );
}

// ── Activity ────────────────────────────────────────────────────────────────

Future<ErpActivity?> showQuickCreateActivityDialog(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final subtasks = <Map<String, TextEditingController>>[];
  var saving = false;
  String? error;

  void addSubtask() {
    subtasks.add({
      'name': TextEditingController(),
      'desc': TextEditingController(),
    });
  }

  // Start with 1 empty sub-activity field
  addSubtask();

  final result = await showDialog<ErpActivity>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            title: const Text('Add activity'),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Creates an activity with nested sub-activities under Configurations → Activities.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: _dec('Activity name', required: true),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: descCtrl,
                        decoration: _dec('Description (optional)'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sub-activities / Tasks',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setLocal(() => addSubtask());
                            },
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            label: const Text('Add Sub-activity', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (int i = 0; i < subtasks.length; i++) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: subtasks[i]['name'],
                                  decoration: InputDecoration(
                                    labelText: 'Sub-activity ${i + 1}',
                                    hintText: 'e.g. Excavation',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: subtasks[i]['desc'],
                                  decoration: const InputDecoration(
                                    labelText: 'Notes',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              if (subtasks.length > 1) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                  tooltip: 'Remove',
                                  onPressed: () {
                                    setLocal(() {
                                      subtasks[i]['name']?.dispose();
                                      subtasks[i]['desc']?.dispose();
                                      subtasks.removeAt(i);
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        setLocal(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final subtaskPayload = <Map<String, dynamic>>[];
                          for (final st in subtasks) {
                            final n = st['name']?.text.trim() ?? '';
                            if (n.isNotEmpty) {
                              subtaskPayload.add({
                                'name': n,
                                'description': st['desc']?.text.trim().isNotEmpty == true
                                    ? st['desc']?.text.trim()
                                    : null,
                              });
                            }
                          }

                          final created =
                              await ctx.read<WorkOrderRepository>().createActivity({
                            'name': nameCtrl.text.trim(),
                            if (descCtrl.text.trim().isNotEmpty)
                              'description': descCtrl.text.trim(),
                            'subtasks': subtaskPayload,
                          });
                          AppEventBus.instance.fireErpMutated(
                            module: 'activities',
                            entityId: created.id,
                            action: 'created',
                          );
                          if (ctx.mounted) Navigator.pop(ctx, created);
                        } catch (e) {
                          setLocal(() {
                            saving = false;
                            error = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
  nameCtrl.dispose();
  descCtrl.dispose();
  for (final st in subtasks) {
    st['name']?.dispose();
    st['desc']?.dispose();
  }
  return result;
}

class ActivityDropdownWithCreate extends StatelessWidget {
  const ActivityDropdownWithCreate({
    super.key,
    required this.value,
    required this.activities,
    required this.onChanged,
    required this.onActivityCreated,
    this.decoration,
    this.required = false,
    this.includeNullOption = false,
    this.nullLabel = 'Select activity',
    this.hint,
    this.enabled = true,
  });

  final String? value;
  final List<ErpActivity> activities;
  final ValueChanged<String?> onChanged;
  final ValueChanged<ErpActivity> onActivityCreated;
  final InputDecoration? decoration;
  final bool required;
  final bool includeNullOption;
  final String nullLabel;
  final Widget? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = activities.where((a) => a.isActive).toList();
    final items = <DropdownMenuItem<String?>>[
      if (includeNullOption)
        DropdownMenuItem<String?>(value: null, child: Text(nullLabel)),
      for (final a in active)
        DropdownMenuItem<String?>(
          value: a.id,
          child: Text(a.name, overflow: TextOverflow.ellipsis),
        ),
    ];
    if (value != null && !active.any((a) => a.id == value)) {
      final match = activities.where((a) => a.id == value).firstOrNull;
      if (match != null) {
        items.insert(
          includeNullOption ? 1 : 0,
          DropdownMenuItem<String?>(value: match.id, child: Text(match.name)),
        );
      }
    }

    return dropdownWithAddButton(
      tooltip: 'Add new activity',
      enabled: enabled,
      onAdd: () async {
        final created = await showQuickCreateActivityDialog(context);
        if (created == null) return;
        onActivityCreated(created);
        onChanged(created.id);
      },
      child: DropdownButtonFormField<String?>(
        key: ValueKey('activity-dd-$value-${activities.length}'),
        isExpanded: true,
        initialValue: value,
        hint: hint,
        decoration: decoration ??
            InputDecoration(
              labelText: required ? 'Activity *' : 'Activity',
              border: const OutlineInputBorder(),
            ),
        items: items,
        onChanged: enabled ? onChanged : null,
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Activity is required' : null
            : null,
      ),
    );
  }
}

// ── Material ────────────────────────────────────────────────────────────────

Future<ErpMaterial?> showQuickCreateMaterialDialog(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final itemCodeCtrl = TextEditingController();
  final brandCtrl = TextEditingController();
  final sizeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '0');
  String? categoryCode;
  String? unitCode;
  var saving = false;
  String? error;

  final result = await showDialog<ErpMaterial>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Add material'),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Creates a material under Configurations → Materials with category and unit tracking.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: _dec('Material name', required: true),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: itemCodeCtrl,
                        decoration: _dec('Item code (optional, e.g. MAT-001)'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 10),
                      lookupDropdown(
                        context: ctx,
                        category: 'INVENTORY_CATEGORY',
                        label: 'Category',
                        value: categoryCode,
                        onChanged: (v) => setLocal(() => categoryCode = v),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: brandCtrl,
                        decoration: _dec('Brand (e.g. UltraTech, Tata Steel)'),
                      ),
                      const SizedBox(height: 10),
                      lookupDropdown(
                        context: ctx,
                        category: kWoMeasurementUnit,
                        label: 'Unit of Measure (UoM)',
                        value: unitCode,
                        onChanged: (v) => setLocal(() => unitCode = v),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: sizeCtrl,
                        decoration: _dec('Size / Dimensions (e.g. 10mm, 50kg)'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: qtyCtrl,
                        decoration: _dec('Initial Qty on hand'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: descCtrl,
                        decoration: _dec('Specifications / Description (optional)'),
                        maxLines: 2,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        setLocal(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final created = await ctx.read<BoqRepository>().createMaterial({
                            'name': nameCtrl.text.trim(),
                            if (itemCodeCtrl.text.trim().isNotEmpty)
                              'itemCode': itemCodeCtrl.text.trim().toUpperCase(),
                            if (categoryCode != null && categoryCode!.isNotEmpty)
                              'categoryCode': categoryCode,
                            'brand': brandCtrl.text.trim().isEmpty
                                ? null
                                : brandCtrl.text.trim(),
                            'unitCode': unitCode,
                            'size': sizeCtrl.text.trim().isEmpty
                                ? null
                                : sizeCtrl.text.trim(),
                            if (descCtrl.text.trim().isNotEmpty)
                              'description': descCtrl.text.trim(),
                            'qtyOnHand': double.tryParse(qtyCtrl.text) ?? 0,
                          });
                          AppEventBus.instance.fireErpMutated(
                            module: 'materials',
                            entityId: created.id,
                            action: 'created',
                          );
                          if (ctx.mounted) Navigator.pop(ctx, created);
                        } catch (e) {
                          setLocal(() {
                            saving = false;
                            error = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
  nameCtrl.dispose();
  itemCodeCtrl.dispose();
  brandCtrl.dispose();
  sizeCtrl.dispose();
  descCtrl.dispose();
  qtyCtrl.dispose();
  return result;
}

class MaterialDropdownWithCreate extends StatelessWidget {
  const MaterialDropdownWithCreate({
    super.key,
    required this.value,
    required this.materials,
    required this.onChanged,
    required this.onMaterialCreated,
    this.decoration,
    this.required = false,
    this.includeNullOption = false,
    this.nullLabel = 'Select material',
    this.itemLabel,
    this.enabled = true,
  });

  final String? value;
  final List<ErpMaterial> materials;
  final ValueChanged<String?> onChanged;
  final ValueChanged<ErpMaterial> onMaterialCreated;
  final InputDecoration? decoration;
  final bool required;
  final bool includeNullOption;
  final String nullLabel;
  final String Function(ErpMaterial)? itemLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    String labelOf(ErpMaterial m) =>
        itemLabel?.call(m) ??
        [
          if (m.itemCode != null && m.itemCode!.isNotEmpty) m.itemCode!,
          if (m.brand != null && m.brand!.isNotEmpty) m.brand!,
          m.name,
        ].join(' — ');

    final active = materials.where((m) => m.isActive).toList();
    final items = <DropdownMenuItem<String?>>[
      if (includeNullOption)
        DropdownMenuItem<String?>(value: null, child: Text(nullLabel)),
      for (final m in active)
        DropdownMenuItem<String?>(
          value: m.id,
          child: Text(labelOf(m), overflow: TextOverflow.ellipsis),
        ),
    ];
    if (value != null && !active.any((m) => m.id == value)) {
      final match = materials.where((m) => m.id == value).firstOrNull;
      if (match != null) {
        items.insert(
          includeNullOption ? 1 : 0,
          DropdownMenuItem<String?>(value: match.id, child: Text(labelOf(match))),
        );
      }
    }

    return dropdownWithAddButton(
      tooltip: 'Add new material',
      enabled: enabled,
      onAdd: () async {
        final created = await showQuickCreateMaterialDialog(context);
        if (created == null) return;
        onMaterialCreated(created);
        onChanged(created.id);
      },
      child: DropdownButtonFormField<String?>(
        key: ValueKey('material-dd-$value-${materials.length}'),
        isExpanded: true,
        initialValue: value,
        decoration: decoration ??
            InputDecoration(
              labelText: required ? 'Material *' : 'Material',
              border: const OutlineInputBorder(),
            ),
        items: items,
        onChanged: enabled ? onChanged : null,
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Material is required' : null
            : null,
      ),
    );
  }
}

// ── Machine ─────────────────────────────────────────────────────────────────

Future<ErpMachine?> showQuickCreateMachineDialog(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final brandCtrl = TextEditingController();
  final sizeCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '0');
  String? unitCode;
  var saving = false;
  String? error;

  final result = await showDialog<ErpMachine>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Add machine'),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Creates a machine under Configurations → Machines.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: _dec('Name', required: true),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: brandCtrl,
                        decoration: _dec('Brand'),
                      ),
                      const SizedBox(height: 10),
                      lookupDropdown(
                        context: ctx,
                        category: kWoMeasurementUnit,
                        label: 'Unit',
                        value: unitCode,
                        onChanged: (v) => setLocal(() => unitCode = v),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: sizeCtrl,
                        decoration: _dec('Size'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: qtyCtrl,
                        decoration: _dec('Qty on hand'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        setLocal(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final created = await ctx.read<BoqRepository>().createMachine({
                            'name': nameCtrl.text.trim(),
                            'brand': brandCtrl.text.trim().isEmpty
                                ? null
                                : brandCtrl.text.trim(),
                            'unitCode': unitCode,
                            'size': sizeCtrl.text.trim().isEmpty
                                ? null
                                : sizeCtrl.text.trim(),
                            'qtyOnHand': double.tryParse(qtyCtrl.text) ?? 0,
                          });
                          AppEventBus.instance.fireErpMutated(
                            module: 'machines',
                            entityId: created.id,
                            action: 'created',
                          );
                          if (ctx.mounted) Navigator.pop(ctx, created);
                        } catch (e) {
                          setLocal(() {
                            saving = false;
                            error = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
  nameCtrl.dispose();
  brandCtrl.dispose();
  sizeCtrl.dispose();
  qtyCtrl.dispose();
  return result;
}

class MachineDropdownWithCreate extends StatelessWidget {
  const MachineDropdownWithCreate({
    super.key,
    required this.value,
    required this.machines,
    required this.onChanged,
    required this.onMachineCreated,
    this.decoration,
    this.required = false,
    this.includeNullOption = false,
    this.nullLabel = 'Select machine',
    this.itemLabel,
    this.enabled = true,
  });

  final String? value;
  final List<ErpMachine> machines;
  final ValueChanged<String?> onChanged;
  final ValueChanged<ErpMachine> onMachineCreated;
  final InputDecoration? decoration;
  final bool required;
  final bool includeNullOption;
  final String nullLabel;
  final String Function(ErpMachine)? itemLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    String labelOf(ErpMachine m) =>
        itemLabel?.call(m) ??
        '${m.brand != null && m.brand!.isNotEmpty ? '${m.brand} - ' : ''}${m.name}';

    final active = machines.where((m) => m.isActive).toList();
    final items = <DropdownMenuItem<String?>>[
      if (includeNullOption)
        DropdownMenuItem<String?>(value: null, child: Text(nullLabel)),
      for (final m in active)
        DropdownMenuItem<String?>(
          value: m.id,
          child: Text(labelOf(m), overflow: TextOverflow.ellipsis),
        ),
    ];
    if (value != null && !active.any((m) => m.id == value)) {
      final match = machines.where((m) => m.id == value).firstOrNull;
      if (match != null) {
        items.insert(
          includeNullOption ? 1 : 0,
          DropdownMenuItem<String?>(value: match.id, child: Text(labelOf(match))),
        );
      }
    }

    return dropdownWithAddButton(
      tooltip: 'Add new machine',
      enabled: enabled,
      onAdd: () async {
        final created = await showQuickCreateMachineDialog(context);
        if (created == null) return;
        onMachineCreated(created);
        onChanged(created.id);
      },
      child: DropdownButtonFormField<String?>(
        key: ValueKey('machine-dd-$value-${machines.length}'),
        isExpanded: true,
        initialValue: value,
        decoration: decoration ??
            InputDecoration(
              labelText: required ? 'Machine *' : 'Machine',
              border: const OutlineInputBorder(),
            ),
        items: items,
        onChanged: enabled ? onChanged : null,
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Machine is required' : null
            : null,
      ),
    );
  }
}

// ── Labour ──────────────────────────────────────────────────────────────────

Future<ErpLabour?> showQuickCreateLabourDialog(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  String? unitCode;
  var saving = false;
  String? error;

  final result = await showDialog<ErpLabour>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Add labour type'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Creates a labour type under Configurations → Labour.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: _dec('Name', required: true),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    lookupDropdown(
                      context: ctx,
                      category: kWoMeasurementUnit,
                      label: 'Unit',
                      value: unitCode,
                      onChanged: (v) => setLocal(() => unitCode = v),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: rateCtrl,
                      decoration: _dec('Default rate'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        setLocal(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final created = await ctx.read<BoqRepository>().createLabour({
                            'name': nameCtrl.text.trim(),
                            'unitCode': unitCode,
                            'defaultRate': double.tryParse(rateCtrl.text),
                          });
                          AppEventBus.instance.fireErpMutated(
                            module: 'labour',
                            entityId: created.id,
                            action: 'created',
                          );
                          if (ctx.mounted) Navigator.pop(ctx, created);
                        } catch (e) {
                          setLocal(() {
                            saving = false;
                            error = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
  nameCtrl.dispose();
  rateCtrl.dispose();
  return result;
}

class LabourDropdownWithCreate extends StatelessWidget {
  const LabourDropdownWithCreate({
    super.key,
    required this.value,
    required this.labour,
    required this.onChanged,
    required this.onLabourCreated,
    this.decoration,
    this.required = false,
    this.enabled = true,
  });

  final String? value;
  final List<ErpLabour> labour;
  final ValueChanged<String?> onChanged;
  final ValueChanged<ErpLabour> onLabourCreated;
  final InputDecoration? decoration;
  final bool required;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = labour.where((l) => l.isActive).toList();
    final items = <DropdownMenuItem<String?>>[
      for (final l in active)
        DropdownMenuItem<String?>(
          value: l.id,
          child: Text(l.name, overflow: TextOverflow.ellipsis),
        ),
    ];
    if (value != null && !active.any((l) => l.id == value)) {
      final match = labour.where((l) => l.id == value).firstOrNull;
      if (match != null) {
        items.insert(0, DropdownMenuItem<String?>(value: match.id, child: Text(match.name)));
      }
    }

    return dropdownWithAddButton(
      tooltip: 'Add new labour type',
      enabled: enabled,
      onAdd: () async {
        final created = await showQuickCreateLabourDialog(context);
        if (created == null) return;
        onLabourCreated(created);
        onChanged(created.id);
      },
      child: DropdownButtonFormField<String?>(
        key: ValueKey('labour-dd-$value-${labour.length}'),
        isExpanded: true,
        initialValue: value,
        decoration: decoration ??
            InputDecoration(
              labelText: required ? 'Labour Type *' : 'Labour Type',
              border: const OutlineInputBorder(),
            ),
        items: items,
        onChanged: enabled ? onChanged : null,
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Labour type is required' : null
            : null,
      ),
    );
  }
}

// ── Store ───────────────────────────────────────────────────────────────────

Future<ErpStoreMaster?> showQuickCreateStoreDialog(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  var saving = false;
  String? error;

  final result = await showDialog<ErpStoreMaster>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Add store'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Creates a store under Configurations → Stores.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: _dec('Store name', required: true),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: locationCtrl,
                      decoration: _dec('Location', required: true),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        setLocal(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final created = await ctx.read<BoqRepository>().createStore(
                            {
                              'name': nameCtrl.text.trim(),
                              'location': locationCtrl.text.trim(),
                            },
                            fromConfig: true,
                          );
                          AppEventBus.instance.fireErpMutated(
                            module: 'stores',
                            entityId: created.id,
                            action: 'created',
                          );
                          if (ctx.mounted) Navigator.pop(ctx, created);
                        } catch (e) {
                          setLocal(() {
                            saving = false;
                            error = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
  nameCtrl.dispose();
  locationCtrl.dispose();
  return result;
}

class StoreDropdownWithCreate extends StatelessWidget {
  const StoreDropdownWithCreate({
    super.key,
    required this.value,
    required this.stores,
    required this.onChanged,
    required this.onStoreCreated,
    this.decoration,
    this.required = false,
    this.includeNullOption = false,
    this.nullLabel = 'Select store',
    this.enabled = true,
  });

  final String? value;
  final List<ErpStoreMaster> stores;
  final ValueChanged<String?> onChanged;
  final ValueChanged<ErpStoreMaster> onStoreCreated;
  final InputDecoration? decoration;
  final bool required;
  final bool includeNullOption;
  final String nullLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = stores.where((s) => s.isActive).toList();
    final items = <DropdownMenuItem<String?>>[
      if (includeNullOption)
        DropdownMenuItem<String?>(value: null, child: Text(nullLabel)),
      for (final s in active)
        DropdownMenuItem<String?>(
          value: s.id,
          child: Text('${s.name} (${s.location})', overflow: TextOverflow.ellipsis),
        ),
    ];
    if (value != null && !active.any((s) => s.id == value)) {
      final match = stores.where((s) => s.id == value).firstOrNull;
      if (match != null) {
        items.insert(
          includeNullOption ? 1 : 0,
          DropdownMenuItem<String?>(
            value: match.id,
            child: Text('${match.name} (${match.location})'),
          ),
        );
      }
    }

    return dropdownWithAddButton(
      tooltip: 'Add new store',
      enabled: enabled,
      onAdd: () async {
        final created = await showQuickCreateStoreDialog(context);
        if (created == null) return;
        onStoreCreated(created);
        onChanged(created.id);
      },
      child: DropdownButtonFormField<String?>(
        key: ValueKey('store-dd-$value-${stores.length}'),
        isExpanded: true,
        initialValue: value,
        decoration: decoration ??
            InputDecoration(
              labelText: required ? 'Store *' : 'Store',
              border: const OutlineInputBorder(),
            ),
        items: items,
        onChanged: enabled ? onChanged : null,
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Store is required' : null
            : null,
      ),
    );
  }
}
