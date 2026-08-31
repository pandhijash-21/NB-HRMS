import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_providers.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _loadingRemembered = true;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final repo = ref.read(authRepositoryProvider);
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
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authNotifierProvider.notifier);
    auth.clearError();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final identifier = _identifierController.text;
    final password = _passwordController.text;

    final ok = await auth.login(
      identifier: identifier,
      password: password,
    );

    if (!mounted || !ok) return;

    final repo = ref.read(authRepositoryProvider);
    final session = ref.read(authNotifierProvider);
    if (_rememberMe && !session.isFirstLogin) {
      await repo.saveRememberedCredentials(
        identifier: identifier,
        password: password,
      );
      TextInput.finishAutofillContext(shouldSave: true);
    } else if (!_rememberMe) {
      await repo.clearRememberedCredentials();
      TextInput.finishAutofillContext(shouldSave: false);
    }

    if (!mounted) return;

    if (session.isFirstLogin) {
      context.go('/change-password');
    } else if (session.needsEmailVerification) {
      context.go('/verify-emails');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final submitting = auth.isSubmitting;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 720;

    return Theme(
      data: authScreenTheme(),
      child: Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
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
                color: const Color(0xFFC5A059).withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC5A059).withOpacity(0.1),
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
                        
                        // Glassmorphism Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1B18).withOpacity(0.7),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFC5A059).withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(32, 40, 32, 36),
                              child: AutofillGroup(
                                child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Welcome Back',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Sign in with your employee credentials to continue.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                    if (auth.infoMessage != null) ...[
                                      const SizedBox(height: 24),
                                      InlineBanner.info(message: auth.infoMessage!),
                                    ],
                                    const SizedBox(height: 32),
                                    
                                    // Username Field
                                    TextFormField(
                                      controller: _identifierController,
                                      enabled: !submitting,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.username],
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
                                      onChanged: (_) => auth.errorMessage != null
                                          ? ref.read(authNotifierProvider.notifier).clearError()
                                          : null,
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // Password Field
                                    AuthPasswordField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      hint: '••••••••',
                                      obscure: _obscurePassword,
                                      enabled: !submitting,
                                      onToggle: () => setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      ),
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) =>
                                          submitting ? null : _submit(),
                                      onChanged: (_) => auth.errorMessage != null
                                          ? ref
                                              .read(authNotifierProvider.notifier)
                                              .clearError()
                                          : null,
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
                                              onChanged: submitting ||
                                                      _loadingRemembered
                                                  ? null
                                                  : (v) => setState(
                                                        () => _rememberMe =
                                                            v ?? false,
                                                      ),
                                              activeColor:
                                                  const Color(0xFFC5A059),
                                              checkColor:
                                                  const Color(0xFF1A1816),
                                              side: BorderSide(
                                                color: Colors.white
                                                    .withOpacity(0.35),
                                              ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Remember me',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.75),
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
                                    ],
                                    const SizedBox(height: 36),
                                    
                                    // Submit Button
                                    SizedBox(
                                      height: 54,
                                      child: FilledButton(
                                        onPressed: submitting ? null : _submit,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFFC5A059),
                                          foregroundColor: const Color(0xFF1A1816),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          elevation: 4,
                                          shadowColor: const Color(0xFFC5A059).withOpacity(0.5),
                                        ),
                                        child: submitting
                                            ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 3,
                                                  color: Color(0xFF1A1816),
                                                ),
                                              )
                                            : const Text(
                                                'Sign in',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Having trouble signing in? Contact your administrator.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.4),
                                      ),
                                    ),
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
        Container(
          height: compact ? 80 : 100,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC5A059).withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/nbdeveloperlogo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'NB CRM',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 24 : 28,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'CRM · HRMS · ERP',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFC5A059),
            fontWeight: FontWeight.w700,
            fontSize: compact ? 12 : 14,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
