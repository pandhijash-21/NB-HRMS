import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
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

    final ok = await auth.login(
      identifier: _identifierController.text,
      password: _passwordController.text,
    );

    if (!mounted || !ok) return;

    final session = ref.read(authNotifierProvider);
    if (session.isFirstLogin) {
      context.go('/change-password');
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

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.midnight,
              AppColors.slate,
              Color(0xFF314E5C),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 32 : 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BrandHeader(compact: !wide),
                    const SizedBox(height: 28),
                    Material(
                      color: AppColors.surface,
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Sign in',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.midnight,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Use your employee ID or username to continue.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              if (auth.infoMessage != null) ...[
                                const SizedBox(height: 16),
                                InlineBanner.info(message: auth.infoMessage!),
                              ],
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _identifierController,
                                enabled: !submitting,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                  labelText: 'Employee ID / Username',
                                  hintText: 'e.g. 1 or HOD_OPS',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Employee ID or username is required';
                                  }
                                  return null;
                                },
                                onChanged: (_) => auth.errorMessage != null
                                    ? ref
                                        .read(authNotifierProvider.notifier)
                                        .clearError()
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                enabled: !submitting,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) =>
                                    submitting ? null : _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: '••••••••',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: submitting
                                        ? null
                                        : () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password is required';
                                  }
                                  return null;
                                },
                                onChanged: (_) => auth.errorMessage != null
                                    ? ref
                                        .read(authNotifierProvider.notifier)
                                        .clearError()
                                    : null,
                              ),
                              if (auth.errorMessage != null) ...[
                                const SizedBox(height: 16),
                                InlineBanner.error(message: auth.errorMessage!),
                              ],
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: submitting ? null : _submit,
                                child: submitting
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: AppColors.midnight,
                                        ),
                                      )
                                    : const Text('Sign in'),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Having trouble signing in? Contact your administrator.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
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
          width: compact ? 56 : 64,
          height: compact ? 56 : 64,
          decoration: BoxDecoration(
            color: AppColors.bronze,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            'NB',
            style: TextStyle(
              color: AppColors.midnight,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 20 : 22,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'NB Developer',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'CRM · HRMS · ERP',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.bronze,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
              ),
        ),
      ],
    );
  }
}
