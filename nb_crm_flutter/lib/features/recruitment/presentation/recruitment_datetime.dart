import 'package:flutter/material.dart';

export '../domain/recruitment_dates.dart';

Color statusColor(String code) {
  switch (code.toUpperCase()) {
    case 'INTERVIEW_SCHEDULED':
      return const Color(0xFF2563eb);
    case 'INTERVIEW_ATTENDED':
      return const Color(0xFF0891b2);
    case 'NOT_CAME':
      return const Color(0xFF78716c);
    case 'RESCHEDULED':
      return const Color(0xFFd97706);
    case 'SELECTED_FOR_NEXT_ROUND':
      return const Color(0xFF7c3aed);
    case 'FINAL_ROUND':
      return const Color(0xFF4f46e5);
    case 'SELECTED':
      return const Color(0xFF16a34a);
    case 'ON_HOLD':
      return const Color(0xFFca8a04);
    case 'REJECTED':
      return const Color(0xFFdc2626);
    case 'DROPOUT':
      return const Color(0xFF9f1239);
    default:
      return const Color(0xFF64748b);
  }
}

String statusLabel(String code) => code.replaceAll('_', ' ');
