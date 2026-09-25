import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app_version.dart';
import '../../data/platform_repository.dart';

class AppVersionPolicyCard extends StatefulWidget {
  const AppVersionPolicyCard({
    super.key,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  @override
  State<AppVersionPolicyCard> createState() => _AppVersionPolicyCardState();
}

class _AppVersionPolicyCardState extends State<AppVersionPolicyCard> {
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _web = TextEditingController();
  final _android = TextEditingController();
  final _ios = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _web.dispose();
    _android.dispose();
    _ios.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final policy = await context.read<PlatformRepository>().getAppVersionPolicy();
      if (!mounted) return;
      _min.text = policy.minVersion;
      _max.text = policy.maxVersion;
      _web.text = policy.updateUrlWeb;
      _android.text = policy.updateUrlAndroid;
      _ios.text = policy.updateUrlIos;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await context.read<PlatformRepository>().saveAppVersionPolicy(
            minVersion: _min.text.trim(),
            maxVersion: _max.text.trim(),
            updateUrlWeb: _web.text.trim(),
            updateUrlAndroid: _android.text.trim(),
            updateUrlIos: _ios.text.trim(),
          );
      if (!mounted) return;
      _min.text = saved.minVersion;
      _max.text = saved.maxVersion;
      _web.text = saved.updateUrlWeb;
      _android.text = saved.updateUrlAndroid;
      _ios.text = saved.updateUrlIos;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App version policy saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.borderColor),
      ),
      padding: const EdgeInsets.all(24),
      child: _loading
          ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App version',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: widget.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Installed app is $kAppVersion. Below the minimum, people must update before they can continue. Below the latest version, they see a dismissible update notice each time they open the app. The Update button opens the link for the device they are using.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: widget.textSecondary),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _field('min_version', 'Minimum version', _min, '1.0.0'),
                    _field('max_version', 'Latest version', _max, '1.0.1'),
                  ],
                ),
                const SizedBox(height: 12),
                _field('Web update link', 'Opened in the browser app', _web, 'https://', wide: true),
                const SizedBox(height: 12),
                _field('Android update link', 'Opened in the Android app', _android, 'https://play.google.com/...', wide: true),
                const SizedBox(height: 12),
                _field('iOS update link', 'Opened in the iOS app', _ios, 'https://apps.apple.com/...', wide: true),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save version policy'),
                ),
              ],
            ),
    );
  }

  Widget _field(String label, String hint, TextEditingController controller, String example, {bool wide = false}) {
    return SizedBox(
      width: wide ? double.infinity : 280,
      child: TextField(
        controller: controller,
        keyboardType: wide ? TextInputType.url : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: example,
          helperText: hint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
