import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/domain/permissions.dart';
import '../../attendance/presentation/attendance_providers.dart';
import '../../leave/presentation/widgets/leave_shared_widgets.dart';
import '../../../core/tour/models/tour_models.dart';
import '../../../core/tour/widgets/tour_target.dart';

/// Home palette aligned with login branding (solid colors).
class _HomeC {
  static const brand = Color(0xFF141A16);
  static const gold = Color(0xFFC5A36A);
  static const goldSoft = Color(0xFFD6BC85);
  static const cream = Color(0xFFF3F0EA);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A1F1B);
  static const mute = Color(0xFF6F766F);
  static const line = Color(0xFFE2DDD5);
}

class UpcomingBirthday {
  const UpcomingBirthday({
    required this.employeeId,
    required this.name,
    required this.daysUntil,
    required this.nextOccurrence,
    this.employeeCode,
    this.photoUrl,
    this.turningAge,
  });

  final int employeeId;
  final String name;
  final int daysUntil;
  final DateTime nextOccurrence;
  final String? employeeCode;
  final String? photoUrl;
  final int? turningAge;

  factory UpcomingBirthday.fromJson(Map<String, dynamic> json) {
    return UpcomingBirthday(
      employeeId: (json['employeeId'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Employee',
      daysUntil: (json['daysUntil'] as num?)?.toInt() ?? 0,
      nextOccurrence: DateTime.tryParse('${json['nextOccurrence']}') ?? DateTime.now(),
      employeeCode: json['employeeCode'] as String?,
      photoUrl: json['photoUrl'] as String?,
      turningAge: (json['turningAge'] as num?)?.toInt(),
    );
  }
}
enum ModuleCategory {
  mySpace('My Space'),
  management('Management & Approvals'),
  system('System Administration');

  const ModuleCategory(this.label);
  final String label;
}

class _ModuleCardData {
  const _ModuleCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.enabled,
    required this.category,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? route;
  final bool enabled;
  final ModuleCategory category;
  final Color color;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  List<UpcomingBirthday> _birthdays = const [];
  bool _birthdaysLoading = true;
  String? _punchInIso;
  String? _punchOutIso;
  bool _punchLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBirthdays();
      _loadTodayPunch();
      _promptEmergencyIfNeeded();
    });
  }

  void _promptEmergencyIfNeeded() {
    final auth = context.read<AuthBloc>().state;
    if (!auth.needsEmergencyContact || !mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Emergency contact required'),
          content: const Text(
            'Add at least one family contact and mark them as an emergency contact before using the app.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/profile/edit');
              },
              child: const Text('Add emergency contact'),
            ),
          ],
        ),
      ),
    );
  }

  String _todayYmdIst() {
    final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return formatDateYmd(DateTime(ist.year, ist.month, ist.day));
  }

  Future<void> _loadTodayPunch() async {
    try {
      final day = await ref.read(attendanceRepositoryProvider).getMyDay(
            date: _todayYmdIst(),
          );
      if (!mounted) return;
      setState(() {
        _punchInIso = day.summary.firstIn;
        _punchOutIso = day.summary.lastOut;
        _punchLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _punchInIso = null;
        _punchOutIso = null;
        _punchLoading = false;
      });
    }
  }

  Future<void> _loadBirthdays() async {
    try {
      final dio = ref.read(dioClientProvider);
      final data = await dio.getEnvelope<Map<String, dynamic>>(
        'employees/upcoming-birthdays',
        queryParameters: const {'daysAhead': 45, 'limit': 10},
        parse: (raw) {
          if (raw is! Map) return <String, dynamic>{'items': <UpcomingBirthday>[]};
          final items = (raw['items'] as List? ?? [])
              .whereType<Map>()
              .map((e) => UpcomingBirthday.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          return {'items': items};
        },
      );
      if (!mounted) return;
      setState(() {
        _birthdays = (data['items'] as List<UpcomingBirthday>?) ?? const [];
        _birthdaysLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _birthdays = const [];
        _birthdaysLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth.user;
    final name = user?.name ?? 'there';
    final role = user?.role ?? '';

    if (Permissions.isSuperAdmin(role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/platform');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final wide = MediaQuery.sizeOf(context).width >= 900;
    final medium = MediaQuery.sizeOf(context).width >= 600;
    final phone = MediaQuery.sizeOf(context).width < 600;

    final hasWorkforce = Permissions.canViewWorkforce(auth.permissions, auth.user?.employeeViewScope, role);
    final isHR = Permissions.isAdmin(role) || ['ADMIN', 'HR', 'SYSTEM_ADMINISTRATOR', 'SYSTEMADMIN'].contains(role.toUpperCase());
    final canApproveLeave = Permissions.isAdmin(role) ||
        Permissions.canApproveLeave(auth.permissions) ||
        Permissions.canReadLeave(auth.permissions, role);
    final canAdminLeave = Permissions.isAdmin(role) || Permissions.canAdminLeave(
      auth.permissions,
      role,
      auth.user?.employeeViewScope,
    );
    final canAdminAttendance = Permissions.isAdmin(role) || Permissions.canAdminAttendance(auth.permissions, role);
    final canAccessAdmin = Permissions.canAccessAdminPortal(
      auth.permissions,
      auth.user?.employeeViewScope,
      role,
    );
    final canManageUsers = Permissions.canManageUsers(auth.permissions, role);
    final canManageRoles = Permissions.canManageRoles(auth.permissions, role);
    final canManageInstitutes = Permissions.canManageInstitutes(auth.permissions, role);

    final modules = <_ModuleCardData>[
      if (Permissions.canReadOrgTree(auth.permissions, auth.user?.role))
        const _ModuleCardData(
          title: 'Org Chart',
          subtitle: 'Hierarchy, leads, and who to contact',
          icon: Icons.account_tree_rounded,
          route: '/org-tree',
          enabled: true,
          category: ModuleCategory.mySpace,
          color: Color(0xFF2563EB),
        ),
      if (Permissions.canReadTasks(auth.permissions, auth.user?.role))
        const _ModuleCardData(
          title: 'Tasks',
          subtitle: 'Assignments, subtasks, deadlines & Gantt',
          icon: Icons.task_alt_rounded,
          route: '/tasks',
          enabled: true,
          category: ModuleCategory.mySpace,
          color: Color(0xFF4f46e5),
        ),
      if (Permissions.canReadSupport(auth.permissions, auth.user?.role))
        const _ModuleCardData(
          title: 'Support',
          subtitle: 'Raise IT tickets and track resolution',
          icon: Icons.support_agent_rounded,
          route: '/support',
          enabled: true,
          category: ModuleCategory.mySpace,
          color: Color(0xFFB45309),
        ),
      if (Permissions.canReadChat(auth.permissions, auth.user?.role))
        const _ModuleCardData(
          title: 'Chat',
          subtitle: '1:1 and group chat, files, presence',
          icon: Icons.chat,
          route: '/chat',
          enabled: true,
          category: ModuleCategory.mySpace,
          color: Color(0xFF2563EB),
        ),
      if (Permissions.canReadMeetings(auth.permissions, auth.user?.role))
        const _ModuleCardData(
          title: 'Meet',
          subtitle: 'Voice, video, screen share, guest codes, AI summary',
          icon: Icons.videocam,
          route: '/meet',
          enabled: true,
          category: ModuleCategory.mySpace,
          color: Color(0xFF0f766e),
        ),
      if (Permissions.canReadLeave(auth.permissions, auth.user?.role) ||
          Permissions.canWriteLeave(auth.permissions, auth.user?.role) ||
          canApproveLeave ||
          canAdminLeave)
        _ModuleCardData(
          title: 'Leave',
          subtitle: () {
            final parts = <String>['Balances', 'apply', 'history'];
            if (canApproveLeave) parts.add('approvals');
            if (canAdminLeave) parts.add('admin');
            return parts.join(', ');
          }(),
          icon: Icons.event_available_rounded,
          route: '/leave',
          enabled: true,
          category: ModuleCategory.mySpace,
          color: const Color(0xFF0284c7), // Sky Blue
        ),
      if (Permissions.canReadAttendance(auth.permissions, auth.user?.role) ||
          canAdminAttendance)
        _ModuleCardData(
          title: 'Attendance',
          subtitle: canAdminAttendance
              ? 'My punches, policy, manual punches & all employees'
              : 'Calendar and punch history',
          icon: Icons.fingerprint_rounded,
          route: '/attendance',
          enabled: true,
          category: ModuleCategory.mySpace,
          color: const Color(0xFF16a34a), // Green
        ),
      const _ModuleCardData(
        title: 'Profile',
        subtitle: 'View and update your profile',
        icon: Icons.person_rounded,
        route: '/profile',
        enabled: true,
        category: ModuleCategory.mySpace,
        color: Color(0xFF9333ea), // Purple
      ),
      if (Permissions.canReadReimbursements(auth.permissions, auth.user?.role))
        const _ModuleCardData(
          title: 'Reimbursements',
          subtitle: 'Apply, track & approve claims',
          icon: Icons.receipt_long_rounded,
          route: '/reimbursements',
          enabled: true,
          category: ModuleCategory.mySpace,
          color: Color(0xFF0f766e), // Teal dark
        ),
      if (Permissions.canReadRecruitment(auth.permissions, auth.user?.role))
        const _ModuleCardData(
          title: 'Recruitment',
          subtitle: 'Openings and hiring pipeline',
          icon: Icons.work_outline_rounded,
          route: '/recruitment',
          enabled: true,
          category: ModuleCategory.mySpace,
          color: Color(0xFF7c3aed),
        ),
      if (Permissions.canReadRepository(auth.permissions, auth.user?.role))
        const _ModuleCardData(
          title: 'Repository',
          subtitle: 'Company policies & documents',
          icon: Icons.folder_shared_rounded,
          route: '/repository',
          enabled: true,
          category: ModuleCategory.mySpace,
          color: Color(0xFF0369a1),
        ),
      if (Permissions.canReadPayroll(auth.permissions, auth.user?.role))
        const _ModuleCardData(
          title: 'Payroll',
          subtitle: 'Monthwise salaries, paid vs remaining',
          icon: Icons.payments_rounded,
          route: '/admin/salary/payroll',
          enabled: true,
          category: ModuleCategory.mySpace,
          color: Color(0xFFea580c), // Orange
        ),
      if (hasWorkforce)
        const _ModuleCardData(
          title: 'Workforce',
          subtitle: 'Manage workforce directory',
          icon: Icons.groups_rounded,
          route: '/admin/employees',
          enabled: true,
          category: ModuleCategory.management,
          color: Color(0xFF0d9488), // Teal
        ),
      if (isHR)
        const _ModuleCardData(
          title: 'Profile Approvals',
          subtitle: 'Review employee profile changes',
          icon: Icons.assignment_turned_in_rounded,
          route: '/admin/approvals',
          enabled: true,
          category: ModuleCategory.management,
          color: Color(0xFF4f46e5), // Indigo
        ),
      if (canAccessAdmin)
        const _ModuleCardData(
          title: 'Admin Dashboard',
          subtitle: 'HR system overview and KPIs',
          icon: Icons.dashboard_rounded,
          route: '/admin/dashboard',
          enabled: true,
          category: ModuleCategory.system,
          color: Color(0xFFe11d48), // Rose
        ),
      if (canManageUsers)
        const _ModuleCardData(
          title: 'Users',
          subtitle: 'Manage login accounts and roles',
          icon: Icons.manage_accounts_rounded,
          route: '/admin/users',
          enabled: true,
          category: ModuleCategory.system,
          color: Color(0xFF475569), // Slate
        ),
      if (canManageRoles)
        const _ModuleCardData(
          title: 'Roles',
          subtitle: 'Roles & permission matrix',
          icon: Icons.shield_rounded,
          route: '/admin/roles',
          enabled: true,
          category: ModuleCategory.system,
          color: Color(0xFFb45309), // Amber/Brown
        ),
      if (canManageUsers || canManageInstitutes)
        const _ModuleCardData(
          title: 'Configurations',
          subtitle: 'Institutes, designations & all dropdowns',
          icon: Icons.tune_rounded,
          route: '/admin/configurations',
          enabled: true,
          category: ModuleCategory.system,
          color: Color(0xFF0d9488),
        ),
      if (Permissions.isAdmin(role))
        const _ModuleCardData(
          title: 'Storage',
          subtitle: 'Used space, remaining capacity & data wipe',
          icon: Icons.cloud_rounded,
          route: '/admin/storage',
          enabled: true,
          category: ModuleCategory.system,
          color: Color(0xFF7c3aed),
        ),
      if (canAccessAdmin)
        const _ModuleCardData(
          title: 'Audit',
          subtitle: 'Change history (REST pending)',
          icon: Icons.history_edu_rounded,
          route: '/admin/audit',
          enabled: true,
          category: ModuleCategory.system,
          color: Color(0xFF64748b), // Slate Light
        ),
    ];

    final hero = _GreetingsCard(
      name: name,
      role: role,
      punchLoading: _punchLoading,
      punchInIso: _punchInIso,
      punchOutIso: _punchOutIso,
      onPunchIn: () => context.go('/attendance'),
    );

    final filteredModules = modules.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final searchBar = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : _HomeC.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _HomeC.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      height: 52,
      child: Row(
        children: [
          NbIcon(
            Icons.search_rounded,
            color: _HomeC.mute,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: GoogleFonts.sourceSans3(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search modules, tools, and actions...',
                hintStyle: GoogleFonts.sourceSans3(
                  color: _HomeC.mute.withValues(alpha: 0.75),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: NbIcon(
                Icons.clear_rounded,
                color: _HomeC.mute,
                size: 20,
              ),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
        ],
      ),
    );

    Widget buildCategorySection(ModuleCategory category) {
      final categoryModules = filteredModules.where((m) => m.category == category).toList();
      if (categoryModules.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 14, top: 8),
            child: Text(
              category.label.toUpperCase(),
              style: GoogleFonts.sourceSans3(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.8,
                color: _HomeC.mute,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final double gridWidth = constraints.maxWidth;
              final int crossAxisCount = wide ? 3 : (medium ? 2 : 1);
              final double cellWidth =
                  (gridWidth - (crossAxisCount - 1) * 14.0) / crossAxisCount;
              final double targetHeight = phone ? 108.0 : 96.0;
              final double dynamicAspectRatio = cellWidth / targetHeight;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categoryModules.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: dynamicAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final item = categoryModules[index];
                  return _ModernModuleCard(
                    data: item,
                    onTap: item.enabled && item.route != null
                        ? () => context.go(item.route!)
                        : null,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 28),
        ],
      );
    }

    final hasResults = filteredModules.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : _HomeC.cream,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                medium ? 28 : 16,
                phone ? 16 : 22,
                medium ? 28 : 16,
                phone ? 88 : 48,
              ),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TourTarget(
                    id: TourIds.step('hrms.home', 2),
                    child: hero,
                  ),
                  const SizedBox(height: 18),
                  searchBar,
                  const SizedBox(height: 20),
                  _UpcomingBirthdaysStrip(
                    loading: _birthdaysLoading,
                    items: _birthdays,
                  ),
                  const SizedBox(height: 28),
                  if (hasResults) buildCategorySection(ModuleCategory.mySpace),
                  if (hasResults)
                    TourTarget(
                      id: TourIds.step('hrms.home', 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          buildCategorySection(ModuleCategory.management),
                          buildCategorySection(ModuleCategory.system),
                        ],
                      ),
                    )
                  else ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            NbIcon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No features match "$_searchQuery"',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Check the spelling or try a different term',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GreetingsCard extends StatefulWidget {
  const _GreetingsCard({
    required this.name,
    required this.role,
    required this.punchLoading,
    required this.punchInIso,
    required this.punchOutIso,
    required this.onPunchIn,
  });

  final String name;
  final String role;
  final bool punchLoading;
  final String? punchInIso;
  final String? punchOutIso;
  final VoidCallback onPunchIn;

  @override
  State<_GreetingsCard> createState() => _GreetingsCardState();
}

class _GreetingsCardState extends State<_GreetingsCard> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    final timeStr = DateFormat('hh:mm:ss a').format(_now);
    final dateStr = DateFormat('EEE, d MMM yyyy').format(_now);
    final punchedIn = widget.punchInIso != null && widget.punchInIso!.isNotEmpty;
    final punchInLabel = punchedIn ? '${formatIsoTime(widget.punchInIso)} IST' : '—';
    final punchOutLabel = (widget.punchOutIso != null && widget.punchOutIso!.isNotEmpty)
        ? '${formatIsoTime(widget.punchOutIso)} IST'
        : '—';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        phone ? 16 : 22,
        phone ? 16 : 18,
        phone ? 16 : 22,
        phone ? 16 : 18,
      ),
      decoration: BoxDecoration(
        color: _HomeC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _HomeC.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          phone
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GreetingIdentity(name: widget.name, role: widget.role, phone: true),
                    const SizedBox(height: 14),
                    _DigitalClockBlock(timeStr: timeStr, dateStr: dateStr, compact: true),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _GreetingIdentity(
                        name: widget.name,
                        role: widget.role,
                        phone: false,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _DigitalClockBlock(timeStr: timeStr, dateStr: dateStr, compact: false),
                  ],
                ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: _HomeC.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _HomeC.line),
            ),
            child: widget.punchLoading
                ? const SizedBox(
                    height: 36,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : phone
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PunchTimesRow(
                            punchInLabel: punchInLabel,
                            punchOutLabel: punchOutLabel,
                            punchedIn: punchedIn,
                          ),
                          if (!punchedIn) ...[
                            const SizedBox(height: 10),
                            _PunchInButton(onPressed: widget.onPunchIn),
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _PunchTimesRow(
                              punchInLabel: punchInLabel,
                              punchOutLabel: punchOutLabel,
                              punchedIn: punchedIn,
                            ),
                          ),
                          if (!punchedIn) ...[
                            const SizedBox(width: 14),
                            _PunchInButton(onPressed: widget.onPunchIn),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _PunchTimesRow extends StatelessWidget {
  const _PunchTimesRow({
    required this.punchInLabel,
    required this.punchOutLabel,
    required this.punchedIn,
  });

  final String punchInLabel;
  final String punchOutLabel;
  final bool punchedIn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PunchStat(
            label: 'Punch in',
            value: punchInLabel,
            emphasize: punchedIn,
          ),
        ),
        Container(width: 1, height: 36, color: _HomeC.line),
        Expanded(
          child: _PunchStat(
            label: 'Punch out',
            value: punchOutLabel,
            emphasize: punchOutLabel != '—',
          ),
        ),
      ],
    );
  }
}

class _PunchStat extends StatelessWidget {
  const _PunchStat({
    required this.label,
    required this.value,
    required this.emphasize,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.sourceSans3(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _HomeC.mute,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.sourceSans3(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: emphasize ? _HomeC.ink : _HomeC.mute,
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchInButton extends StatelessWidget {
  const _PunchInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _HomeC.brand,
        foregroundColor: _HomeC.cream,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.login_rounded, size: 18),
      label: Text(
        'Punch in now',
        style: GoogleFonts.sourceSans3(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _GreetingIdentity extends StatelessWidget {
  const _GreetingIdentity({
    required this.name,
    required this.role,
    required this.phone,
  });

  final String name;
  final String role;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/nb-logo.png',
            width: phone ? 44 : 50,
            height: phone ? 44 : 50,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: phone ? 44 : 50,
              height: phone ? 44 : 50,
              color: _HomeC.brand,
              alignment: Alignment.center,
              child: Text(
                'NB',
                style: GoogleFonts.fraunces(
                  fontWeight: FontWeight.w700,
                  color: _HomeC.gold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: GoogleFonts.sourceSans3(
                  color: _HomeC.mute,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.fraunces(
                  color: _HomeC.ink,
                  fontSize: phone ? 22 : 26,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              if (role.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _HomeC.brand,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: GoogleFonts.sourceSans3(
                      color: _HomeC.goldSoft,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DigitalClockBlock extends StatelessWidget {
  const _DigitalClockBlock({
    required this.timeStr,
    required this.dateStr,
    required this.compact,
  });

  final String timeStr;
  final String dateStr;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: _HomeC.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _HomeC.line),
      ),
      child: Column(
        crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            timeStr,
            style: GoogleFonts.sourceSans3(
              color: _HomeC.ink,
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateStr,
            style: GoogleFonts.sourceSans3(
              color: _HomeC.mute,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingBirthdaysStrip extends StatelessWidget {
  const _UpcomingBirthdaysStrip({
    required this.loading,
    required this.items,
  });

  final bool loading;
  final List<UpcomingBirthday> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: _HomeC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _HomeC.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cake_outlined, color: _HomeC.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                'UPCOMING BIRTHDAYS',
                style: GoogleFonts.sourceSans3(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: _HomeC.mute,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          else if (items.isEmpty)
            Text(
              'No upcoming birthdays in the next 45 days.',
              style: GoogleFonts.sourceSans3(
                fontSize: 13.5,
                color: _HomeC.mute,
              ),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final b = items[index];
                  final when = b.daysUntil == 0
                      ? 'Today'
                      : b.daysUntil == 1
                          ? 'Tomorrow'
                          : 'In ${b.daysUntil} days';
                  final dateLabel = DateFormat('d MMM').format(b.nextOccurrence);
                  return Container(
                    width: 200,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: _HomeC.cream,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: b.daysUntil == 0
                            ? _HomeC.gold.withValues(alpha: 0.55)
                            : _HomeC.line,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _HomeC.brand,
                          backgroundImage: (b.photoUrl != null && b.photoUrl!.isNotEmpty)
                              ? NetworkImage(b.photoUrl!)
                              : null,
                          child: (b.photoUrl == null || b.photoUrl!.isEmpty)
                              ? Text(
                                  b.name.isNotEmpty ? b.name[0].toUpperCase() : '?',
                                  style: GoogleFonts.sourceSans3(
                                    color: _HomeC.goldSoft,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                b.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sourceSans3(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: _HomeC.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$dateLabel · $when',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 12,
                                  color: _HomeC.mute,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (b.turningAge != null)
                                Text(
                                  'Turning ${b.turningAge}',
                                  style: GoogleFonts.sourceSans3(
                                    fontSize: 11,
                                    color: _HomeC.gold,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ModernModuleCard extends StatefulWidget {
  const _ModernModuleCard({required this.data, this.onTap});

  final _ModuleCardData data;
  final VoidCallback? onTap;

  @override
  State<_ModernModuleCard> createState() => _ModernModuleCardState();
}

class _ModernModuleCardState extends State<_ModernModuleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phone = MediaQuery.sizeOf(context).width < 600;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = enabled),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0.0, _isHovered ? -3.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: isDark
              ? Theme.of(context).colorScheme.surface
              : _HomeC.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? _HomeC.gold.withValues(alpha: 0.45)
                : _HomeC.line,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.03),
              blurRadius: _isHovered ? 16 : 8,
              offset: Offset(0, _isHovered ? 8 : 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: phone ? 14 : 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: phone ? 46 : 50,
                      height: phone ? 46 : 50,
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? _HomeC.brand
                            : widget.data.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: NbIcon(
                        widget.data.icon,
                        color: _isHovered ? _HomeC.goldSoft : widget.data.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.data.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sourceSans3(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              color: isDark
                                  ? Theme.of(context).colorScheme.onSurface
                                  : _HomeC.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.data.subtitle,
                            style: GoogleFonts.sourceSans3(
                              color: _HomeC.mute,
                              fontSize: 12.5,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (enabled)
                      NbIcon(
                        Icons.arrow_forward_rounded,
                        color: _isHovered ? _HomeC.gold : _HomeC.line,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
