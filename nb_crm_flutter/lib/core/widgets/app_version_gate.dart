import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_version.dart';
import '../network/dio_client.dart';
import '../services/branding_config.dart';
import '../utils/open_url.dart';

/// Blocks the app when it is below the Superadmin minimum version, and
/// shows a dismissible update notice on each entry when a newer version exists.
class AppVersionGate extends StatefulWidget {
  const AppVersionGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends State<AppVersionGate> with WidgetsBindingObserver {
  bool _hard = false;
  bool _softVisible = false;
  bool _softDismissedThisVisit = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _softDismissedThisVisit = false;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    if (!mounted || _checking) return;
    _checking = true;
    try {
      await BrandingConfig.fetch(context.read<DioClient>());
      if (!mounted) return;
      final kind = appUpdateKind(
        current: kAppVersion,
        minVersion: BrandingConfig.minVersion,
        maxVersion: BrandingConfig.maxVersion,
      );
      setState(() => _hard = kind == AppUpdateKind.hard);
      if (kind == AppUpdateKind.soft && !_softVisible && !_softDismissedThisVisit) {
        _softVisible = true;
        _showSoft();
      }
    } finally {
      _checking = false;
    }
  }

  String get _updateTarget => BrandingConfig.updateLinkForThisDevice();

  Future<void> _openUpdate() async {
    final target = _updateTarget;
    if (!target.startsWith('http')) return;
    await openExternalUrl(target);
  }

  void _showSoft() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Update available'),
          content: Text(
            'Version ${BrandingConfig.maxVersion} is available. You are on $kAppVersion.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: BrandingConfig.updateLinkForThisDevice().startsWith('http')
                  ? () {
                      Navigator.of(ctx).pop();
                      _openUpdate();
                    }
                  : null,
              child: const Text('Update'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      _softVisible = false;
      _softDismissedThisVisit = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_hard)
          const Positioned.fill(child: _HardUpdateWall()),
      ],
    );
  }
}

class _HardUpdateWall extends StatelessWidget {
  const _HardUpdateWall();

  @override
  Widget build(BuildContext context) {
    final latest = BrandingConfig.maxVersion.trim();
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.system_update_alt_rounded, size: 36, color: Color(0xFF1A1F1B)),
                      const SizedBox(height: 14),
                      const Text(
                        'Update required',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1F1B)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        latest.isEmpty
                            ? 'This version ($kAppVersion) is no longer supported. Install the latest app to continue.'
                            : 'This version ($kAppVersion) is no longer supported. Install $latest or newer to continue.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF6F766F)),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: BrandingConfig.updateLinkForThisDevice().startsWith('http')
                            ? () => openExternalUrl(BrandingConfig.updateLinkForThisDevice())
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1F1B),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF1A1F1B).withValues(alpha: 0.35),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Update now', style: TextStyle(fontWeight: FontWeight.w700)),
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
