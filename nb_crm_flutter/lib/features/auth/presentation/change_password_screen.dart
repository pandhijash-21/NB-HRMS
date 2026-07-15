import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import 'auth_providers.dart';
import 'widgets/auth_widgets.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authNotifierProvider.notifier);
    auth.clearError();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await auth.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );

    if (!mounted || !ok) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final submitting = auth.isSubmitting;
    final forced = auth.isFirstLogin;
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return PopScope(
      canPop: !forced,
      child: Scaffold(
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
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'NB Developer',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        forced
                            ? 'First sign-in — set a new password to continue'
                            : 'Change your password',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.bronze,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
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
                                  'Change password',
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
                                  'Use at least 8 characters with a letter and a number. '
                                  'You will need to sign in again afterward.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 24),
                                _PasswordField(
                                  controller: _currentController,
                                  label: 'Current password',
                                  obscure: _obscureCurrent,
                                  enabled: !submitting,
                                  onToggle: () => setState(
                                    () => _obscureCurrent = !_obscureCurrent,
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Current password is required'
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                _PasswordField(
                                  controller: _newController,
                                  label: 'New password',
                                  obscure: _obscureNew,
                                  enabled: !submitting,
                                  onToggle: () => setState(
                                    () => _obscureNew = !_obscureNew,
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: validateNewPassword,
                                ),
                                const SizedBox(height: 14),
                                _PasswordField(
                                  controller: _confirmController,
                                  label: 'Confirm new password',
                                  obscure: _obscureConfirm,
                                  enabled: !submitting,
                                  onToggle: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) =>
                                      submitting ? null : _submit(),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please confirm your new password';
                                    }
                                    if (v != _newController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                if (auth.errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  InlineBanner.error(
                                    message: auth.errorMessage!,
                                  ),
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
                                      : const Text('Update password'),
                                ),
                                if (forced) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    'This step is required before you can use the app.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
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
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
    required this.enabled,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show password' : 'Hide password',
          onPressed: enabled ? onToggle : null,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: validator,
    );
  }
}
