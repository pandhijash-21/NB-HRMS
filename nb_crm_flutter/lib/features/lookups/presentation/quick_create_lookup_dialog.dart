import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/realtime/app_event_bus.dart';
import '../data/lookup_repository.dart';
import '../domain/lookup_models.dart';

/// Whether inline (+) quick-create is allowed for this lookup category.
bool lookupQuickCreateAllowed(String category) {
  final u = category.toUpperCase().replaceAll('-', '_');
  if (u.contains('STATUS')) return false;
  if (u.contains('CAMPAIGN')) return false;
  return true;
}

String _codeFromLabel(String label) {
  final cleaned = label
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return cleaned.isEmpty ? 'OPTION' : cleaned;
}

/// Dialog to add a Config lookup option without leaving the form.
Future<LookupOption?> showQuickCreateLookupDialog(
  BuildContext context, {
  required String category,
  String? title,
  String? parentCategory,
  String? parentCode,
  String? parentLabel,
}) async {
  final labelCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  var autoCode = true;
  var saving = false;
  String? error;

  final result = await showDialog<LookupOption>(
    context: context,
    barrierDismissible: !saving,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            title: Text(title ?? 'Add $category option'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Creates a new option under Configurations → $category.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  if (parentCode != null && parentCode.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white24 : const Color(0xFFBFDBFE),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_tree_outlined,
                            size: 16,
                            color: isDark ? Colors.lightBlueAccent : const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Linked under: ${parentLabel ?? parentCode} ($parentCode)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E40AF),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: labelCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Label *',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Civil Work',
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (v) {
                      if (!autoCode) return;
                      codeCtrl.text = _codeFromLabel(v);
                      setLocal(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Code *',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. CIVIL_WORK',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) {
                      autoCode = false;
                      setLocal(() {});
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ],
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
                        final label = labelCtrl.text.trim();
                        final code = codeCtrl.text.trim().toUpperCase();
                        if (label.isEmpty || code.isEmpty) {
                          setLocal(() => error = 'Label and code are required');
                          return;
                        }
                        setLocal(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final repo = ctx.read<LookupRepository>();
                          final created = await repo.create(
                            category: category,
                            code: code,
                            label: label,
                          );
                          repo.invalidateCategory(category);
                          AppEventBus.instance.fireErpMutated(
                            module: 'lookups',
                            entityId: category,
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

  labelCtrl.dispose();
  codeCtrl.dispose();
  return result;
}
