import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mobile_input_formatter.dart';

/// Shows an editable dial number with Country Code intelligence before click-to-call.
/// Clean, responsive, typography-first dialog with minimal icons.
Future<String?> showClickToCallDialDialog(
  BuildContext context, {
  required String phone,
  String? leadName,
  String? countryCode,
}) async {
  final parsed = parseCountryPhone(phone, countryCode);
  final initial = parsed.e164.isNotEmpty ? parsed.e164 : formatClickToCallDialPreview(phone);
  final controller = TextEditingController(text: initial);

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      final surfaceBg = isDark ? const Color(0xFF1E293B) : Colors.white;

      return StatefulBuilder(
        builder: (context, setState) {
          final currentParsed = parseCountryPhone(controller.text, countryCode);

          return AlertDialog(
            backgroundColor: surfaceBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Initiate Call',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentParsed.isDomestic
                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                        : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: currentParsed.isDomestic
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    currentParsed.countryLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: currentParsed.isDomestic
                          ? const Color(0xFF059669)
                          : const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leadName != null && leadName.trim().isNotEmpty) ...[
                    Text(
                      leadName.trim(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    'Country code and telephony gateway routing are automatically formatted.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Dial Number',
                      hintText: '+91XXXXXXXXXX',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentParsed.isDomestic
                        ? 'Indian 10-digit number will be routed via domestic gateway.'
                        : 'International number will be dialed via global trunk.',
                    style: TextStyle(
                      fontSize: 11,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: textMuted, fontWeight: FontWeight.w500),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () {
                  final dial = digitsOnlyPhone(controller.text);
                  if (dial.isEmpty) return;
                  Navigator.pop(ctx, dial);
                },
                child: const Text('Call', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}
