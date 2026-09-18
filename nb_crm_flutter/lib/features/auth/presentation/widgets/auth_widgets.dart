import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

export '../../../../core/utils/password_policy.dart';

/// Shared muted stone auth palette (no pure white / no bright gold).
const authGold = Color(0xFF5C6B5F); // kept name for call sites — muted sage
const authInk = Color(0xFF2A2E34);
const authFieldFill = Color(0xFFD0CBC1);
const authPanel = Color(0xFFDDD8CE);
const authStone = Color(0xFFC7C2B8);
const authLine = Color(0xFFA39E94);
const authMuted = Color(0xFF5A616C);
const authAccentDeep = Color(0xFF3E4A41);

/// Light muted theme for auth screens (login / password / verify).
ThemeData authScreenTheme() {
  return ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: authAccentDeep,
      secondary: authGold,
      surface: authPanel,
      error: Color(0xFF8F4E48),
      onSurface: authInk,
      onPrimary: authStone,
    ),
    scaffoldBackgroundColor: authStone,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: authAccentDeep,
      selectionColor: authGold.withValues(alpha: 0.28),
      selectionHandleColor: authAccentDeep,
    ),
  );
}

/// Soft stone backdrop used on auth flows.
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
                child: ColoredBox(color: authStone),
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
            color: authAccentDeep,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'NB CRM',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: authInk,
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
              color: authAccentDeep,
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
    return Container(
      decoration: BoxDecoration(
        color: authPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: authLine.withValues(alpha: 0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: authInk.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
      child: child,
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
    fillColor: authFieldFill,
    labelStyle: TextStyle(color: authMuted.withValues(alpha: 0.95), fontWeight: FontWeight.w600),
    floatingLabelStyle: const TextStyle(color: authAccentDeep, fontWeight: FontWeight.w700),
    hintStyle: TextStyle(color: authMuted.withValues(alpha: 0.55)),
    errorStyle: const TextStyle(
      color: Color(0xFF8F4E48),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    errorMaxLines: 3,
    prefixIconColor: authAccentDeep,
    suffixIconColor: authMuted,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: authLine.withValues(alpha: 0.7), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: authAccentDeep, width: 1.4),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: authLine.withValues(alpha: 0.4), width: 1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF8F4E48)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF8F4E48), width: 1.4),
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
      height: 50,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: authAccentDeep,
          foregroundColor: authStone,
          disabledBackgroundColor: authAccentDeep.withValues(alpha: 0.45),
          disabledForegroundColor: authStone.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: busy
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: authStone),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
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
    final bg = isError ? const Color(0xFFE8D6D3) : const Color(0xFFD5E0D7);
    final fg = isError ? const Color(0xFF8F4E48) : const Color(0xFF3E4A41);
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
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
    this.focusNode,
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
  final FocusNode? focusNode;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  FocusNode? _internalFocus;
  FocusNode get _effectiveFocus => widget.focusNode ?? (_internalFocus ??= FocusNode());

  @override
  void dispose() {
    _internalFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hints = kIsWeb ? const <String>[] : widget.autofillHints;
    return TextFormField(
      controller: widget.controller,
      focusNode: _effectiveFocus,
      enabled: widget.enabled,
      readOnly: false,
      obscureText: widget.obscure,
      obscuringCharacter: '•',
      keyboardType: widget.obscure ? TextInputType.text : TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      autofillHints: hints,
      autocorrect: false,
      enableSuggestions: false,
      enableInteractiveSelection: true,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      style: const TextStyle(
        color: authInk,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      cursorColor: authAccentDeep,
      decoration: authFieldDecoration(
        label: widget.label,
        hint: widget.hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: widget.obscure ? 'Show password' : 'Hide password',
          onPressed: widget.enabled ? widget.onToggle : null,
          icon: Icon(
            widget.obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: authMuted,
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
                    color: rule.ok ? authAccentDeep : authMuted.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rule.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: rule.ok ? authAccentDeep : authMuted.withValues(alpha: 0.75),
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
