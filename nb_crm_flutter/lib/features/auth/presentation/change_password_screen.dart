import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'bloc/auth_bloc.dart';
import 'widgets/auth_widgets.dart';

class _C {
  static const gold = Color(0xFFC5A36A);
  static const goldSoft = Color(0xFFD6BC85);
  static const card = Color(0xFFFFFFFF);
  static const field = Color(0xFFF4F2EE);
  static const ink = Color(0xFF1A1F1B);
  static const mute = Color(0xFF6F766F);
  static const onImage = Color(0xFFF7F4EE);
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final authBloc = context.read<AuthBloc>();
    authBloc.add(const AuthClearErrorRequested());
    if (!(_formKey.currentState?.validate() ?? false)) return;

    authBloc.add(AuthChangePasswordRequested(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          prev.isSubmitting && !curr.isSubmitting && curr.infoMessage != null,
      listener: (context, state) {
        if (!mounted) return;
        context.go('/login');
      },
      buildWhen: (prev, curr) =>
          prev.isSubmitting != curr.isSubmitting ||
          prev.errorMessage != curr.errorMessage,
      builder: (context, auth) {
        final card = _PasswordCard(
          formKey: _formKey,
          currentController: _currentController,
          newController: _newController,
          confirmController: _confirmController,
          obscureCurrent: _obscureCurrent,
          obscureNew: _obscureNew,
          obscureConfirm: _obscureConfirm,
          submitting: auth.isSubmitting,
          errorMessage: auth.errorMessage,
          onToggleCurrent: () => setState(() => _obscureCurrent = !_obscureCurrent),
          onToggleNew: () => setState(() => _obscureNew = !_obscureNew),
          onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
          onSubmit: _submit,
        );

        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: const Color(0xFF0B100E),
          ),
          child: PopScope(
            canPop: false,
            child: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const _Backdrop(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xE6000000),
                          Color(0x99000000),
                          Color(0x00000000),
                        ],
                        stops: [0.0, 0.28, 0.5],
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: fade,
                    child: wide
                        ? Row(
                            children: [
                              const Expanded(flex: 58, child: _BrandPanel()),
                              Expanded(
                                flex: 42,
                                child: SafeArea(
                                  child: Center(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 28,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 440),
                                        child: card,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : SafeArea(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                              child: Column(
                                children: [
                                  const _MobileBrandHeader(),
                                  const SizedBox(height: 22),
                                  card,
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/nbbg.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0B100E)),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 36, 36, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BrandHeader(onDark: true),
            const Spacer(flex: 3),
            Text(
              'Set a\npassword',
              style: GoogleFonts.fraunces(
                fontSize: 64,
                fontWeight: FontWeight.w600,
                height: 0.95,
                letterSpacing: -1.5,
                color: _C.goldSoft,
              ),
            ),
            const SizedBox(height: 16),
            Container(width: 48, height: 2, color: _C.gold),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                'Replace the temporary password before you continue. You will sign in again afterward.',
                style: GoogleFonts.sourceSans3(
                  fontSize: 16,
                  height: 1.45,
                  color: _C.onImage.withValues(alpha: 0.88),
                ),
              ),
            ),
            const Spacer(flex: 4),
            Text(
              'HRMS  ·  CRM  ·  ERP',
              style: GoogleFonts.sourceSans3(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.6,
                color: _C.onImage.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final title = onDark ? _C.onImage : _C.ink;
    final sub = onDark ? _C.onImage.withValues(alpha: 0.7) : _C.mute;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/nb-logo.png',
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 52,
              height: 52,
              color: _C.gold,
              alignment: Alignment.center,
              child: Text(
                'NB',
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _C.ink,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NB DEVELOPER',
              style: GoogleFonts.sourceSans3(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: title,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'BUILDING BETTER TOMORROW',
              style: GoogleFonts.sourceSans3(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.3,
                color: sub,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileBrandHeader extends StatelessWidget {
  const _MobileBrandHeader();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          color: Colors.black.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandHeader(onDark: true),
              const SizedBox(height: 14),
              Text(
                'Set a password',
                style: GoogleFonts.fraunces(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: _C.goldSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordCard extends StatelessWidget {
  const _PasswordCard({
    required this.formKey,
    required this.currentController,
    required this.newController,
    required this.confirmController,
    required this.obscureCurrent,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.submitting,
    required this.errorMessage,
    required this.onToggleCurrent,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController currentController;
  final TextEditingController newController;
  final TextEditingController confirmController;
  final bool obscureCurrent;
  final bool obscureNew;
  final bool obscureConfirm;
  final bool submitting;
  final String? errorMessage;
  final VoidCallback onToggleCurrent;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 32, 30, 24),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set new password',
              style: GoogleFonts.fraunces(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: _C.ink,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              passwordPolicyHint,
              style: GoogleFonts.sourceSans3(
                fontSize: 14,
                height: 1.4,
                color: _C.mute,
              ),
            ),
            const SizedBox(height: 26),
            _PasswordField(
              fieldKey: const ValueKey('pwd-current'),
              controller: currentController,
              hint: 'Current password',
              obscure: obscureCurrent,
              enabled: !submitting,
              onToggle: onToggleCurrent,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Current password is required' : null,
            ),
            const SizedBox(height: 14),
            _PasswordField(
              fieldKey: const ValueKey('pwd-new'),
              controller: newController,
              hint: 'New password',
              obscure: obscureNew,
              enabled: !submitting,
              onToggle: onToggleNew,
              textInputAction: TextInputAction.next,
              validator: (v) {
                final issue = validateNewPassword(v);
                if (issue != null) return issue;
                if (v == currentController.text) {
                  return 'New password must be different';
                }
                return null;
              },
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: newController,
              builder: (context, value, _) => _PolicyChecklist(password: value.text),
            ),
            const SizedBox(height: 14),
            _PasswordField(
              fieldKey: const ValueKey('pwd-confirm'),
              controller: confirmController,
              hint: 'Confirm new password',
              obscure: obscureConfirm,
              enabled: !submitting,
              onToggle: onToggleConfirm,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submitting ? null : onSubmit(),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please confirm your new password';
                }
                if (v != newController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              InlineBanner.error(message: errorMessage!),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: submitting ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: _C.ink,
                  foregroundColor: _C.card,
                  disabledBackgroundColor: _C.ink.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: _C.card,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Set password',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: _C.mute.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Required before you can use the app.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12,
                      color: _C.mute,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.fieldKey,
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.enabled,
    required this.onToggle,
    required this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints = const [],
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool enabled;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      obscuringCharacter: '•',
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autofillHints: kIsWeb ? const [] : autofillHints,
      autocorrect: false,
      enableSuggestions: false,
      style: GoogleFonts.sourceSans3(
        color: _C.ink,
        fontWeight: FontWeight.w600,
        fontSize: 14.5,
      ),
      cursorColor: _C.ink,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show password' : 'Hide password',
          onPressed: enabled ? onToggle : null,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: _C.field,
        hintStyle: GoogleFonts.sourceSans3(
          color: _C.mute.withValues(alpha: 0.7),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: _C.mute,
        suffixIconColor: _C.mute,
        errorStyle: const TextStyle(
          color: Color(0xFF8F4E48),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        errorMaxLines: 3,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.ink, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8F4E48)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8F4E48), width: 1.2),
        ),
      ),
      validator: validator,
    );
  }
}

class _PolicyChecklist extends StatelessWidget {
  const _PolicyChecklist({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final rules = <({bool ok, String label})>[
      (ok: password.length >= 6, label: 'At least 6 characters'),
      (ok: RegExp(r'[A-Z]').hasMatch(password), label: '1 uppercase letter'),
      (ok: RegExp(r'[a-z]').hasMatch(password), label: '1 lowercase letter'),
      (ok: RegExp(r'[0-9]').hasMatch(password), label: '1 number'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    rule.ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: 16,
                    color: rule.ok ? _C.gold : _C.mute.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rule.label,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: rule.ok ? _C.ink : _C.mute.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
