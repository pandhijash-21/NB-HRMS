import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../auth/domain/permissions.dart';
import '../../presentation/admin_notifier.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../profile/presentation/widgets/profile_tabs.dart';
import '../../../profile/domain/profile_models.dart';
import '../../domain/admin_models.dart';
import '../../../leave/presentation/widgets/employee_leave_tab.dart';

class AdminEmployeeDetailScreen extends ConsumerStatefulWidget {
  final int employeeId;

  const AdminEmployeeDetailScreen({super.key, required this.employeeId});

  @override
  ConsumerState<AdminEmployeeDetailScreen> createState() => _AdminEmployeeDetailScreenState();
}

class _AdminEmployeeDetailScreenState extends ConsumerState<AdminEmployeeDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = [
    'General',
    'Personal',
    'Address',
    'Other',
    'Family',
    'Academic',
    'Experience',
    'Bank',
    'Salary',
    'Leave',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Initialize active profile employee ID to reload detail profile
    Future.microtask(() {
      ref.read(activeProfileEmployeeIdProvider.notifier).set(widget.employeeId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Gate screen with RBAC
    final hasAccess = Permissions.canViewWorkforce(
      authState.permissions,
      authState.user?.employeeViewScope,
    );

    if (!hasAccess) {
      return const Scaffold(body: Center(child: Text('Access Denied')));
    }

    final profileAsyncVal = ref.watch(profileProvider);
    final assignmentsAsync = ref.watch(employeeAssignmentsProvider(widget.employeeId));

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Employee HR File'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/profile/edit?employeeId=${widget.employeeId}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Profile (Admin)'),
            ),
          ),
        ],
      ),
      body: profileAsyncVal.when(
        data: (profile) => Column(
          children: [
            _buildProfileSummaryHeader(profile),
            _buildAssignmentSection(context, assignmentsAsync),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  GeneralViewTab(profile: profile),
                  PersonalViewTab(profile: profile),
                  AddressViewTab(profile: profile),
                  OtherViewTab(profile: profile),
                  FamilyViewTab(profile: profile),
                  AcademicViewTab(profile: profile),
                  const ExperienceViewTab(),
                  BankViewTab(profile: profile),
                  SalaryViewTab(profile: profile),
                  EmployeeLeaveTab(employeeId: widget.employeeId),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load profile details\n$err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(profileProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSummaryHeader(EmployeeProfile profile) {
    final initials = profile.generalInfo?.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join('') ?? '?';
    return Container(
      color: AppColors.midnight,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.slate,
            backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                ? NetworkImage(profile.photoUrl!)
                : null,
            child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                ? Text(
                    initials.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.sand),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.generalInfo?.fullName ?? 'Unnamed Employee',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile.generalInfo?.designation ?? "No Designation"} · ${profile.generalInfo?.department ?? "No Dept"}',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Code: ${profile.generalInfo?.employeeCode ?? "N/A"} · Status: ${profile.status}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentSection(BuildContext context, AsyncValue<List<EmployeeAssignment>> assignmentsAsync) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timeline, color: AppColors.bronze, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Employment Assignments & History',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.midnight),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _showHistoryDetailsDialog(context, assignmentsAsync),
                  child: const Text('View All Logs', style: TextStyle(fontSize: 12, color: AppColors.bronze)),
                ),
              ],
            ),
            assignmentsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No employment assignment logs found.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  );
                }
                // Sort by effectiveFrom desc to show latest first
                final sorted = List<EmployeeAssignment>.from(list)
                  ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
                final current = sorted.first;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.sand,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current: ${current.designation}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.midnight),
                                ),
                                Text(
                                  'Institute: ${current.subOrganization ?? "GIT"} · From: ${_formatDate(current.effectiveFrom)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(context, 'Assign Position', () => _showPositionDialog(context)),
                        _buildActionButton(context, 'Transfer Institute', () => _showTransferDialog(context)),
                        _buildActionButton(context, 'Upgrade Designation', () => _showUpgradeDialog(context)),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              )),
              error: (err, _) => Text('Error loading history: $err', style: const TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.midnight,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.midnight,
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.bronze,
        labelColor: AppColors.bronze,
        unselectedLabelColor: Colors.white70,
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  void _showHistoryDetailsDialog(BuildContext context, AsyncValue<List<EmployeeAssignment>> asyncList) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assignment Logs Timeline'),
        content: SizedBox(
          width: 400,
          height: 350,
          child: asyncList.when(
            data: (list) {
              if (list.isEmpty) return const Center(child: Text('No historical logs.'));
              final sorted = List<EmployeeAssignment>.from(list)
                ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));

              return ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (ctx, i) {
                  final log = sorted[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: AppColors.bronze),
                          const SizedBox(width: 8),
                          Text(
                            log.designation,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 2, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sub-Org: ${log.subOrganization ?? "GIT"} · Department: ${log.department ?? "N/A"}'),
                            Text('Effective: ${_formatDate(log.effectiveFrom)} - ${log.effectiveTo != null ? _formatDate(log.effectiveTo!) : "Present"}'),
                            if (log.reason != null && log.reason!.isNotEmpty)
                              Text('Reason: ${log.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      const Divider(),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  // Position Mapping Dialog
  void _showPositionDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Map Position Designation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the Position Designation UUID (or leave blank to remove mapping):', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Position Designation UUID'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final uuid = ctrl.text.trim();
              Navigator.pop(ctx);
              try {
                await ref.read(adminRepositoryProvider).assignPosition(
                      widget.employeeId,
                      uuid.isEmpty ? null : uuid,
                    );
                ref.invalidate(employeeAssignmentsProvider(widget.employeeId));
                await _refreshProfileAfterHrAction();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Position updated successfully')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  // Transfer Dialog
  void _showTransferDialog(BuildContext context) {
    final subOrgCtrl = TextEditingController(text: 'GIT');
    final reasonCtrl = TextEditingController();
    DateTime effectiveFrom = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Institute Transfer'),
          scrollable: true,
          content: Column(
            children: [
              TextField(
                controller: subOrgCtrl,
                decoration: const InputDecoration(labelText: 'New Sub-Organization / Institute'),
              ),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason for Transfer'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Effective From: ${_formatDate(effectiveFrom)}')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: effectiveFrom,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => effectiveFrom = picked);
                      }
                    },
                    child: const Text('Select Date'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(adminRepositoryProvider).instituteTransfer(widget.employeeId, {
                    'newSubOrganization': subOrgCtrl.text.trim(),
                    'effectiveFrom': effectiveFrom.toIso8601String().split('T').first,
                    'reason': reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                  });
                  ref.invalidate(employeeAssignmentsProvider(widget.employeeId));
                  await _refreshProfileAfterHrAction();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Institute transfer completed')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                  }
                }
              },
              child: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  // Designation Upgrade Dialog
  void _showUpgradeDialog(BuildContext context) {
    final desCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime effectiveFrom = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Designation Upgrade'),
          scrollable: true,
          content: Column(
            children: [
              TextField(
                controller: desCtrl,
                decoration: const InputDecoration(labelText: 'New Designation Name'),
              ),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason for Upgrade'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Effective From: ${_formatDate(effectiveFrom)}')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: effectiveFrom,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => effectiveFrom = picked);
                      }
                    },
                    child: const Text('Select Date'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(adminRepositoryProvider).designationUpgrade(widget.employeeId, {
                    'newDesignation': desCtrl.text.trim(),
                    'effectiveFrom': effectiveFrom.toIso8601String().split('T').first,
                    'reason': reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                  });
                  ref.invalidate(employeeAssignmentsProvider(widget.employeeId));
                  await _refreshProfileAfterHrAction();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Designation upgraded successfully')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                  }
                }
              },
              child: const Text('Upgrade'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _refreshProfileAfterHrAction() async {
    await ref.read(profileProvider.notifier).refresh();
  }
}
