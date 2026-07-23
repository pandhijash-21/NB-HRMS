import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../admin/domain/admin_models.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../../org/domain/org_models.dart';
import '../../../org/presentation/org_providers.dart';
import '../../domain/recruitment_models.dart';
import '../recruitment_providers.dart';
import '../recruitment_datetime.dart';
import '../widgets/document_viewer.dart';
import '../widgets/recruitment_widgets.dart';

String _fmtDate(DateTime d) => fmtIstDate(d);

/// Wall-clock IST (from date/time pickers) — do not re-offset.
String _fmtPickedDateTime(DateTime d) => fmtIstDateTime(d);

class RecruitmentHubScreen extends ConsumerStatefulWidget {
  const RecruitmentHubScreen({super.key});

  @override
  ConsumerState<RecruitmentHubScreen> createState() => _RecruitmentHubScreenState();
}

class _RecruitmentHubScreenState extends ConsumerState<RecruitmentHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authNotifierProvider);
    final canAdmin = Permissions.canWriteRecruitment(auth.permissions, auth.user?.role);
    _tabs = TabController(length: canAdmin ? 4 : 2, vsync: this);
    _tabs.addListener(() {
      // Only rebuild when the selected tab settles — animating ticks were
      // restarting autoDispose FutureProviders and leaving tabs spinning.
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(vacanciesProvider);
    ref.invalidate(adminRequirementsProvider);
    ref.invalidate(candidatesProvider(null));
    ref.invalidate(myInterviewsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final canAdmin = Permissions.canWriteRecruitment(auth.permissions, auth.user?.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recruitment'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Vacancies'),
            const Tab(text: 'My interviews'),
            if (canAdmin) const Tab(text: 'Requirements'),
            if (canAdmin) const Tab(text: 'Candidates'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _VacanciesTab(onOpen: (r) => _showVacancyDetail(r)),
          _MyInterviewsTab(),
          if (canAdmin) _RequirementsTab(onEdit: (r) => _openRequirementForm(existing: r)),
          if (canAdmin) _CandidatesTab(
            onAdd: () => _openCandidateForm(),
            onOpen: (c) => context.push('/recruitment/candidates/${c.id}'),
          ),
        ],
      ),
      floatingActionButton: canAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                if (_tabs.index == 3) {
                  _openCandidateForm();
                } else {
                  _openRequirementForm();
                }
              },
              backgroundColor: AppColors.bronze,
              icon: const Icon(Icons.add),
              label: Text(_tabs.index == 3 ? 'Add candidate' : 'Add requirement'),
            )
          : null,
    );
  }

  Future<void> _showVacancyDetail(JobRequirement r) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('${r.instituteName ?? ''} · ${r.department}'),
            Text('${r.jobLocation} / ${r.branchLocation}'),
            Text('Vacancies: ${r.vacancies} · ${r.employmentTypeCode}'),
            if (r.ctc != null) Text('CTC: ${r.ctc}'),
            if ((r.requiredEducation ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Education: ${r.requiredEducation}'),
            ],
            if ((r.requiredExperience ?? '').isNotEmpty) Text('Experience: ${r.requiredExperience}'),
            if ((r.requiredSkills ?? '').isNotEmpty) Text('Skills: ${r.requiredSkills}'),
          ],
        ),
      ),
    );
  }

  Future<void> _openRequirementForm({JobRequirement? existing}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RequirementFormSheet(existing: existing),
    );
    if (ok == true) _refresh();
  }

  Future<void> _openCandidateForm() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _CandidateFormSheet(),
    );
    if (ok == true) _refresh();
  }
}

class _VacanciesTab extends ConsumerStatefulWidget {
  const _VacanciesTab({required this.onOpen});
  final void Function(JobRequirement) onOpen;

  @override
  ConsumerState<_VacanciesTab> createState() => _VacanciesTabState();
}

