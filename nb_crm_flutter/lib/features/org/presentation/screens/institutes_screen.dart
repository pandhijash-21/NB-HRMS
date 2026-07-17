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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!hasAccess) {
      return _accessDenied(isDark);
    }

    final institutesAsync = ref.watch(institutesListProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Institutes',
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
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC5A059)),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(institutesListProvider),
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
              'Configure campuses / sub-organizations.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : const Color(0xFF607D8B),
              ),
            ),
            const SizedBox(height: 20),
            _buildCreateCard(context, isDark),
            const SizedBox(height: 20),
            institutesAsync.when(
              data: (institutes) => _buildListSection(context, institutes, isDark),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
              ),
              error: (err, _) => _errorCard(
                isDark: isDark,
                message: 'Failed to load institutes',
                detail: '$err',
                onRetry: () => ref.invalidate(institutesListProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard(BuildContext context, bool isDark) {
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
                const Icon(Icons.add_business_rounded, color: Color(0xFFC5A059), size: 20),
                const SizedBox(width: 10),
                Text(
                  'Add New Institute',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              decoration: InputDecoration(
                labelText: 'Code',
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                prefixIcon: const Icon(Icons.tag_rounded, color: Color(0xFFC5A059), size: 18),
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
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
              textCapitalization: TextCapitalization.characters,
              onChanged: (v) {
                final upper = v.toUpperCase();
                if (upper != v) {
                  _codeCtrl.value = _codeCtrl.value.copyWith(
                    text: upper,
                    selection: TextSelection.collapsed(offset: upper.length),
                  );
                }
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Full name',
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                prefixIcon: const Icon(Icons.domain_rounded, color: Color(0xFFC5A059), size: 18),
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
                  onPressed: _creating ||
                          _codeCtrl.text.trim().isEmpty ||
                          _nameCtrl.text.trim().isEmpty
                      ? null
                      : _createInstitute,
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
                    _creating ? 'Adding…' : 'Add Institute',
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

  Widget _buildListSection(BuildContext context, List<Institute> institutes, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.apartment_rounded, color: Color(0xFFC5A059), size: 20),
              const SizedBox(width: 10),
              Text(
                'All Institutes',
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
                  '${institutes.length}',
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
        if (institutes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.domain_disabled_rounded,
                    size: 64,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No institutes configured yet.',
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
          ...institutes.map((inst) => _instituteRow(context, inst, isDark)),
      ],
    );
  }

  Widget _instituteRow(BuildContext context, Institute inst, bool isDark) {
    return Opacity(
      opacity: inst.isActive ? 1 : 0.5,
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
        child: InkWell(
          onTap: () => context.push('/admin/institutes/${inst.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                    ),
                  ),
                  child: Icon(
                    Icons.business_rounded,
                    color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inst.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC),
                          ),
                        ),
                        child: Text(
                          inst.code,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF607D8B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!inst.isActive) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.12),
                      border: Border.all(color: Colors.grey, width: 1.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'INACTIVE',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                    ),
                  ),
                ],
                Switch(
                  value: inst.isActive,
                  activeColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  onChanged: (checked) => _toggleActive(inst.id, checked),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? Colors.white24 : Colors.grey,
                  size: 22,
                ),
              ],
            ),
          ),
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
        const SnackBar(content: Text('Institute added successfully')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to add institute: $e'),
          backgroundColor: Colors.red,
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
          backgroundColor: Colors.red,
        ),
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
            const SizedBox(height: 8),
            const Text(
              'You do not have permission to manage institutes.',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard({
    required bool isDark,
    required String message,
    required String detail,
    required VoidCallback onRetry,
  }) {
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
            Text(message, style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF212F3D))),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF607D8B))),
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
