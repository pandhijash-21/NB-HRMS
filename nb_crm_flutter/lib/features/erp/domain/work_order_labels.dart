import 'package:flutter/material.dart';

class WorkOrderLabels {
  static String statusLabel(String code) {
    switch (code) {
      case 'ISSUED':
        return 'Issued';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'COMPLETED':
        return 'Completed';
      case 'COMPLETED_DELAYED':
        return 'Completed (Delayed)';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return code;
    }
  }

  static Color statusColor(String code) {
    switch (code) {
      case 'ISSUED':
        return const Color(0xFF1e3a5f);
      case 'IN_PROGRESS':
        return const Color(0xFFea580c);
      case 'COMPLETED':
        return const Color(0xFF166534);
      case 'COMPLETED_DELAYED':
        return const Color(0xFF65a30d);
      case 'CANCELLED':
        return const Color(0xFFf87171);
      default:
        return const Color(0xFF64748b);
    }
  }

  static String approvalLabel(String code) {
    switch (code) {
      case 'PENDING':
        return 'Pending';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'NOT_APPLICABLE':
        return 'Not Applicable';
      default:
        return code;
    }
  }

  static Color approvalColor(String code) {
    switch (code) {
      case 'PENDING':
        return const Color(0xFFca8a04);
      case 'APPROVED':
        return const Color(0xFF16a34a);
      case 'REJECTED':
        return const Color(0xFFdc2626);
      case 'NOT_APPLICABLE':
        return const Color(0xFF475569);
      default:
        return const Color(0xFF64748b);
    }
  }

  static const statusOptions = [
    'ISSUED',
    'IN_PROGRESS',
    'COMPLETED',
    'COMPLETED_DELAYED',
    'CANCELLED',
  ];

  static const approvalOptions = [
    'PENDING',
    'APPROVED',
    'REJECTED',
    'NOT_APPLICABLE',
  ];
}
