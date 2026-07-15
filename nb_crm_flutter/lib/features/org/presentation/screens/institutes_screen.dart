import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/org_models.dart';
import '../org_providers.dart';

class InstitutesScreen extends ConsumerStatefulWidget {
  const InstitutesScreen({super.key});

  @override
  ConsumerState<InstitutesScreen> createState() => _InstitutesScreenState();
}

class _InstitutesScreenState extends ConsumerState<InstitutesScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final role = auth.user?.role ?? '';
    final hasAccess = Permissions.canManageUsers(auth.permissions, role) ||
        Permissions.canManageInstitutes(auth.permissions, role);

    if (!hasAccess) {
      return _accessDenied();
    }

    final institutesAsync = ref.watch(institutesListProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Institutes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(institutesListProvider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Configure campuses / sub-organizations.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          _buildCreateCard(context),
          const SizedBox(height: 16),
          institutesAsync.when(
            data: (institutes) => _buildListCard(context, institutes),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.bronze),
              ),
            ),
            error: (err, _) => _errorCard(
              message: 'Failed to load institutes',
              detail: '$err',
              onRetry: () => ref.invalidate(institutesListProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add institute',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.midnight),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(labelText: 'Code'),
              textCapitalization: TextCapitalization.characters,
              onChanged: (v) {
                final upper = v.toUpperCase();
                if (upper != v) {
                  _codeCtrl.value = _codeCtrl.value.copyWith(
                    text: upper,
                    selection: TextSelection.collapsed(offset: upper.length),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _creating ||
                        _codeCtrl.text.trim().isEmpty ||
                        _nameCtrl.text.trim().isEmpty
                    ? null
                    : _createInstitute,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.midnight,
                ),
                child: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context, List<Institute> institutes) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'All institutes',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.midnight),
            ),
            const SizedBox(height: 12),
            if (institutes.isEmpty)
              const Text(
                'No institutes configured yet.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ...institutes.map((inst) => _instituteRow(context, inst)),
          ],
        ),
      ),
    );
  }

  Widget _instituteRow(BuildContext context, Institute inst) {
    return Opacity(
      opacity: inst.isActive ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.midnight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.business, color: AppColors.midnight, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => context.push('/admin/institutes/${inst.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inst.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.midnight,
                      ),
                    ),
                    Text(
                      inst.code,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!inst.isActive)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Inactive',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            Switch(
              value: inst.isActive,
              activeThumbColor: AppColors.bronze,
              onChanged: (checked) => _toggleActive(inst.id, checked),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onPressed: () => context.push('/admin/institutes/${inst.id}'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInstitute() async {
    setState(() => _creating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orgRepositoryProvider).createInstitute(
            code: _codeCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
          );
      _codeCtrl.clear();
      _nameCtrl.clear();
      ref.invalidate(institutesListProvider);
      ref.invalidate(activeInstitutesProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Institute added')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to add institute: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _toggleActive(String id, bool isActive) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orgRepositoryProvider).updateInstitute(id, isActive: isActive);
      ref.invalidate(institutesListProvider);
      ref.invalidate(activeInstitutesProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update institute: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _accessDenied() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gpp_bad, size: 64, color: AppColors.error),
            SizedBox(height: 16),
            Text(
              'Access Denied',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('You do not have permission to manage institutes.'),
          ],
        ),
      ),
    );
  }

  Widget _errorCard({
    required String message,
    required String detail,
    required VoidCallback onRetry,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
