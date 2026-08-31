import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../auth/domain/permissions.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final user = auth.user;
    final name = user?.name ?? 'there';
    final role = user?.role ?? '';
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final medium = MediaQuery.sizeOf(context).width >= 600;
    final phone = MediaQuery.sizeOf(context).width < 600;

    final hasWorkforce = Permissions.canViewWorkforce(auth.permissions, auth.user?.employeeViewScope);
    final isHR = ['ADMIN', 'HR'].contains(role.toUpperCase());
    final canApproveLeave = Permissions.canApproveLeave(auth.permissions) ||
        Permissions.canReadLeave(auth.permissions);
    final canAdminLeave = Permissions.canAdminLeave(
      auth.permissions,
      role,
      auth.user?.employeeViewScope,
    );
    final canAdminAttendance = Permissions.canAdminAttendance(auth.permissions, role);
    final canAccessAdmin = Permissions.canAccessAdminPortal(
      auth.permissions,
      auth.user?.employeeViewScope,
    );
    final canManageUsers = Permissions.canManageUsers(auth.permissions, role);
    final canManageRoles = Permissions.canManageRoles(auth.permissions, role);
    final canManageInstitutes = Permissions.canManageInstitutes(auth.permissions, role);

    final modules = <_ModuleCardData>[
      _ModuleCardData(
        title: 'Employee tree',
        subtitle: 'Org chart, leads, and who to contact',
        icon: Icons.account_tree_rounded,
        route: '/org-tree',
        enabled: true,
        category: ModuleCategory.mySpace,
        color: const Color(0xFF2563EB),
      ),
      _ModuleCardData(
        title: 'Tasks',
        subtitle: 'Assign work, track progress, review & Gantt',
        icon: Icons.task_alt_rounded,
        route: '/tasks',
        enabled: true,
        category: ModuleCategory.mySpace,
        color: const Color(0xFF4f46e5),
      ),
      _ModuleCardData(
        title: 'Chat',
        subtitle: '1:1 and group chat, files, presence',
        icon: Icons.chat_bubble_rounded,
        route: '/chat',
        enabled: true,
        category: ModuleCategory.mySpace,
        color: const Color(0xFF2563EB),
      ),
      _ModuleCardData(
        title: 'Meet',
        subtitle: 'Voice, video, screen share, guest codes, AI summary',
        icon: Icons.videocam_rounded,
        route: '/meet',
        enabled: true,
        category: ModuleCategory.mySpace,
        color: const Color(0xFF0f766e),
      ),
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
        enabled: Permissions.canReadLeave(auth.permissions) ||
            Permissions.canWriteLeave(auth.permissions) ||
            canApproveLeave ||
            canAdminLeave ||
            user?.employeeId != null,
        category: ModuleCategory.mySpace,
        color: const Color(0xFF0284c7), // Sky Blue
      ),
      _ModuleCardData(
        title: 'Attendance',
        subtitle: canAdminAttendance
            ? 'My punches, policy, manual punches & all employees'
            : 'Calendar and punch history',
        icon: Icons.fingerprint_rounded,
        route: '/attendance',
        enabled: Permissions.canReadAttendance(auth.permissions) ||
            canAdminAttendance ||
            user?.employeeId != null,
        category: ModuleCategory.mySpace,
        color: const Color(0xFF16a34a), // Green
      ),
      _ModuleCardData(
        title: 'Profile',
        subtitle: 'View and update your profile',
        icon: Icons.person_rounded,
        route: '/profile',
        enabled: true,
        category: ModuleCategory.mySpace,
        color: const Color(0xFF9333ea), // Purple
      ),
      _ModuleCardData(
        title: 'Reimbursements',
        subtitle: 'Apply, track & approve claims',
        icon: Icons.receipt_long_rounded,
        route: '/reimbursements',
        enabled: Permissions.canReadReimbursements(auth.permissions) ||
            Permissions.canWriteReimbursements(auth.permissions) ||
            user?.employeeId != null,
        category: ModuleCategory.mySpace,
        color: const Color(0xFF0f766e), // Teal dark
      ),
      _ModuleCardData(
        title: 'Recruitment',
        subtitle: isHR || canAccessAdmin
            ? 'Vacancies'
            : 'Openings (view only when posted)',
        icon: Icons.work_outline_rounded,
        route: '/recruitment',
        enabled: true,
        category: ModuleCategory.mySpace,
        color: const Color(0xFF7c3aed),
      ),
      _ModuleCardData(
        title: 'Repository',
        subtitle: 'Company policies & documents',
        icon: Icons.folder_shared_rounded,
        route: '/repository',
        enabled: true,
        category: ModuleCategory.mySpace,
        color: const Color(0xFF0369a1),
      ),
      _ModuleCardData(
        title: 'Payroll',
        subtitle: Permissions.canReadSalary(auth.permissions)
            ? 'Monthwise salaries, paid vs remaining'
            : 'No salary access',
        icon: Icons.payments_rounded,
        route: '/admin/salary/payroll',
        enabled: Permissions.canReadSalary(auth.permissions),
        category: ModuleCategory.mySpace,
        color: const Color(0xFFea580c), // Orange
      ),
      if (hasWorkforce)
        _ModuleCardData(
          title: 'Workforce',
          subtitle: 'Manage workforce directory',
          icon: Icons.groups_rounded,
          route: '/admin/employees',
          enabled: true,
          category: ModuleCategory.management,
          color: const Color(0xFF0d9488), // Teal
        ),
      if (isHR)
        _ModuleCardData(
          title: 'Profile Approvals',
          subtitle: 'Review employee profile changes',
          icon: Icons.assignment_turned_in_rounded,
          route: '/admin/approvals',
          enabled: true,
          category: ModuleCategory.management,
          color: const Color(0xFF4f46e5), // Indigo
        ),
      if (canAccessAdmin)
        _ModuleCardData(
          title: 'Admin Dashboard',
          subtitle: 'HR system overview and KPIs',
          icon: Icons.dashboard_rounded,
          route: '/admin/dashboard',
          enabled: true,
          category: ModuleCategory.system,
          color: const Color(0xFFe11d48), // Rose
        ),
      if (canManageUsers)
        _ModuleCardData(
          title: 'Users',
          subtitle: 'Manage login accounts and roles',
          icon: Icons.manage_accounts_rounded,
          route: '/admin/users',
          enabled: true,
          category: ModuleCategory.system,
          color: const Color(0xFF475569), // Slate
        ),
      if (canManageRoles)
        _ModuleCardData(
          title: 'Roles',
          subtitle: 'Roles & permission matrix',
          icon: Icons.shield_rounded,
          route: '/admin/roles',
          enabled: true,
          category: ModuleCategory.system,
          color: const Color(0xFFb45309), // Amber/Brown
        ),
      if (canManageUsers || canManageInstitutes)
        _ModuleCardData(
          title: 'Configurations',
          subtitle: 'Institutes, designations & all dropdowns',
          icon: Icons.tune_rounded,
          route: '/admin/configurations',
          enabled: true,
          category: ModuleCategory.system,
          color: const Color(0xFF0d9488),
        ),
      if (canAccessAdmin)
        _ModuleCardData(
          title: 'Audit',
          subtitle: 'Change history (REST pending)',
          icon: Icons.history_edu_rounded,
          route: '/admin/audit',
          enabled: true,
          category: ModuleCategory.system,
          color: const Color(0xFF64748b), // Slate Light
        ),
    ];

    final hero = _GreetingsCard(name: name, role: role);

    final filteredModules = modules.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final searchBar = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      height: 56,
      child: Row(
        children: [
          NbIcon(
            Icons.search_rounded,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search modules, tools, and actions...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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
            padding: const EdgeInsets.only(left: 4, bottom: 16, top: 12),
            child: Text(
              category.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final double gridWidth = constraints.maxWidth;
              final int crossAxisCount = wide ? 3 : (medium ? 2 : 1);
              final double cellWidth =
                  (gridWidth - (crossAxisCount - 1) * 16.0) / crossAxisCount;
              // Taller cards on phones so subtitle doesn't clip.
              final double targetHeight = phone ? 108.0 : 96.0;
              final double dynamicAspectRatio = cellWidth / targetHeight;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categoryModules.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
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
          const SizedBox(height: 32),
        ],
      );
    }

    final hasResults = filteredModules.isNotEmpty;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          medium ? 28 : 16,
          phone ? 16 : 24,
          medium ? 28 : 16,
          phone ? 88 : 48, // room for radial menu on phones
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            const SizedBox(height: 24),
            searchBar,
            const SizedBox(height: 32),
            if (hasResults) ...[
              buildCategorySection(ModuleCategory.mySpace),
              buildCategorySection(ModuleCategory.management),
              buildCategorySection(ModuleCategory.system),
            ] else ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      NbIcon(
                        Icons.search_off_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No features match "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check the spelling or try a different term',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(child: content),
    );
  }
}

