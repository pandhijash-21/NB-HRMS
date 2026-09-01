import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_envelope.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/nb_icon.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/admin_models.dart';
import '../admin_notifier.dart';

final _storageUsageProvider = FutureProvider.autoDispose<StorageUsage>((ref) {
  return ref.read(adminRepositoryProvider).getStorageUsage();
});

class AdminStorageScreen extends ConsumerWidget {
  const AdminStorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final isAdmin = Permissions.isAdmin(auth.user?.role);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Only Admin can view storage.')),
      );
    }

    final usageAsync = ref.watch(_storageUsageProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Storage',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        leading: const AppBackButton(fallbackLocation: '/admin/configurations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const NbIcon(Icons.refresh_rounded, color: Color(0xFFC5A059)),
            onPressed: () => ref.invalidate(_storageUsageProvider),
          ),
        ],
      ),
      body: usageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: e is ApiException ? e.message : '$e',
          onRetry: () => ref.invalidate(_storageUsageProvider),
        ),
        data: (usage) => _StorageBody(
          usage: usage,
          isDark: isDark,
          onPurged: () => ref.invalidate(_storageUsageProvider),
        ),
      ),
    );
  }
}

class _StorageBody extends ConsumerStatefulWidget {
  const _StorageBody({
    required this.usage,
    required this.isDark,
    required this.onPurged,
  });

  final StorageUsage usage;
  final bool isDark;
  final VoidCallback onPurged;

  @override
  ConsumerState<_StorageBody> createState() => _StorageBodyState();
}

class _StorageBodyState extends ConsumerState<_StorageBody> {
  bool _purging = false;

  @override
  Widget build(BuildContext context) {
    final usage = widget.usage;
    final isDark = widget.isDark;
    final remainingPct = usage.hasLimit ? (usage.remainingRatio * 100).clamp(0, 100) : null;
    final usedPct = usage.hasLimit ? (usage.usedRatio * 100).clamp(0, 100) : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        _Card(
          isDark: isDark,
          child: Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                width: 196,
                height: 196,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 196,
                      height: 196,
                      child: CircularProgressIndicator(
                        value: usage.hasLimit ? usage.usedRatio.clamp(0.0, 1.0) : 0,
                        strokeWidth: 14,
                        backgroundColor: isDark
                            ? const Color(0xFFC5A059).withValues(alpha: 0.14)
                            : const Color(0xFFE5ECF0),
                        color: usage.hasLimit && usage.usedRatio >= 0.9
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFC5A059),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          remainingPct != null ? '${remainingPct.round()}%' : _fmtBytes(usage.usedBytes),
                          style: TextStyle(
                            fontSize: remainingPct != null ? 36 : 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          remainingPct != null ? 'remaining' : 'used',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                usage.hasLimit
                    ? '${_fmtBytes(usage.usedBytes)} of ${_fmtBytes(usage.limitBytes)} used'
                    : '${_fmtBytes(usage.usedBytes)} used',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                usage.hasLimit
                    ? '${_fmtBytes(usage.remainingBytes)} free${usedPct != null ? ' · ${usedPct.round()}% used' : ''}'
                    : (usage.cloudinaryConfigured
                        ? 'Plan limit not reported by Cloudinary'
                        : 'Cloudinary is not configured — showing collaboration files only'),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                ),
              ),
              if (usage.cloudinaryPlan != null && usage.cloudinaryPlan!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Plan: ${usage.cloudinaryPlan}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFFC5A059),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
              const SizedBox(height: 10),
              _RowStat(label: 'Chat & meeting files', value: _fmtBytes(usage.collabBytes), hint: '${usage.collabObjects} objects'),
              _RowStat(label: 'Chat messages', value: '${usage.chatMessages}'),
              _RowStat(label: 'Chat attachments', value: '${usage.chatAttachments}'),
              _RowStat(label: 'Meeting chat', value: '${usage.meetingChats}'),
              _RowStat(label: 'Repository documents', value: '${usage.repositoryDocs}', last: true),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Danger zone',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Clears chat and meeting text, uploaded documents, photos, resumes, letters, and recordings. Employee records, payroll, and attendance are kept.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: isDark ? Colors.white54 : const Color(0xFF607D8B),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _purging ? null : _confirmPurge,
          icon: _purging
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const NbIcon(Icons.delete_forever_rounded, color: Colors.white),
          label: Text(_purging ? 'Clearing…' : 'Clear all text and documents'),
        ),
      ],
    );
  }

  Future<void> _confirmPurge() async {
    final messenger = ScaffoldMessenger.of(context);
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _AdminPasswordDialog(),
    );
    if (password == null || password.isEmpty || !mounted) return;
    setState(() => _purging = true);
    try {
      await ref.read(adminRepositoryProvider).purgeStorage(password: password);
      if (!mounted) return;
      widget.onPurged();
      messenger.showSnackBar(
        const SnackBar(content: Text('Text and document data cleared.')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : '$e';
      messenger.showSnackBar(
        SnackBar(content: Text(msg.replaceFirst(RegExp(r'^Exception: '), ''))),
      );
    } finally {
      if (mounted) setState(() => _purging = false);
    }
  }
}

class _AdminPasswordDialog extends StatefulWidget {
  const _AdminPasswordDialog();

  @override
  State<_AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<_AdminPasswordDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm with admin password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes chat text, documents, photos, and files. Enter your admin password to continue.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Admin password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show' : 'Hide',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: _submit,
          child: const Text('Delete data'),
        ),
      ],
    );
  }

  void _submit() {
    final password = _ctrl.text;
    if (password.trim().isEmpty) return;
    Navigator.pop(context, password);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.isDark, required this.child});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withValues(alpha: 0.16)
              : const Color(0xFFCFD8DC),
        ),
      ),
      child: child,
    );
  }
}

class _RowStat extends StatelessWidget {
  const _RowStat({
    required this.label,
    required this.value,
    this.hint,
    this.last = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const kb = 1024.0;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / gb).toStringAsFixed(2)} GB';
}
