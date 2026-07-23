import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/presentation/admin_notifier.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../domain/recruitment_models.dart';
import '../recruitment_datetime.dart';
import '../recruitment_providers.dart';
import 'document_viewer.dart';

Future<void> openResume(
  BuildContext context,
  WidgetRef ref,
  String? url, {
  String? fileName,
}) async {
  if (url == null || url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No resume uploaded')),
    );
    return;
  }
  await openResumeLikeProfileDocs(
    context,
    ref,
    url: url,
    fileName: fileName,
  );
}

String resolveInterviewerLabel(WidgetRef ref, InterviewRound round) {
  final fromApi = round.interviewerName?.trim();
  if (fromApi != null &&
      fromApi.isNotEmpty &&
      fromApi != round.interviewerUserId) {
    return fromApi;
  }
  final names = ref.watch(employeeNamesProvider).asData?.value;
  if (names != null) {
    for (final n in names) {
      if (n.userId == round.interviewerUserId && n.fullName.isNotEmpty) {
        return n.displayLabel;
      }
    }
  }
  return fromApi?.isNotEmpty == true ? fromApi! : 'Interviewer';
}

Widget statusStripe(String statusCode) {
  final c = statusColor(statusCode);
  return Container(
    width: 6,
    decoration: BoxDecoration(
      color: c,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
    ),
  );
}

Widget statusChip(String statusCode) {
  final c = statusColor(statusCode);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: c.withValues(alpha: 0.45)),
    ),
    child: Text(
      statusLabel(statusCode),
      style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11),
    ),
  );
}

class InterviewRoundCard extends ConsumerWidget {
  const InterviewRoundCard({
    super.key,
    required this.round,
    this.onUpdateStatus,
    this.onConfirm,
  });

  final InterviewRound round;
  final VoidCallback? onUpdateStatus;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ist = round.scheduledAt != null
        ? parseApiDateTimeIst(round.scheduledAt!.toIso8601String())
        : null;
    final interviewer = resolveInterviewerLabel(ref, round);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            statusStripe(round.statusCode),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Round ${round.roundNumber} · ${round.interviewTypeCode}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        statusChip(round.statusCode),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Interviewer: $interviewer'),
                    if (ist != null) Text('Scheduled: ${fmtIstDateTime(ist)}'),
                    if ((round.remarks ?? '').isNotEmpty)
                      Text('Remarks: ${round.remarks}'),
                    if (round.isLocked) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Confirmed by Admin — interviewer view only',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ] else if (round.awaitsAdminConfirm) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Awaiting Admin confirmation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                    if (onUpdateStatus != null || onConfirm != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (onUpdateStatus != null)
                            TextButton.icon(
                              onPressed: onUpdateStatus,
                              icon: const Icon(Icons.edit_note, size: 18),
                              label: const Text('Update status'),
                            ),
                          if (onConfirm != null)
                            FilledButton.tonalIcon(
                              onPressed: onConfirm,
                              icon: const Icon(Icons.verified_outlined, size: 18),
                              label: const Text('Confirm outcome'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interviewer/admin status update. Remarks start blank (new feedback).
Future<bool> showInterviewStatusDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String candidateName,
  required String roundId,
  String initialStatus = 'INTERVIEW_SCHEDULED',
  String? resumeUrl,
  String? resumeFileName,
  List<InterviewRound> history = const [],
}) async {
  String status = initialStatus.isNotEmpty ? initialStatus : 'INTERVIEW_SCHEDULED';
  final remarks = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (ctx, dialogRef, _) {
        return AlertDialog(
          title: Text('Update — $candidateName'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (resumeUrl != null && resumeUrl.isNotEmpty)
                    resumeAttachmentTile(
                      context: ctx,
                      ref: dialogRef,
                      url: resumeUrl,
                      fileName: resumeFileName,
                    ),
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Interview history',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    ...history.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'R${r.roundNumber} · ${r.interviewTypeCode} · '
                          '${resolveInterviewerLabel(dialogRef, r)} · ${statusLabel(r.statusCode)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const Divider(),
                  ],
                  lookupDropdown(
                    ref: dialogRef,
                    category: 'INTERVIEW_STATUS',
                    label: 'Status',
                    value: status,
                    required: true,
                    onChanged: (v) => status = v,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: remarks,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Your remarks (new)',
                      hintText: 'Enter interview feedback',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        );
      },
    ),
  );

  if (ok != true) return false;
  if (status.isEmpty) status = 'INTERVIEW_SCHEDULED';

  await ref.read(recruitmentRepositoryProvider).updateRoundStatus(
        roundId,
        statusCode: status,
        remarks: remarks.text.trim(),
      );
  return true;
}
