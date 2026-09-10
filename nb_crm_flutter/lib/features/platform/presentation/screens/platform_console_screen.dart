import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/bloc_async_value.dart';
import '../../../../core/theme/nb_icon.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/platform_repository.dart';
import '../../domain/platform_models.dart';
import '../bloc/platform_console_bloc.dart';
import '../bloc/platform_console_event.dart';
import '../bloc/platform_console_state.dart';

class PlatformConsoleScreen extends StatelessWidget {
  const PlatformConsoleScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => PlatformConsoleBloc(
        repository: ctx.read<PlatformRepository>(),
      ),
      child: _PlatformConsoleScreenView(initialTab: initialTab),
    );
  }
}

class _PlatformConsoleScreenView extends StatefulWidget {
  const _PlatformConsoleScreenView({this.initialTab = 0});

  final int initialTab;

  @override
  State<_PlatformConsoleScreenView> createState() => _PlatformConsoleScreenViewState();
}

class _PlatformConsoleScreenViewState extends State<_PlatformConsoleScreenView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchCompany = '';
  String _searchAdmin = '';
  String _companyStatusFilter = 'ALL'; // ALL, ACTIVE, SUSPENDED
  String _trashFilter = 'ALL'; // ALL, COMPANIES, ADMINS

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    context.read<PlatformConsoleBloc>().add(const PlatformConsoleRefreshRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PlatformConsoleBloc, PlatformConsoleState>(
      listenWhen: (prev, curr) =>
          curr.actionError != null || curr.actionSuccessMessage != null,
      listener: (context, state) {
        if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          context.read<PlatformConsoleBloc>().add(const PlatformClearMessage());
        } else if (state.actionError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionError!),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
          context.read<PlatformConsoleBloc>().add(const PlatformClearMessage());
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        // Premium Harmonious Color Palette
        final bgColor = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
        final surfaceColor = isDark ? const Color(0xFF111827) : Colors.white;
        final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
        final textPrimary = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

        final statsAsync = BlocAsyncValue<PlatformStats>(
          status: state.status,
          value: state.stats,
          error: state.errorMessage,
        );
        final companiesAsync = BlocAsyncValue<List<ClientCompany>>(
          status: state.status,
          value: state.status.isInitial ? null : state.companies,
          error: state.errorMessage,
        );
        final adminsAsync = BlocAsyncValue<List<PlatformAdminUser>>(
          status: state.status,
          value: state.status.isInitial ? null : state.admins,
          error: state.errorMessage,
        );
        final trashAsync = BlocAsyncValue<PlatformTrashData>(
          status: state.status,
          value: state.trash,
          error: state.errorMessage,
        );

    final isMobile = MediaQuery.sizeOf(context).width < 650;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNavbar(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, statsAsync),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 14 : 24,
                        vertical: isMobile ? 16 : 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroSection(context, isDark, textPrimary, textSecondary),
                          SizedBox(height: isMobile ? 16 : 20),
                          _buildMetricsGrid(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, statsAsync),
                          SizedBox(height: isMobile ? 18 : 24),
                          _buildSegmentedTabBar(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary),
                          SizedBox(height: isMobile ? 16 : 20),
                          _buildActiveTabContent(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, statsAsync, companiesAsync, adminsAsync, trashAsync),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP NAVBAR (Responsive, prevents overflow on mobile)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTopNavbar(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    BlocAsyncValue<PlatformStats> statsAsync,
  ) {
    final auth = context.watch<AuthBloc>().state;
    final username = auth.user?.username ?? 'superadmin';
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 650;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 28, vertical: isMobile ? 10 : 14),
      child: Row(
        children: [
          // Platform Brand Logo
          Container(
            width: isMobile ? 36 : 42,
            height: isMobile ? 36 : 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor.withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/nbdeveloperlogo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF6366F1),
                  alignment: Alignment.center,
                  child: const Text(
                    'NB',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NB Suite',
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'SaaS Platform',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF818CF8),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isMobile) ...[
                  const SizedBox(height: 2),
                  Text(
                    'CRM • HRMS • ERP Multi-Tenant Management',
                    style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          // Actions
          if (!isMobile)
            statsAsync.maybeWhen(
              data: (stats) {
                final isOk = stats.dbStatus == 'HEALTHY';
                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isOk ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isOk ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isOk ? const Color(0xFF10B981) : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOk ? 'System Healthy' : 'Degraded',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOk ? const Color(0xFF10B981) : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          IconButton(
            onPressed: _refreshAll,
            tooltip: 'Refresh Data',
            icon: NbIcon(Icons.refresh_rounded, size: 18, color: textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            style: IconButton.styleFrom(
              backgroundColor: borderColor.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => context.read<ThemeCubit>().toggleTheme(),
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
            icon: NbIcon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 18, color: textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            style: IconButton.styleFrom(
              backgroundColor: borderColor.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          // User chip / Sign out
          PopupMenuButton<String>(
            tooltip: 'Account Settings',
            onSelected: (val) {
              if (val == 'logout') {
                context.read<AuthBloc>().add(const AuthLogoutRequested());
              }
            },
            offset: const Offset(0, 42),
            color: surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: borderColor),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary, fontSize: 13),
                    ),
                    Text(
                      'Root Superadmin',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 16, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: 5),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFF6366F1),
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'S',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 6),
                    Text(
                      username,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded, size: 16, color: textSecondary),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HERO SECTION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeroSection(BuildContext context, bool isDark, Color textPrimary, Color textSecondary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        final onboardBtn = Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showOnboardCompanyDialog(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20,
                  vertical: isMobile ? 12 : 14,
                ),
                child: Row(
                  mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    NbIcon(Icons.add_business_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Onboard Company',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Multi-Tenant Administration',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Onboard client companies, provision root System Admins, and configure module subscriptions.',
                style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.35),
              ),
              const SizedBox(height: 14),
              onboardBtn,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Multi-Tenant Administration',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Onboard client companies, provision root System Admins, configure subscribed module packages, and oversee engine health.',
                    style: TextStyle(fontSize: 13.5, color: textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            onboardBtn,
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // METRICS GRID (Responsive Multi-Column)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMetricsGrid(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    BlocAsyncValue<PlatformStats> statsAsync,
  ) {
    return statsAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Failed to load metrics: $e', style: const TextStyle(color: Colors.red)),
      data: (stats) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isMobile = width < 600;
            final int crossCount = width > 1200 ? 5 : (width > 800 ? 3 : 2);
            final double spacing = isMobile ? 10 : 14;
            final double cardWidth = (width - ((crossCount - 1) * spacing)) / crossCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _buildMetricCard(
                  width: cardWidth,
                  isMobile: isMobile,
                  title: 'Client Companies',
                  value: '${stats.totalCompanies}',
                  subtitle: '${stats.activeCompanies} Active Tenants',
                  icon: Icons.apartment_rounded,
                  color: const Color(0xFF38BDF8), // Crisp Sky
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _tabController.animateTo(0),
                ),
                _buildMetricCard(
                  width: cardWidth,
                  isMobile: isMobile,
                  title: 'System Admins',
                  value: '${stats.totalSystemAdmins}',
                  subtitle: 'Root Administrators',
                  icon: Icons.admin_panel_settings_rounded,
                  color: const Color(0xFF34D399), // Emerald
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _tabController.animateTo(1),
                ),
                _buildMetricCard(
                  width: cardWidth,
                  isMobile: isMobile,
                  title: 'Platform Users',
                  value: '${stats.totalUsers}',
                  subtitle: 'Across All Tenants',
                  icon: Icons.group_rounded,
                  color: const Color(0xFFA78BFA), // Violet
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _buildMetricCard(
                  width: cardWidth,
                  isMobile: isMobile,
                  title: 'Engine & Database',
                  value: stats.dbStatus == 'HEALTHY' ? 'Operational' : 'Degraded',
                  subtitle: 'PostgreSQL & Redis Online',
                  icon: Icons.dns_rounded,
                  color: stats.dbStatus == 'HEALTHY' ? const Color(0xFF22D3EE) : const Color(0xFFF87171),
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _tabController.animateTo(3),
                ),
                _buildMetricCard(
                  width: cardWidth,
                  isMobile: isMobile,
                  title: 'Trash Bin',
                  value: '${stats.totalTrash}',
                  subtitle: '30-Day Auto Purge',
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFF43F5E), // Rose
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _tabController.animateTo(4),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard({
    required double width,
    required bool isMobile,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    VoidCallback? onTap,
  }) {
    final card = Container(
      width: width,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: isMobile ? 32 : 38,
                height: isMobile ? 32 : 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: NbIcon(icon, color: color, size: isMobile ? 16 : 20),
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward_rounded, size: 14, color: textSecondary.withValues(alpha: 0.6)),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: isMobile ? 9.5 : 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      );
    }
    return card;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEGMENTED TAB SWITCHER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSegmentedTabBar(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
        tabs: const [
          Tab(
            icon: NbIcon(Icons.business_rounded, size: 15),
            text: 'Tenants',
          ),
          Tab(
            icon: NbIcon(Icons.admin_panel_settings_rounded, size: 15),
            text: 'System Admins',
          ),
          Tab(
            icon: NbIcon(Icons.apps_rounded, size: 15),
            text: 'Module Licensing',
          ),
          Tab(
            icon: NbIcon(Icons.monitor_heart_rounded, size: 15),
            text: 'Platform Health',
          ),
          Tab(
            icon: NbIcon(Icons.delete_outline_rounded, size: 15),
            text: 'Trash Bin',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIVE TAB CONTENT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildActiveTabContent(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    BlocAsyncValue<PlatformStats> statsAsync,
    BlocAsyncValue<List<ClientCompany>> companiesAsync,
    BlocAsyncValue<List<PlatformAdminUser>> adminsAsync,
    BlocAsyncValue<PlatformTrashData> trashAsync,
  ) {
    switch (_tabController.index) {
      case 0:
        return _buildCompaniesTab(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, companiesAsync);
      case 1:
        return _buildAdminsTab(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, adminsAsync);
      case 2:
        return _buildModulesTab(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, companiesAsync);
      case 3:
        return _buildDiagnosticsTab(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, statsAsync);
      case 4:
      default:
        return _buildTrashTab(context, isDark, surfaceColor, borderColor, textPrimary, textSecondary, trashAsync);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: CLIENT COMPANIES (TENANTS)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCompaniesTab(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    BlocAsyncValue<List<ClientCompany>> companiesAsync,
  ) {
    return companiesAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Error loading companies: $e', style: const TextStyle(color: Colors.red))),
      data: (companies) {
        final filtered = companies.where((c) {
          if (_companyStatusFilter == 'ACTIVE' && !c.isActive) return false;
          if (_companyStatusFilter == 'SUSPENDED' && c.isActive) return false;
          if (_searchCompany.isEmpty) return true;
          final q = _searchCompany.toLowerCase();
          return c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q) ||
              (c.contactPerson ?? '').toLowerCase().contains(q) ||
              (c.primaryAdminUsername ?? '').toLowerCase().contains(q);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        NbIcon(Icons.search_rounded, size: 18, color: textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            style: TextStyle(fontSize: 14, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search client companies by name, code, contact or admin...',
                              hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (val) => setState(() => _searchCompany = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Status Filter Chips
                Wrap(
                  spacing: 6,
                  children: [
                    _buildFilterChip('All (${companies.length})', 'ALL', isDark, surfaceColor, borderColor, textPrimary),
                    _buildFilterChip('Active (${companies.where((c) => c.isActive).length})', 'ACTIVE', isDark, surfaceColor, borderColor, textPrimary),
                    _buildFilterChip('Suspended (${companies.where((c) => !c.isActive).length})', 'SUSPENDED', isDark, surfaceColor, borderColor, textPrimary),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NbIcon(Icons.business_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'No matching client companies',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try adjusting your search criteria or onboard a new client company.',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final company = filtered[index];
                  return _buildCompanyCard(context, company, isDark, surfaceColor, borderColor, textPrimary, textSecondary);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary) {
    final isSelected = _companyStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _companyStatusFilter = value);
      },
      selectedColor: const Color(0xFF4F46E5),
      backgroundColor: surfaceColor,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : textPrimary,
      ),
      side: BorderSide(color: isSelected ? const Color(0xFF4F46E5) : borderColor, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
    );
  }

  Widget _buildCompanyCard(
    BuildContext context,
    ClientCompany company,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: company.isActive ? borderColor : const Color(0xFFEF4444).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: company.isActive
                      ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: NbIcon(
                    Icons.apartment_rounded,
                    color: company.isActive ? const Color(0xFF6366F1) : const Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          company.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: borderColor.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            company.code,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: company.isActive
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            company.isActive ? 'ACTIVE' : 'SUSPENDED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: company.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contact: ${company.contactPerson ?? 'N/A'} • Email: ${company.email ?? 'N/A'} • Phone: ${company.mobileNo ?? 'N/A'}',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              // Entitlements Button
              OutlinedButton.icon(
                onPressed: () => _showEntitlementsDialog(context, company),
                icon: const NbIcon(Icons.tune_rounded, size: 15),
                label: const Text('Entitlements'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              // Suspend / Activate Toggle
              FilledButton.tonalIcon(
                onPressed: () => _toggleCompanyStatus(company),
                icon: NbIcon(
                  company.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                  size: 15,
                  color: company.isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
                label: Text(
                  company.isActive ? 'Suspend' : 'Activate',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: company.isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: company.isActive
                      ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                      : const Color(0xFF10B981).withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              // Move to Trash Button
              IconButton(
                onPressed: () => _confirmTrashCompany(company),
                tooltip: 'Move to Trash (30 Days Retention)',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const NbIcon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Subscribed Modules: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
              ),
              const SizedBox(width: 6),
              Wrap(
                spacing: 6,
                children: [
                  _buildModuleBadge('HRMS', company.enabledModules.contains('HRMS'), const Color(0xFF10B981)),
                  _buildModuleBadge('CRM', company.enabledModules.contains('CRM'), const Color(0xFF6366F1)),
                  _buildModuleBadge('ERP', company.enabledModules.contains('ERP'), const Color(0xFFF59E0B)),
                ],
              ),
              const Spacer(),
              NbIcon(Icons.person_rounded, size: 15, color: textSecondary),
              const SizedBox(width: 4),
              Text(
                'System Admin: ',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              Text(
                company.primaryAdminUsername ?? 'Unassigned',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textPrimary),
              ),
              const SizedBox(width: 16),
              NbIcon(Icons.groups_rounded, size: 15, color: textSecondary),
              const SizedBox(width: 4),
              Text(
                'Total Users: ${company.userCount}',
                style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModuleBadge(String label, bool isEnabled, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isEnabled ? color.withValues(alpha: 0.14) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isEnabled ? color.withValues(alpha: 0.35) : Colors.transparent,
        ),
      ),
      child: Text(
        isEnabled ? '✓ $label' : '✕ $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isEnabled ? color : Colors.grey,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: COMPANY SYSTEM ADMINS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAdminsTab(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    BlocAsyncValue<List<PlatformAdminUser>> adminsAsync,
  ) {
    return adminsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Error loading admins: $e', style: const TextStyle(color: Colors.red))),
      data: (admins) {
        final filtered = admins.where((a) {
          if (_searchAdmin.isEmpty) return true;
          final q = _searchAdmin.toLowerCase();
          return a.username.toLowerCase().contains(q) ||
              a.companyName.toLowerCase().contains(q);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  NbIcon(Icons.search_rounded, size: 18, color: textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      style: TextStyle(fontSize: 14, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search system admins by username or client company...',
                        hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchAdmin = val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final admin = filtered[index];
                return _buildAdminCard(context, admin, isDark, surfaceColor, borderColor, textPrimary, textSecondary);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminCard(
    BuildContext context,
    PlatformAdminUser admin,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isLocked = admin.loginBlocked || admin.loginTemporarilyLocked;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLocked ? const Color(0xFFEF4444).withValues(alpha: 0.35) : borderColor,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
            child: const NbIcon(Icons.admin_panel_settings_rounded, color: Color(0xFF818CF8), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      admin.username,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        admin.companyName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF818CF8),
                        ),
                      ),
                    ),
                    if (isLocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LOCKED OUT',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Created: ${admin.createdAt.split('T').first} • Last Login: ${admin.lastLoginAt != null ? admin.lastLoginAt!.split('T').first : 'Never'} • Fails: ${admin.loginFailCount}',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor.withValues(alpha: 0.8)),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline_rounded, size: 14, color: textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Username: ',
                            style: TextStyle(fontSize: 11.5, color: textSecondary, fontWeight: FontWeight.w600),
                          ),
                          SelectableText(
                            admin.username,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: textPrimary),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 13),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            tooltip: 'Copy Username',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: admin.username));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Username "${admin.username}" copied to clipboard'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            'Password: ',
                            style: TextStyle(fontSize: 11.5, color: textSecondary, fontWeight: FontWeight.w600),
                          ),
                          SelectableText(
                            admin.plainPassword ?? '01011998',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFFF59E0B)),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            tooltip: 'Copy Password',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: admin.plainPassword ?? '01011998'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isLocked) ...[
            FilledButton.icon(
              onPressed: () => _unlockAdmin(admin),
              icon: const NbIcon(Icons.lock_open_rounded, size: 15),
              label: const Text('Unlock Account'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton.icon(
            onPressed: () => _showResetPasswordDialog(context, admin),
            icon: const NbIcon(Icons.key_rounded, size: 15),
            label: const Text('Reset Password'),
            style: OutlinedButton.styleFrom(
              foregroundColor: textPrimary,
              side: BorderSide(color: borderColor),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (admin.username.toLowerCase() != 'superadmin') ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _confirmTrashAdmin(admin),
              tooltip: 'Move to Trash (30 Days Retention)',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const NbIcon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: MODULE LICENSING & ENTITLEMENTS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildModulesTab(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    BlocAsyncValue<List<ClientCompany>> companiesAsync,
  ) {
    return companiesAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      data: (companies) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Module Entitlements Matrix',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Instantly toggle CRM, HRMS, and ERP suite privileges per client company.',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 20),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(1.5),
                },
                border: TableBorder.all(
                  color: borderColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: borderColor.withValues(alpha: 0.35),
                    ),
                    children: [
                      _buildHeaderCell('Company', textPrimary),
                      _buildHeaderCell('HRMS Suite', textPrimary),
                      _buildHeaderCell('CRM Suite', textPrimary),
                      _buildHeaderCell('ERP Suite', textPrimary),
                      _buildHeaderCell('Actions', textPrimary),
                    ],
                  ),
                  for (final company in companies)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(company.name, style: TextStyle(fontWeight: FontWeight.w800, color: textPrimary)),
                              Text('Code: ${company.code}', style: TextStyle(fontSize: 11, color: textSecondary)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Switch(
                            value: company.enabledModules.contains('HRMS'),
                            activeThumbColor: const Color(0xFF10B981),
                            onChanged: (val) => _quickToggleModule(company, 'HRMS', val),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Switch(
                            value: company.enabledModules.contains('CRM'),
                            activeThumbColor: const Color(0xFF6366F1),
                            onChanged: (val) => _quickToggleModule(company, 'CRM', val),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Switch(
                            value: company.enabledModules.contains('ERP'),
                            activeThumbColor: const Color(0xFFF59E0B),
                            onChanged: (val) => _quickToggleModule(company, 'ERP', val),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: OutlinedButton(
                            onPressed: () => _showEntitlementsDialog(context, company),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textPrimary,
                              side: BorderSide(color: borderColor),
                            ),
                            child: const Text('Configure'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCell(String title, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: textPrimary),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 4: PLATFORM DIAGNOSTICS & HEALTH
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDiagnosticsTab(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    BlocAsyncValue<PlatformStats> statsAsync,
  ) {
    return statsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      data: (stats) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SaaS Platform Diagnostics',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary),
              ),
              const SizedBox(height: 16),
              _buildDiagRow('Database Engine', stats.dbStatus == 'HEALTHY' ? 'Connected (PostgreSQL)' : 'Degraded', stats.dbStatus == 'HEALTHY' ? const Color(0xFF10B981) : Colors.red, textPrimary, borderColor),
              _buildDiagRow('Session Cache', stats.redisStatus == 'CONNECTED' ? 'Online (Redis)' : 'Local Fallback', stats.redisStatus == 'CONNECTED' ? const Color(0xFF10B981) : Colors.orange, textPrimary, borderColor),
              _buildDiagRow('Platform Version', stats.platformVersion, const Color(0xFF818CF8), textPrimary, borderColor),
              _buildDiagRow('Server Uptime', '${stats.uptimeSeconds ~/ 3600}h ${(stats.uptimeSeconds % 3600) ~/ 60}m', const Color(0xFF38BDF8), textPrimary, borderColor),
              _buildDiagRow('Total Multi-Tenant Companies', '${stats.totalCompanies} Provisioned', textPrimary, textPrimary, borderColor),
              _buildDiagRow('System Admin Accounts', '${stats.totalSystemAdmins} Active', textPrimary, textPrimary, borderColor, isLast: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagRow(String label, String value, Color statusColor, Color textPrimary, Color borderColor, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.w800, color: statusColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: borderColor),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 5: TRASH RETENTION BIN (30 DAYS)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTrashTab(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    BlocAsyncValue<PlatformTrashData> trashAsync,
  ) {
    return trashAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NbIcon(Icons.error_outline_rounded, size: 40, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load trash bin: $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _refreshAll,
                icon: const NbIcon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (trashData) {
        final companies = trashData.companies;
        final admins = trashData.admins;
        final totalCount = companies.length + admins.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar with info and Empty Trash button
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
              ),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: NbIcon(Icons.delete_sweep_rounded, color: Color(0xFFF43F5E), size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '30-Day Trash Retention Bin',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$totalCount ${totalCount == 1 ? 'Item' : 'Items'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF43F5E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Items moved to trash are automatically purged after 30 days if not restored. You can restore them or permanently delete them anytime.',
                          style: TextStyle(fontSize: 12, color: textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  if (totalCount > 0) ...[
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () => _confirmEmptyTrash(),
                      icon: const NbIcon(Icons.delete_forever_rounded, size: 16, color: Colors.white),
                      label: const Text('Empty Trash'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter Chips: All, Companies, Admins
            Wrap(
              spacing: 8,
              children: [
                _buildTrashFilterChip('All Items ($totalCount)', 'ALL', isDark, surfaceColor, borderColor, textPrimary),
                _buildTrashFilterChip('Companies (${companies.length})', 'COMPANIES', isDark, surfaceColor, borderColor, textPrimary),
                _buildTrashFilterChip('System Admins (${admins.length})', 'ADMINS', isDark, surfaceColor, borderColor, textPrimary),
              ],
            ),
            const SizedBox(height: 16),

            // Items listing or empty state
            if (totalCount == 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: NbIcon(Icons.check_circle_outline_rounded, size: 36, color: Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Trash Bin is Empty',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No client companies or system administrators are currently in trash.',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  // Companies
                  if (_trashFilter == 'ALL' || _trashFilter == 'COMPANIES')
                    ...companies.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTrashItemCard(
                            context: context,
                            item: c,
                            isCompany: true,
                            isDark: isDark,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        )),
                  // Admins
                  if (_trashFilter == 'ALL' || _trashFilter == 'ADMINS')
                    ...admins.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTrashItemCard(
                            context: context,
                            item: a,
                            isCompany: false,
                            isDark: isDark,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        )),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildTrashItemCard({
    required BuildContext context,
    required PlatformTrashItem item,
    required bool isCompany,
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final deletedDateStr = item.deletedAt.split('T').first;
    final expiresDateStr = item.expiresAt.split('T').first;
    final isUrgent = item.daysRemaining <= 5;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUrgent ? const Color(0xFFEF4444).withValues(alpha: 0.4) : borderColor,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isCompany
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.12)
                  : const Color(0xFF34D399).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: NbIcon(
                isCompany ? Icons.apartment_rounded : Icons.admin_panel_settings_rounded,
                color: isCompany ? const Color(0xFF38BDF8) : const Color(0xFF34D399),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCompany ? (item.code ?? 'COMPANY') : 'SYSTEM ADMIN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Countdown badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NbIcon(
                            Icons.timer_outlined,
                            size: 12,
                            color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.daysRemaining > 0 ? '${item.daysRemaining} days left' : 'Expiring Today',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final detail = isCompany ? (item.contactPerson ?? item.email) : item.companyName;
                    return Text(
                      'Deleted: $deletedDateStr • Auto-purge: $expiresDateStr${detail != null ? ' • $detail' : ''}',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Actions: Restore & Permanent Delete
          FilledButton.tonalIcon(
            onPressed: () => isCompany ? _confirmRestoreCompany(item) : _confirmRestoreAdmin(item),
            icon: const NbIcon(Icons.restore_from_trash_rounded, size: 15, color: Color(0xFF10B981)),
            label: const Text(
              'Restore',
              style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => isCompany ? _confirmPurgeCompany(item) : _confirmPurgeAdmin(item),
            icon: const NbIcon(Icons.delete_forever_rounded, size: 15, color: Color(0xFFEF4444)),
            label: const Text(
              'Delete Forever',
              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashFilterChip(String label, String value, bool isDark, Color surfaceColor, Color borderColor, Color textPrimary) {
    final isSelected = _trashFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _trashFilter = value),
      selectedColor: const Color(0xFF4F46E5),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isSelected ? Colors.white : textPrimary,
      ),
      backgroundColor: surfaceColor,
      side: BorderSide(color: isSelected ? const Color(0xFF4F46E5) : borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODALS & ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════
  Future<String?> _promptSuperAdminPasswordConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmButtonLabel,
    bool isDestructive = true,
  }) async {
    final passCtrl = TextEditingController();
    bool obscurePassword = true;
    String? validationError;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = isDestructive ? const Color(0xFFEF4444) : const Color(0xFF4F46E5);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: NbIcon(
                      isDestructive ? Icons.warning_amber_rounded : Icons.lock_outline_rounded,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          NbIcon(Icons.shield_outlined, size: 18, color: primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'SuperAdmin authentication required. Enter your SuperAdmin password to execute this operation.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passCtrl,
                      obscureText: obscurePassword,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'SuperAdmin Password *',
                        hintText: 'Enter your superadmin password',
                        errorText: validationError,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.password_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isEmpty) {
                          setDialogState(() => validationError = 'Password is required');
                        } else {
                          Navigator.of(ctx).pop(val.trim());
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final pwd = passCtrl.text.trim();
                    if (pwd.isEmpty) {
                      setDialogState(() => validationError = 'Password is required to proceed');
                      return;
                    }
                    Navigator.of(ctx).pop(pwd);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(confirmButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmTrashCompany(ClientCompany company) async {
    final repo = context.read<PlatformRepository>();
    final password = await _promptSuperAdminPasswordConfirmation(
      context: context,
      title: 'Move Company to Trash',
      message: 'Company "${company.name}" and all of its associated users will be deactivated and moved to Trash for 30 days.',
      confirmButtonLabel: 'Move to Trash',
      isDestructive: true,
    );

    if (password == null) return;

    try {
      await repo.trashCompany(company.id, superadminPassword: password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Company "${company.name}" moved to trash (30-day retention)'),
            backgroundColor: Colors.orange,
          ),
        );
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move company to trash: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmTrashAdmin(PlatformAdminUser admin) async {
    final repo = context.read<PlatformRepository>();
    final password = await _promptSuperAdminPasswordConfirmation(
      context: context,
      title: 'Move Admin to Trash',
      message: 'System admin account "${admin.username}" (${admin.companyName}) will be deactivated and moved to Trash for 30 days.',
      confirmButtonLabel: 'Move to Trash',
      isDestructive: true,
    );

    if (password == null) return;

    try {
      await repo.trashAdmin(admin.id, superadminPassword: password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System admin "${admin.username}" moved to trash (30-day retention)'),
            backgroundColor: Colors.orange,
          ),
        );
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move admin to trash: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmRestoreCompany(PlatformTrashItem item) async {
    final repo = context.read<PlatformRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const NbIcon(Icons.restore_from_trash_rounded, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 10),
            Expanded(child: Text('Restore Company "${item.name}"?')),
          ],
        ),
        content: Text('Reactivate company "${item.name}" and restore all associated tenant services and users?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Restore Company'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await repo.restoreCompany(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Company "${item.name}" restored successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshAll();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to restore company: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmPurgeCompany(PlatformTrashItem item) async {
    final repo = context.read<PlatformRepository>();
    final password = await _promptSuperAdminPasswordConfirmation(
      context: context,
      title: 'Permanently Delete Company',
      message: '⚠️ This will PERMANENTLY ERASE company "${item.name}", its departments, employees, settings, and all records immediately.\n\nTHIS ACTION CANNOT BE UNDONE.',
      confirmButtonLabel: 'Delete Forever',
      isDestructive: true,
    );

    if (password == null) return;

    try {
      await repo.purgeCompany(item.id, superadminPassword: password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Company "${item.name}" permanently deleted'),
            backgroundColor: Colors.red,
          ),
        );
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete company: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmRestoreAdmin(PlatformTrashItem item) async {
    final repo = context.read<PlatformRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const NbIcon(Icons.restore_from_trash_rounded, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 10),
            Expanded(child: Text('Restore System Admin "${item.name}"?')),
          ],
        ),
        content: Text('Reactivate administrator "${item.name}" and allow sign-in?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Restore Admin'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await repo.restoreAdmin(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('System admin "${item.name}" restored successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshAll();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to restore admin: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmPurgeAdmin(PlatformTrashItem item) async {
    final repo = context.read<PlatformRepository>();
    final password = await _promptSuperAdminPasswordConfirmation(
      context: context,
      title: 'Permanently Delete Admin',
      message: '⚠️ This will PERMANENTLY DELETE system admin account "${item.name}".\n\nTHIS ACTION CANNOT BE UNDONE.',
      confirmButtonLabel: 'Delete Forever',
      isDestructive: true,
    );

    if (password == null) return;

    try {
      await repo.purgeAdmin(item.id, superadminPassword: password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System admin "${item.name}" permanently deleted'),
            backgroundColor: Colors.red,
          ),
        );
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete admin: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmEmptyTrash() async {
    final repo = context.read<PlatformRepository>();
    final password = await _promptSuperAdminPasswordConfirmation(
      context: context,
      title: 'Empty Entire Trash Bin',
      message: '⚠️ WARNING: This will permanently delete ALL companies and system administrators currently in the trash bin.\n\nTHIS ACTION CANNOT BE UNDONE.',
      confirmButtonLabel: 'Empty Trash Now',
      isDestructive: true,
    );

    if (password == null) return;

    try {
      await repo.emptyTrash(superadminPassword: password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trash bin completely emptied'),
            backgroundColor: Colors.red,
          ),
        );
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to empty trash: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showOnboardCompanyDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final adminUserCtrl = TextEditingController();
    final adminPassCtrl = TextEditingController(text: '01011998');
    final modules = <String>{'HRMS', 'CRM', 'ERP'};

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  NbIcon(Icons.add_business_rounded, color: Color(0xFF4F46E5)),
                  SizedBox(width: 10),
                  Text('Onboard New Client Company'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Company Profile',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Company Name *',
                          hintText: 'e.g. Acme Corporation',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          if (codeCtrl.text.isEmpty || codeCtrl.text == val.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().take(8)) {
                            codeCtrl.text = val.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase().take(8);
                          }
                          if (adminUserCtrl.text.isEmpty || adminUserCtrl.text == '${val.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}_admin') {
                            adminUserCtrl.text = '${val.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}_admin';
                          }
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: codeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Company Code *',
                                hintText: 'e.g. ACME',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: contactCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Contact Person',
                                hintText: 'e.g. John Doe',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'admin@acme.com',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                hintText: '+91 9876543210',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '2. Subscribed Suite Modules',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('HRMS Suite'),
                            selected: modules.contains('HRMS'),
                            onSelected: (v) => setDialogState(() => v ? modules.add('HRMS') : modules.remove('HRMS')),
                          ),
                          FilterChip(
                            label: const Text('CRM Suite'),
                            selected: modules.contains('CRM'),
                            onSelected: (v) => setDialogState(() => v ? modules.add('CRM') : modules.remove('CRM')),
                          ),
                          FilterChip(
                            label: const Text('ERP Suite'),
                            selected: modules.contains('ERP'),
                            onSelected: (v) => setDialogState(() => v ? modules.add('ERP') : modules.remove('ERP')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '3. Root Company System Admin Account',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'This admin account will be handed over to the client company to manage their CRM/HRMS.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: adminUserCtrl,
                        decoration: const InputDecoration(
                          labelText: 'System Admin Username *',
                          hintText: 'e.g. acme_admin',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: adminPassCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Initial Password *',
                          hintText: 'Minimum 6 characters',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty ||
                        codeCtrl.text.trim().isEmpty ||
                        adminUserCtrl.text.trim().isEmpty ||
                        adminPassCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required fields')),
                      );
                      return;
                    }

                    try {
                      final repo = context.read<PlatformRepository>();
                      await repo.onboardCompany({
                        'name': nameCtrl.text.trim(),
                        'code': codeCtrl.text.trim(),
                        'contactPerson': contactCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'mobileNo': phoneCtrl.text.trim(),
                        'enabledModules': modules.toList(),
                        'adminUsername': adminUserCtrl.text.trim(),
                        'adminPassword': adminPassCtrl.text.trim(),
                      });

                      if (context.mounted) {
                        Navigator.of(dialogCtx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Company "${nameCtrl.text.trim()}" and admin "${adminUserCtrl.text.trim()}" onboarded successfully!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _refreshAll();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Onboard & Provision Admin'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleCompanyStatus(ClientCompany company) async {
    final newStatus = !company.isActive;
    try {
      final repo = context.read<PlatformRepository>();
      await repo.updateCompany(company.id, {'isActive': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Company "${company.name}" ${newStatus ? 'activated' : 'suspended'} successfully',
            ),
          ),
        );
      }
      _refreshAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _quickToggleModule(ClientCompany company, String mod, bool enable) async {
    final updated = List<String>.from(company.enabledModules);
    if (enable && !updated.contains(mod)) {
      updated.add(mod);
    } else if (!enable && updated.contains(mod)) {
      updated.remove(mod);
    }

    try {
      final repo = context.read<PlatformRepository>();
      await repo.updateCompany(company.id, {'enabledModules': updated});
      _refreshAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update module: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showEntitlementsDialog(BuildContext context, ClientCompany company) async {
    final modules = Set<String>.from(company.enabledModules);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Module Entitlements: ${company.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('HRMS Suite (Workforce, Attendance, Leave, Payroll)'),
                    value: modules.contains('HRMS'),
                    onChanged: (v) => setDialogState(() => v! ? modules.add('HRMS') : modules.remove('HRMS')),
                  ),
                  CheckboxListTile(
                    title: const Text('CRM Suite (Pre-sales, Post-sales, Deals, Bin)'),
                    value: modules.contains('CRM'),
                    onChanged: (v) => setDialogState(() => v! ? modules.add('CRM') : modules.remove('CRM')),
                  ),
                  CheckboxListTile(
                    title: const Text('ERP Suite (Projects, Work Orders, Store, DPR)'),
                    value: modules.contains('ERP'),
                    onChanged: (v) => setDialogState(() => v! ? modules.add('ERP') : modules.remove('ERP')),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    try {
                      final repo = context.read<PlatformRepository>();
                      await repo.updateCompany(company.id, {'enabledModules': modules.toList()});
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Entitlements updated successfully')),
                        );
                        _refreshAll();
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Save Entitlements'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _unlockAdmin(PlatformAdminUser admin) async {
    try {
      final repo = context.read<PlatformRepository>();
      await repo.unlockAdminAccount(admin.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System admin "${admin.username}" unlocked successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _refreshAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unlock: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showResetPasswordDialog(BuildContext context, PlatformAdminUser admin) async {
    final passCtrl = TextEditingController(text: '01011998');

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Reset Password: ${admin.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reset the master password for ${admin.username} (${admin.companyName}).'),
              const SizedBox(height: 16),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (passCtrl.text.trim().length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }
                try {
                  final repo = context.read<PlatformRepository>();
                  await repo.resetAdminPassword(admin.id, passCtrl.text.trim());
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Password reset successfully for ${admin.username}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _refreshAll();
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Reset Password'),
            ),
          ],
        );
      },
    );
  }
}

extension _StringExtension on String {
  String take(int n) {
    if (length <= n) return this;
    return substring(0, n);
  }
}
