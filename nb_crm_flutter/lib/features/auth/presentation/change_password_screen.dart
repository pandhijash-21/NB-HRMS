import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  void initState() {
    super.initState();
    _newController.addListener(() => setState(() {}));
  }

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

    return AuthScenicScaffold(
      canPop: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthBrandMark(subtitle: 'Update your password to continue'),
          const SizedBox(height: 28),
          AuthGlassCard(
            child: AutofillGroup(
              child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Set new password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    passwordPolicyHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 28),
                  AuthPasswordField(
                    controller: _currentController,
                    label: 'Current password',
                    hint: 'Temporary or existing password',
                    obscure: _obscureCurrent,
                    enabled: !submitting,
                    onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Current password is required' : null,
                  ),
                  const SizedBox(height: 14),
                  AuthPasswordField(
                    controller: _newController,
                    label: 'New password',
                    obscure: _obscureNew,
                    enabled: !submitting,
                    onToggle: () => setState(() => _obscureNew = !_obscureNew),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) {
                      final issue = validateNewPassword(v);
                      if (issue != null) return issue;
                      if (v == _currentController.text) {
                        return 'New password must be different';
                      }
                      return null;
                    },
                  ),
                  PasswordPolicyChecklist(password: _newController.text),
                  const SizedBox(height: 14),
                  AuthPasswordField(
                    controller: _confirmController,
                    label: 'Confirm new password',
                    obscure: _obscureConfirm,
                    enabled: !submitting,
                    onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => submitting ? null : _submit(),
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
                    InlineBanner.error(message: auth.errorMessage!),
                  ],
                  const SizedBox(height: 24),
                  AuthGoldButton(
                    label: 'Set password',
                    busy: submitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'This step is required before you can use the app. You will sign in again afterward.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