class _VacanciesTabState extends ConsumerState<_VacanciesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(vacanciesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No open vacancies right now.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = rows[i];
            return Card(
              child: ListTile(
                title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${r.instituteName ?? ''} · ${r.department}\n'
                  '${r.jobLocation} · ${r.vacancies} opening(s)',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onOpen(r),
              ),
            );
          },
        );
      },
    );
  }
}

class _MyInterviewsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MyInterviewsTab> createState() => _MyInterviewsTabState();
}

class _MyInterviewsTabState extends ConsumerState<_MyInterviewsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(myInterviewsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 48,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No interviews assigned to you',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'When Admin schedules you as interviewer, they show up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: rows.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == 0) {
              final actionable = rows.where((e) => e.canUpdate).length;
              final locked = rows.length - actionable;
              return Text(
                '$actionable actionable · $locked confirmed (view only)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              );
            }
            final item = rows[i - 1];
            final c = item.candidate;
            final r = item.round;
            final canUpdate = item.canUpdate && r.canInterviewerUpdate;
            final ist = r.scheduledAt != null
                ? parseApiDateTimeIst(r.scheduledAt!.toIso8601String())
                : null;
            final color = statusColor(r.statusCode);

            return Material(
              color: isDark ? const Color(0xFF1E1B18) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: canUpdate ? () => _updateStatus(context, ref, item) : null,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? color.withValues(alpha: 0.35)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 5,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(14),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.fullName,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            c.contactNumber,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.white54
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    statusChip(r.statusCode),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _MetaRow(
                                  icon: Icons.work_outline,
                                  text:
                                      '${c.requirement?.title ?? 'Role'} · Round ${r.roundNumber} · ${r.interviewTypeCode}',
                                ),
                                if (ist != null) ...[
                                  const SizedBox(height: 6),
                                  _MetaRow(
                                    icon: Icons.schedule,
                                    text: fmtIstDateTime(ist),
                                  ),
                                ],
                                if (c.rounds.length > 1) ...[
                                  const SizedBox(height: 6),
                                  _MetaRow(
                                    icon: Icons.history,
                                    text:
                                        '${c.rounds.length} rounds in history',
                                  ),
                                ],
                                if (r.isLocked) ...[
                                  const SizedBox(height: 6),
                                  _MetaRow(
                                    icon: Icons.lock_outline,
                                    text: 'Confirmed by Admin — view only',
                                  ),
                                ] else if (r.awaitsAdminConfirm) ...[
                                  const SizedBox(height: 6),
                                  _MetaRow(
                                    icon: Icons.hourglass_top,
                                    text: 'Awaiting Admin confirmation',
                                  ),
                                ],
                                if ((r.remarks ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  _MetaRow(
                                    icon: Icons.notes,
                                    text: r.remarks!,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if ((c.resumeUrl ?? '').isNotEmpty)
                                      OutlinedButton.icon(
                                        onPressed: () => openResumeLikeProfileDocs(
                                          context,
                                          ref,
                                          url: c.resumeUrl!,
                                          fileName: c.resumeFileName,
                                        ),
                                        icon: const Icon(Icons.attach_file, size: 18),
                                        label: Text(
                                          (c.resumeFileName?.isNotEmpty == true)
                                              ? c.resumeFileName!
                                              : 'View attachment',
                                        ),
                                      ),
                                    const Spacer(),
                                    if (canUpdate)
                                      FilledButton.tonalIcon(
                                        onPressed: () =>
                                            _updateStatus(context, ref, item),
                                        icon: const Icon(Icons.edit_note, size: 18),
                                        label: const Text('Update'),
                                      )
                                    else
                                      Text(
                                        'View only',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white38
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    MyInterviewItem item,
  ) async {
    if (!item.canUpdate || item.round.isLocked) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This round is confirmed by Admin — view only'),
          ),
        );
      }
      return;
    }
    try {
      final ok = await showInterviewStatusDialog(
        context: context,
        ref: ref,
        candidateName: item.candidate.fullName,
        roundId: item.round.id,
        initialStatus: item.round.statusCode.isNotEmpty
            ? item.round.statusCode
            : 'INTERVIEW_SCHEDULED',
        resumeUrl: item.candidate.resumeUrl,
        resumeFileName: item.candidate.resumeFileName,
        history: item.candidate.rounds,
      );
      if (ok) {
        ref.invalidate(myInterviewsProvider);
        ref.invalidate(candidatesProvider(null));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status updated — Admin notified')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequirementsTab extends ConsumerStatefulWidget {
  const _RequirementsTab({required this.onEdit});
  final void Function(JobRequirement) onEdit;

  @override
  ConsumerState<_RequirementsTab> createState() => _RequirementsTabState();
}

class _RequirementsTabState extends ConsumerState<_RequirementsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(adminRequirementsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed: $e\n\nIf this mentions RECRUITMENT permission, log out and log back in after seeding.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No requirements yet. Tap + to add one.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = rows[i];
            return Card(
              child: ListTile(
                title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${r.instituteName ?? ''} · ${r.department}\n'
                  '${r.isActive ? 'Active' : 'Inactive'} · ${r.vacancies} opening(s) · '
                  '${r.candidateCount} candidate(s)',
                ),
                isThreeLine: true,
                trailing: Switch(
                  value: r.isActive,
                  onChanged: (v) async {
                    try {
                      await ref.read(recruitmentRepositoryProvider).setActive(r.id, v);
                      ref.invalidate(adminRequirementsProvider);
                      ref.invalidate(vacanciesProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                ),
                onTap: () => widget.onEdit(r),
              ),
            );
          },
        );
      },
    );
  }
}

