import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/lookup_models.dart';
import 'lookup_providers.dart';

/// Resolves active lookup options for [category], with optional hardcoded fallbacks.
List<LookupOption> resolveLookupOptions(
  WidgetRef ref,
  String category, {
  List<LookupOption> fallback = const [],
}) {
  final async = ref.watch(activeLookupsByCategoryProvider(category));
  final fromApi = async.asData?.value ?? const <LookupOption>[];
  if (fromApi.isNotEmpty) return fromApi;
  return fallback;
}

bool lookupsLoading(WidgetRef ref, String category) {
  return ref.watch(activeLookupsByCategoryProvider(category)).isLoading;
}

void _defer(VoidCallback fn) {
  WidgetsBinding.instance.addPostFrameCallback((_) => fn());
}

/// Required dropdown bound to a lookup category (stores [LookupOption.code]).
Widget lookupDropdown({
  required WidgetRef ref,
  required String category,
  required String label,
  required String? value,
  required ValueChanged<String> onChanged,
  List<LookupOption> fallback = const [],
  bool required = false,
}) {
  if (lookupsLoading(ref, category) &&
      resolveLookupOptions(ref, category, fallback: fallback).isEmpty) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
        child: const SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
  return _LookupCodeDropdown(
    category: category,
    label: label,
    value: value,
    required: required,
    options: List<LookupOption>.from(
      resolveLookupOptions(ref, category, fallback: fallback),
    ),
    onChanged: onChanged,
  );
}

/// Multi-select chips bound to a lookup category (stores codes as a set).
Widget lookupMultiCheckbox({
  required WidgetRef ref,
  required String category,
  required String label,
  required Set<String> selected,
  required ValueChanged<Set<String>> onChanged,
}) {
  final options = resolveLookupOptions(ref, category);
  if (lookupsLoading(ref, category) && options.isEmpty) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: const SizedBox(
        height: 24,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
  if (options.isEmpty) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: 'Add options under Configurations → Projects → Amenities.',
      ),
      child: const Text('No amenities configured yet'),
    );
  }

  return _LookupMultiChipField(
    label: label,
    options: options,
    selected: selected,
    onChanged: onChanged,
  );
}

