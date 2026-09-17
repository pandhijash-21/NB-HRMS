import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/platform_repository.dart';
import '../../domain/platform_models.dart';

/// Superadmin dialog: grant System Admin privileges to people without changing designation.
class CompanyGrantAdminSheet extends StatefulWidget {
  const CompanyGrantAdminSheet({
    super.key,
    required this.company,
    required this.repository,
  });

  final ClientCompany company;
  final PlatformRepository repository;

  static Future<void> show(
    BuildContext context, {
    required ClientCompany company,
    required PlatformRepository repository,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CompanyGrantAdminSheet(
        company: company,
        repository: repository,
      ),
    );
  }

  @override
  State<CompanyGrantAdminSheet> createState() => _CompanyGrantAdminSheetState();
}

class _CompanyGrantAdminSheetState extends State<CompanyGrantAdminSheet> {
  List<CompanyPerson> _people = const [];
  bool _loading = true;
  String? _error;
  String _search = '';
  final Set<int> _updating = {};
  Timer? _searchDebounce;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.listCompanyPeople(
        widget.company.id,
        search: search,
      );
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _people = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      final q = value.trim();
      _load(search: q.length >= 2 ? q : null);
    });
  }

  Future<void> _grant(CompanyPerson person) async {
    if (_updating.contains(person.employeeId)) return;
    setState(() => _updating.add(person.employeeId));
    try {
      final rows = await widget.repository.grantCompanyAdmin(
        widget.company.id,
        person.employeeId,
      );
      if (!mounted) return;
      setState(() => _people = rows);
      await _load(search: _search.trim().length >= 2 ? _search.trim() : null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${person.fullName} now has System Admin privileges. Designation stays ${person.designation ?? 'unchanged'}.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Grant failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(person.employeeId));
    }
  }

  Future<void> _revoke(CompanyPerson person) async {
    if (_updating.contains(person.employeeId)) return;
    setState(() => _updating.add(person.employeeId));
    try {
      final rows = await widget.repository.revokeCompanyAdmin(
        widget.company.id,
        person.employeeId,
      );
      if (!mounted) return;
      setState(() => _people = rows);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Revoked System Admin privileges for ${person.fullName}.'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revoke failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(person.employeeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);
    final surface = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final border = isDark ? const Color(0xFF3D3830) : const Color(0xFFE2E8F0);
    final q = _search.trim().toLowerCase();
    final filtered = _people.where((p) {
      if (q.isEmpty) return true;
      return p.fullName.toLowerCase().contains(q) ||
          (p.employeeCode ?? '').toLowerCase().contains(q) ||
          (p.designation ?? '').toLowerCase().contains(q) ||
          (p.username ?? '').toLowerCase().contains(q);
    }).toList();

    return Dialog(
      backgroundColor: surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: SizedBox(
        width: 720,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        color: Color(0xFF0EA5E9), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grant Company Admin — ${widget.company.name}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gives the same privileges as the System Admin login. Designation (e.g. HR HEAD) stays the same.',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search people added by this company\'s admins…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center,
                                    style: const TextStyle(color: Color(0xFFEF4444))),
                                const SizedBox(height: 12),
                                FilledButton(onPressed: _load, child: const Text('Retry')),
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                _people.isEmpty
                                    ? 'No people added by this company\'s admins yet.'
                                    : 'No matches.',
                                style: TextStyle(color: textSecondary),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: border),
                              itemBuilder: (context, i) {
                                final person = filtered[i];
                                final busy = _updating.contains(person.employeeId);
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  title: Text(
                                    person.fullName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          [
                                            if ((person.employeeCode ?? '').isNotEmpty)
                                              person.employeeCode,
                                            if ((person.designation ?? '').isNotEmpty)
                                              person.designation,
                                            if ((person.username ?? '').isNotEmpty)
                                              '@${person.username}',
                                          ].join(' · '),
                                          style: TextStyle(fontSize: 12, color: textSecondary),
                                        ),
                                        if (person.isNativeAdmin)
                                          _chip('Built-in System Admin', const Color(0xFF6366F1)),
                                        if (person.companyAdminGranted)
                                          _chip('Granted System Admin', const Color(0xFF0EA5E9)),
                                        if (!person.hasLoginAccount)
                                          _chip('No login account', const Color(0xFFEF4444)),
                                      ],
                                    ),
                                  ),
                                  trailing: busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : person.canGrant
                                          ? FilledButton(
                                              onPressed: () => _grant(person),
                                              child: const Text('Grant admin'),
                                            )
                                          : person.canRevoke
                                              ? OutlinedButton(
                                                  onPressed: () => _revoke(person),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: const Color(0xFFEF4444),
                                                  ),
                                                  child: const Text('Revoke'),
                                                )
                                              : null,
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