class _CandidatesTab extends ConsumerStatefulWidget {
  const _CandidatesTab({required this.onAdd, required this.onOpen});
  final VoidCallback onAdd;
  final void Function(RecruitmentCandidate) onOpen;

  @override
  ConsumerState<_CandidatesTab> createState() => _CandidatesTabState();
}

class _CandidatesTabState extends ConsumerState<_CandidatesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(candidatesProvider(null));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No candidates yet.'),
                const SizedBox(height: 8),
                TextButton(onPressed: widget.onAdd, child: const Text('Add candidate')),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = rows[i];
            return Card(
              child: ListTile(
                title: Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${c.requirement?.title ?? ''} · ${c.currentStatusCode}\n'
                  '${c.contactNumber}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onOpen(c),
              ),
            );
          },
        );
      },
    );
  }
}

class _RequirementFormSheet extends ConsumerStatefulWidget {
  const _RequirementFormSheet({this.existing});
  final JobRequirement? existing;

  @override
  ConsumerState<_RequirementFormSheet> createState() => _RequirementFormSheetState();
}

class _RequirementFormSheetState extends ConsumerState<_RequirementFormSheet> {
  final _dept = TextEditingController();
  final _jobLoc = TextEditingController();
  final _branch = TextEditingController();
  final _vacancies = TextEditingController(text: '1');
  final _ctc = TextEditingController();
  final _edu = TextEditingController();
  final _exp = TextEditingController();
  final _skills = TextEditingController();
  String? _instituteId;
  String? _designationId;
  String? _employmentType;
  String? _managerUserId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _dept.text = e.department;
      _jobLoc.text = e.jobLocation;
      _branch.text = e.branchLocation;
      _vacancies.text = '${e.vacancies}';
      _ctc.text = e.ctc?.toString() ?? '';
      _edu.text = e.requiredEducation ?? '';
      _exp.text = e.requiredExperience ?? '';
      _skills.text = e.requiredSkills ?? '';
      _instituteId = e.instituteId;
      _designationId = e.designationId;
      _employmentType = e.employmentTypeCode;
      _managerUserId = e.reportingManagerUserId;
    }
  }

  @override
  void dispose() {
    _dept.dispose();
    _jobLoc.dispose();
    _branch.dispose();
    _vacancies.dispose();
    _ctc.dispose();
    _edu.dispose();
    _exp.dispose();
    _skills.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final institutes = ref.watch(activeInstitutesProvider).asData?.value ?? const <Institute>[];
    final designations =
        (ref.watch(jobDesignationsProvider).asData?.value ?? const <Designation>[])
            .where((d) => d.isActive)
            .toList();
    final names = ref.watch(employeeNamesProvider).asData?.value ?? const <EmployeeNameOption>[];
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'New job requirement' : 'Edit requirement',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _instituteId,
              decoration: const InputDecoration(labelText: 'Institute', border: OutlineInputBorder()),
              items: institutes
                  .map((i) => DropdownMenuItem(value: i.id, child: Text(i.name)))
                  .toList(),
              onChanged: (v) => setState(() => _instituteId = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _dept,
              decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _designationId,
              decoration: const InputDecoration(
                labelText: 'Designation',
                border: OutlineInputBorder(),
                helperText: 'Must exist under Designations config',
              ),
              items: designations
                  .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                  .toList(),
              onChanged: (v) => setState(() => _designationId = v),
            ),
            const SizedBox(height: 10),
            lookupDropdown(
              ref: ref,
              category: 'APPOINTMENT_TYPE',
              label: 'Appointment type',
              value: _employmentType,
              required: true,
              onChanged: (v) => setState(() => _employmentType = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _jobLoc,
              decoration: const InputDecoration(labelText: 'Job location', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _branch,
              decoration: const InputDecoration(labelText: 'Branch location', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vacancies,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Vacancies', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              value: _managerUserId,
              decoration: const InputDecoration(
                labelText: 'Reporting manager',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Not set')),
                ...names
                    .where((n) => n.userId.isNotEmpty)
                    .map((n) => DropdownMenuItem(value: n.userId, child: Text(n.displayLabel))),
              ],
              onChanged: (v) => setState(() => _managerUserId = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctc,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'CTC (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _edu,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Required education',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _exp,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Required experience',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _skills,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Required skills',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    // Lookup dropdowns can show a default label before async options notify
    // the parent; resolve appointment type from active lookups if needed.
    var employmentType = _employmentType;
    if (employmentType == null || employmentType.isEmpty) {
      final opts = resolveLookupOptions(ref, 'APPOINTMENT_TYPE');
      if (opts.isNotEmpty) employmentType = opts.first.code;
    }

    if (_instituteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an institute')),
      );
      return;
    }
    if (_designationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a designation')),
      );
      return;
    }
    if (employmentType == null || employmentType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an appointment type')),
      );
      return;
    }
    if (_dept.text.trim().isEmpty ||
        _jobLoc.text.trim().isEmpty ||
        _branch.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill department, job location, and branch')),
      );
      return;
    }
    setState(() {
      _saving = true;
      _employmentType = employmentType;
    });
    final body = {
      'instituteId': _instituteId,
      'department': _dept.text.trim(),
      'designationId': _designationId,
      'employmentTypeCode': employmentType,
      'jobLocation': _jobLoc.text.trim(),
      'branchLocation': _branch.text.trim(),
      'vacancies': int.tryParse(_vacancies.text.trim()) ?? 1,
      'reportingManagerUserId': _managerUserId,
      'ctc': _ctc.text.trim().isEmpty ? null : _ctc.text.trim(),
      'requiredEducation': _edu.text.trim(),
      'requiredExperience': _exp.text.trim(),
      'requiredSkills': _skills.text.trim(),
    };
    try {
      final repo = ref.read(recruitmentRepositoryProvider);
      if (widget.existing == null) {
        await repo.createRequirement(body);
      } else {
        await repo.updateRequirement(widget.existing!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CandidateFormSheet extends ConsumerStatefulWidget {
  const _CandidateFormSheet();

  @override
  ConsumerState<_CandidateFormSheet> createState() => _CandidateFormSheetState();
}

class _CandidateFormSheetState extends ConsumerState<_CandidateFormSheet> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _remarks = TextEditingController();
  String? _requirementId;
  String? _source;
  String? _interviewType;
  String? _interviewerUserId;
  DateTime? _resumeDate = DateTime.now();
  DateTime? _scheduledAt;
  String? _resumeUrl;
  String? _resumeFileName;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _remarks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final openJobs = (ref.watch(adminRequirementsProvider).asData?.value ?? const <JobRequirement>[])
        .where((r) => r.isActive)
        .toList();
    final names = ref.watch(employeeNamesProvider).asData?.value ?? const <EmployeeNameOption>[];
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add candidate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _requirementId,
              decoration: const InputDecoration(
                labelText: 'Open job requirement',
                border: OutlineInputBorder(),
              ),
              items: openJobs
                  .map(
                    (j) => DropdownMenuItem(
                      value: j.id,
                      child: Text('${j.title} · ${j.instituteName ?? ''}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _requirementId = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contact,
              decoration: const InputDecoration(labelText: 'Contact number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            lookupDropdown(
              ref: ref,
              category: 'CANDIDATE_SOURCE',
              label: 'Source',
              value: _source,
              required: true,
              onChanged: (v) => setState(() => _source = v),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Resume received: ${_resumeDate != null ? _fmtDate(_resumeDate!) : 'Not set'}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _resumeDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _resumeDate = d);
              },
            ),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickResume,
              icon: const Icon(Icons.upload_file),
              label: Text(_uploading
                  ? 'Uploading…'
                  : (_resumeFileName?.isNotEmpty == true
                      ? _resumeFileName!
                      : 'Upload resume (optional)')),
            ),
            if (_resumeFileName != null && _resumeUrl != null) ...[
              const SizedBox(height: 8),
              Text(
                'Attached: $_resumeFileName',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 10),
            lookupDropdown(
              ref: ref,
              category: 'INTERVIEW_TYPE',
              label: 'Interview type',
              value: _interviewType,
              required: true,
              onChanged: (v) => setState(() => _interviewType = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _interviewerUserId,
              decoration: const InputDecoration(
                labelText: 'Interviewer',
                border: OutlineInputBorder(),
              ),
              items: names
                  .where((n) => n.userId.isNotEmpty)
                  .map((n) => DropdownMenuItem(value: n.userId, child: Text(n.displayLabel)))
                  .toList(),
              onChanged: (v) => setState(() => _interviewerUserId = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Scheduled: ${_scheduledAt != null ? _fmtPickedDateTime(_scheduledAt!) : 'Not set'}',
              ),
              trailing: const Icon(Icons.event),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _scheduledAt ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d == null || !context.mounted) return;
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? DateTime.now()),
                );
                if (t == null) return;
                setState(() {
                  _scheduledAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                });
              },
            ),
            TextField(
              controller: _remarks,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Add candidate'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(recruitmentRepositoryProvider).uploadResume(
            bytes: bytes,
            filename: file.name,
          );
      setState(() {
        _resumeUrl = url;
        _resumeFileName = file.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_requirementId == null ||
        _name.text.trim().isEmpty ||
        _contact.text.trim().isEmpty ||
        (_source ?? '').isEmpty ||
        (_interviewType ?? '').isEmpty ||
        (_interviewerUserId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill required fields')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(recruitmentRepositoryProvider).createCandidate({
        'requirementId': _requirementId,
        'fullName': _name.text.trim(),
        'contactNumber': _contact.text.trim(),
        'sourceCode': _source,
        'resumeReceivedDate': _resumeDate != null ? toDateOnly(_resumeDate!) : null,
        'resumeUrl': _resumeUrl,
        'resumeFileName': _resumeFileName,
        'interviewTypeCode': _interviewType,
        'interviewerUserId': _interviewerUserId,
        'scheduledAt': _scheduledAt != null ? toApiDateTimeFromIst(_scheduledAt!) : null,
        'remarks': _remarks.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
