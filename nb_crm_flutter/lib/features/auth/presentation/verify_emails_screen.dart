import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_providers.dart';
import 'widgets/auth_widgets.dart';

class VerifyEmailsScreen extends ConsumerStatefulWidget {
  const VerifyEmailsScreen({super.key});

  @override
  ConsumerState<VerifyEmailsScreen> createState() => _VerifyEmailsScreenState();
}

class _VerifyEmailsScreenState extends ConsumerState<VerifyEmailsScreen> {
  bool _loading = true;
  String? _error;
  List<PendingEmail> _emails = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      final status = await repo.fetchEmailVerificationStatus();
      if (!mounted) return;
      setState(() {
        _emails = status.emails;
        _loading = false;
      });
      if (!status.needsEmailVerification) {
        await ref
            .read(authNotifierProvider.notifier)
            .markEmailVerificationComplete();
        if (mounted) context.go('/home');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load email verification status.';
      });
    }
  }

  Future<void> _onEmailVerified() async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _emails.where((e) => !e.verified).length;
    return AuthScenicScaffold(
      canPop: false,
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthBrandMark(
            subtitle: pending > 1 ? 'Verify your email addresses' : 'Verify your email address',
          ),
          const SizedBox(height: 28),
          AuthGlassCard(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: authGold),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Email verification',
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
                        'We sent a 6-digit code to each email on your profile. '
                        'You have 3 attempts per code. Wait 2 minutes before requesting a new one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        InlineBanner.error(message: _error!),
                      ],
                      const SizedBox(height: 20),
                      for (final email in _emails) ...[
                        _EmailVerifyCard(
                          email: email,
                          repo: ref.read(authRepositoryProvider),
                          onVerified: _onEmailVerified,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_emails.isEmpty)
                        const InlineBanner.info(
                          message: 'No emails found on your profile. Contact HR.',
                        ),
                      TextButton(
                        onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                        style: TextButton.styleFrom(foregroundColor: authGold),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmailVerifyCard extends StatefulWidget {
  const _EmailVerifyCard({
    required this.email,
    required this.repo,
    required this.onVerified,
  });

  final PendingEmail email;
  final AuthRepository repo;
  final Future<void> Function() onVerified;

  @override
  State<_EmailVerifyCard> createState() => _EmailVerifyCardState();
}

class _EmailVerifyCardState extends State<_EmailVerifyCard> {
  final _otpController = TextEditingController();
  late int _cooldown;
  Timer? _timer;
  bool _sending = false;
  bool _verifying = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _cooldown = widget.email.cooldownSeconds;
    if (_cooldown > 0) _startTicker();
  }

  @override
  void didUpdateWidget(covariant _EmailVerifyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.email.email != widget.email.email ||
        oldWidget.email.verified != widget.email.verified) {
      _cooldown = widget.email.cooldownSeconds;
      if (_cooldown > 0) _startTicker();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        setState(() => _cooldown = 0);
        _timer?.cancel();
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      final seconds = await widget.repo.sendEmailOtp(widget.email.email);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _cooldown = seconds;
        _message = 'OTP sent to ${widget.email.email}';
        _messageIsError = false;
      });
      _startTicker();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('smtp is not configured')) {
        await widget.onVerified();
        return;
      }
      setState(() {
        _sending = false;
        _message = e.message;
        _messageIsError = true;
        final match = RegExp(r'(\d+)\s+seconds').firstMatch(e.message);
        if (match != null) {
          _cooldown = int.tryParse(match.group(1)!) ?? _cooldown;
          if (_cooldown > 0) _startTicker();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _message = 'Failed to send OTP. Check SMTP configuration.';
        _messageIsError = true;
      });
    }
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _message = 'Enter the 6-digit OTP';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _verifying = true;
      _message = null;
    });
    try {
      final result = await widget.repo.verifyEmailOtp(
        email: widget.email.email,
        otp: otp,
      );
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _message = 'Verified';
        _messageIsError = false;
      });
      if (!result.needsEmailVerification) {
        // Parent will navigate home after reload.
      }
      await widget.onVerified();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _message = e.message;
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _message = 'Verification failed. Try again.';
        _messageIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = widget.email.verified;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: verified
              ? AppColors.success.withValues(alpha: 0.55)
              : authGold.withValues(alpha: 0.18),
        ),
        color: verified
            ? AppColors.success.withValues(alpha: 0.12)
            : authFieldFill.withValues(alpha: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.verified_outlined : Icons.mail_outline,
                color: verified ? const Color(0xFF6EE7B7) : authGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.email.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.email.email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (verified)
                const Text(
                  'Verified',
                  style: TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (!verified) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 4),
              cursorColor: authGold,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: authFieldDecoration(
                label: '6-digit OTP',
                counterText: '',
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_sending || _cooldown > 0) ? null : _send,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
                      side: BorderSide(color: authGold.withValues(alpha: 0.35)),
                      minimumSize: const Size(48, 48),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: authGold),
                          )
                        : Text(
                            _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Send OTP',
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _verifying ? null : _verify,
                    style: FilledButton.styleFrom(
                      backgroundColor: authGold,
                      foregroundColor: authInk,
                      minimumSize: const Size(48, 48),
                    ),
                    child: _verifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: authInk),
                          )
                        : const Text('Verify', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _messageIsError ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
