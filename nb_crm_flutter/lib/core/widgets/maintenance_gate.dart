import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/app_module_cubit.dart';
import '../di/app_repositories.dart';
import '../services/branding_config.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

/// Full-screen gate for Global System Maintenance.
/// Always bypassed for Superadmin users and /platform routes.
class GlobalMaintenanceGate extends StatefulWidget {
  const GlobalMaintenanceGate({
    super.key,
    required this.child,
    this.isSuperAdmin = false,
  });

  final Widget child;
  final bool isSuperAdmin;

  @override
  State<GlobalMaintenanceGate> createState() => _GlobalMaintenanceGateState();
}

class _GlobalMaintenanceGateState extends State<GlobalMaintenanceGate> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BrandingConfig.maintenanceNotifier,
      builder: (context, _, __) {
        return BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (prev, curr) =>
              prev.isSuperAdmin != curr.isSuperAdmin || prev.status != curr.status,
          builder: (context, authState) {
            final superAdmin = widget.isSuperAdmin || authState.isSuperAdmin;
            final isGlobalDown = BrandingConfig.isGlobalMaintenance;

            if (isGlobalDown && !superAdmin) {
              return const GlobalMaintenanceScreen();
            }

            return widget.child;
          },
        );
      },
    );
  }
}

/// Standalone Full-Screen Maintenance Display for Global Platform Downtime.
class GlobalMaintenanceScreen extends StatefulWidget {
  const GlobalMaintenanceScreen({super.key});

  @override
  State<GlobalMaintenanceScreen> createState() => _GlobalMaintenanceScreenState();
}

class _GlobalMaintenanceScreenState extends State<GlobalMaintenanceScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _calculateRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    final endStr = BrandingConfig.maintenanceEstimatedEndTime;
    if (endStr != null && endStr.isNotEmpty) {
      final end = DateTime.tryParse(endStr);
      if (end != null) {
        final diff = end.difference(DateTime.now());
        setState(() {
          _remaining = diff.isNegative ? Duration.zero : diff;
        });
        return;
      }
    }
    setState(() => _remaining = Duration.zero);
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final dio = AppRepositories().dioClient;
      await BrandingConfig.fetch(dio);
    } catch (_) {}
    if (mounted) {
      _calculateRemaining();
      setState(() => _isRefreshing = false);
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final title = BrandingConfig.globalMaintenanceTitle.isNotEmpty
        ? BrandingConfig.globalMaintenanceTitle
        : 'System Under Scheduled Maintenance';
    final message = BrandingConfig.globalMaintenanceMessage.isNotEmpty
        ? BrandingConfig.globalMaintenanceMessage
        : 'NB Infra Projects LTD. platform is currently undergoing scheduled enhancements. Services will be restored shortly.';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1412),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: const Color(0xFF181F1B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFC5A059).withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC5A059).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFC5A059)),
                      ),
                      child: const Icon(
                        Icons.engineering_rounded,
                        size: 38,
                        color: Color(0xFFC5A059),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'NB INFRA PROJECTS LTD.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: Color(0xFFC5A059),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEDEDED),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFA5B2A9),
                        height: 1.5,
                      ),
                    ),
                    if (_remaining > Duration.zero) ...[
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1412),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF263229)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'ESTIMATED COMPLETION IN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                color: Color(0xFF8B988E),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDuration(_remaining),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3.0,
                                color: Color(0xFFC5A059),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _isRefreshing ? null : _refresh,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFC5A059),
                            foregroundColor: const Color(0xFF0F1412),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isRefreshing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F1412)),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            _isRefreshing ? 'Checking...' : 'Check Status',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => context.go('/login'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEDEDED),
                            side: const BorderSide(color: Color(0xFF38463D)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Admin Access'),
                        ),
                      ],
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

/// In-place view shown when an individual module (CRM, HRMS, ERP, COLLAB) is under maintenance.
class ModuleMaintenanceView extends StatefulWidget {
  const ModuleMaintenanceView({
    super.key,
    required this.moduleKey,
  });

  final String moduleKey;

  @override
  State<ModuleMaintenanceView> createState() => _ModuleMaintenanceViewState();
}

class _ModuleMaintenanceViewState extends State<ModuleMaintenanceView> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _calculateRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    final endStr = BrandingConfig.maintenanceEstimatedEndTime;
    if (endStr != null && endStr.isNotEmpty) {
      final end = DateTime.tryParse(endStr);
      if (end != null) {
        final diff = end.difference(DateTime.now());
        setState(() {
          _remaining = diff.isNegative ? Duration.zero : diff;
        });
        return;
      }
    }
    setState(() => _remaining = Duration.zero);
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final dio = AppRepositories().dioClient;
      await BrandingConfig.fetch(dio);
    } catch (_) {}
    if (mounted) {
      _calculateRemaining();
      setState(() => _isRefreshing = false);
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = BrandingConfig.getModuleMaintenance(widget.moduleKey);
    final modTitle = cfg?.title.isNotEmpty == true
        ? cfg!.title
        : '${widget.moduleKey.toUpperCase()} Module Under Maintenance';
    final modMessage = cfg?.message.isNotEmpty == true
        ? cfg!.message
        : 'The ${widget.moduleKey.toUpperCase()} suite is temporarily undergoing planned maintenance. Other platform modules remain operational.';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A201C) : Colors.white;
    final textColor = isDark ? const Color(0xFFEDEDED) : const Color(0xFF1E2822);
    final subtextColor = isDark ? const Color(0xFF9AA399) : const Color(0xFF5A665D);
    final borderColor = isDark ? const Color(0xFF2A322C) : const Color(0xFFE2E8E4);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5A059).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.build_circle_outlined,
                    size: 34,
                    color: Color(0xFFC5A059),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5A059).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'MODULE: ${widget.moduleKey.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Color(0xFFC5A059),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  modTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  modMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: subtextColor,
                    height: 1.5,
                  ),
                ),
                if (_remaining > Duration.zero) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141916) : const Color(0xFFF4F6F4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ESTIMATED COMPLETION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                            color: subtextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(_remaining),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.5,
                            color: Color(0xFFC5A059),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _isRefreshing ? null : _refresh,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC5A059),
                        foregroundColor: const Color(0xFF0F1412),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F1412)),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(_isRefreshing ? 'Checking...' : 'Refresh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Switch to a safe fallback module (e.g. HRMS if CRM is down, or ERP)
                        if (widget.moduleKey.toUpperCase() != 'HRMS' && !BrandingConfig.isModuleInMaintenance('HRMS')) {
                          context.read<AppModuleCubit>().setModule(AppModule.hrms);
                          context.go('/home');
                        } else if (widget.moduleKey.toUpperCase() != 'ERP' && !BrandingConfig.isModuleInMaintenance('ERP')) {
                          context.read<AppModuleCubit>().setModule(AppModule.erp);
                          context.go('/erp/home');
                        } else if (widget.moduleKey.toUpperCase() != 'CRM' && !BrandingConfig.isModuleInMaintenance('CRM')) {
                          context.read<AppModuleCubit>().setModule(AppModule.crm);
                          context.go('/crm/dashboard');
                        } else {
                          context.go('/home');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Go to Active Module'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
