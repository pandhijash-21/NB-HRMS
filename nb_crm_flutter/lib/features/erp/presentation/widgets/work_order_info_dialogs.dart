import 'package:flutter/material.dart';

import '../../domain/work_order_labels.dart';

void showWorkOrderStatusInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Status Information'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow(
              label: 'Issued',
              color: WorkOrderLabels.statusColor('ISSUED'),
              text:
                  'Default status when a work order is created and shared with the contractor.',
            ),
            _InfoRow(
              label: 'In Progress',
              color: WorkOrderLabels.statusColor('IN_PROGRESS'),
              text: 'Execution has started on-site.',
            ),
            _InfoRow(
              label: 'Completed',
              color: WorkOrderLabels.statusColor('COMPLETED'),
              text: 'All work in scope completed within the planned schedule.',
            ),
            _InfoRow(
              label: 'Completed (Delayed)',
              color: WorkOrderLabels.statusColor('COMPLETED_DELAYED'),
              text: 'Work completed but exceeded the planned timeline.',
            ),
            _InfoRow(
              label: 'Cancelled',
              color: WorkOrderLabels.statusColor('CANCELLED'),
              text: 'Work order terminated before completion.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}

void showWorkOrderApprovalInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Approval Information'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow(
              label: 'Pending',
              color: WorkOrderLabels.approvalColor('PENDING'),
              text: 'Submitted and awaiting review from the assigned approver.',
            ),
            _InfoRow(
              label: 'Approved',
              color: WorkOrderLabels.approvalColor('APPROVED'),
              text: 'Reviewed and accepted. Work can proceed.',
            ),
            _InfoRow(
              label: 'Rejected',
              color: WorkOrderLabels.approvalColor('REJECTED'),
              text: 'Not approved. Revise or discard based on feedback.',
            ),
            _InfoRow(
              label: 'Not Applicable',
              color: WorkOrderLabels.approvalColor('NOT_APPLICABLE'),
              text: 'No approval required for this record.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.color, required this.text});

  final String label;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF93c5fd), style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(text, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class WoStatusBadge extends StatelessWidget {
  const WoStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: WorkOrderLabels.statusColor(status),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        WorkOrderLabels.statusLabel(status),
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class WoApprovalBadge extends StatelessWidget {
  const WoApprovalBadge({super.key, required this.approvalStatus});

  final String approvalStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: WorkOrderLabels.approvalColor(approvalStatus),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        WorkOrderLabels.approvalLabel(approvalStatus),
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
