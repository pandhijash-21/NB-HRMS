import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

export '../../../../core/utils/password_policy.dart';

const authGold = Color(0xFFC5A059);
const authInk = Color(0xFF1A1816);
const authFieldFill = Color(0xFF2B2722);

/// Dark theme for auth screens so light-mode app theme cannot make typed
/// passwords (and the cursor) invisible on dark fields.
ThemeData authScreenTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: authGold,
      secondary: authGold,
      surface: Color(0xFF1E1B18),
      error: Color(0xFFFF8A80),
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: authInk,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: authGold,
      selectionColor: authGold.withValues(alpha: 0.35),
      selectionHandleColor: authGold,
    ),
  );
}

/// Dark gold backdrop used on login, first-password, and email verification.
class AuthScenicScaffold extends StatelessWidget {
  const AuthScenicScaffold({
    super.key,
    required this.child,
    this.maxWidth = 460,
    this.canPop = true,
  });

  final Widget child;
  final double maxWidth;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Theme(
      data: authScreenTheme(),
      child: PopScope(
        canPop: canPop,
        child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F0E0D),
                      Color(0xFF1A1816),
                      Color(0xFF2B2722),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -100,
              right: -100,
              child: IgnorePointer(
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: authGold.withValues(alpha: 0.05),
                    boxShadow: [
                      BoxShadow(
                        color: authGold.withValues(alpha: 0.1),
                        blurRadius: 100,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
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
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Column(
      children: [
        Image.asset(
          'assets/images/nbdeveloperlogo.png',
          height: compact ? 72 : 96,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.apartment_rounded,
            size: compact ? 48 : 64,
            color: authGold,
          ),
        ),
        const SizedBox(height: 16),
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
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: authGold,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class AuthGlassCard extends StatelessWidget {
  const AuthGlassCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B18).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: authGold.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
          child: child,
        ),
      ),
    );
  }
}

InputDecoration authFieldDecoration({
  required String label,
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? counterText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    counterText: counterText,
    filled: true,
    fillColor: authFieldFill.withValues(alpha: 0.55),
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600),
    floatingLabelStyle: const TextStyle(color: authGold, fontWeight: FontWeight.w700),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
    errorStyle: const TextStyle(
      color: Color(0xFFFF8A80),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    errorMaxLines: 3,
    prefixIconColor: authGold,
    suffixIconColor: Colors.white.withValues(alpha: 0.55),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: authGold.withValues(alpha: 0.12), width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: authGold, width: 1.5),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: authGold.withValues(alpha: 0.08), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFFF8A80)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 1.5),
    ),
  );
}

class AuthGoldButton extends StatelessWidget {
  const AuthGoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: authGold,
          foregroundColor: authInk,
          disabledBackgroundColor: authGold.withValues(alpha: 0.45),
          disabledForegroundColor: authInk.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          shadowColor: authGold.withValues(alpha: 0.45),
        ),
        child: busy
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: authInk),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.4),
              ),
      ),
    );
  }
}


class InlineBanner extends StatelessWidget {
  const InlineBanner.error({super.key, required this.message})
      : _tone = _BannerTone.error;

  const InlineBanner.info({super.key, required this.message})
      : _tone = _BannerTone.info;

  final String message;
  final _BannerTone _tone;

  @override
  Widget build(BuildContext context) {
    final isError = _tone == _BannerTone.error;
    final bg = isError ? AppColors.errorSoft : AppColors.successSoft;
    final fg = isError ? AppColors.error : AppColors.success;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BannerTone { error, info }

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.hint,
    this.validator,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String> autofillHints;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Chrome + Flutter web treat `new-password` + obscureText as a password
    // manager form and leave the previous field readonly after you tab away.
    final hints = kIsWeb ? const <String>[] : widget.autofillHints;
    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      readOnly: false,
      obscureText: widget.obscure,
      obscuringCharacter: '•',
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      onTap: () {
        if (!_focus.hasFocus) _focus.requestFocus();
      },
      autofillHints: hints,
      autocorrect: false,
      enableSuggestions: false,
      enableInteractiveSelection: true,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      cursorColor: authGold,
      decoration: authFieldDecoration(
        label: widget.label,
        hint: widget.hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: widget.obscure ? 'Show password' : 'Hide password',
          onPressed: widget.enabled ? widget.onToggle : null,
          icon: Icon(
            widget.obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
      validator: widget.validator,
    );
  }
}

class PasswordPolicyChecklist extends StatelessWidget {
  const PasswordPolicyChecklist({super.key, required this.password});

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
      padding: const EdgeInsets.only(top: 10, left: 4),
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
                    color: rule.ok
                        ? const Color(0xFF81C784)
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rule.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: rule.ok
                          ? const Color(0xFF81C784)
                          : Colors.white.withValues(alpha: 0.45),
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
