import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!hasAccess) {
      return _accessDenied(isDark);
    }

    final jobDesignations = ref.watch(jobDesignationsProvider);
    final positions = ref.watch(positionDesignationsProvider);
    final slots = ref.watch(positionSlotsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Designations',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
          ),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/admin/configurations'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC5A059)),
            tooltip: 'Refresh',
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0.0, 30.0 * (1.0 - value)),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Text(
              'Create job designations for employees, then alias accounts (HOI-GIT, …) linked to positions.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : const Color(0xFF607D8B),
              ),
            ),
            const SizedBox(height: 20),
            _buildCreateDesignationCard(isDark),
            const SizedBox(height: 20),
            jobDesignations.when(
              data: (list) => _buildDesignationsList(list, isDark),
              loading: () => _LoadingCard(isDark: isDark),
              error: (err, _) => _ErrorCard(
                isDark: isDark,
                message: 'Failed to load designations',
                detail: '$err',
                onRetry: () => ref.invalidate(jobDesignationsProvider),
              ),
            ),
            const SizedBox(height: 20),
            positions.when(
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                return _buildPositionsReference(list, isDark);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            _AliasAccountsSection(
              slotsAsync: slots,
              onRefresh: _refreshAll,
            ),
          ],
        ),
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

  Widget _buildCreateDesignationCard(bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_rounded, color: Color(0xFFC5A059), size: 20),
                const SizedBox(width: 10),
                Text(
                  'Add Job Designation',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'For employees (Professor, Clerk, …). Supports salary structures.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : const Color(0xFF607D8B),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                prefixIcon: const Icon(Icons.work_rounded, color: Color(0xFFC5A059), size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
                ),
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: _creating || _nameCtrl.text.trim().isEmpty ? null : _createDesignation,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                    foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                    disabledBackgroundColor: isDark ? const Color(0xFFC5A059).withOpacity(0.3) : const Color(0xFFCFD8DC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _creating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    _creating ? 'Adding…' : 'Add',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesignationsList(List<Designation> list, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: Color(0xFFC5A059), size: 20),
              const SizedBox(width: 10),
              Text(
                'Job Designations',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                  ),
                ),
                child: Text(
                  '${list.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (list.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.badge_rounded, size: 64, color: isDark ? Colors.white10 : Colors.black12),
                  const SizedBox(height: 16),
                  Text(
                    'No designations yet.',
                    style: TextStyle(
                      color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...list.map((d) => _designationRow(d, isDark)),
      ],
    );
  }

  Widget _designationRow(Designation d, bool isDark) {
    return Opacity(
      opacity: d.isActive ? 1 : 0.5,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                  ),
                ),
                child: Icon(
                  Icons.work_rounded,
                  color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  d.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: d.isActive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  border: Border.all(
                    color: d.isActive ? Colors.green : Colors.grey,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  d.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: d.isActive ? Colors.green : Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Switch(
                value: d.isActive,
                activeColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                onChanged: (checked) => _toggleDesignation(d.id, checked),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                onPressed: () => _confirmDeleteDesignation(d),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositionsReference(List<Designation> positions, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_rounded, color: Color(0xFFC5A059), size: 20),
                const SizedBox(width: 10),
                Text(
                  'Positions',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                    ),
                  ),
                  child: Text(
                    '${positions.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Created from Workforce. Edit permissions in Roles & Permissions.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : const Color(0xFF607D8B),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: positions.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                    border: Border.all(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_rounded,
                        color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                      if (p.linkedRole != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.linkedRole!.name,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF2E7D32),
                            ),
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
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
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
        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDeleteDesignation(Designation d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete designation?'),
        content: Text(
          'Delete "${d.name}"?\n\n'
          'If employees or salary structures still use it, it will be deactivated instead.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orgRepositoryProvider).deleteDesignation(d.id);
      ref.invalidate(jobDesignationsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Designation deleted / deactivated')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _accessDenied(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gpp_bad_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF212F3D),
              ),
            ),
          ],
        ),
      ),
    );
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

  InputDecoration _styledInput(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: const Color(0xFFC5A059), size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final positionsAsync = ref.watch(positionDesignationsProvider);
    final institutesAsync = ref.watch(activeInstitutesProvider);

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.manage_accounts_rounded, color: Color(0xFFC5A059), size: 20),
                const SizedBox(width: 10),
                Text(
                  'Alias Accounts',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Institute logins (e.g. HOI-GIT). Each picks a position and inherits its permissions.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : const Color(0xFF607D8B),
              ),
            ),
            const SizedBox(height: 16),
            positionsAsync.when(
              data: (positions) {
                if (positions.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'No positions yet. Create one from Workforce → Positions first.',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return _buildForm(positions, institutesAsync, isDark);
              },
              loading: () => _LoadingCard(isDark: isDark),
              error: (err, _) => _ErrorCard(
                isDark: isDark,
                message: 'Failed to load positions',
                detail: '$err',
                onRetry: () => ref.invalidate(positionDesignationsProvider),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 1.5,
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.key_rounded, color: Color(0xFFC5A059), size: 18),
                const SizedBox(width: 8),
                Text(
                  'EXISTING ALIAS ACCOUNTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            widget.slotsAsync.when(
              data: (slots) {
                if (slots.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.key_off_rounded, size: 48, color: isDark ? Colors.white10 : Colors.black12),
                          const SizedBox(height: 12),
                          Text(
                            'None yet.',
                            style: TextStyle(
                              color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: slots.map((s) => _slotRow(s, isDark)).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
              error: (err, _) => _ErrorCard(
                isDark: isDark,
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

  Widget _buildForm(List<Designation> positions, AsyncValue<List<Institute>> institutesAsync, bool isDark) {
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
          decoration: _styledInput('Position', Icons.account_tree_rounded, isDark),
          dropdownColor: isDark ? const Color(0xFF2B2722) : Colors.white,
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
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC),
            ),
          ),
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(
              'University-wide (no institute binding)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF212F3D),
              ),
            ),
            subtitle: Text(
              'For IT Admin, VC, Registrar, etc.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : const Color(0xFF607D8B),
              ),
            ),
            value: _universityWide,
            activeColor: const Color(0xFFC5A059),
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
        ),
        if (_universityWide) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC),
              ),
            ),
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                'Grant full university admin access',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
              value: _grantUniversityAccess,
              activeColor: const Color(0xFFC5A059),
              onChanged: (v) => setState(() => _grantUniversityAccess = v ?? false),
            ),
          ),
        ],
        if (!_universityWide) ...[
          const SizedBox(height: 14),
          institutesAsync.when(
            data: (institutes) => DropdownButtonFormField<String>(
              initialValue: _instituteId,
              decoration: _styledInput('Institute', Icons.domain_rounded, isDark),
              dropdownColor: isDark ? const Color(0xFF2B2722) : Colors.white,
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
            loading: () => const LinearProgressIndicator(color: Color(0xFFC5A059)),
            error: (_, __) => Text(
              'Failed to load institutes',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _codeCtrl,
          decoration: _styledInput('Login code', Icons.tag_rounded, isDark),
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameCtrl,
          decoration: _styledInput('Display name', Icons.label_rounded, isDark),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordCtrl,
          decoration: _styledInput('Initial password', Icons.lock_rounded, isDark),
          obscureText: true,
        ),
        if (selected != null && selected.linkedRoleId == null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This position has no role linked.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: _canSubmit(selected) && !_creating ? _createAlias : null,
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
              foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
              disabledBackgroundColor: isDark ? const Color(0xFFC5A059).withOpacity(0.3) : const Color(0xFFCFD8DC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _creating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(
              _creating ? 'Creating…' : 'Create Alias Account',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
              const SizedBox(width: 8),
              Text(
                'Alias Created',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
            ],
          ),
          content: Text(
            'Login: ${result.loginId ?? result.slot.code}\nPassword: ${result.password ?? _passwordCtrl.text}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF263238),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
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
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Widget _slotRow(PositionSlot slot, bool isDark) {
    final active = slot.user?.isActive ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF8FAFC),
        border: Border.all(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1816) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
              ),
            ),
            child: Icon(
              Icons.key_rounded,
              color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.code,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  slot.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF263238),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Position: ${slot.designation.name} · Role: ${slot.linkedRole.name}'
                  '${slot.subOrganization != null ? ' · ${slot.subOrganization}' : ' · University-wide'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : const Color(0xFF607D8B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: active ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              border: Border.all(color: active ? Colors.green : Colors.grey, width: 1.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              active ? 'ACTIVE' : 'INACTIVE',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: active ? Colors.green : Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.isDark,
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final bool isDark;
  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF212F3D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF607D8B)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
