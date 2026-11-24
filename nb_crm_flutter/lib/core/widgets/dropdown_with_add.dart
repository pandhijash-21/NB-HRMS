import 'package:flutter/material.dart';

/// Wraps any dropdown (or form field) with an inline (+) quick-create button.
Widget dropdownWithAddButton({
  required Widget child,
  required VoidCallback? onAdd,
  String tooltip = 'Add new',
  bool enabled = true,
}) {
  if (onAdd == null) return child;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: child),
      Padding(
        padding: const EdgeInsets.only(left: 4, top: 6),
        child: IconButton(
          tooltip: tooltip,
          onPressed: enabled ? onAdd : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ),
    ],
  );
}