class _GreetingsCard extends StatefulWidget {
  const _GreetingsCard({
    required this.name,
    required this.role,
  });

  final String name;
  final String role;

  @override
  State<_GreetingsCard> createState() => _GreetingsCardState();
}

class _GreetingsCardState extends State<_GreetingsCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -3.0 : 0.0),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
          vertical: MediaQuery.sizeOf(context).width < 600 ? 28 : 40,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1A1816), // Premium dark cocoa charcoal
              Color(0xFF2B2722), // Deep warm bronze
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1816).withOpacity(_isHovered ? 0.45 : 0.32),
              blurRadius: _isHovered ? 28 : 24,
              offset: _isHovered ? const Offset(0, 14) : const Offset(0, 12),
            ),
            BoxShadow(
              color: const Color(0xFFC5A059).withOpacity(_isHovered ? 0.12 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFC5A059).withOpacity(_isHovered ? 0.28 : 0.18),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AnimatedDefaultTextStyle(
              duration: Duration(milliseconds: 300),
              style: TextStyle(
                color: Color(0xFFD4C3A3),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                fontFamily: 'Inter',
              ),
              child: Text('Welcome back,'),
            ),
            const SizedBox(height: 8),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: Colors.white,
                fontSize: MediaQuery.sizeOf(context).width < 600 ? 28 : 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontFamily: 'Inter',
              ),
              child: Text(widget.name),
            ),
            if (widget.role.isNotEmpty) ...[
              const SizedBox(height: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFC5A059).withOpacity(0.2),
                      const Color(0xFFC5A059).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFFC5A059).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  widget.role.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFE2D6BE),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              )
            ]
          ],
        ),
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
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = enabled),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -4.0 : 0.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered 
                ? widget.data.color.withOpacity(0.3) 
                : Theme.of(context).dividerColor.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.data.color.withOpacity(_isHovered ? 0.15 : 0.03),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 10 : 4),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width < 600 ? 14 : 18,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: MediaQuery.sizeOf(context).width < 600 ? 48 : 54,
                      height: MediaQuery.sizeOf(context).width < 600 ? 48 : 54,
                      decoration: BoxDecoration(
                        color: _isHovered 
                            ? widget.data.color 
                            : widget.data.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: NbIcon(
                        widget.data.icon,
                        color: _isHovered ? Colors.white : widget.data.color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 18),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.data.subtitle,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 13,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (enabled)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform: Matrix4.identity()..translate(_isHovered ? 4.0 : 0.0, 0.0),
                        child: NbIcon(
                          Icons.arrow_forward_rounded, 
                          color: _isHovered ? widget.data.color : Colors.grey.shade300,
                        ),
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
