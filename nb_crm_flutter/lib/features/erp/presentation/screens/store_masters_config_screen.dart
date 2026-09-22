import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_back_button.dart';
import '../../data/boq_repository.dart';
import '../../domain/store_models.dart';

/// ERP Configurations → Stores (name + location).
class StoreMastersConfigScreen extends StatefulWidget {
  const StoreMastersConfigScreen({super.key});

  @override
  State<StoreMastersConfigScreen> createState() => _StoreMastersConfigScreenState();
}

class _StoreMastersConfigScreenState extends State<StoreMastersConfigScreen> {
  List<ErpStoreMaster> _stores = [];
  bool _loading = true;
  String? _error;
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<BoqRepository>().listStoresConfig(includeInactive: true);
      if (!mounted) return;
      setState(() {
        _stores = list;
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

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    if (name.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and location are required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<BoqRepository>().createStore(
            {'name': name, 'location': location},
            fromConfig: true,
          );
      _nameCtrl.clear();
      _locationCtrl.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(ErpStoreMaster store) async {
    final nameCtrl = TextEditingController(text: store.name);
    final locCtrl = TextEditingController(text: store.location);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit store'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Store name'),
            ),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<BoqRepository>().updateStore(
            store.id,
            {'name': nameCtrl.text.trim(), 'location': locCtrl.text.trim()},
            fromConfig: true,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _toggleActive(ErpStoreMaster store) async {
    try {
      await context.read<BoqRepository>().updateStore(
            store.id,
            {'isActive': !store.isActive},
            fromConfig: true,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stores'),
        leading: const AppBackButton(fallbackLocation: '/erp/configurations'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Add store',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Store name *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _locationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Location *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _saving ? null : _add,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Add store'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Configured stores',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                if (_stores.isEmpty)
                  const Text('No stores yet. Add a name and location above.'),
                for (final s in _stores)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.warehouse_outlined,
                        color: s.isActive ? const Color(0xFF0D9488) : Colors.grey,
                      ),
                      title: Text(s.name),
                      subtitle: Text(s.location),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!s.isActive)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Chip(label: Text('Inactive', style: TextStyle(fontSize: 11))),
                            ),
                          IconButton(
                            tooltip: s.isActive ? 'Deactivate' : 'Activate',
                            icon: Icon(s.isActive ? Icons.toggle_on : Icons.toggle_off),
                            onPressed: () => _toggleActive(s),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(s),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
