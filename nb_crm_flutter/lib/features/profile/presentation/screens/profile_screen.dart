import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../profile_notifier.dart';
import '../widgets/profile_tabs.dart';
import '../../domain/profile_models.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final int? employeeId;

  const ProfileScreen({super.key, this.employeeId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
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
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    Future.microtask(() {
      final auth = ref.read(authNotifierProvider);
      final empId = widget.employeeId ?? auth.user?.employeeId;
      if (empId == null) return;
      final current = ref.read(activeProfileEmployeeIdProvider);
      if (current != empId) {
        ref.read(activeProfileEmployeeIdProvider.notifier).set(empId);
      } else {
        // Same employee — still refresh so post-approval data is live.
        ref.read(profileProvider.notifier).refresh();
      }
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
    // If employeeId is not provided, fetch logged-in user's profile
    final empId = widget.employeeId ?? authState.user?.employeeId;

    if (empId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Error: No profile ID provided or found in session.'),
        ),
      );
    }

    final profileAsyncVal = ref.watch(profileProvider);

    // Determine edit permission based on RBAC scope
    final userScope = authState.permissions['PERSONAL_INFO']?.contains('WRITE') == true;
    final isOwnProfile = authState.user?.employeeId == empId;
    final canEdit = isOwnProfile || userScope;

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Employee Profile'),
        leading: widget.employeeId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () => context.go('/home'),
              ),
        actions: [
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  widget.employeeId != null
                      ? '/profile/edit?employeeId=$empId'
                      : '/profile/edit',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white60),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Profile'),
              ),
            ),
        ],
      ),
      body: profileAsyncVal.when(
        data: (profile) => Column(
          children: [
            _buildProfileHeader(context, profile),
            _buildTabBar(context),
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
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.bronze),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Failed to load profile details\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
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

  Widget _buildProfileHeader(BuildContext context, EmployeeProfile profile) {
    final statusColor = _getStatusColor(profile.status);
    final initials = profile.generalInfo?.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join('') ?? '?';

    return Container(
      color: AppColors.midnight,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.slate,
            backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                ? NetworkImage(profile.photoUrl!)
                : null,
            child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                ? Text(
                    initials.isNotEmpty ? initials.toUpperCase() : 'EE',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.sand,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.generalInfo?.fullName ?? 'Unnamed Employee',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.25),
                        border: Border.all(color: statusColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        profile.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  profile.generalInfo?.designation ?? 'No Designation Assigned',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.sand,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.generalInfo?.department ?? 'No Department Assigned',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      profile.generalInfo != null
                          ? 'Joined ${_formatDate(profile.generalInfo!.joiningDate)}'
                          : 'No Joining Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
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

  Widget _buildTabBar(BuildContext context) {
    return Container(
      color: AppColors.midnight,
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.bronze,
        labelColor: AppColors.bronze,
        unselectedLabelColor: Colors.white60,
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'ON_LEAVE':
        return Colors.orange;
      case 'INACTIVE':
      case 'RESIGNED':
      case 'RETIRED':
        return Colors.grey;
      case 'TERMINATED':
        return Colors.red;
      default:
        return AppColors.bronze;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
