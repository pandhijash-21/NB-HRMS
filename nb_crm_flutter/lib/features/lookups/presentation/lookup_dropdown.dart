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
      _syncFromWidget(notifyParentIfDefaulted: false);
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
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: ValueKey('lookup-code-${widget.category}-$selected'),
        initialValue: selected,
        decoration: InputDecoration(
          labelText: widget.required ? '${widget.label} *' : widget.label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o.code, child: Text(o.label)),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('lookup-nullable-code-${widget.category}-$selected'),
        initialValue: selected,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Not set')),
          for (final o in options)
            DropdownMenuItem<String?>(value: o.code, child: Text(o.label)),
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
      padding: const EdgeInsets.only(bottom: 16),
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
      padding: const EdgeInsets.only(bottom: 16),
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
