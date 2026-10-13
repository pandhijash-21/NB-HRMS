import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/domain/permissions.dart';
import '../../data/crm_repository.dart';
import '../bloc/crm_leads_bloc.dart';

const String kActiveCrmScopePrefKey = 'active_crm_scope';

/// Interactive CRM Scope Switcher Dropdown
/// Allows instant switching between NB Developer CRM (Real Estate) and NB Finserve CRM (Financial Services).
class CrmScopeSelectorWidget extends StatefulWidget {
  final VoidCallback? onScopeChanged;
  final bool compact;
  final bool iconOnly;
  final bool isSidebar;

  const CrmScopeSelectorWidget({
    super.key,
    this.onScopeChanged,
    this.compact = false,
    this.iconOnly = false,
    this.isSidebar = false,
  });

  @override
  State<CrmScopeSelectorWidget> createState() => _CrmScopeSelectorWidgetState();
}

class _CrmScopeSelectorWidgetState extends State<CrmScopeSelectorWidget> {
  @override
  void initState() {
    super.initState();
    _restorePersistedScope();
  }

  Future<void> _restorePersistedScope() async {
    try {
      final authState = context.read<AuthBloc>().state;
      final perms = authState.permissions;
      final role = authState.user?.role;
      final canAccessDev = Permissions.canAccessDeveloperCrm(perms, role);
      final canAccessFin = Permissions.canAccessFinserveCrm(perms, role);

      final repo = context.read<CrmRepository>();

      if (!canAccessDev && canAccessFin) {
        repo.setScope('NB_FINSERVE');
        return;
      }
      if (canAccessDev && !canAccessFin) {
        repo.setScope('NB_DEVELOPER');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final savedScope = prefs.getString(kActiveCrmScopePrefKey);
      if (savedScope != null && mounted) {
        if (repo.scope != savedScope) {
          repo.setScope(savedScope);
        }
      }
    } catch (_) {}
  }

  Future<void> _onSelectScope(String newScope) async {
    final repo = context.read<CrmRepository>();
    if (repo.scope == newScope) return;

    repo.setScope(newScope);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kActiveCrmScopePrefKey, newScope);
    } catch (_) {}

    if (mounted) {
      // If CrmLeadsBloc is present in context, reload leads
      try {
        context.read<CrmLeadsBloc>().add(const CrmLeadsLoadRequested());
      } catch (_) {}

      if (widget.onScopeChanged != null) {
        widget.onScopeChanged!();
      }

      final isFinserve = newScope == 'NB_FINSERVE';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isFinserve ? Icons.account_balance_wallet_rounded : Icons.apartment_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                isFinserve
                    ? 'Switched to NB Finserve CRM'
                    : 'Switched to NB Developer CRM',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          backgroundColor: isFinserve ? const Color(0xFF1D4ED8) : const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = context.watch<CrmRepository>();
    final authState = context.watch<AuthBloc>().state;
    final perms = authState.permissions;
    final role = authState.user?.role;

    final canAccessDev = Permissions.canAccessDeveloperCrm(perms, role);
    final canAccessFin = Permissions.canAccessFinserveCrm(perms, role);

    return ValueListenableBuilder<String>(
      valueListenable: repo.scopeNotifier,
      builder: (context, currentScope, _) {
        final isFinserve = currentScope == 'NB_FINSERVE';

        final items = <PopupMenuEntry<String>>[];

        if (canAccessDev) {
          items.add(
            PopupMenuItem<String>(
              value: 'NB_DEVELOPER',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: Color(0xFF0D9488),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NB Developer CRM',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Real Estate & Towers',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isFinserve)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF0D9488),
                      size: 18,
                    ),
                ],
              ),
            ),
          );
        }

        if (canAccessDev && canAccessFin) {
          items.add(const PopupMenuDivider());
        }

        if (canAccessFin) {
          items.add(
            PopupMenuItem<String>(
              value: 'NB_FINSERVE',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFF2563EB),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NB Finserve CRM',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Financial Services & Loans',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isFinserve)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2563EB),
                      size: 18,
                    ),
                ],
              ),
            ),
          );
        }

        final canSwitch = canAccessDev && canAccessFin;

        final onDarkSurface = widget.isSidebar || isDark;

        final Color cardBg;
        final Color borderColor;
        final Color titleColor;
        final Color subtitleColor;
        final Color iconColor;
        final Color chevronColor;

        if (onDarkSurface) {
          if (isFinserve) {
            cardBg = const Color(0xFF1E3A8A).withValues(alpha: 0.45);
            borderColor = const Color(0xFF60A5FA);
            titleColor = Colors.white;
            subtitleColor = const Color(0xFF93C5FD);
            iconColor = const Color(0xFF93C5FD);
            chevronColor = Colors.white;
          } else {
            cardBg = const Color(0xFF0F766E).withValues(alpha: 0.45);
            borderColor = const Color(0xFF2DD4BF);
            titleColor = Colors.white;
            subtitleColor = const Color(0xFF5EEAD4);
            iconColor = const Color(0xFF5EEAD4);
            chevronColor = Colors.white;
          }
        } else {
          if (isFinserve) {
            cardBg = const Color(0xFFEFF6FF);
            borderColor = const Color(0xFF2563EB);
            titleColor = const Color(0xFF1E3A8A);
            subtitleColor = const Color(0xFF2563EB);
            iconColor = const Color(0xFF2563EB);
            chevronColor = const Color(0xFF2563EB);
          } else {
            cardBg = const Color(0xFFF0FDF4);
            borderColor = const Color(0xFF0D9488);
            titleColor = const Color(0xFF134E4A);
            subtitleColor = const Color(0xFF0D9488);
            iconColor = const Color(0xFF0D9488);
            chevronColor = const Color(0xFF0D9488);
          }
        }

        return Center(
          child: PopupMenuButton<String>(
            tooltip: canSwitch ? 'Toggle CRM Entity' : 'Active CRM',
            enabled: canSwitch,
            onSelected: _onSelectScope,
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
            color: isDark ? const Color(0xFF1E1B18) : Colors.white,
            itemBuilder: (_) => items,
            child: widget.iconOnly
                ? Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: borderColor,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: borderColor.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isFinserve ? Icons.account_balance_wallet_rounded : Icons.apartment_rounded,
                      size: 20,
                      color: iconColor,
                    ),
                  )
                : Container(
                    constraints: BoxConstraints(
                      minHeight: widget.isSidebar ? 38 : 32,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.compact ? 8 : 10,
                      vertical: widget.isSidebar ? 6 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: borderColor,
                        width: 1.5,
                      ),
                      boxShadow: onDarkSurface
                          ? [
                              BoxShadow(
                                color: borderColor.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: borderColor.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: onDarkSurface
                                ? borderColor.withValues(alpha: 0.25)
                                : borderColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            isFinserve ? Icons.account_balance_wallet_rounded : Icons.apartment_rounded,
                            size: widget.compact ? 14 : 16,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.isSidebar && !widget.compact)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isFinserve ? 'NB Finserve CRM' : 'NB Developer CRM',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                  height: 1.15,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                isFinserve ? 'Financial Services' : 'Real Estate',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: subtitleColor,
                                  height: 1.1,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            isFinserve ? 'NB Finserve CRM' : 'NB Developer CRM',
                            style: TextStyle(
                              fontSize: widget.compact ? 11.5 : 12.5,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                              letterSpacing: -0.1,
                            ),
                          ),
                        if (canSwitch) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 19,
                            color: chevronColor,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
