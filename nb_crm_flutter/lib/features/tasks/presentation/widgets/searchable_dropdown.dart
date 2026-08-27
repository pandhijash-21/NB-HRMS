import 'package:flutter/material.dart';

const _pickerCancelled = '__picker_cancelled__';

class SearchableDropdown<T> extends StatefulWidget {
  const SearchableDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.itemValue,
    this.value,
    this.onChanged,
    this.helperText,
    this.hint = 'Search…',
    this.allowClear = false,
    this.clearLabel = 'None',
  });

  final String label;
  final List<T> items;
  final String Function(T item) itemLabel;
  final String Function(T item) itemValue;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? helperText;
  final String hint;
  final bool allowClear;
  final String clearLabel;

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  String get _selectedLabel {
    if (widget.value == null) return widget.allowClear ? widget.clearLabel : 'Select…';
    for (final item in widget.items) {
      if (widget.itemValue(item) == widget.value) return widget.itemLabel(item);
    }
    return 'Select…';
  }

  Future<void> _openPicker() async {
    final picked = await showDialog<String?>(
      context: context,
      builder: (ctx) => _SearchablePickerDialog<T>(
        title: widget.label,
        items: widget.items,
        itemLabel: widget.itemLabel,
        itemValue: widget.itemValue,
        selected: widget.value,
        hint: widget.hint,
        allowClear: widget.allowClear,
        clearLabel: widget.clearLabel,
      ),
    );
    if (!mounted || picked == _pickerCancelled) return;
    widget.onChanged?.call(picked!.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        helperText: widget.helperText,
        suffixIcon: const Icon(Icons.search_rounded),
      ),
      child: InkWell(
        onTap: widget.onChanged == null ? null : _openPicker,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            _selectedLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: widget.value == null && !widget.allowClear
                  ? Theme.of(context).hintColor
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchablePickerDialog<T> extends StatefulWidget {
  const _SearchablePickerDialog({
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.itemValue,
    required this.selected,
    required this.hint,
    required this.allowClear,
    required this.clearLabel,
  });

  final String title;
  final List<T> items;
  final String Function(T item) itemLabel;
  final String Function(T item) itemValue;
  final String? selected;
  final String hint;
  final bool allowClear;
  final String clearLabel;

  @override
  State<_SearchablePickerDialog<T>> createState() => _SearchablePickerDialogState<T>();
}

class _SearchablePickerDialogState<T> extends State<_SearchablePickerDialog<T>> {
  final _query = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<T> get _filtered {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items.where((item) => widget.itemLabel(item).toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 12),
            if (widget.allowClear)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, ''),
                  child: Text(widget.clearLabel),
                ),
              ),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text('No matches'))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final item = _filtered[i];
                        final id = widget.itemValue(item);
                        return ListTile(
                          title: Text(widget.itemLabel(item)),
                          selected: id == widget.selected,
                          onTap: () => Navigator.pop(context, id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, _pickerCancelled), child: const Text('Cancel')),
      ],
    );
  }
}
