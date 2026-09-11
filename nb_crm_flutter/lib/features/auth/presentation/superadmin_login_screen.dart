import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'bloc/auth_bloc.dart';
import 'widgets/auth_widgets.dart';

/// Dedicated Superadmin Login Portal (`/superadmin/login`).
/// Strictly isolated from client company and employee logins.
class SuperadminLoginScreen extends StatefulWidget {
  const SuperadminLoginScreen({super.key});

  @override
  State<SuperadminLoginScreen> createState() => _SuperadminLoginScreenState();
}

class _SuperadminLoginScreenState extends State<SuperadminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

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
      portal: 'superadmin',
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
            // Deep Obsidian / Dark Crimson gradient background
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A0908),
                      Color(0xFF140D0B),
                      Color(0xFF1F120E),
                    ],
                  ),
                ),
              ),
            ),

            // Subtle crimson glowing radial flare
            Positioned(
              top: -120,
              right: -100,
              child: Container(
                width: 480,
                height: 480,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE65100).withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -120,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.08),
                ),
              ),
            ),

            // Foreground Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 460 : 400),
                    child: BlocConsumer<AuthBloc, AuthState>(
                      listenWhen: (prev, curr) =>
                          prev.errorMessage != curr.errorMessage &&
                          curr.errorMessage != null,
                      listener: (context, state) {
                        if (state.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(state.errorMessage!),
                              backgroundColor: Colors.red.shade900,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      builder: (context, state) {
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF181513).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE65100).withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 36,
                                offset: const Offset(0, 16),
                              ),
                              BoxShadow(
                                color: const Color(0xFFE65100).withValues(alpha: 0.1),
                                blurRadius: 24,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Shield Emblem
                                Center(
                                  child: Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFE65100), Color(0xFFB71C1C)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFE65100).withValues(alpha: 0.4),
                                          blurRadius: 18,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.admin_panel_settings_rounded,
                                      color: Colors.white,
                                      size: 38,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Title
                                const Text(
                                  'Superadmin Portal',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'SaaS Platform Console & License Governance',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFFFA726),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Text(
                                    'RESTRICTED ACCESS: Authorized Platform Administrators Only',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEF9A9A),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Error Banner
                                if (state.errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade900.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade700),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            state.errorMessage!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Username / Email Field
                                TextFormField(
                                  controller: _identifierController,
                                  focusNode: _identifierFocusNode,
                                  keyboardType: TextInputType.text,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Superadmin Identifier',
                                    labelStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                                    hintText: 'superadmin or admin@platform.io',
                                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    prefixIcon: const Icon(Icons.shield_outlined, color: Color(0xFFFFA726), size: 20),
                                    filled: true,
                                    fillColor: const Color(0xFF221F1C),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE65100), width: 1.5),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Identifier required';
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                                ),
                                const SizedBox(height: 16),

                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocusNode,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Security Key / Password',
                                    labelStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFFFA726), size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: Colors.grey.shade400,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF221F1C),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFE65100), width: 1.5),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Password required';
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                const SizedBox(height: 24),

                                // Authenticate Button
                                ElevatedButton(
                                  onPressed: state.isSubmitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE65100),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: state.isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.login_rounded, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Authenticate Superadmin',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 24),

                                // Return to standard portal link
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () => context.go('/login'),
                                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFFB0BEC5)),
                                    label: const Text(
                                      'Looking for Employee or Client Login? Return to Standard Portal',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFFB0BEC5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
