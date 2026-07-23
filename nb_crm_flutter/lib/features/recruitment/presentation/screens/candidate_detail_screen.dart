import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../admin/domain/admin_models.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../domain/recruitment_models.dart';
import '../recruitment_datetime.dart';
import '../recruitment_providers.dart';
import '../widgets/document_viewer.dart';
import '../widgets/recruitment_widgets.dart';

class CandidateDetailScreen extends ConsumerWidget {
  const CandidateDetailScreen({super.key, required this.candidateId});

  final String candidateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final canAdmin = Permissions.canWriteRecruitment(auth.permissions, auth.user?.role);
    final async = ref.watch(candidateDetailProvider(candidateId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidate'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/recruitment'),
        ),
        actions: [
          if (canAdmin)
            IconButton(
              tooltip: 'Edit candidate',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                final c = ref.read(candidateDetailProvider(candidateId)).asData?.value;
                if (c != null) _editCandidate(context, ref, c);
              },
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed: $e')),
        data: (c) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      c.fullName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (canAdmin)
                    TextButton.icon(
                      onPressed: () => _editCandidate(context, ref, c),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(c.contactNumber),
              Text('Source: ${c.sourceCode}'),
              Row(
                children: [
                  const Text('Status: '),
                  statusChip(c.currentStatusCode),
                ],
              ),
              Text('Job: ${c.requirement?.title ?? c.requirementId}'),
              if (c.resumeReceivedDate != null)
                Text('Resume received: ${fmtIstDate(c.resumeReceivedDate)}'),
              const SizedBox(height: 10),
              resumeAttachmentTile(
                context: context,
                ref: ref,
                url: c.resumeUrl,
                fileName: c.resumeFileName,
              ),
              if (c.hiredEmployeeId != null) ...[
                const SizedBox(height: 12),
                const Text('Hire details', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                if (c.offeredSalary != null)
                  Text('Offered salary: ${c.offeredSalary!.toStringAsFixed(0)}'),
                if (c.expectedJoiningDate != null)
                  Text('Expected joining: ${fmtIstDate(c.expectedJoiningDate)}'),
                if (c.actualJoiningDate != null)
                  Text('Actual joining: ${fmtIstDate(c.actualJoiningDate)}'),
                if ((c.hireRemarks ?? '').trim().isNotEmpty)
                  Text('Hire remarks: ${c.hireRemarks!.trim()}'),
                const SizedBox(height: 4),
                Text('Hired employee #${c.hiredEmployeeId} (${c.hiredEmployeeCode ?? ''})'),
              ],
              const SizedBox(height: 16),
              const Text('Interview history', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (c.rounds.isEmpty) const Text('No rounds yet.'),
              ...c.rounds.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InterviewRoundCard(
                    round: r,
                    onUpdateStatus: canAdmin
                        ? () => _updateRound(context, ref, c, r)
                        : null,
                    onConfirm: canAdmin && r.awaitsAdminConfirm
                        ? () => _confirmRound(context, ref, c, r)
                        : null,
                  ),
                ),
              ),
              if (canAdmin) ...[
                const SizedBox(height: 8),
                if (c.canScheduleNext)
                  FilledButton.icon(
                    onPressed: () => _scheduleNext(context, ref, c),
                    icon: const Icon(Icons.event),
                    label: const Text('Schedule next round'),
                  ),
                if (c.canHire) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _hire(context, ref, c),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Hire to workforce'),
                  ),
                ],
                if (c.hiredEmployeeId != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/admin/employees/${c.hiredEmployeeId}'),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open employee profile'),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editCandidate(
    BuildContext context,
    WidgetRef ref,
    RecruitmentCandidate c,
  ) async {
    final name = TextEditingController(text: c.fullName);
    final contact = TextEditingController(text: c.contactNumber);
    String? source = c.sourceCode;
    DateTime? resumeDate = c.resumeReceivedDate;
    String? resumeUrl = c.resumeUrl;
    String? resumeFileName = c.resumeFileName;
    var uploading = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Edit candidate',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contact,
                      decoration: const InputDecoration(
                        labelText: 'Contact number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Consumer(
                      builder: (ctx, dialogRef, _) => lookupDropdown(
                        ref: dialogRef,
                        category: 'CANDIDATE_SOURCE',
                        label: 'Source',
                        value: source,
                        required: true,
                        onChanged: (v) => setLocal(() => source = v),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Resume received: ${resumeDate != null ? fmtIstDate(resumeDate) : 'Not set'}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: resumeDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setLocal(() => resumeDate = d);
                      },
                    ),
                    Text(
                      resumeFileName?.isNotEmpty == true
                          ? 'File: $resumeFileName'
                          : 'No resume file',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: uploading
                          ? null
                          : () async {
                              setLocal(() => uploading = true);
                              try {
                                final result = await _pickAndUploadResume(ref);
                                if (result != null) {
                                  setLocal(() {
                                    resumeUrl = result.url;
                                    resumeFileName = result.fileName;
                                  });
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) setLocal(() => uploading = false);
                              }
                            },
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        uploading
                            ? 'Uploading…'
                            : (resumeUrl == null || resumeUrl!.isEmpty)
                                ? 'Upload resume'
                                : 'Replace resume',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save changes'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty || contact.text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and contact are required')),
        );
      }
      return;
    }
    try {
      await ref.read(recruitmentRepositoryProvider).updateCandidate(c.id, {
        'fullName': name.text.trim(),
        'contactNumber': contact.text.trim(),
        'sourceCode': source,
        'resumeReceivedDate': resumeDate != null ? toDateOnly(resumeDate!) : null,
        'resumeUrl': resumeUrl,
        'resumeFileName': resumeFileName,
      });
      ref.invalidate(candidateDetailProvider(c.id));
      ref.invalidate(candidatesProvider(null));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Candidate updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirmRound(
    BuildContext context,
    WidgetRef ref,
    RecruitmentCandidate c,
    InterviewRound r,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm interview outcome'),
        content: Text(
          'Confirm Round ${r.roundNumber} status “${r.statusCode}”?\n\n'
          'After confirmation the interviewer can still see details but cannot change them.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(recruitmentRepositoryProvider).confirmRound(r.id);
      ref.invalidate(candidateDetailProvider(c.id));
      ref.invalidate(candidatesProvider(null));
      ref.invalidate(myInterviewsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Outcome confirmed — interviewer locked')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _updateRound(
    BuildContext context,
    WidgetRef ref,
    RecruitmentCandidate c,
    InterviewRound r,
  ) async {
    try {
      final ok = await showInterviewStatusDialog(
        context: context,
        ref: ref,
        candidateName: c.fullName,
        roundId: r.id,
        initialStatus: r.statusCode,
        resumeUrl: c.resumeUrl,
        resumeFileName: c.resumeFileName,
        history: c.rounds,
      );
      if (ok) {
        ref.invalidate(candidateDetailProvider(c.id));
        ref.invalidate(candidatesProvider(null));
        ref.invalidate(myInterviewsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status updated')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _scheduleNext(
    BuildContext context,
    WidgetRef ref,
    RecruitmentCandidate c,
  ) async {
    String? interviewType;
    String? interviewerUserId;
    DateTime? scheduledAt;
    final remarks = TextEditingController();

    // Start loading interviewers before the dialog opens.
    ref.read(employeeNamesProvider.future);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, dialogRef, _) {
          final namesAsync = dialogRef.watch(employeeNamesProvider);
          final names = namesAsync.asData?.value ?? const <EmployeeNameOption>[];
          final interviewerItems = names
              .where((n) => n.userId.isNotEmpty)
              .map((n) => DropdownMenuItem(value: n.userId, child: Text(n.displayLabel)))
              .toList();

          return StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
              title: const Text('Schedule next round'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    lookupDropdown(
                      ref: dialogRef,
                      category: 'INTERVIEW_TYPE',
                      label: 'Interview type',
                      value: interviewType,
                      required: true,
                      onChanged: (v) => setLocal(() => interviewType = v),
                    ),
                    const SizedBox(height: 10),
                    if (namesAsync.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Loading interviewers…'),
                          ],
                        ),
                      )
                    else if (namesAsync.hasError)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Could not load interviewers: ${namesAsync.error}',
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      )
                    else if (interviewerItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No interviewers available. Ensure employees have user accounts.',
                          style: TextStyle(fontSize: 13),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: interviewerUserId,
                        decoration: const InputDecoration(
                          labelText: 'Interviewer',
                          border: OutlineInputBorder(),
                        ),
                        items: interviewerItems,
                        onChanged: (v) => setLocal(() => interviewerUserId = v),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        scheduledAt == null
                            ? 'Pick schedule (IST)'
                            : fmtIstDateTime(scheduledAt),
                      ),
                      trailing: const Icon(Icons.event),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d == null) return;
                        if (!ctx.mounted) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t == null) return;
                        setLocal(() {
                          scheduledAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                        });
                      },
                    ),
                    TextField(
                      controller: remarks,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Schedule notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Schedule')),
              ],
            ),
          );
        },
      ),
    );
    if (ok != true) return;
    if ((interviewType ?? '').isEmpty || (interviewerUserId ?? '').isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interview type and interviewer are required')),
        );
      }
      return;
    }
    try {
      await ref.read(recruitmentRepositoryProvider).scheduleNextRound(c.id, {
        'interviewTypeCode': interviewType,
        'interviewerUserId': interviewerUserId,
        'scheduledAt': scheduledAt != null ? toApiDateTimeFromIst(scheduledAt!) : null,
        'remarks': remarks.text.trim(),
        'statusCode': 'INTERVIEW_SCHEDULED',
      });
      ref.invalidate(candidateDetailProvider(c.id));
      ref.invalidate(candidatesProvider(null));
      ref.invalidate(myInterviewsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Next round scheduled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _hire(
    BuildContext context,
    WidgetRef ref,
    RecruitmentCandidate c,
  ) async {
    final code = TextEditingController();
    final salary = TextEditingController();
    final remarks = TextEditingController();
    final email = TextEditingController();
    DateTime? expected = DateTime.now().add(const Duration(days: 15));
    DateTime? actual;
    DateTime? birthDate;

    String dobPasswordHint(DateTime d) {
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      return '$dd$mm${d.year}';
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setLocal) => Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hire ${c.fullName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Creates a workforce employee with login password from birth date (DDMMYYYY).',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Employee code *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      birthDate == null
                          ? 'Birth date * (login password)'
                          : 'Birth date *: ${fmtIstDate(birthDate)} → ${dobPasswordHint(birthDate!)}',
                    ),
                    subtitle: const Text(
                      'Temporary password is DDMMYYYY from this date (e.g. 15 Mar 1998 → 15031998).',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.cake_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: birthDate ?? DateTime(1995, 1, 1),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setLocal(() => birthDate = d);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: salary,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Offered salary',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: 'Personal email (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Expected joining: ${expected != null ? fmtIstDate(expected) : 'Not set'}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: expected ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (d != null) setLocal(() => expected = d);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Actual joining: ${actual != null ? fmtIstDate(actual) : 'Not set'}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: actual ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (d != null) setLocal(() => actual = d);
                    },
                  ),
                  TextField(
                    controller: remarks,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Hire remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Create employee'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (ok != true) return;
    if (code.text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee code is required')),
        );
      }
      return;
    }
    if (birthDate == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Birth date is required for login credentials')),
        );
      }
      return;
    }
    try {
      final result = await ref.read(recruitmentRepositoryProvider).hireCandidate(c.id, {
        'employeeCode': code.text.trim(),
        'birthDate': toDateOnly(birthDate!),
        'offeredSalary': salary.text.trim().isEmpty ? null : salary.text.trim(),
        'expectedJoiningDate': expected != null ? toDateOnly(expected!) : null,
        'actualJoiningDate': actual != null ? toDateOnly(actual!) : null,
        'hireRemarks': remarks.text.trim(),
        'personalEmail': email.text.trim().isEmpty ? null : email.text.trim(),
      });
      ref.invalidate(candidateDetailProvider(c.id));
      ref.invalidate(candidatesProvider(null));
      ref.invalidate(workforceListProvider);
      ref.invalidate(employeeNamesProvider);

      final emp = result['employee'];
      final empId = emp is Map ? emp['id'] : null;
      final initialPassword =
          emp is Map ? emp['initialPassword']?.toString() : null;
      if (context.mounted) {
        final pwdMsg = (initialPassword != null && initialPassword.isNotEmpty)
            ? ' Login: employee code + password $initialPassword (DOB).'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 14),
            content: Text(
              'Added to workforce.$pwdMsg Open profile to complete org & letters.',
            ),
          ),
        );
        if (empId != null) {
          context.go('/admin/employees/$empId');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<({String url, String fileName})?> _pickAndUploadResume(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    final url = await ref.read(recruitmentRepositoryProvider).uploadResume(
          bytes: bytes,
          filename: file.name,
        );
    return (url: url, fileName: file.name);
  }
}
