import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cleans an incoming phone/mobile string by stripping non-digits and leading 91,
/// returning at most 10 digits suitable for a +91-prefixed field.
String cleanMobile10(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    return digits.substring(2);
  }
  if (digits.length > 10) {
    return digits.substring(digits.length - 10);
  }
  return digits;
}

/// Standard formatters for Indian 10-digit mobile numbers:
/// Digits only and strictly limited to 10 characters.
final List<TextInputFormatter> mobileInputFormatters = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(10),
];

/// Non-editable, static "+91 | " prefix for InputDecoration.
Widget buildMobilePrefix({bool isDark = false}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(width: 12),
      Text(
        '+91',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        width: 1,
        height: 18,
        color: isDark ? const Color(0xFF4A443E) : const Color(0xFFCBD5E1),
      ),
      const SizedBox(width: 8),
    ],
  );
}

/// Validator for 10-digit mobile numbers.
String? Function(String?) mobileValidator({
  bool required = false,
  String label = 'Mobile number',
}) {
  return (v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) {
      return required ? '$label is required' : null;
    }
    if (s.length != 10) {
      return '$label must be exactly 10 digits';
    }
    return null;
  };
}

/// A dedicated form field for mobile numbers with static "+91",
/// strictly numbers-only, exactly 10 digits max, and built-in validation.
class MobileNumberFormField extends StatelessWidget {
  const MobileNumberFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.label = 'Mobile No',
    this.hint = 'Enter 10-digit number',
    this.required = false,
    this.readOnly = false,
    this.onChanged,
    this.validator,
    this.decoration,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final bool required;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final InputDecoration? decoration;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseDec = decoration ??
        InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0),
            ),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF252220) : const Color(0xFFF8FAFC),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        );

    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      readOnly: readOnly,
      keyboardType: TextInputType.phone,
      inputFormatters: mobileInputFormatters,
      decoration: baseDec.copyWith(
        prefixIcon: buildMobilePrefix(isDark: isDark),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: hint,
      ),
      validator: validator ?? mobileValidator(required: required, label: label),
      onChanged: onChanged,
    );
  }
}
