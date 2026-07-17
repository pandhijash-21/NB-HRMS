import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/lookup_models.dart';
import '../lookup_providers.dart';

class LookupCategoryScreen extends ConsumerStatefulWidget {
  const LookupCategoryScreen({super.key, required this.category});

  final String category;

  @override
  ConsumerState<LookupCategoryScreen> createState() => _LookupCategoryScreenState();
}

class _LookupCategoryScreenState extends ConsumerState<LookupCategoryScreen> {
  final _codeCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(lookupGroupsProvider);
    LookupCategoryGroup? group;
    for (final g in groupsAsync.asData?.value ?? const <LookupCategoryGroup>[]) {
      if (g.key == widget.category) {
        group = g;
        break;
      }
    }

    final title = group?.label ?? widget.category;
    final options = group?.options ?? const <LookupOption>[];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin/configurations'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC5A059)),
            onPressed: () => ref.invalidate(lookupGroupsProvider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (group?.description != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                group!.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                ),
              ),
            ),
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E1B18) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Add option', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display label',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. A+',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code (stored value)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. A_POS',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _create,
                    child: Text(_saving ? 'Saving…' : 'Add'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (groupsAsync.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (options.isEmpty)
            const Text('No options yet.')
          else
            ...options.map((o) => _optionTile(o, isDark)),
        ],
      ),
    );
  }

  Widget _optionTile(LookupOption o, bool isDark) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : const Color(0xFFCFD8DC),
        ),
      ),
      child: Opacity(
        opacity: o.isActive ? 1 : 0.55,
        child: ListTile(
          title: Text(o.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(o.code, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: o.isActive,
                onChanged: (v) => _toggle(o, v),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                onPressed: () => _delete(o),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    final label = _labelCtrl.text.trim();
    var code = _codeCtrl.text.trim();
    if (label.isEmpty) return;
    if (code.isEmpty) {
      code = label.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
    }
    setState(() => _saving = true);
    try {
      await ref.read(lookupRepositoryProvider).create(
            category: widget.category,
            code: code,
            label: label,
          );
      _labelCtrl.clear();
      _codeCtrl.clear();
      ref.invalidate(lookupGroupsProvider);
      ref.invalidate(activeLookupsByCategoryProvider(widget.category));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Option added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(LookupOption o, bool isActive) async {
    try {
      await ref.read(lookupRepositoryProvider).update(o.id, isActive: isActive);
      ref.invalidate(lookupGroupsProvider);
      ref.invalidate(activeLookupsByCategoryProvider(widget.category));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete(LookupOption o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete option?'),
        content: Text('Remove "${o.label}" from ${widget.category}?'),
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
    if (ok != true) return;
    try {
      await ref.read(lookupRepositoryProvider).delete(o.id);
      ref.invalidate(lookupGroupsProvider);
      ref.invalidate(activeLookupsByCategoryProvider(widget.category));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