class _LookupMultiChipField extends StatelessWidget {
  const _LookupMultiChipField({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<LookupOption> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFF2563eb);
    const accentDark = Color(0xFF1d4ed8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF607D8B),
              ),
            ),
            const Spacer(),
            if (selected.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${selected.length} selected',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFC5A059).withValues(alpha: 0.2)
                  : const Color(0xFFCFD8DC),
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                _AmenityChip(
                  label: o.label,
                  selected: selected.contains(o.code),
                  isDark: isDark,
                  accent: accent,
                  accentDark: accentDark,
                  onTap: () {
                    final next = Set<String>.from(selected);
                    if (next.contains(o.code)) {
                      next.remove(o.code);
                    } else {
                      next.add(o.code);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.accent,
    required this.accentDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final Color accent;
  final Color accentDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (isDark ? accentDark : accent)
        : (isDark ? const Color(0xFF1E1B18) : Colors.white);
    final border = selected
        ? (isDark ? accent : accent)
        : (isDark ? const Color(0xFF3A3530) : const Color(0xFFCFD8DC));
    final fg = selected
        ? Colors.white
        : (isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF37474F));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
            boxShadow: selected && !isDark
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 16,
                color: selected ? Colors.white : (isDark ? Colors.white38 : const Color(0xFF90A4AE)),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nullable dropdown (includes "Not set").
Widget lookupNullableDropdown({
  required WidgetRef ref,
  required String category,
  required String label,
  required String? value,
  required ValueChanged<String?> onChanged,
  List<LookupOption> fallback = const [],
}) {
  return _LookupNullableCodeDropdown(
    category: category,
    label: label,
    value: value,
    options: List<LookupOption>.from(
      resolveLookupOptions(ref, category, fallback: fallback),
    ),
    onChanged: onChanged,
  );
}

/// Dropdown that stores the **label** (for fields historically free-text like bank/org).
Widget lookupLabelDropdown({
  required WidgetRef ref,
  required String category,
  required String label,
  required String? value,
  required ValueChanged<String> onChanged,
  List<String> fallbackLabels = const [],
  bool required = false,
}) {
  final options = resolveLookupOptions(ref, category);
  final labels = List<String>.from(
    options.isNotEmpty ? options.map((o) => o.label) : fallbackLabels,
  );
  return _LookupLabelDropdown(
    category: category,
    label: label,
    value: value,
    required: required,
    labels: labels,
    options: options,
    onChanged: onChanged,
  );
}

/// Nullable label dropdown (includes "Not set").
Widget lookupNullableLabelDropdown({
  required WidgetRef ref,
  required String category,
  required String label,
  required String? value,
  required ValueChanged<String?> onChanged,
  List<String> fallbackLabels = const [],
}) {
  final options = resolveLookupOptions(ref, category);
  final labels = List<String>.from(
    options.isNotEmpty ? options.map((o) => o.label) : fallbackLabels,
  );
  return _LookupNullableLabelDropdown(
    category: category,
    label: label,
    value: value,
    labels: labels,
    options: options,
    onChanged: onChanged,
  );
}

String? _matchCode(List<LookupOption> options, String? value) {
  if (value == null || value.isEmpty) return null;
  for (final o in options) {
    if (o.code == value || o.label == value) return o.code;
  }
  return value; // legacy free-text kept visible
}

String? _matchLabel(
  List<LookupOption> options,
  List<String> labels,
  String? value,
) {
  if (value == null || value.isEmpty) return null;
  if (labels.contains(value)) return value;
  for (final o in options) {
    if (o.code == value) return o.label;
  }
  return value; // legacy free-text kept visible
}

class _LookupCodeDropdown extends StatefulWidget {
  final String category;
  final String label;
  final String? value;
  final bool required;
  final List<LookupOption> options;
  final ValueChanged<String> onChanged;

  const _LookupCodeDropdown({
    required this.category,
    required this.label,
    required this.value,
    required this.required,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_LookupCodeDropdown> createState() => _LookupCodeDropdownState();
}

class _LookupCodeDropdownState extends State<_LookupCodeDropdown> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _syncFromWidget(notifyParentIfDefaulted: true);
  }

  @override
  void didUpdateWidget(covariant _LookupCodeDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.options.length != widget.options.length) {
      // Options often arrive after first frame (async lookups). If we only
      // default visually and skip onChanged, required forms keep a null value.
      final optionsJustLoaded =
          oldWidget.options.isEmpty && widget.options.isNotEmpty;
      final parentStillEmpty = widget.value == null || widget.value!.isEmpty;
      _syncFromWidget(
        notifyParentIfDefaulted: optionsJustLoaded && parentStillEmpty,
      );
    }
  }

  void _syncFromWidget({required bool notifyParentIfDefaulted}) {
    final options = List<LookupOption>.from(widget.options);
    if (options.isEmpty) {
      _selected = null;
      return;
    }

    var matched = _matchCode(options, widget.value);
    if (matched != null && !options.any((o) => o.code == matched)) {
      options.insert(
        0,
        LookupOption(
          id: 'legacy',
          category: widget.category,
          code: matched,
          label: matched,
        ),
      );
    }

    if (matched == null && widget.required) {
      matched = options.first.code;
      if (notifyParentIfDefaulted && widget.value != matched) {
        _defer(() {
          if (mounted) widget.onChanged(matched!);
        });
      }
    }
    _selected = matched;
  }

  @override
  Widget build(BuildContext context) {
    final options = List<LookupOption>.from(widget.options);
    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            errorText:
                'No options configured. Add some under Configurations → ${widget.category}.',
          ),
          child: const Text('—'),
        ),
      );
    }

    var selected = _selected;
    if (selected != null && !options.any((o) => o.code == selected)) {
      options.insert(
        0,
        LookupOption(
          id: 'legacy',
          category: widget.category,
          code: selected,
          label: selected,
        ),
      );
    }
    if (selected == null && widget.required) {
      selected = options.first.code;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: DropdownButtonFormField<String>(
        key: ValueKey('lookup-code-${widget.category}-$selected'),
        isExpanded: true,
        initialValue: selected,
        decoration: InputDecoration(
          labelText: widget.required ? '${widget.label} *' : widget.label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final o in options)
            DropdownMenuItem(
              value: o.code,
              child: Text(o.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => _selected = v);
          _defer(() => widget.onChanged(v));
        },
        validator: widget.required
            ? (v) => (v == null || v.isEmpty) ? '${widget.label} is required' : null
            : null,
      ),
    );
  }
}

class _LookupNullableCodeDropdown extends StatefulWidget {
  final String category;
  final String label;
  final String? value;
  final List<LookupOption> options;
  final ValueChanged<String?> onChanged;

  const _LookupNullableCodeDropdown({
    required this.category,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_LookupNullableCodeDropdown> createState() =>
      _LookupNullableCodeDropdownState();
}

class _LookupNullableCodeDropdownState
    extends State<_LookupNullableCodeDropdown> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = _matchCode(widget.options, widget.value);
  }

