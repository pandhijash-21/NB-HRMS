import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'bloc/auth_bloc.dart';

/// Copies AuthBloc (login / shell) into Riverpod AuthNotifier so screens that
/// still watch [authNotifierProvider] see the signed-in admin after login
/// without requiring a full page reload.
class AuthRiverpodBridge extends ConsumerStatefulWidget {
  const AuthRiverpodBridge({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthRiverpodBridge> createState() => _AuthRiverpodBridgeState();
}

class _AuthRiverpodBridgeState extends ConsumerState<AuthRiverpodBridge> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  AuthBloc? _maybeAuthBloc() {
    try {
      return context.read<AuthBloc>();
    } catch (_) {
      return null;
    }
  }

  void _hydrate() {
    if (!mounted) return;
    final authBloc = _maybeAuthBloc();
    if (authBloc == null) return;
    ref.read(authNotifierProvider.notifier).hydrateFromBloc(authBloc.state);
  }

  @override
  Widget build(BuildContext context) {
    final authBloc = _maybeAuthBloc();
    if (authBloc == null) return widget.child;
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        ref.read(authNotifierProvider.notifier).hydrateFromBloc(state);
      },
      child: widget.child,
    );
  }
}
