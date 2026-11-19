import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/password_policy.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

class _C {
  static const card = Color(0xFFFFFFFF);
  static const field = Color(0xFFF4F2EE);
  static const ink = Color(0xFF1A1F1B);
  static const mute = Color(0xFF6F766F);
  static const line = Color(0xFFD9D4CB);
  static const onImage = Color(0xFFF7F4EE);
}

enum _ForgotStep { identifier, otp, password, done }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _otpController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  _ForgotStep _step = _ForgotStep.identifier;
  bool _busy = false;
  String? _error;
  String? _info;
  String? _maskedEmail;
  String? _resetToken;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _idController.dispose();
    _otpController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _requestOtp() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final repo = context.read<AuthRepository>();
      final res = await repo.requestForgotPassword(_idController.text);
      if (!mounted) return;
      setState(() {
        _step = _ForgotStep.otp;
        _maskedEmail = res.maskedEmail;
        _info = res.message;
        _busy = false;
      });
      _startCooldown(res.cooldownSeconds);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final repo = context.read<AuthRepository>();
      final res = await repo.verifyForgotPasswordOtp(
        identifier: _idController.text,
        otp: _otpController.text,
      );
      if (!mounted) return;
      setState(() {
        _resetToken = res.resetToken;
        _step = _ForgotStep.password;
        _info = res.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final token = _resetToken;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Reset session expired. Start again.');
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = context.read<AuthRepository>();
      final msg = await repo.resetForgotPassword(
        resetToken: token,
        newPassword: _newController.text,
        confirmPassword: _confirmController.text,
      );
      if (!mounted) return;
      setState(() {
        _step = _ForgotStep.done;
        _info = msg;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B100E),
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF0B100E)),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(28, 30, 28, 22),
                    decoration: BoxDecoration(
                      color: _C.card,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 36,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _step == _ForgotStep.done
                                ? 'Password reset'
                                : 'Forgot password',
                            style: GoogleFonts.fraunces(
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              color: _C.ink,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _subtitle,
                            style: GoogleFonts.sourceSans3(
                              fontSize: 14,
                              height: 1.4,
                              color: _C.mute,
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (_step == _ForgotStep.identifier) ...[
                            TextFormField(
                              controller: _idController,
                              enabled: !_busy,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _busy ? null : _requestOtp(),
                              decoration: _dec('Employee ID / Username / Email'),
                              style: _fieldStyle,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 18),
                            _primaryBtn('Send OTP', _requestOtp),
                          ] else if (_step == _ForgotStep.otp) ...[
                            TextFormField(
                              controller: _otpController,
                              enabled: !_busy,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _busy ? null : _verifyOtp(),
                              decoration: _dec('Enter OTP'),
                              style: _fieldStyle,
                              validator: (v) =>
                                  (v == null || v.trim().length < 4) ? 'Enter the OTP' : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: (_busy || _cooldown > 0) ? null : _requestOtp,
                                    child: Text(
                                      _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend OTP',
                                      style: GoogleFonts.sourceSans3(
                                        fontWeight: FontWeight.w700,
                                        color: _C.ink,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _primaryBtn('Verify OTP', _verifyOtp),
                                ),
                              ],
                            ),
                          ] else if (_step == _ForgotStep.password) ...[
                            Text(
                              passwordPolicyHint,
                              style: GoogleFonts.sourceSans3(
                                fontSize: 13,
                                color: _C.mute,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _newController,
                              enabled: !_busy,
                              obscureText: _obscureNew,
                              decoration: _dec(
                                'New password',
                                suffix: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscureNew = !_obscureNew),
                                  icon: Icon(
                                    _obscureNew
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              style: _fieldStyle,
                              validator: validateNewPassword,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmController,
                              enabled: !_busy,
                              obscureText: _obscureConfirm,
                              decoration: _dec(
                                'Confirm new password',
                                suffix: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              style: _fieldStyle,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Confirm password is required';
                                }
                                if (v != _newController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            _primaryBtn('Reset password', _resetPassword),
                          ] else ...[
                            InlineBanner.info(
                              message: _info ??
                                  'Password reset successful. Please log in with your new password.',
                            ),
                            const SizedBox(height: 18),
                            _primaryBtn('Back to login', () => context.go('/login')),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            InlineBanner.error(message: _error!),
                          ],
                          if (_info != null && _step != _ForgotStep.done) ...[
                            const SizedBox(height: 14),
                            InlineBanner.info(message: _info!),
                          ],
                          if (_step != _ForgotStep.done) ...[
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _busy ? null : () => context.go('/login'),
                              child: Text(
                                'Back to login',
                                style: GoogleFonts.sourceSans3(
                                  fontWeight: FontWeight.w700,
                                  color: _C.mute,
                                ),
                              ),
                            ),
                          ],
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

  String get _subtitle {
    switch (_step) {
      case _ForgotStep.identifier:
        return 'Enter your employee ID, username, or email. We will send an OTP to your registered email.';
      case _ForgotStep.otp:
        return _maskedEmail != null && _maskedEmail!.isNotEmpty
            ? 'Enter the OTP sent to $_maskedEmail'
            : 'Enter the OTP sent to your registered email.';
      case _ForgotStep.password:
        return 'Choose a new password, then confirm it.';
      case _ForgotStep.done:
        return 'You can sign in with your new password.';
    }
  }

  TextStyle get _fieldStyle => GoogleFonts.sourceSans3(
        color: _C.ink,
        fontWeight: FontWeight.w600,
        fontSize: 14.5,
      );

  InputDecoration _dec(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _C.field,
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _C.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _C.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _C.ink, width: 1.4),
      ),
    );
  }

  Widget _primaryBtn(String label, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.ink,
          foregroundColor: _C.onImage,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                label,
                style: GoogleFonts.sourceSans3(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
