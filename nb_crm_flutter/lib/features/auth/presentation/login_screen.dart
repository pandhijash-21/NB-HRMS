import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/app_version.dart';
import '../../../core/network/api_url_cubit.dart';
import '../../../core/network/app_config.dart';
import '../../../core/services/location_access_gate.dart';
import '../../../core/tour/mascot/mascot_clip_registry.dart';
import '../../../core/widgets/backend_env_switcher.dart';
import '../../../core/widgets/install_android_app_button.dart';
import '../data/auth_repository.dart';
import 'bloc/auth_bloc.dart';
import 'widgets/auth_widgets.dart';

class _C {
  static const gold = Color(0xFFC5A36A);
  static const goldSoft = Color(0xFFD6BC85);
  static const card = Color(0xFFFFFFFF);
  static const field = Color(0xFFF4F2EE);
  static const ink = Color(0xFF1A1F1B);
  static const mute = Color(0xFF6F766F);
  static const line = Color(0xFFE2DDD5);
  static const onImage = Color(0xFFF7F4EE);
  static const apkBg = Color(0xFFF0E6D4);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _loadingRemembered = true;
  bool _checkingLocation = false;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
    _enter.forward();
    _loadRememberedCredentials();
    // Ask for location as soon as login is visible (before credentials submit).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(LocationAccessGate.requestPermissionPrompt());
    });
  }

  Future<void> _loadRememberedCredentials() async {
    final repo = context.read<AuthRepository>();
    final remembered = await repo.readRememberedCredentials();
    if (!mounted) return;
    if (remembered != null) {
      _identifierController.text = remembered.identifier;
      _passwordController.text = remembered.password;
      setState(() {
        _rememberMe = true;
        _loadingRemembered = false;
      });
    } else {
      setState(() => _loadingRemembered = false);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authBloc = context.read<AuthBloc>();
    if (authBloc.state.isSubmitting || _checkingLocation) return;
    authBloc.add(const AuthClearErrorRequested());
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _checkingLocation = true);
    final location = await LocationAccessGate.ensureReadyForLogin();
    if (!mounted) return;
    setState(() => _checkingLocation = false);

    if (!location.allowed) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Location is MANDATORY'),
          content: Text(location.message),
          actions: [
            if (!kIsWeb)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    final isSuperAdmin = identifier.toLowerCase() == 'superadmin' ||
        (kIsWeb && Uri.base.toString().toLowerCase().contains('superadmin'));

    authBloc.add(AuthLoginRequested(
      identifier: identifier,
      password: password,
      portal: isSuperAdmin ? 'superadmin' : 'standard',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);

    return Theme(
      data: authScreenTheme(),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _LoginBackdrop(),
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
                        const Expanded(flex: 58, child: _BrandOverlay()),
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
                                  child: _LoginCard(
                                    formKey: _formKey,
                                    identifierController: _identifierController,
                                    passwordController: _passwordController,
                                    identifierFocusNode: _identifierFocusNode,
                                    passwordFocusNode: _passwordFocusNode,
                                    obscurePassword: _obscurePassword,
                                    rememberMe: _rememberMe,
                                    loadingRemembered: _loadingRemembered,
                                    onToggleObscure: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    onRememberChanged: (v) =>
                                        setState(() => _rememberMe = v),
                                    onSubmit: _submit,
                                    checkingLocation: _checkingLocation,
                                  ),
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
                            _LoginCard(
                              formKey: _formKey,
                              identifierController: _identifierController,
                              passwordController: _passwordController,
                              identifierFocusNode: _identifierFocusNode,
                              passwordFocusNode: _passwordFocusNode,
                              obscurePassword: _obscurePassword,
                              rememberMe: _rememberMe,
                              loadingRemembered: _loadingRemembered,
                              onToggleObscure: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              onRememberChanged: (v) =>
                                  setState(() => _rememberMe = v),
                              onSubmit: _submit,
                              checkingLocation: _checkingLocation,
                            ),
                          ],
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

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  static const _bg = 'assets/images/nbbg.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _bg,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, error, __) {
        debugPrint('nbbg.png failed: $error');
        return const ColoredBox(color: Color(0xFF0B100E));
      },
    );
  }
}

