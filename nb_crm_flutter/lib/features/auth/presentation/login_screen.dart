import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_url_cubit.dart';
import '../../../core/network/app_config.dart';
import '../data/auth_repository.dart';
import 'bloc/auth_bloc.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _loadingRemembered = true;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final repo = context.read<AuthRepository>();
    final remembered = await repo.readRememberedCredentials();
    if (!mounted) return;
    if (remembered != null) {
      _identifierController.text = remembered.identifier;
      _passwordController.text = remembered.password;
      setState(() {
        _rememberMe = true;
        _loadingRemembered = false;
      });
    } else {
      setState(() => _loadingRemembered = false);
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final authBloc = context.read<AuthBloc>();
    if (authBloc.state.isSubmitting) return;

    authBloc.add(const AuthClearErrorRequested());

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    authBloc.add(AuthLoginRequested(
      identifier: identifier,
      password: password,
      portal: 'standard',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 720;

    return Theme(
      data: authScreenTheme(),
      child: Scaffold(
        body: Stack(
          children: [
            // Background Gradient
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F0E0D), // Deep rich black
                      Color(0xFF1A1816), // Very dark brown/black
                      Color(0xFF2B2722), // Lighter dark brown
                    ],
                  ),
                ),
              ),
            ),

            // Subtle glowing orb effect in the background
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC5A059).withValues(alpha: 0.05),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC5A059).withValues(alpha: 0.1),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 32 : 20,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutExpo,
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0.0, 40.0 * (1.0 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BrandHeader(compact: !wide),
                          const SizedBox(height: 36),

                          // Glassmorphism Card — skip blur on web (causes flicker)
                          Builder(builder: (context) {
                            final cardDecoration = BoxDecoration(
                              color: const Color(0xFF1E1B18).withValues(alpha: kIsWeb ? 0.92 : 0.7),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFC5A059).withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            );
                            final cardChild = Container(
                              decoration: cardDecoration,
                              padding: EdgeInsets.all(wide ? 32 : 24),
                                child: BlocConsumer<AuthBloc, AuthState>(
                                  listenWhen: (prev, curr) =>
                                      prev.isSubmitting != curr.isSubmitting ||
                                      prev.status != curr.status ||
                                      prev.errorMessage != curr.errorMessage,
                                  listener: (context, auth) async {
                                    if (auth.errorMessage != null && auth.errorMessage!.isNotEmpty) {
                                      _passwordFocusNode.requestFocus();
                                      _passwordController.selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset: _passwordController.text.length,
                                      );
                                      return;
                                    }

                                    if (auth.isAuthenticated) {
                                      final repo = context.read<AuthRepository>();
                                      final identifier = _identifierController.text.trim();
                                      final password = _passwordController.text;

                                      if (_rememberMe && !auth.isFirstLogin) {
                                        await repo.saveRememberedCredentials(
                                          identifier: identifier,
                                          password: password,
                                        );
                                        if (!kIsWeb) {
                                          TextInput.finishAutofillContext(shouldSave: true);
                                        }
                                      } else if (!_rememberMe) {
                                        await repo.clearRememberedCredentials();
                                        if (!kIsWeb) {
                                          TextInput.finishAutofillContext(shouldSave: false);
                                        }
                                      }

                                      if (!context.mounted) return;

                                      if (auth.isFirstLogin) {
                                        context.go('/change-password');
                                      } else if (auth.needsEmailVerification) {
                                        context.go('/verify-emails');
                                      } else if (auth.isSuperAdmin) {
                                        context.go('/platform');
                                      } else {
                                        context.go('/home');
                                      }
                                    }
                                  },
                                  builder: (context, auth) {
                                    final submitting = auth.isSubmitting;

                                    return Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Welcome Back',
                                            style: TextStyle(
                                              fontSize: wide ? 28 : 24,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Sign in to access your portal',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white.withValues(alpha: 0.6),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          const SizedBox(height: 28),

                                          // Employee Code / Username Field
                                          TextFormField(
                                            key: const ValueKey('login-username-field'),
                                            controller: _identifierController,
                                            focusNode: _identifierFocusNode,
                                            enabled: true,
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                                            autofillHints: kIsWeb ? const [] : const [AutofillHints.username],
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                            cursorColor: authGold,
                                            decoration: authFieldDecoration(
                                              label: 'Employee Code / Username',
                                              hint: 'e.g. TEST1234 or HOD_OPS',
                                              prefixIcon: const Icon(Icons.person_rounded),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Employee ID or username is required';
                                              }
                                              return null;
                                            },
                                            onChanged: (_) {
                                              if (auth.errorMessage != null) {
                                                context.read<AuthBloc>().add(const AuthClearErrorRequested());
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 20),

                                          // Password Field
                                          AuthPasswordField(
                                            key: const ValueKey('login-password-field'),
                                            controller: _passwordController,
                                            focusNode: _passwordFocusNode,
                                            label: 'Password',
                                            hint: '••••••••',
                                            obscure: _obscurePassword,
                                            enabled: true,
                                            onToggle: () => setState(
                                              () => _obscurePassword = !_obscurePassword,
                                            ),
                                            textInputAction: TextInputAction.done,
                                            onSubmitted: (_) => submitting ? null : _submit(),
                                            onChanged: (_) {
                                              if (auth.errorMessage != null) {
                                                context.read<AuthBloc>().add(const AuthClearErrorRequested());
                                              }
                                            },
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Password is required';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          InkWell(
                                            onTap: submitting || _loadingRemembered
                                                ? null
                                                : () => setState(
                                                      () => _rememberMe = !_rememberMe,
                                                    ),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child: Checkbox(
                                                    value: _rememberMe,
                                                    onChanged: submitting || _loadingRemembered
                                                        ? null
                                                        : (v) => setState(
                                                              () => _rememberMe = v ?? false,
                                                            ),
                                                    activeColor: const Color(0xFFC5A059),
                                                    checkColor: const Color(0xFF1A1816),
                                                    side: BorderSide(
                                                      color: Colors.white.withValues(alpha: 0.35),
                                                    ),
                                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Remember me',
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.75),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (auth.errorMessage != null) ...[
                                            const SizedBox(height: 20),
                                            InlineBanner.error(message: auth.errorMessage!),
                                            if (!kReleaseMode &&
                                                (auth.errorMessage!.contains('Unable to reach server') ||
                                                 auth.errorMessage!.contains('reach the server'))) ...[
                                              const SizedBox(height: 8),
                                              BlocBuilder<ApiUrlCubit, String>(
                                                buildWhen: (previous, current) => previous != current,
                                                builder: (context, currentUrl) {
                                                  final isLocal = currentUrl.contains('127.0.0.1') ||
                                                      currentUrl.contains('localhost');
                                                  return Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: InkWell(
                                                      onTap: submitting
                                                          ? null
                                                          : () {
                                                              final target = isLocal
                                                                  ? AppConfig.liveApiBaseUrl
                                                                  : AppConfig.localApiBaseUrl;
                                                              context.read<ApiUrlCubit>().setUrl(target);
                                                              context.read<AuthBloc>().add(const AuthClearErrorRequested());
                                                              _submit();
                                                            },
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.swap_horiz_rounded,
                                                                size: 16, color: Color(0xFFC5A059)),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              isLocal
                                                                  ? 'Switch to Live Server (crm.nbdeveloper.co.in)'
                                                                  : 'Switch to Local Server (127.0.0.1:4000)',
                                                              style: const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w700,
                                                                color: Color(0xFFC5A059),
                                                                decoration: TextDecoration.underline,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ],
                                          if (auth.infoMessage != null) ...[
                                            const SizedBox(height: 20),
                                            InlineBanner.info(message: auth.infoMessage!),
                                          ],
                                          const SizedBox(height: 28),

                                          // Luxurious Gold Submit Button
                                          Container(
                                            height: 52,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(14),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFE2C481), // Light shimmering gold
                                                  Color(0xFFC5A059), // Classic metallic gold
                                                  Color(0xFF9E7D3B), // Deep antique bronze/gold
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFC5A059).withValues(alpha: 0.35),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: submitting ? null : _submit,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                              ),
                                              child: submitting
                                                  ? const SizedBox(
                                                      height: 22,
                                                      width: 22,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Color(0xFF1A1816),
                                                      ),
                                                    )
                                                  : const Text(
                                                      'Sign In',
                                                      style: TextStyle(
                                                        color: Color(0xFF1A1816),
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          if (!kReleaseMode) ...[
                                            const SizedBox(height: 20),
                                            // Server Environment Switcher (Local Development Only)
                                            BlocBuilder<ApiUrlCubit, String>(
                                              buildWhen: (previous, current) => previous != current,
                                              builder: (context, currentBaseUrl) {
                                                final isLocal = currentBaseUrl.contains('127.0.0.1') ||
                                                    currentBaseUrl.contains('localhost');
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.04),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(
                                                      color: isLocal
                                                          ? Colors.amber.withValues(alpha: 0.25)
                                                          : const Color(0xFF22C55E).withValues(alpha: 0.3),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        isLocal
                                                            ? Icons.developer_mode_rounded
                                                            : Icons.cloud_done_rounded,
                                                        size: 15,
                                                        color: isLocal ? Colors.amber : const Color(0xFF22C55E),
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
                                                                color: isLocal
                                                                    ? Colors.amber
                                                                    : const Color(0xFF22C55E),
                                                              ),
                                                            ),
                                                            Text(
                                                              currentBaseUrl,
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors.white.withValues(alpha: 0.45),
                                                                fontFamily: 'monospace',
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      InkWell(
                                                        onTap: submitting
                                                            ? null
                                                            : () {
                                                                final target = isLocal
                                                                    ? AppConfig.liveApiBaseUrl
                                                                    : AppConfig.localApiBaseUrl;
                                                                AppConfig.setApiBaseUrl(target);
                                                                context.read<ApiUrlCubit>().setUrl(target);
                                                                context.read<AuthBloc>().add(const AuthClearErrorRequested());
                                                              },
                                                        borderRadius: BorderRadius.circular(6),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(
                                                              horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFC5A059).withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(
                                                                color: const Color(0xFFC5A059).withValues(alpha: 0.3)),
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
                                              },
                                            ),
                                          ],
                                          const SizedBox(height: 24),
                                          Text(
                                            'Protected by enterprise security. All access is audited.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                );
                            if (kIsWeb) return cardChild;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                child: cardChild,
                              ),
                            );
                          }),
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
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/nbdeveloperlogo.png',
          height: compact ? 72 : 96,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            width: compact ? 64 : 76,
            height: compact ? 64 : 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE2C481),
                  Color(0xFFC5A059),
                  Color(0xFF8C6D2D),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.domain_rounded,
                size: compact ? 34 : 40,
                color: const Color(0xFF1A1816),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'NB CRM',
          style: TextStyle(
            fontSize: compact ? 26 : 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [Color(0xFFFFF7D6), Color(0xFFC5A059)],
              ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'HRMS · CRM · ERP SUITE',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 3.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFC5A059).withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
