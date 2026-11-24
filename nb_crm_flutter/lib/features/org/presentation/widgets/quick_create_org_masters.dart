import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/dropdown_with_add.dart';
import '../../data/org_repository.dart';
import '../../domain/org_models.dart';
import '../org_providers.dart';
import 'company_details_form.dart';

/// Quick-add designation (Configurations → Designations).
Future<Designation?> showQuickCreateDesignationDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  var saving = false;
  String? error;

  final result = await showDialog<Designation>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Add designation'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Creates a designation under Configurations → Designations.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
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
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          setLocal(() => error = 'Name is required');
                          return;
                        }
                        setLocal(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final created = await ctx
                              .read<OrgRepository>()
                              .createDesignation(name: name);
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
  return result;
}

/// Quick-add institute using the full Configurations editor dialog.
Future<Institute?> showQuickCreateInstituteDialog(BuildContext context) async {
  final repo = context.read<OrgRepository>();
  List<Organization> orgs = const [];
  String? orgsError;
  try {
    orgs = await repo.listActiveOrganizations();
  } catch (e) {
    try {
      final all = await repo.listOrganizations();
      orgs = all.where((o) => o.isActive).toList();
    } catch (e2) {
      orgsError = '$e2';
    }
  }
  if (!context.mounted) return null;

  final result = await showInstituteEditorDialog(
    context,
    organizations: orgs,
    organizationsError: orgsError,
  );
  if (result == null || !context.mounted) return null;

  try {
    return await repo.createInstitute(result.body);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
    return null;
  }
}

/// Quick-add organization using the full Configurations editor dialog.
Future<Organization?> showQuickCreateOrganizationDialog(BuildContext context) async {
  final result = await showOrganizationEditorDialog(context);
  if (result == null || !context.mounted) return null;
  try {
    return await context.read<OrgRepository>().createOrganization(result.body);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
    return null;
  }
}