class _BrandOverlay extends StatelessWidget {
  const _BrandOverlay();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 36, 36, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BrandHeader(onDark: true),
            const Spacer(flex: 2),
            const _LoginMrNbHello(),
            const SizedBox(height: 8),
            Text(
              'NB CRM',
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
                'People, projects, and site progress — one private workspace.',
                style: GoogleFonts.sourceSans3(
                  fontSize: 16,
                  height: 1.45,
                  color: _C.onImage.withValues(alpha: 0.88),
                ),
              ),
            ),
            const SizedBox(height: 36),
            const Row(
              children: [
                _FeatureItem(icon: Icons.people_outline_rounded, label: 'Manage Teams'),
                SizedBox(width: 28),
                _FeatureItem(icon: Icons.bar_chart_rounded, label: 'Track Progress'),
                SizedBox(width: 28),
                _FeatureItem(
                  icon: Icons.description_outlined,
                  label: 'Streamline Operations',
                ),
              ],
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
            const SizedBox(height: 8),
            Text(
              'Version $kAppVersion',
              style: GoogleFonts.sourceSans3(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: _C.goldSoft,
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

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 26, color: _C.onImage.withValues(alpha: 0.9)),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.sourceSans3(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _C.onImage.withValues(alpha: 0.8),
          ),
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
                'NB CRM',
                style: GoogleFonts.fraunces(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: _C.goldSoft,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Version $kAppVersion',
                style: GoogleFonts.sourceSans3(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
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

class _LoginMrNbHello extends StatefulWidget {
  const _LoginMrNbHello();

  @override
  State<_LoginMrNbHello> createState() => _LoginMrNbHelloState();
}

class _LoginMrNbHelloState extends State<_LoginMrNbHello>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _bob,
        builder: (context, child) {
          final lift = (1 - Curves.easeInOut.transform(_bob.value)) * 7;
          return Transform.translate(offset: Offset(0, -lift), child: child);
        },
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _C.gold.withValues(alpha: 0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hello!',
                      style: GoogleFonts.fraunces(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _C.ink,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "I'm Mr. NB. Welcome back.",
                      style: GoogleFonts.sourceSans3(
                        fontSize: 12.5,
                        color: _C.mute,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: const Size(16, 8),
                painter: _HelloTailPainter(),
              ),
              const SizedBox(height: 2),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.gold, width: 2.4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: _C.gold.withValues(alpha: 0.3),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: ColoredBox(
                    color: const Color(0xFF0B0B0B),
                    child: Image.asset(
                      MascotClipRegistry.wave.gif,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.high,
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

class _HelloTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2 - 7, 0)
      ..lineTo(size.width / 2 + 7, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _C.gold.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.identifierController,
    required this.passwordController,
    required this.identifierFocusNode,
    required this.passwordFocusNode,
    required this.obscurePassword,
    required this.rememberMe,
    required this.loadingRemembered,
    required this.onToggleObscure,
    required this.onRememberChanged,
    required this.onSubmit,
    this.checkingLocation = false,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final FocusNode identifierFocusNode;
  final FocusNode passwordFocusNode;
  final bool obscurePassword;
  final bool rememberMe;
  final bool loadingRemembered;
  final bool checkingLocation;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onRememberChanged;
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
      child: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (prev, curr) =>
            prev.isSubmitting != curr.isSubmitting ||
            prev.status != curr.status ||
            prev.errorMessage != curr.errorMessage,
        listener: (context, auth) async {
          if (auth.errorMessage != null && auth.errorMessage!.isNotEmpty) {
            passwordFocusNode.requestFocus();
            passwordController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: passwordController.text.length,
            );
            return;
          }

          if (auth.isAuthenticated) {
            final repo = context.read<AuthRepository>();
            final identifier = identifierController.text.trim();
            final password = passwordController.text;

            if (rememberMe && !auth.isFirstLogin) {
              await repo.saveRememberedCredentials(
                identifier: identifier,
                password: password,
              );
              if (!kIsWeb) {
                TextInput.finishAutofillContext(shouldSave: true);
              }
            } else if (!rememberMe) {
              await repo.clearRememberedCredentials();
              if (!kIsWeb) {
                TextInput.finishAutofillContext(shouldSave: false);
              }
            }

            if (!context.mounted) return;

            if (auth.isFirstLogin) {
              context.go('/change-password');
            } else if (auth.needsEmailVerification) {
              context.go('/verify-emails');
            } else if (auth.isSuperAdmin) {
              context.go('/platform');
            } else {
              context.go('/home');
            }
          }
        },
        builder: (context, auth) {
          final submitting = auth.isSubmitting || checkingLocation;

          return Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sign in',
                  style: GoogleFonts.fraunces(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: _C.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome back! Location is MANDATORY — GPS must be on to sign in.',
                  style: GoogleFonts.sourceSans3(
                    fontSize: 14,
                    color: _C.mute,
                  ),
                ),
                const SizedBox(height: 26),
                TextFormField(
                  key: const ValueKey('login-username-field'),
                  controller: identifierController,
                  focusNode: identifierFocusNode,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => passwordFocusNode.requestFocus(),
                  autofillHints: kIsWeb ? const [] : const [AutofillHints.username],
                  style: GoogleFonts.sourceSans3(
                    color: _C.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                  cursorColor: _C.ink,
                  decoration: _fieldDecoration(
                    hint: 'Employee Code / Username',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Employee ID or username is required';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (auth.errorMessage != null) {
                      context.read<AuthBloc>().add(const AuthClearErrorRequested());
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('login-password-field'),
                  controller: passwordController,
                  focusNode: passwordFocusNode,
                  obscureText: obscurePassword,
                  obscuringCharacter: '•',
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => submitting ? null : onSubmit(),
                  autofillHints: kIsWeb ? const [] : const [AutofillHints.password],
                  style: GoogleFonts.sourceSans3(
                    color: _C.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                  cursorColor: _C.ink,
                  decoration: _fieldDecoration(
                    hint: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      onPressed: onToggleObscure,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (auth.errorMessage != null) {
                      context.read<AuthBloc>().add(const AuthClearErrorRequested());
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    InkWell(
                      onTap: submitting || loadingRemembered
                          ? null
                          : () => onRememberChanged(!rememberMe),
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          SizedBox(
                            height: 22,
                            width: 22,
                            child: Checkbox(
                              value: rememberMe,
                              onChanged: submitting || loadingRemembered
                                  ? null
                                  : (v) => onRememberChanged(v ?? false),
                              activeColor: _C.ink,
                              checkColor: _C.card,
                              side: const BorderSide(color: _C.line),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remember me',
                            style: GoogleFonts.sourceSans3(
                              color: _C.mute,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Contact your admin to reset your password.',
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.sourceSans3(
                          color: _C.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  InlineBanner.error(message: auth.errorMessage!),
                  if (!kReleaseMode &&
                      (auth.errorMessage!.contains('Unable to reach server') ||
                          auth.errorMessage!.contains('reach the server'))) ...[
                    const SizedBox(height: 8),
                    BlocBuilder<ApiUrlCubit, String>(
                      buildWhen: (previous, current) => previous != current,
                      builder: (context, currentUrl) {
                        final isLocal = currentUrl.contains('127.0.0.1') ||
                            currentUrl.contains('localhost');
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: submitting
                                ? null
                                : () {
                                    final target = isLocal
                                        ? AppConfig.liveApiBaseUrl
                                        : AppConfig.localApiBaseUrl;
                                    context.read<ApiUrlCubit>().setUrl(target);
                                    context
                                        .read<AuthBloc>()
                                        .add(const AuthClearErrorRequested());
                                    onSubmit();
                                  },
                            child: Text(
                              isLocal ? 'Switch to Live Server' : 'Switch to Local Server',
                              style: GoogleFonts.sourceSans3(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _C.ink,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
                if (auth.infoMessage != null) ...[
                  const SizedBox(height: 14),
                  InlineBanner.info(message: auth.infoMessage!),
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
                                'Continue',
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(const AuthClearErrorRequested());
                      context.go('/superadmin/login');
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Platform Superadmin →',
                      style: GoogleFonts.sourceSans3(
                        color: _C.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (InstallAndroidAppButton.visible) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: _C.apkBg,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => InstallAndroidAppButton.download(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.android_rounded, color: _C.gold, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Install Android app (.apk)',
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _C.ink,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: _C.ink.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (!kReleaseMode) ...[
                  const SizedBox(height: 12),
                  BackendEnvSwitcher.card(enabled: !submitting),
                ],
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
                    Text(
                      'Access is private and audited.',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 12,
                        color: _C.mute,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Version $kAppVersion',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: _C.gold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _C.field,
      hintStyle: GoogleFonts.sourceSans3(
        color: _C.mute.withValues(alpha: 0.7),
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: _C.mute,
      suffixIconColor: _C.mute,
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
    );
  }
}
