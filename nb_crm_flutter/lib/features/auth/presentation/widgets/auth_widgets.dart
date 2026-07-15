import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class InlineBanner extends StatelessWidget {
  const InlineBanner.error({super.key, required this.message})
      : _tone = _BannerTone.error;

  const InlineBanner.info({super.key, required this.message})
      : _tone = _BannerTone.info;

  final String message;
  final _BannerTone _tone;

  @override
  Widget build(BuildContext context) {
    final isError = _tone == _BannerTone.error;
    final bg = isError ? AppColors.errorSoft : AppColors.successSoft;
    final fg = isError ? AppColors.error : AppColors.success;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BannerTone { error, info }

/// Mirrors backend `ChangePasswordSchema` (Zod).
String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'New password is required';
  }
  if (value.length < 8) {
    return 'Minimum 8 characters';
  }
  if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
    return 'Must contain at least one letter';
  }
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'Must contain at least one number';
  }
  return null;
}
