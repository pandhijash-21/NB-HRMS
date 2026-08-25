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
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return PopScope(
      canPop: false,
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
                  constraints: const BoxConstraints(maxWidth: 520),
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
                        'Verify your email address${_emails.where((e) => !e.verified).length > 1 ? 'es' : ''}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
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
                          child: _loading
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Email verification',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'We sent a 6-digit code to each email on your profile. '
                                      'You have 3 attempts per code. Wait 2 minutes before requesting a new one.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
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
                                        message:
                                            'No emails found on your profile. Contact HR.',
                                      ),
                                    TextButton(
                                      onPressed: () => ref
                                          .read(authNotifierProvider.notifier)
                                          .logout(),
                                      child: const Text('Sign out'),
                                    ),
                                  ],
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
              ? AppColors.success.withValues(alpha: 0.45)
              : AppColors.slate.withValues(alpha: 0.25),
        ),
        color: verified
            ? AppColors.successSoft
            : Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.verified_outlined : Icons.mail_outline,
                color: verified ? AppColors.success : AppColors.midnight,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.email.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      widget.email.email,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (verified)
                Text(
                  'Verified',
                  style: TextStyle(
                    color: AppColors.success,
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
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '6-digit OTP',
                counterText: '',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_sending || _cooldown > 0) ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _cooldown > 0
                                ? 'Resend in ${_cooldown}s'
                                : 'Send OTP',
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _verifying ? null : _verify,
                    child: _verifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Verify'),
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
                  color: _messageIsError ? AppColors.error : AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
