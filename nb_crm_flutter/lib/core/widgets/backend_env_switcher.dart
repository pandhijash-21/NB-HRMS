import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../network/api_url_cubit.dart';
import '../network/app_config.dart';

/// Debug-only local ↔ live API switcher. Hidden in release builds.
class BackendEnvSwitcher extends StatelessWidget {
  const BackendEnvSwitcher.card({super.key, this.enabled = true})
      : compact = false;

  const BackendEnvSwitcher.chip({super.key})
      : enabled = true,
        compact = true;

  final bool enabled;
  final bool compact;

  void _switchTo(BuildContext context, String target) {
    if (!enabled || kReleaseMode) return;
    final auth = context.read<AuthBloc>();
    final wasAuth = auth.state.isAuthenticated;
    final wasSuper = auth.state.isSuperAdmin;
    final goingLocal = AppConfig.isLocalUrl(target);

    context.read<ApiUrlCubit>().setUrl(target);

    if (wasAuth) {
      auth.add(AuthLogoutRequested(
        skipRemote: true,
        infoMessage: goingLocal
            ? 'Switched to Local Dev. Sign in again.'
            : 'Switched to Live Server. Sign in again.',
      ));
      context.go(wasSuper ? '/superadmin/login' : '/login');
      return;
    }

    auth.add(const AuthClearErrorRequested());
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) return const SizedBox.shrink();

    return BlocBuilder<ApiUrlCubit, String>(
      buildWhen: (previous, current) => previous != current,
      builder: (context, currentBaseUrl) {
        final isLocal = AppConfig.isLocalUrl(currentBaseUrl);
        if (compact) {
          return _Chip(
            isLocal: isLocal,
            enabled: enabled,
            onToggle: () => _switchTo(
              context,
              isLocal ? AppConfig.liveApiBaseUrl : AppConfig.localApiBaseUrl,
            ),
          );
        }
        return _Card(
          isLocal: isLocal,
          currentBaseUrl: currentBaseUrl,
          enabled: enabled,
          onToggle: () => _switchTo(
            context,
            isLocal ? AppConfig.liveApiBaseUrl : AppConfig.localApiBaseUrl,
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.isLocal,
    required this.enabled,
    required this.onToggle,
  });

  final bool isLocal;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = isLocal ? Colors.amber : const Color(0xFF22C55E);
    return Tooltip(
      message: isLocal
          ? 'Using local database (localhost:4000). Tap to use live.'
          : 'Using live database (crm.nbdeveloper.co.in). Tap to use local.',
      child: InkWell(
        onTap: enabled ? onToggle : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLocal ? Icons.developer_mode_rounded : Icons.cloud_done_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                isLocal ? 'DB: Local' : 'DB: Live',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isLocal ? 'Use Live' : 'Use Local',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.9),
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.isLocal,
    required this.currentBaseUrl,
    required this.enabled,
    required this.onToggle,
  });

  final bool isLocal;
  final String currentBaseUrl;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD0CBC1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLocal
              ? const Color(0xFF8A7A3E).withValues(alpha: 0.45)
              : const Color(0xFF3E4A41).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLocal ? Icons.developer_mode_rounded : Icons.cloud_done_rounded,
            size: 15,
            color: isLocal ? const Color(0xFF8A7A3E) : const Color(0xFF3E4A41),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLocal ? 'Backend: Local Dev' : 'Backend: Live Server',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isLocal ? const Color(0xFF8A7A3E) : const Color(0xFF3E4A41),
                  ),
                ),
                Text(
                  currentBaseUrl,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF5A616C),
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: enabled ? onToggle : null,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFC5A059).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFC5A059).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                isLocal ? 'Use Live' : 'Use Local',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC5A059),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