/// Designation dropdown (stores designation **name**) with inline +.
class DesignationNameDropdownWithCreate extends ConsumerWidget {
  const DesignationNameDropdownWithCreate({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.decoration,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final bool required;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designations = (ref.watch(jobDesignationsProvider).asData?.value ??
            const <Designation>[])
        .where((d) => d.isActive && !d.isAlias)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final names = designations.map((d) => d.name).toList();
    final current = value?.trim() ?? '';
    if (current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }
    final selected = names.contains(current) ? current : null;

    return dropdownWithAddButton(
      tooltip: 'Add new designation',
      onAdd: () async {
        final created = await showQuickCreateDesignationDialog(context);
        if (created == null) return;
        ref.invalidate(jobDesignationsProvider);
        onChanged(created.name);
      },
      child: DropdownButtonFormField<String>(
        key: ValueKey('desig-name-$selected-${names.length}'),
        isExpanded: true,
        initialValue: selected,
        decoration: decoration ??
            InputDecoration(
              labelText: required ? 'Designation *' : 'Designation',
              border: const OutlineInputBorder(),
            ),
        items: [
          for (final name in names)
            DropdownMenuItem(value: name, child: Text(name)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Designation is required' : null
            : null,
      ),
    );
  }
}

/// Designation dropdown (stores designation **id**) with inline +.
class DesignationIdDropdownWithCreate extends ConsumerWidget {
  const DesignationIdDropdownWithCreate({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.decoration,
    this.jobOnly = true,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool required;
  final InputDecoration? decoration;
  final bool jobOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designations = (ref.watch(jobDesignationsProvider).asData?.value ??
            const <Designation>[])
        .where((d) => d.isActive && (!jobOnly || !d.isAlias))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final ids = designations.map((d) => d.id).toSet();
    final selected = (value != null && ids.contains(value)) ? value : null;

    return dropdownWithAddButton(
      tooltip: 'Add new designation',
      onAdd: () async {
        final created = await showQuickCreateDesignationDialog(context);
        if (created == null) return;
        ref.invalidate(jobDesignationsProvider);
        onChanged(created.id);
      },
      child: DropdownButtonFormField<String?>(
        key: ValueKey('desig-id-$selected-${designations.length}'),
        isExpanded: true,
        initialValue: selected,
        decoration: decoration ??
            InputDecoration(
              labelText: required ? 'Designation *' : 'Designation',
              border: const OutlineInputBorder(),
              helperText: 'Must exist under Designations config',
            ),
        items: [
          if (!required)
            const DropdownMenuItem<String?>(value: null, child: Text('Select designation')),
          for (final d in designations)
            DropdownMenuItem<String?>(value: d.id, child: Text(d.name)),
        ],
        onChanged: onChanged,
        validator: required ? (v) => v == null ? 'Required' : null : null,
      ),
    );
  }
}

/// Institute dropdown with inline +.
class InstituteDropdownWithCreate extends ConsumerWidget {
  const InstituteDropdownWithCreate({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.decoration,
    this.includeNullOption = true,
    this.nullLabel = 'Not assigned',
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool required;
  final InputDecoration? decoration;
  final bool includeNullOption;
  final String nullLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutes = (ref.watch(activeInstitutesProvider).asData?.value ??
            const <Institute>[])
        .where((i) => i.isActive)
        .toList();
    final ids = institutes.map((i) => i.id).toSet();
    final selected = (value != null && ids.contains(value)) ? value : null;

    return dropdownWithAddButton(
      tooltip: 'Add new institute',
      onAdd: () async {
        final created = await showQuickCreateInstituteDialog(context);
        if (created == null) return;
        ref.invalidate(activeInstitutesProvider);
        ref.invalidate(institutesListProvider);
        onChanged(created.id);
      },
      child: DropdownButtonFormField<String?>(
        key: ValueKey('inst-$selected-${institutes.length}'),
        isExpanded: true,
        initialValue: selected,
        decoration: decoration ??
            const InputDecoration(
              labelText: 'Institute',
              border: OutlineInputBorder(),
              helperText: 'From Configurations → Institutes',
            ),
        items: [
          if (includeNullOption)
            DropdownMenuItem<String?>(value: null, child: Text(nullLabel)),
          for (final inst in institutes)
            DropdownMenuItem<String?>(
              value: inst.id,
              child: Text('${inst.name} (${inst.code})', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
        validator: required ? (v) => v == null ? 'Required' : null : null,
      ),
    );
  }
}

/// Organization dropdown (stores organization **name**) with inline +.
class OrganizationNameDropdownWithCreate extends ConsumerWidget {
  const OrganizationNameDropdownWithCreate({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.decoration,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final bool required;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgs = ref.watch(activeOrganizationsProvider).asData?.value ?? const [];
    final labels = orgs
        .map((o) => o.name)
        .where((n) => n.trim().isNotEmpty)
        .toList();
    final current = value?.trim() ?? '';
    if (current.isNotEmpty && !labels.contains(current)) {
      labels.insert(0, current);
    }
    final selected = labels.contains(current) ? current : null;

    return dropdownWithAddButton(
      tooltip: 'Add new organization',
      onAdd: () async {
        final created = await showQuickCreateOrganizationDialog(context);
        if (created == null) return;
        ref.invalidate(activeOrganizationsProvider);
        ref.invalidate(organizationsListProvider);
        onChanged(created.name);
      },
      child: DropdownButtonFormField<String>(
        key: ValueKey('org-name-$selected-${labels.length}'),
        isExpanded: true,
        initialValue: selected,
        decoration: decoration ??
            InputDecoration(
              labelText: required ? 'Organization *' : 'Organization',
              border: const OutlineInputBorder(),
              helperText: labels.isEmpty
                  ? 'Nothing in Configurations → Organizations. Add one with +.'
                  : null,
            ),
        items: [
          for (final name in labels)
            DropdownMenuItem(
              value: name,
              child: Text(name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Organization is required' : null
            : null,
      ),
    );
  }
}
