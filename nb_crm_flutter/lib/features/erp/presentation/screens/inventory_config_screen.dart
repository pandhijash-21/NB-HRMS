import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/boq_repository.dart';
import '../../domain/contractor_lookup_keys.dart';
import '../../domain/resource_models.dart';

/// Configurations → Inventory (catalog of materials with item codes).
class InventoryConfigScreen extends StatefulWidget {
  const InventoryConfigScreen({super.key});

  @override
  State<InventoryConfigScreen> createState() => _InventoryConfigScreenState();
}

class _InventoryConfigScreenState extends State<InventoryConfigScreen> {
  List<ErpMaterial> _items = [];
  bool _loading = true;
  String? _error;

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
      final list = await context.read<BoqRepository>().listMaterials(includeInactive: true);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openForm({ErpMaterial? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _InventoryFormDialog(existing: existing),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Inventory'),
        leading: const AppBackButton(fallbackLocation: '/erp/configurations'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: const Color(0xFF1e3a5f),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('No inventory items yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final m = _items[i];
                        return Card(
                          child: ListTile(
                            leading: m.imageUrl != null && m.imageUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      m.imageUrl!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.inventory_2_outlined),
                                    ),
                                  )
                                : const Icon(Icons.inventory_2_outlined),
                            title: Text(
                              m.itemCode != null && m.itemCode!.isNotEmpty
                                  ? '${m.itemCode} · ${m.name}'
                                  : m.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              [
                                if (m.categoryCode != null) m.categoryCode!,
                                if (m.brand != null || m.brandCode != null)
                                  m.brand ?? m.brandCode!,
                                if (m.unitCode != null) m.unitCode!,
                                if (m.size != null || m.sizeCode != null)
                                  m.size ?? m.sizeCode!,
                              ].join(' · '),
                            ),
                            trailing: Icon(
                              m.isActive ? Icons.check_circle : Icons.block,
                              color: m.isActive ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                            onTap: () => _openForm(existing: m),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _InventoryFormDialog extends StatefulWidget {
  const _InventoryFormDialog({this.existing});
  final ErpMaterial? existing;

  @override
  State<_InventoryFormDialog> createState() => _InventoryFormDialogState();
}

class _InventoryFormDialogState extends State<_InventoryFormDialog> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  String? _categoryCode;
  String? _brandCode;
  String? _unitCode;
  String? _sizeCode;
  String? _imageUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _codeCtrl = TextEditingController(text: e?.itemCode ?? '');
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _categoryCode = e?.categoryCode;
    _brandCode = e?.brandCode ?? e?.brand;
    _unitCode = e?.unitCode;
    _sizeCode = e?.sizeCode ?? e?.size;
    _imageUrl = e?.imageUrl;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await pickFileFromDevice(imagesOnly: true);
    if (picked == null) return;
    setState(() => _saving = true);
    try {
      final uploaded = await context.read<BoqRepository>().uploadInventoryImage(
            bytes: picked.bytes,
            filename: picked.name,
          );
      if (!mounted) return;
      setState(() => _imageUrl = uploaded.url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'itemCode': code.isEmpty ? null : code,
        'categoryCode': _categoryCode,
        'brandCode': _brandCode,
        'brand': _brandCode,
        'name': name,
        'unitCode': _unitCode,
        'sizeCode': _sizeCode,
        'size': _sizeCode,
        'imageUrl': _imageUrl,
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'isActive': true,
      };
      final repo = context.read<BoqRepository>();
      if (widget.existing != null) {
        await repo.updateMaterial(widget.existing!.id, body);
      } else {
        await repo.createMaterial(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Inventory Item' : 'Edit Inventory Item'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: 'Item Code', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              lookupNullableDropdown(
                category: kInventoryCategory,
                label: 'Category',
                value: _categoryCode,
                onChanged: (v) => setState(() => _categoryCode = v),
              ),
              const SizedBox(height: 10),
              lookupNullableDropdown(
                category: kInventoryBrand,
                label: 'Brand',
                value: _brandCode,
                onChanged: (v) => setState(() => _brandCode = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Material Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              lookupNullableDropdown(
                category: kInventoryUom,
                label: 'Material UoM',
                value: _unitCode,
                onChanged: (v) => setState(() => _unitCode = v),
              ),
              const SizedBox(height: 10),
              lookupNullableDropdown(
                category: kInventorySize,
                label: 'Size',
                value: _sizeCode,
                onChanged: (v) => setState(() => _sizeCode = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Material Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_imageUrl != null && _imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_imageUrl!, width: 56, height: 56, fit: BoxFit.cover),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _saving ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_imageUrl == null ? 'Add Image' : 'Change Image'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