  @override
  void didUpdateWidget(covariant _LookupNullableCodeDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _selected = _matchCode(widget.options, widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = List<LookupOption>.from(widget.options);
    final selected = _selected;
    if (selected != null &&
        selected.isNotEmpty &&
        !options.any((o) => o.code == selected)) {
      options.insert(
        0,
        LookupOption(
          id: 'legacy',
          category: widget.category,
          code: selected,
          label: selected,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('lookup-nullable-code-${widget.category}-$selected'),
        isExpanded: true,
        initialValue: selected,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Not set')),
          for (final o in options)
            DropdownMenuItem<String?>(
              value: o.code,
              child: Text(o.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          setState(() => _selected = v);
          _defer(() => widget.onChanged(v));
        },
      ),
    );
  }
}

class _LookupLabelDropdown extends StatefulWidget {
  final String category;
  final String label;
  final String? value;
  final bool required;
  final List<String> labels;
  final List<LookupOption> options;
  final ValueChanged<String> onChanged;

  const _LookupLabelDropdown({
    required this.category,
    required this.label,
    required this.value,
    required this.required,
    required this.labels,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_LookupLabelDropdown> createState() => _LookupLabelDropdownState();
}

class _LookupLabelDropdownState extends State<_LookupLabelDropdown> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _syncFromWidget(notifyParentIfDefaulted: true);
  }

  @override
  void didUpdateWidget(covariant _LookupLabelDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.labels.length != widget.labels.length) {
      _syncFromWidget(notifyParentIfDefaulted: false);
    }
  }

  void _syncFromWidget({required bool notifyParentIfDefaulted}) {
    final labels = List<String>.from(widget.labels);
    if (labels.isEmpty) {
      _selected = null;
      return;
    }
    var matched = _matchLabel(widget.options, labels, widget.value);
    if (matched != null && !labels.contains(matched)) {
      labels.insert(0, matched);
    }
    if (matched == null && widget.required) {
      matched = labels.first;
      if (notifyParentIfDefaulted && widget.value != matched) {
        _defer(() {
          if (mounted) widget.onChanged(matched!);
        });
      }
    }
    _selected = matched;
  }

  @override
  Widget build(BuildContext context) {
    final labels = List<String>.from(widget.labels);
    if (labels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            errorText:
                'No options configured under Configurations → ${widget.category}.',
          ),
          child: const Text('—'),
        ),
      );
    }

    var selected = _selected;
    if (selected != null && !labels.contains(selected)) {
      labels.insert(0, selected);
    }
    if (selected == null && widget.required) {
      selected = labels.first;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: DropdownButtonFormField<String>(
        key: ValueKey('lookup-label-${widget.category}-$selected'),
        initialValue: selected,
        decoration: InputDecoration(
          labelText: widget.required ? '${widget.label} *' : widget.label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final l in labels) DropdownMenuItem(value: l, child: Text(l)),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => _selected = v);
          _defer(() => widget.onChanged(v));
        },
        validator: widget.required
            ? (v) => (v == null || v.isEmpty) ? '${widget.label} is required' : null
            : null,
      ),
    );
  }
}

class _LookupNullableLabelDropdown extends StatefulWidget {
  final String category;
  final String label;
  final String? value;
  final List<String> labels;
  final List<LookupOption> options;
  final ValueChanged<String?> onChanged;

  const _LookupNullableLabelDropdown({
    required this.category,
    required this.label,
    required this.value,
    required this.labels,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_LookupNullableLabelDropdown> createState() =>
      _LookupNullableLabelDropdownState();
}

class _LookupNullableLabelDropdownState
    extends State<_LookupNullableLabelDropdown> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = _matchLabel(widget.options, widget.labels, widget.value);
  }

  @override
  void didUpdateWidget(covariant _LookupNullableLabelDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _selected = _matchLabel(widget.options, widget.labels, widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = List<String>.from(widget.labels);
    final selected = _selected;
    if (selected != null &&
        selected.isNotEmpty &&
        !labels.contains(selected)) {
      labels.insert(0, selected);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('lookup-nullable-label-${widget.category}-$selected'),
        initialValue: selected,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Not set')),
          for (final l in labels)
            DropdownMenuItem<String?>(value: l, child: Text(l)),
        ],
        onChanged: (v) {
          setState(() => _selected = v);
          _defer(() => widget.onChanged(v));
        },
      ),
    );
  }
}
