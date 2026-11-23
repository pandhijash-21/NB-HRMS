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

/// Digits only (no truncation) — used for international / dial overrides.
String digitsOnlyPhone(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  return raw.replaceAll(RegExp(r'\D'), '');
}

/// Parsed country and phone structure for intelligent telephony and deduplication display
class ParsedCountryPhone {
  final String countryCode;
  final String countryLabel;
  final String nationalNumber;
  final String e164;
  final bool isDomestic;

  const ParsedCountryPhone({
    required this.countryCode,
    required this.countryLabel,
    required this.nationalNumber,
    required this.e164,
    required this.isDomestic,
  });
}

/// Parses phone string and optional country code into structured ParsedCountryPhone
ParsedCountryPhone parseCountryPhone(String? phone, [String? countryCode]) {
  final raw = (phone ?? '').trim();
  final d = digitsOnlyPhone(raw);
  var cc = digitsOnlyPhone(countryCode ?? '');
  var nat = d;

  if (cc.isNotEmpty) {
    if (nat.startsWith(cc) && nat.length > cc.length + 5) {
      nat = nat.substring(cc.length);
    }
  } else if (raw.startsWith('+') || raw.startsWith('00')) {
    final clean = raw.startsWith('00') && d.length > 2 ? d.substring(2) : d;
    const prefixes = [
      '971', '966', '974', '968', '965', '973', '852', '880', '977', '353',
      '91', '44', '61', '65', '60', '62', '66', '63', '81', '82', '86', '49',
      '33', '39', '34', '31', '32', '41', '20', '27', '64', '94', '92', '1', '7'
    ];
    for (final p in prefixes) {
      if (clean.startsWith(p) && clean.length > p.length) {
        cc = p;
        nat = clean.substring(p.length);
        break;
      }
    }
    if (cc.isEmpty) {
      cc = clean.length > 10 ? clean.substring(0, clean.length - 10) : '91';
      nat = clean.length > 10 ? clean.substring(clean.length - 10) : clean;
    }
  } else {
    if (d.length == 10) {
      cc = '91';
      nat = d;
    } else if (d.length == 11 && d.startsWith('0')) {
      cc = '91';
      nat = d.substring(1);
    } else if (d.length == 12 && d.startsWith('91')) {
      cc = '91';
      nat = d.substring(2);
    } else if (d.length == 12 && d.startsWith('971')) {
      cc = '971';
      nat = d.substring(3);
    } else if (d.length == 11 && d.startsWith('1')) {
      cc = '1';
      nat = d.substring(1);
    } else {
      cc = '91';
      nat = d.length > 10 ? d.substring(d.length - 10) : d;
    }
  }

  if (nat.startsWith('0') && nat.length >= 10) {
    nat = nat.replaceFirst(RegExp(r'^0+'), '');
  }

  String label;
  switch (cc) {
    case '91':
      label = 'India (+91)';
      break;
    case '971':
      label = 'UAE (+971)';
      break;
    case '1':
      label = 'USA / Canada (+1)';
      break;
    case '44':
      label = 'UK (+44)';
      break;
    case '65':
      label = 'Singapore (+65)';
      break;
    case '966':
      label = 'Saudi Arabia (+966)';
      break;
    case '974':
      label = 'Qatar (+974)';
      break;
    case '968':
      label = 'Oman (+968)';
      break;
    case '61':
      label = 'Australia (+61)';
      break;
    default:
      label = cc.isNotEmpty ? '+$cc' : 'India (+91)';
  }

  return ParsedCountryPhone(
    countryCode: cc.isNotEmpty ? cc : '91',
    countryLabel: label,
    nationalNumber: nat,
    e164: '+$cc$nat',
    isDomestic: cc == '91' || cc.isEmpty,
  );
}

/// Builds a click-to-call dial preview like `+919876543210`.
/// Keeps an existing `+` country code; otherwise defaults to `+91` + last 10.
String formatClickToCallDialPreview(String? phone) {
  final raw = (phone ?? '').trim().replaceAll(RegExp(r'[\s()-]'), '');
  if (raw.isEmpty) return '+91';
  if (raw.startsWith('+')) {
    final rest = digitsOnlyPhone(raw);
    return rest.isEmpty ? '+' : '+$rest';
  }
  final digits = digitsOnlyPhone(raw);
  if (digits.isEmpty) return '+91';
  if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
  if (digits.length > 10) return '+$digits';
  return '+91$digits';
}

/// Combine editable country code (`+91`) + national number for storage / dialing.
String composeInternationalPhone({
  required String countryCode,
  required String nationalNumber,
}) {
  final cc = countryCode.trim().isEmpty ? '+91' : countryCode.trim();
  final ccDigits = digitsOnlyPhone(cc);
  final national = digitsOnlyPhone(nationalNumber);
  if (national.isEmpty) return '';
  // India: keep legacy 10-digit storage for CRM matching.
  if (ccDigits == '91' || ccDigits.isEmpty) return national.length > 10 ? national.substring(national.length - 10) : national;
  return '$ccDigits$national';
}

/// Mask phone for CRM display: keep last 4 digits, e.g. `9876543210` → `******3210`.
String maskPhone(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final chars = raw.split('');
  final digitIdxs = <int>[];
  for (var i = 0; i < chars.length; i++) {
    if (RegExp(r'\d').hasMatch(chars[i])) digitIdxs.add(i);
  }
  if (digitIdxs.isEmpty) return raw;
  if (digitIdxs.length <= 4) {
    return chars.map((c) => RegExp(r'\d').hasMatch(c) ? '*' : c).join();
  }
  final keep = digitIdxs.sublist(digitIdxs.length - 4).toSet();
  return [
    for (var i = 0; i < chars.length; i++)
      (RegExp(r'\d').hasMatch(chars[i]) && !keep.contains(i)) ? '*' : chars[i],
  ].join();
}

/// Returns [raw] when [showFull] is true; otherwise [maskPhone].
String displayCrmPhone(String? raw, {required bool showFull}) {
  if (raw == null || raw.isEmpty) return '';
  return showFull ? raw : maskPhone(raw);
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
