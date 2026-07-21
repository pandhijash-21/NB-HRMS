import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../profile_notifier.dart';
import '../widgets/profile_tabs.dart';
import '../../domain/profile_models.dart';
import '../../../auth/domain/permissions.dart';
import '../widgets/employee_attendance_tab.dart';
import '../widgets/edit_experience_tab.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final int? employeeId;

  const ProfileScreen({super.key, this.employeeId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'General',
    'Personal',
    'Address',
    'Other',
    'Family',
    'Academic',
    'Experience',
    'Documents',
    'Bank',
    'Salary',
    'Attendance',
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
    final empId = widget.employeeId ?? authState.user?.employeeId;

    if (empId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Error: No profile ID provided or found in session.'),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsyncVal = ref.watch(profileProvider);

    final userScope =
        authState.permissions['PERSONAL_INFO']?.contains('WRITE') == true;
    final isOwnProfile = authState.user?.employeeId == empId;
    final canEdit = isOwnProfile || userScope;

    final canManageLetters =
        Permissions.canManageLetters(
          authState.permissions,
          authState.user?.role,
        ) &&
        !isOwnProfile;

    final canManageAttendanceSettings =
        Permissions.canManageEmployeeAttendance(
          authState.permissions,
          authState.user?.role,
        ) &&
        (widget.employeeId != null || !isOwnProfile);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Employee Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: widget.employeeId != null
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark
                      ? Colors.white.withOpacity(0.8)
                      : const Color(0xFF212F3D),
                ),
                onPressed: () => context.pop(),
              )
            : IconButton(
                icon: Icon(
                  Icons.home_outlined,
                  color: isDark
                      ? Colors.white.withOpacity(0.8)
                      : const Color(0xFF212F3D),
                ),
                onPressed: () => context.go('/home'),
              ),
        actions: [
          if (canEdit)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  widget.employeeId != null
                      ? '/profile/edit?employeeId=$empId'
                      : '/profile/edit',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? const Color(0xFFE2D6BE)
                      : const Color(0xFF263238),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFFC5A059).withOpacity(0.4)
                        : const Color(0xFF263238).withOpacity(0.5),
                    width: 1.2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark
                ? const Color(0xFFC5A059).withOpacity(0.15)
                : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: profileAsyncVal.when(
        data: (profile) => TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, animValue, child) {
            return Transform.translate(
              offset: Offset(0.0, 30.0 * (1.0 - animValue)),
              child: Opacity(opacity: animValue, child: child),
            );
          },
          child: Column(
            children: [
              _buildProfileHeader(context, profile, isDark),
              _buildTabBar(context, isDark),
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
                    EditExperienceTab(employeeId: profile.id, canEdit: false),
                    DocumentsViewTab(
                      profile: profile,
                      canManageLetters: canManageLetters,
                    ),
                    BankViewTab(profile: profile),
                    SalaryViewTab(profile: profile),
                    EmployeeAttendanceTab(
                      employeeId: profile.id,
                      canManageSettings: canManageAttendanceSettings,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
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

  Widget _buildProfileHeader(
    BuildContext context,
    EmployeeProfile profile,
    bool isDark,
  ) {
    final statusColor = _getStatusColor(profile.status, context);
    final initials =
        profile.generalInfo?.fullName
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .join('') ??
        '?';

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [
                  Color(0xFF1A1816), // Premium cocoa
                  Color(0xFF2B2722), // Warm bronze
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [
                  Color(0xFFECEFF1), // Premium light platinum
                  Color(0xFFDFE6E9), // Cool steel
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFFC5A059).withOpacity(0.18)
                : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? const Color(0xFFC5A059).withOpacity(0.4)
                    : const Color(0xFF263238).withOpacity(0.2),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: isDark ? const Color(0xFF2B2722) : Colors.white,
              backgroundImage:
                  profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                  ? NetworkImage(profile.photoUrl!)
                  : null,
              child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                  ? Text(
                      initials.isNotEmpty ? initials.toUpperCase() : 'EE',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFE2D6BE)
                            : const Color(0xFF263238),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.generalInfo?.fullName ?? 'Unnamed Employee',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF212F3D),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        border: Border.all(color: statusColor, width: 1.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        profile.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  profile.generalInfo?.designation.toUpperCase() ??
                      'NO DESIGNATION ASSIGNED',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFD4C3A3)
                        : const Color(0xFF607D8B),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.generalInfo?.department ?? 'No Department Assigned',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white70
                        : const Color(0xFF263238).withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: isDark
                          ? Colors.white38
                          : const Color(0xFF607D8B).withOpacity(0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      profile.generalInfo != null
                          ? 'Joined ${_formatDate(profile.generalInfo!.joiningDate)}'
                          : 'No Joining Date',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF607D8B),
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

  Widget _buildTabBar(BuildContext context, bool isDark) {
    return Container(
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFFC5A059).withOpacity(0.12)
                : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: isDark ? const Color(0xFFC5A059) : Colors.black,
        indicatorWeight: 3,
        labelColor: isDark ? const Color(0xFFE2D6BE) : Colors.black,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.3,
        ),
        unselectedLabelColor: isDark ? Colors.white38 : const Color(0xFF607D8B),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Color _getStatusColor(String status, BuildContext context) {
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
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
