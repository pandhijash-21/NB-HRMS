import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/org_models.dart';
import '../org_providers.dart';

class DesignationsScreen extends ConsumerStatefulWidget {
  const DesignationsScreen({super.key});

  @override
  ConsumerState<DesignationsScreen> createState() => _DesignationsScreenState();
}

class _DesignationsScreenState extends ConsumerState<DesignationsScreen> {
  final _nameCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final role = auth.user?.role ?? '';
    final hasAccess = Permissions.canManageUsers(auth.permissions, role);

    if (!hasAccess) {
      return const Scaffold(
        body: Center(child: Text('Access Denied')),
      );
    }

    final jobDesignations = ref.watch(jobDesignationsProvider);
    final positions = ref.watch(positionDesignationsProvider);
    final slots = ref.watch(positionSlotsProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Designations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Create job designations for employees, then alias accounts (HOI-GIT, …) linked to positions.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          _buildCreateDesignationCard(),
          const SizedBox(height: 16),
          jobDesignations.when(
            data: (list) => _buildDesignationsList(list),
            loading: () => const _LoadingCard(),
            error: (err, _) => _ErrorCard(
              message: 'Failed to load designations',
              detail: '$err',
              onRetry: () => ref.invalidate(jobDesignationsProvider),
            ),
          ),
          const SizedBox(height: 16),
          positions.when(
            data: (list) {
              if (list.isEmpty) return const SizedBox.shrink();
              return _buildPositionsReference(list);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _AliasAccountsSection(
            slotsAsync: slots,
            onRefresh: _refreshAll,
          ),
        ],
      ),
    );
  }

  void _refreshAll() {
    ref.invalidate(jobDesignationsProvider);
    ref.invalidate(positionDesignationsProvider);
    ref.invalidate(positionSlotsProvider);
    ref.invalidate(positionsListProvider);
    ref.invalidate(activeInstitutesProvider);
  }

  Widget _buildCreateDesignationCard() {
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
              'Add job designation',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.midnight),
            ),
            const SizedBox(height: 4),
            const Text(
              'For employees (Professor, Clerk, …). Supports salary structures.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _creating || _nameCtrl.text.trim().isEmpty ? null : _createDesignation,
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

  Widget _buildDesignationsList(List<Designation> list) {
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
              'Job designations',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.midnight),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Text('No designations yet.', style: TextStyle(color: AppColors.textSecondary))
            else
              ...list.map((d) => _designationRow(d)),
          ],
        ),
      ),
    );
  }

  Widget _designationRow(Designation d) {
    return Opacity(
      opacity: d.isActive ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(d.name)),
            Text(
              d.isActive ? 'Active' : 'Inactive',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            Switch(
              value: d.isActive,
              activeThumbColor: AppColors.bronze,
              onChanged: (checked) => _toggleDesignation(d.id, checked),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionsReference(List<Designation> positions) {
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
              'Positions',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.midnight),
            ),
            const SizedBox(height: 4),
            const Text(
              'Created from Workforce. Edit permissions in Roles & Permissions.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: positions.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (p.linkedRole != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          p.linkedRole!.name,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.midnight,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDesignation() async {
    setState(() => _creating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orgRepositoryProvider).createDesignation(
            name: _nameCtrl.text.trim(),
          );
      _nameCtrl.clear();
      ref.invalidate(jobDesignationsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Designation added')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _toggleDesignation(String id, bool isActive) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orgRepositoryProvider).updateDesignation(id, isActive: isActive);
      ref.invalidate(jobDesignationsProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}

class _AliasAccountsSection extends ConsumerStatefulWidget {
  const _AliasAccountsSection({
    required this.slotsAsync,
    required this.onRefresh,
  });

  final AsyncValue<List<PositionSlot>> slotsAsync;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_AliasAccountsSection> createState() => _AliasAccountsSectionState();
}

class _AliasAccountsSectionState extends ConsumerState<_AliasAccountsSection> {
  String? _designationId;
  String? _instituteId;
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: '01011998');
  bool _universityWide = false;
  bool _grantUniversityAccess = false;
  bool _creating = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positionsAsync = ref.watch(positionDesignationsProvider);
    final institutesAsync = ref.watch(activeInstitutesProvider);

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
              'Alias accounts',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.midnight),
            ),
            const SizedBox(height: 4),
            const Text(
              'Institute logins (e.g. HOI-GIT). Each picks a position and inherits its permissions.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            positionsAsync.when(
              data: (positions) {
                if (positions.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No positions yet. Create one from Workforce → Positions first.',
                    ),
                  );
                }
                return _buildForm(positions, institutesAsync);
              },
              loading: () => const _LoadingCard(),
              error: (err, _) => _ErrorCard(
                message: 'Failed to load positions',
                detail: '$err',
                onRetry: () => ref.invalidate(positionDesignationsProvider),
              ),
            ),
            const Divider(height: 32),
            const Text(
              'EXISTING ALIAS ACCOUNTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            widget.slotsAsync.when(
              data: (slots) {
                if (slots.isEmpty) {
                  return const Text('None yet.', style: TextStyle(color: AppColors.textSecondary));
                }
                return Column(
                  children: slots.map(_slotRow).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.bronze)),
              error: (err, _) => _ErrorCard(
                message: 'Failed to load alias accounts',
                detail: '$err',
                onRetry: widget.onRefresh,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(List<Designation> positions, AsyncValue<List<Institute>> institutesAsync) {
    final selected = _designationId == null
        ? null
        : positions.cast<Designation?>().firstWhere(
              (p) => p!.id == _designationId,
              orElse: () => null,
            );
    final instituteList = institutesAsync.asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _designationId,
          decoration: const InputDecoration(labelText: 'Position'),
          items: positions
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    '${p.name}${p.linkedRole != null ? ' (${p.linkedRole!.name})' : ''}',
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() {
              _designationId = v;
              if (v == null) return;
              final picked = positions.firstWhere((p) => p.id == v);
              _syncCodeName(picked, instituteList);
            });
          },
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('University-wide (no institute binding)'),
          subtitle: const Text('For IT Admin, VC, Registrar, etc.'),
          value: _universityWide,
          onChanged: (v) {
            setState(() {
              _universityWide = v ?? false;
              if (_universityWide) {
                _instituteId = null;
              } else {
                _grantUniversityAccess = false;
              }
              _syncCodeName(selected, instituteList);
            });
          },
        ),
        if (_universityWide)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Grant full university admin access'),
            value: _grantUniversityAccess,
            onChanged: (v) => setState(() => _grantUniversityAccess = v ?? false),
          ),
        if (!_universityWide)
          institutesAsync.when(
            data: (institutes) => DropdownButtonFormField<String>(
              initialValue: _instituteId,
              decoration: const InputDecoration(labelText: 'Institute'),
              items: institutes
                  .map(
                    (i) => DropdownMenuItem(
                      value: i.id,
                      child: Text('${i.name} (${i.code})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _instituteId = v;
                  _syncCodeName(selected, institutes);
                });
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Failed to load institutes'),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeCtrl,
          decoration: const InputDecoration(labelText: 'Login code'),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          decoration: const InputDecoration(labelText: 'Initial password'),
          obscureText: true,
        ),
        if (selected != null && selected.linkedRoleId == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'This position has no role linked.',
              style: TextStyle(color: AppColors.error.withValues(alpha: 0.9)),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _canSubmit(selected) && !_creating ? _createAlias : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.midnight,
            foregroundColor: Colors.white,
          ),
          child: _creating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create alias account'),
        ),
      ],
    );
  }

  void _syncCodeName(Designation? selected, List<Institute>? institutes) {
    if (selected == null) return;
    final roleLabel = selected.linkedRole?.name ?? 'POS';
    if (_universityWide) {
      _codeCtrl.text = roleLabel;
      _nameCtrl.text = selected.name;
      return;
    }
    final institute = institutes?.cast<Institute?>().firstWhere(
          (i) => i?.id == _instituteId,
          orElse: () => null,
        );
    if (institute == null) return;
    _codeCtrl.text = '$roleLabel-${institute.code}';
    _nameCtrl.text = '${selected.name} — ${institute.code}';
  }

  bool _canSubmit(Designation? selected) {
    return _designationId != null &&
        _codeCtrl.text.trim().isNotEmpty &&
        _nameCtrl.text.trim().isNotEmpty &&
        _passwordCtrl.text.isNotEmpty &&
        selected?.linkedRoleId != null &&
        (_universityWide || _instituteId != null);
  }

  Future<void> _createAlias() async {
    setState(() => _creating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(orgRepositoryProvider).createPositionSlot(
            code: _codeCtrl.text.trim().toUpperCase(),
            name: _nameCtrl.text.trim(),
            designationId: _designationId!,
            instituteId: _universityWide ? null : _instituteId,
            password: _passwordCtrl.text,
            grantUniversityAccess: _universityWide && _grantUniversityAccess,
          );
      widget.onRefresh();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Alias created'),
          content: Text(
            'Login: ${result.loginId ?? result.slot.code}\nPassword: ${result.password ?? _passwordCtrl.text}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      setState(() {
        _designationId = null;
        _instituteId = null;
        _codeCtrl.clear();
        _nameCtrl.clear();
        _universityWide = false;
        _grantUniversityAccess = false;
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Widget _slotRow(PositionSlot slot) {
    final active = slot.user?.isActive ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: AppColors.midnight,
                  ),
                ),
                Text(slot.name, style: const TextStyle(fontSize: 13)),
                Text(
                  'Position: ${slot.designation.name} · Role: ${slot.linkedRole.name}'
                  '${slot.subOrganization != null ? ' · ${slot.subOrganization}' : ' · University-wide'}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active ? AppColors.successSoft : AppColors.mist,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              active ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: AppColors.bronze)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
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
