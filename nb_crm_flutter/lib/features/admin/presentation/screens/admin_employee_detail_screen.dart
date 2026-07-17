import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Gate screen with RBAC
    final hasAccess = Permissions.canViewWorkforce(
      authState.permissions,
      authState.user?.employeeViewScope,
    );

    if (!hasAccess) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gpp_bad_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w800, 
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You do not have permission to view the workforce administration.',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    final profileAsyncVal = ref.watch(profileProvider);
    final assignmentsAsync = ref.watch(employeeAssignmentsProvider(widget.employeeId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Employee HR File',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/profile/edit?employeeId=${widget.employeeId}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                  side: BorderSide(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFF263238).withOpacity(0.5),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFC5A059)),
                label: const Text('Edit Profile (Admin)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: profileAsyncVal.when(
        data: (profile) => TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0.0, 30.0 * (1.0 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Column(
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
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load profile details\n$err', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = profile.generalInfo?.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join('') ?? '?';
    final statusColor = profile.status.toUpperCase() == 'ACTIVE' ? Colors.green : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFF263238).withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFECEFF1),
              backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                  ? NetworkImage(profile.photoUrl!)
                  : null,
              child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                  ? Text(
                      initials.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                        fontSize: 15,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.generalInfo?.fullName ?? 'Unnamed Employee',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.w800, 
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${profile.generalInfo?.designation ?? "No Designation"}  ·  ${profile.generalInfo?.department ?? "No Dept"}',
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                        ),
                      ),
                      child: Text(
                        'Code: ${profile.generalInfo?.employeeCode ?? "N/A"}',
                        style: TextStyle(
                          fontSize: 10, 
                          color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238), 
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        border: Border.all(color: statusColor, width: 1.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        profile.status,
                        style: TextStyle(
                          fontSize: 9, 
                          fontWeight: FontWeight.w800, 
                          color: statusColor, 
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentSection(BuildContext context, AsyncValue<List<EmployeeAssignment>> assignmentsAsync) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timeline_rounded, color: Color(0xFFC5A059), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Employment Assignments & History',
                      style: TextStyle(
                        fontWeight: FontWeight.w800, 
                        fontSize: 14, 
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showHistoryDetailsDialog(context, assignmentsAsync),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFC5A059)),
                  icon: const Icon(Icons.history_rounded, size: 14),
                  label: const Text('View All Logs', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            assignmentsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No employment assignment logs found.', 
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: const BorderSide(color: Colors.green, width: 4),
                          top: BorderSide(color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC)),
                          right: BorderSide(color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC)),
                          bottom: BorderSide(color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current: ${current.designation}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800, 
                                    fontSize: 13, 
                                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Institute: ${current.subOrganization ?? "GIT"}  ·  From: ${_formatDate(current.effectiveFrom)}',
                                  style: TextStyle(
                                    fontSize: 11, 
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white30 : const Color(0xFF607D8B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildActionButton(context, 'Assign Position', () => _showPositionDialog(context)),
                          const SizedBox(width: 10),
                          _buildActionButton(context, 'Transfer Institute', () => _showTransferDialog(context)),
                          const SizedBox(width: 10),
                          _buildActionButton(context, 'Upgrade Designation', () => _showUpgradeDialog(context)),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC5A059))),
                ),
              ),
              error: (err, _) => Text('Error loading history: $err', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 34,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
          side: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.4) : const Color(0xFFCFD8DC),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Text(
          label, 
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFFC5A059),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: const Color(0xFFC5A059),
        unselectedLabelColor: isDark ? Colors.white30 : const Color(0xFF607D8B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  void _showHistoryDetailsDialog(BuildContext context, AsyncValue<List<EmployeeAssignment>> asyncList) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
        title: Text(
          'Assignment Logs Timeline',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SizedBox(
          width: 400,
          height: 350,
          child: asyncList.when(
            data: (list) {
              if (list.isEmpty) return const Center(child: Text('No historical logs.', style: TextStyle(fontWeight: FontWeight.w600)));
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
                          const Icon(Icons.circle, size: 8, color: Color(0xFFC5A059)),
                          const SizedBox(width: 8),
                          Text(
                            log.designation,
                            style: TextStyle(
                              fontWeight: FontWeight.w800, 
                              fontSize: 13,
                              color: isDark ? Colors.white : const Color(0xFF212F3D),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 4, bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sub-Org: ${log.subOrganization ?? "GIT"} · Department: ${log.department ?? "N/A"}',
                              style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF607D8B), fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Effective: ${_formatDate(log.effectiveFrom)} - ${log.effectiveTo != null ? _formatDate(log.effectiveTo!) : "Present"}',
                              style: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6), fontSize: 11),
                            ),
                            if (log.reason != null && log.reason!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reason: ${log.reason}', 
                                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11, color: Colors.orange),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : Colors.black.withOpacity(0.06),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
            error: (err, _) => Text('Error: $err', style: const TextStyle(color: Colors.red)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Position Mapping Dialog
  void _showPositionDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
        title: Text(
          'Map Position Designation',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the Position Designation UUID (or leave blank to remove mapping):', 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF607D8B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Position Designation UUID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
              foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Assign Position', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // Transfer Dialog
  void _showTransferDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subOrgCtrl = TextEditingController(text: 'GIT');
    final reasonCtrl = TextEditingController();
    DateTime effectiveFrom = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
              width: 1.5,
            ),
          ),
          title: Text(
            'Institute Transfer',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF212F3D),
              fontWeight: FontWeight.w800,
            ),
          ),
          scrollable: true,
          content: Column(
            children: [
              TextField(
                controller: subOrgCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Sub-Organization / Institute',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for Transfer',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Effective From: ${_formatDate(effectiveFrom)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF212F3D),
                      ),
                    ),
                  ),
                  TextButton.icon(
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
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFC5A059)),
                    icon: const Icon(Icons.calendar_today_rounded, size: 14),
                    label: const Text('Select Date', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Transfer', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // Designation Upgrade Dialog
  void _showUpgradeDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime effectiveFrom = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
              width: 1.5,
            ),
          ),
          title: Text(
            'Designation Upgrade',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF212F3D),
              fontWeight: FontWeight.w800,
            ),
          ),
          scrollable: true,
          content: Column(
            children: [
              TextField(
                controller: desCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Designation Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for Upgrade',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Effective From: ${_formatDate(effectiveFrom)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF212F3D),
                      ),
                    ),
                  ),
                  TextButton.icon(
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
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFC5A059)),
                    icon: const Icon(Icons.calendar_today_rounded, size: 14),
                    label: const Text('Select Date', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.w800)),
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
