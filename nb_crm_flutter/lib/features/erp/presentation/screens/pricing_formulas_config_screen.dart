import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_back_button.dart';
import '../../data/project_repository.dart';
import '../../domain/pricing_component_models.dart';

class PricingFormulasConfigScreen extends StatefulWidget {
  const PricingFormulasConfigScreen({super.key});

  @override
  State<PricingFormulasConfigScreen> createState() => _PricingFormulasConfigScreenState();
}

class _PricingFormulasConfigScreenState extends State<PricingFormulasConfigScreen> {
  bool _loading = true;
  String? _error;
  List<ErpPricingComponent> _components = [];
  String _selectedCategory = 'ALL'; // ALL | BASE_PRICE | TAX | MAINTENANCE | OTHER_CHARGE

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<ProjectRepository>().getPricingComponents(includeInactive: true);
      if (mounted) {
        setState(() {
          _components = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleActive(ErpPricingComponent c, bool active) async {
    try {
      final updated = await context.read<ProjectRepository>().updatePricingComponent(
        c.id,
        {'isActive': active},
      );
      setState(() {
        final idx = _components.indexWhere((x) => x.id == c.id);
        if (idx >= 0) _components[idx] = updated;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${c.name} ${active ? 'enabled' : 'disabled'}'),
            duration: const Duration(seconds: 2),
            backgroundColor: active ? const Color(0xFF10B981) : Colors.grey[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteComponent(ErpPricingComponent c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${c.name}?'),
        content: Text('Are you sure you want to remove ${c.name} (${c.code})? Units using this will no longer have this charge applied.'),
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
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await context.read<ProjectRepository>().deletePricingComponent(c.id);
      setState(() {
        _components.removeWhere((x) => x.id == c.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${c.name} removed successfully'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Standard Formulas?'),
        content: const Text(
          'This will restore all default real estate price components, statutory taxes (GST, Stamp Duty, Registration), maintenance, and legal fee formulas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563eb)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Defaults'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await context.read<ProjectRepository>().resetPricingComponents();
      setState(() {
        _components = list;
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Standard pricing formulas restored'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openEditor({ErpPricingComponent? existing, String? initialCategory}) {
    showDialog(
      context: context,
      builder: (ctx) => _ComponentEditorDialog(
        existing: existing,
        initialCategory: initialCategory ?? (_selectedCategory == 'ALL' ? 'BASE_PRICE' : _selectedCategory),
        onSave: (data) async {
          if (existing != null) {
            final updated = await context.read<ProjectRepository>().updatePricingComponent(existing.id, data);
            setState(() {
              final idx = _components.indexWhere((x) => x.id == existing.id);
              if (idx >= 0) _components[idx] = updated;
            });
          } else {
            final created = await context.read<ProjectRepository>().createPricingComponent(data);
            setState(() {
              _components.add(created);
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = [
      ('ALL', 'All Components', Icons.apps_rounded, const Color(0xFF64748B)),
      ('BASE_PRICE', 'Base Pricing', Icons.architecture_rounded, const Color(0xFF2563EB)),
      ('TAX', 'Taxes', Icons.receipt_long_rounded, const Color(0xFFD97706)),
      ('MAINTENANCE', 'Maintenance', Icons.cleaning_services_rounded, const Color(0xFF0D9488)),
      ('OTHER_CHARGE', 'Other Charges', Icons.gavel_rounded, const Color(0xFF7C3AED)),
    ];

    final filtered = _selectedCategory == 'ALL'
        ? _components
        : _components.where((c) => c.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: const Text('Pricing & Tax Formulas', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: const AppBackButton(fallbackLocation: '/erp/configurations'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset Defaults'),
            onPressed: _loading ? null : _resetDefaults,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563eb),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Component'),
              onPressed: _loading ? null : () => _openEditor(),
            ),
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
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Explanatory Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2563eb).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563eb).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calculate_rounded, color: Color(0xFF2563eb), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Formula & Cost Engine Configuration',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage formulas for base rates, floor rise, development charges, preferential location, statutory taxes, maintenance, and legal fees. Toggle off or remove any component (such as maintenance) at any time.',
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
                    const SizedBox(height: 16),

                    // Category Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((cat) {
                          final selected = _selectedCategory == cat.$1;
                          final count = cat.$1 == 'ALL'
                              ? _components.length
                              : _components.where((x) => x.category == cat.$1).length;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(cat.$3, size: 16, color: selected ? Colors.white : cat.$4),
                              label: Text('${cat.$2} ($count)'),
                              selected: selected,
                              selectedColor: cat.$4,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                              onSelected: (_) => setState(() => _selectedCategory = cat.$1),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Components list
                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Text(
                          'No components in this category. Tap "Add Component" above to create one.',
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                        ),
                      )
                    else
                      for (final c in filtered) ...[
                        _ComponentTile(
                          component: c,
                          isDark: isDark,
                          onToggleActive: (v) => _toggleActive(c, v),
                          onEdit: () => _openEditor(existing: c),
                          onDelete: c.isRequired ? null : () => _deleteComponent(c),
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
    );
  }
}

class _ComponentTile extends StatelessWidget {
  const _ComponentTile({
    required this.component,
    required this.isDark,
    required this.onToggleActive,
    required this.onEdit,
    this.onDelete,
  });

  final ErpPricingComponent component;
  final bool isDark;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  Color get _categoryColor {
    switch (component.category) {
      case 'BASE_PRICE':
        return const Color(0xFF2563EB);
      case 'TAX':
        return const Color(0xFFD97706);
      case 'MAINTENANCE':
        return const Color(0xFF0D9488);
      case 'OTHER_CHARGE':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = component.isActive;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? _categoryColor.withValues(alpha: 0.3)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _categoryColor.withValues(alpha: active ? 0.15 : 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  component.code,
                  style: TextStyle(
                    color: active ? _categoryColor : Colors.grey,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  component.categoryLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
              if (component.isRequired) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'REQUIRED',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.red),
                  ),
                ),
              ],
              const Spacer(),
              Switch(
                value: active,
                activeThumbColor: _categoryColor,
                onChanged: onToggleActive,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: active ? (isDark ? Colors.white : const Color(0xFF1E293B)) : Colors.grey,
                      ),
                    ),
                    if (component.description?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          component.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF2563EB)),
                tooltip: 'Edit Formula',
                onPressed: onEdit,
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  tooltip: 'Delete Component',
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Formula Display Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.functions_rounded, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  '${component.code} = ',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB)),
                ),
                Expanded(
                  child: Text(
                    component.formulaPreview.isNotEmpty
                        ? component.formulaPreview
                        : component.formulaTypeLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _categoryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    component.rateUnit ?? '₹/sq.ft',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _categoryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentEditorDialog extends StatefulWidget {
  const _ComponentEditorDialog({
    this.existing,
    required this.initialCategory,
    required this.onSave,
  });

  final ErpPricingComponent? existing;
  final String initialCategory;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  @override
  State<_ComponentEditorDialog> createState() => _ComponentEditorDialogState();
}

class _ComponentEditorDialogState extends State<_ComponentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _descCtrl;
  late String _category;
  late String _formulaType;
  late String _rateUnit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _codeCtrl = TextEditingController(text: e?.code ?? '');
    _rateCtrl = TextEditingController(text: e?.defaultRate != null ? '${e!.defaultRate}' : '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _category = e?.category ?? widget.initialCategory;
    _formulaType = e?.formulaType ?? 'AREA_RATE';
    _rateUnit = e?.rateUnit ?? (_formulaType == 'PERCENTAGE' ? '%' : '₹/sq.ft');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _rateCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _generateFormulaPreview() {
    final name = _nameCtrl.text.trim().isEmpty ? 'Component' : _nameCtrl.text.trim();
    switch (_formulaType) {
      case 'AREA_BSV':
        return 'Super Built-Up Area × Base Rate (BSV)';
      case 'AREA_RATE':
        return 'Super Built-Up Area × $name Rate ($_rateUnit)';
      case 'PERCENTAGE':
        final rate = _rateCtrl.text.trim().isNotEmpty ? '${_rateCtrl.text.trim()}%' : 'X%';
        return '$rate of Total Unit Value';
      case 'FIXED':
        return 'Fixed Amount ($_rateUnit)';
      case 'DOCS_MULTIPLIER':
        return 'Document Count × Fee per Document';
      default:
        return 'Custom Formula';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = {
      'name': _nameCtrl.text.trim(),
      'code': _codeCtrl.text.trim().toUpperCase().replaceAll(' ', '_'),
      'category': _category,
      'formulaType': _formulaType,
      'formulaPreview': _generateFormulaPreview(),
      'rateUnit': _rateUnit,
      'defaultRate': double.tryParse(_rateCtrl.text.trim()),
      'description': _descCtrl.text.trim(),
    };

    try {
      await widget.onSave(payload);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(isNew ? Icons.add_circle_outline : Icons.tune_rounded, color: const Color(0xFF2563eb)),
          const SizedBox(width: 10),
          Text(isNew ? 'Add Pricing Component' : 'Edit Formula — ${widget.existing!.name}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Formula Preview Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563eb).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LIVE FORMULA PREVIEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563eb),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _generateFormulaPreview(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Name & Code
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Component Name *',
                          hintText: 'e.g. Floor Rise Charge (FRC)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _codeCtrl,
                        enabled: isNew,
                        decoration: const InputDecoration(
                          labelText: 'Code *',
                          hintText: 'e.g. FRC',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Category & Formula Type
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'BASE_PRICE', child: Text('Base Pricing & Charges')),
                    DropdownMenuItem(value: 'TAX', child: Text('Taxes')),
                    DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance Charges')),
                    DropdownMenuItem(value: 'OTHER_CHARGE', child: Text('Other Charges')),
                  ],
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: _formulaType,
                  decoration: const InputDecoration(
                    labelText: 'Formula Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'AREA_RATE',
                      child: Text('Area × Component Rate (e.g. Super Built-up × Rate/sq.ft)'),
                    ),
                    DropdownMenuItem(
                      value: 'AREA_BSV',
                      child: Text('Area × Base Rate (BSV) (e.g. Super Built-up × Base Rate)'),
                    ),
                    DropdownMenuItem(
                      value: 'PERCENTAGE',
                      child: Text('% of Total Unit Value (e.g. 5% GST, Stamp Duty)'),
                    ),
                    DropdownMenuItem(
                      value: 'FIXED',
                      child: Text('Fixed Amount (Flat Lump Sum ₹)'),
                    ),
                    DropdownMenuItem(
                      value: 'DOCS_MULTIPLIER',
                      child: Text('Doc Multiplier (Document Count × Fee per Doc)'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _formulaType = v!;
                      if (_formulaType == 'PERCENTAGE') {
                        _rateUnit = '%';
                      } else if (_formulaType == 'DOCS_MULTIPLIER') {
                        _rateUnit = '₹/doc';
                      } else if (_formulaType == 'FIXED') {
                        _rateUnit = '₹';
                      } else {
                        _rateUnit = '₹/sq.ft';
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Rate Unit & Default Rate
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: _formulaType == 'PERCENTAGE' ? 'Default Percentage (%)' : 'Default Rate',
                          hintText: _formulaType == 'PERCENTAGE' ? '5.0' : '0',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _rateUnit,
                        decoration: const InputDecoration(
                          labelText: 'Rate Unit',
                          hintText: '₹/sq.ft, %, ₹',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _rateUnit = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description / Notes',
                    hintText: 'Explain how this charge is computed or applied',
                    border: OutlineInputBorder(),
                  ),
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
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563eb),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_saving ? 'Saving…' : 'Save Formula'),
          onPressed: _saving ? null : _submit,
        ),
      ],
    );
  }
}
