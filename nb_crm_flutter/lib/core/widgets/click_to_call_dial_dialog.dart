import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mobile_input_formatter.dart';

/// Shows an editable dial number (default `+91…`) before click-to-call.
/// Returns digits to send to telephony (user may strip `+91`), or null if cancelled.
Future<String?> showClickToCallDialDialog(
  BuildContext context, {
  required String phone,
  String? leadName,
}) async {
  final initial = formatClickToCallDialPreview(phone);
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phone_in_talk_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 10),
            Expanded(child: Text('Click to Call', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leadName != null && leadName.trim().isNotEmpty) ...[
              Text(
                leadName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Full number with country code. Remove +91 if your dialer needs a 10-digit local number.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
              ],
              decoration: InputDecoration(
                labelText: 'Dial number',
                hintText: '+91XXXXXXXXXX',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.dialpad_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final dial = digitsOnlyPhone(controller.text);
              if (dial.isEmpty) return;
              Navigator.pop(ctx, dial);
            },
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}
