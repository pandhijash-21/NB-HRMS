import 'package:flutter/material.dart';

import '../../data/platform_repository.dart';
import '../../domain/platform_models.dart';
import '../../../rbac/domain/rbac_models.dart';

/// Superadmin dialog: per-company System Admin capability matrix.
class CompanyAdminAccessSheet extends StatefulWidget {
  const CompanyAdminAccessSheet({
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
      builder: (ctx) => CompanyAdminAccessSheet(
        company: company,
        repository: repository,
      ),
    );
  }

  @override
  State<CompanyAdminAccessSheet> createState() => _CompanyAdminAccessSheetState();
}

class _CompanyAdminAccessSheetState extends State<CompanyAdminAccessSheet> {
  static const _columns = [
    ('canRead', 'Read'),
    ('canWrite', 'Write'),
    ('canApprove', 'Approve'),
    ('canDelete', 'Delete'),
    ('canExport', 'Export'),
  ];

  List<ModulePermission> _perms = const [];
  bool _loading = true;
  String? _error;
  String _categoryFilter = 'ALL';
  String _search = '';
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.getCompanyAdminPermissions(widget.company.id);
      if (!mounted) return;
      setState(() {
        _perms = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _normalize(ModulePermission current, Map<String, dynamic> data) {
    final patch = Map<String, dynamic>.from(data);
    final canRead = patch.containsKey('canRead') ? patch['canRead'] == true : current.canRead;
    final canWrite = patch.containsKey('canWrite') ? patch['canWrite'] == true : current.canWrite;
    final canApprove = patch.containsKey('canApprove') ? patch['canApprove'] == true : current.canApprove;
    final canDelete = patch.containsKey('canDelete') ? patch['canDelete'] == true : current.canDelete;
    final canExport = patch.containsKey('canExport') ? patch['canExport'] == true : current.canExport;

    if (canWrite || canApprove || canDelete || canExport) {
      patch['canRead'] = true;
    } else if (patch.containsKey('canRead') && patch['canRead'] != true) {
      patch['canWrite'] = false;
      patch['canApprove'] = false;
      patch['canDelete'] = false;
      patch['canExport'] = false;
    } else if (canRead) {
      patch['canRead'] = true;
    }
    return patch;
  }

  Future<void> _patch(ModulePermission current, Map<String, dynamic> data) async {
    final track = '${current.moduleKey}-${data.keys.join()}';
    if (_updating.contains(track)) return;
    final normalized = _normalize(current, data);
    setState(() => _updating.add(track));
    try {
      final rows = await widget.repository.patchCompanyAdminPermission(
        widget.company.id,
        current.moduleKey,
        normalized,
      );
      if (!mounted) return;
      setState(() => _perms = rows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
        );
        await _load();
      }
    } finally {
      if (mounted) setState(() => _updating.remove(track));
    }
  }

  Future<void> _batch(String category, bool enable) async {
    setState(() => _loading = true);
    try {
      final rows = await widget.repository.batchCompanyAdminPermissions(
        widget.company.id,
        category: category,
        enable: enable,
      );
      if (!mounted) return;
      setState(() {
        _perms = rows;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enable ? 'Granted $category access' : 'Revoked $category access'),
          backgroundColor: enable ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Batch failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  bool _boolFor(ModulePermission p, String key) {
    switch (key) {
      case 'canRead':
        return p.canRead;
      case 'canWrite':
        return p.canWrite;
      case 'canApprove':
        return p.canApprove;
      case 'canDelete':
        return p.canDelete;
      case 'canExport':
        return p.canExport;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);
    final surface = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final border = isDark ? const Color(0xFF3D3830) : const Color(0xFFE2E8F0);

    final filtered = _perms.where((p) {
      if (_categoryFilter != 'ALL' &&
          p.category.toUpperCase() != _categoryFilter.toUpperCase()) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final name = (p.module?.name ?? p.moduleKey).toLowerCase();
        return name.contains(q) || p.moduleKey.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Dialog(
      backgroundColor: surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: SizedBox(
        width: 960,
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
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: Color(0xFF6366F1), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Access — ${widget.company.name}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shared by all System Admins of this company. Includes Collaboration modules.',
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ALL', label: Text('All')),
                      ButtonSegment(value: 'HRMS', label: Text('HRMS')),
                      ButtonSegment(value: 'CRM', label: Text('CRM')),
                      ButtonSegment(value: 'ERP', label: Text('ERP')),
                      ButtonSegment(value: 'COLLABORATION', label: Text('Collab')),
                    ],
                    selected: {_categoryFilter},
                    onSelectionChanged: (v) => setState(() => _categoryFilter = v.first),
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _batch(_categoryFilter, true),
                    icon: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                    label: const Text('Grant'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _batch(_categoryFilter, false),
                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFFEF4444)),
                    label: const Text('Revoke'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    height: 36,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Filter modules...',
                        hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Text('No modules match.', style: TextStyle(color: textSecondary)),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(2.6),
                                  1: FlexColumnWidth(1),
                                  2: FlexColumnWidth(1),
                                  3: FlexColumnWidth(1),
                                  4: FlexColumnWidth(1),
                                  5: FlexColumnWidth(1),
                                  6: FlexColumnWidth(0.7),
                                },
                                border: TableBorder(
                                  horizontalInside: BorderSide(color: border),
                                  top: BorderSide(color: border),
                                  bottom: BorderSide(color: border),
                                  left: BorderSide(color: border),
                                  right: BorderSide(color: border),
                                ),
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF292524)
                                          : const Color(0xFFF8FAFC),
                                    ),
                                    children: [
                                      _header('Module', textPrimary),
                                      for (final c in _columns) _header(c.$2, textPrimary),
                                      _header('All', textPrimary),
                                    ],
                                  ),
                                  for (final p in filtered)
                                    TableRow(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.module?.name ?? p.moduleKey,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: textPrimary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                '${p.category} · ${p.moduleKey}',
                                                style: TextStyle(fontSize: 10, color: textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        for (final c in _columns)
                                          Center(
                                            child: Switch.adaptive(
                                              value: _boolFor(p, c.$1),
                                              onChanged: _updating.any((k) => k.startsWith(p.moduleKey))
                                                  ? null
                                                  : (v) => _patch(p, {c.$1: v}),
                                            ),
                                          ),
                                        Center(
                                          child: IconButton(
                                            tooltip: 'Toggle all actions',
                                            icon: Icon(
                                              p.canRead &&
                                                      p.canWrite &&
                                                      p.canApprove &&
                                                      p.canDelete &&
                                                      p.canExport
                                                  ? Icons.check_circle_rounded
                                                  : Icons.radio_button_unchecked_rounded,
                                              color: p.canRead
                                                  ? const Color(0xFF10B981)
                                                  : textSecondary,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              final all = p.canRead &&
                                                  p.canWrite &&
                                                  p.canApprove &&
                                                  p.canDelete &&
                                                  p.canExport;
                                              _patch(p, {
                                                'canRead': !all,
                                                'canWrite': !all,
                                                'canApprove': !all,
                                                'canDelete': !all,
                                                'canExport': !all,
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
