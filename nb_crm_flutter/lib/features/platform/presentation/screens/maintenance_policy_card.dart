import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/app_repositories.dart';
import '../../../../core/services/branding_config.dart';
import '../../data/platform_repository.dart';
import '../../domain/maintenance_policy.dart';

class MaintenancePolicyCard extends StatefulWidget {
  const MaintenancePolicyCard({
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
  State<MaintenancePolicyCard> createState() => _MaintenancePolicyCardState();
}

class _MaintenancePolicyCardState extends State<MaintenancePolicyCard> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Global
  bool _globalEnabled = false;
  String _globalPlatform = 'both';
  final _globalTitle = TextEditingController();
  final _globalMessage = TextEditingController();

  // Modules
  final Map<String, bool> _modulesEnabled = {
    'CRM': false,
    'HRMS': false,
    'ERP': false,
    'COLLAB': false,
  };
  final Map<String, TextEditingController> _modulesTitle = {};
  final Map<String, TextEditingController> _modulesMessage = {};

  final _estimatedEndTime = TextEditingController();

  static const _moduleLabels = {
    'CRM': 'CRM (Sales, Leads, Visitors, Dialer)',
    'HRMS': 'HRMS (Attendance, Leaves, Salary, Approvals)',
    'ERP': 'ERP (Projects, BOQ, DPR, Store, Tenders)',
    'COLLAB': 'Collaboration (Chat, Meetings, Tracking)',
  };

  static const _moduleIcons = {
    'CRM': Icons.support_agent_rounded,
    'HRMS': Icons.groups_rounded,
    'ERP': Icons.account_balance_rounded,
    'COLLAB': Icons.forum_rounded,
  };

  @override
  void initState() {
    super.initState();
    for (final key in ['CRM', 'HRMS', 'ERP', 'COLLAB']) {
      _modulesTitle[key] = TextEditingController();
      _modulesMessage[key] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    _globalTitle.dispose();
    _globalMessage.dispose();
    for (final c in _modulesTitle.values) {
      c.dispose();
    }
    for (final c in _modulesMessage.values) {
      c.dispose();
    }
    _estimatedEndTime.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<PlatformRepository>();
      final policy = await repo.getMaintenancePolicy();
      if (!mounted) return;

      _globalEnabled = policy.global.enabled;
      _globalPlatform = policy.global.platform;
      _globalTitle.text = policy.global.title;
      _globalMessage.text = policy.global.message;

      for (final key in ['CRM', 'HRMS', 'ERP', 'COLLAB']) {
        final mod = policy.modules[key] ?? const ModuleConfig();
        _modulesEnabled[key] = mod.enabled;
        _modulesTitle[key]?.text = mod.title;
        _modulesMessage[key]?.text = mod.message;
      }

      _estimatedEndTime.text = policy.estimatedEndTime ?? '';

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
      final mods = <String, ModuleConfig>{};
      for (final key in ['CRM', 'HRMS', 'ERP', 'COLLAB']) {
        mods[key] = ModuleConfig(
          enabled: _modulesEnabled[key] ?? false,
          title: _modulesTitle[key]?.text.trim() ?? '',
          message: _modulesMessage[key]?.text.trim() ?? '',
        );
      }

      final policy = MaintenancePolicy(
        global: ModuleConfig(
          enabled: _globalEnabled,
          title: _globalTitle.text.trim(),
          message: _globalMessage.text.trim(),
          platform: _globalPlatform,
        ),
        modules: mods,
        estimatedEndTime: _estimatedEndTime.text.trim().isEmpty ? null : _estimatedEndTime.text.trim(),
      );

      final repo = context.read<PlatformRepository>();
      final saved = await repo.saveMaintenancePolicy(policy);

      // Refresh public cache
      try {
        final dio = AppRepositories().dioClient;
        await BrandingConfig.fetch(dio);
      } catch (_) {}

      if (!mounted) return;

      _globalEnabled = saved.global.enabled;
      _globalTitle.text = saved.global.title;
      _globalMessage.text = saved.global.message;

      for (final key in ['CRM', 'HRMS', 'ERP', 'COLLAB']) {
        final mod = saved.modules[key] ?? const ModuleConfig();
        _modulesEnabled[key] = mod.enabled;
        _modulesTitle[key]?.text = mod.title;
        _modulesMessage[key]?.text = mod.message;
      }
      _estimatedEndTime.text = saved.estimatedEndTime ?? '';

      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maintenance policy updated successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  void _addHoursToEstimate(int hours) {
    final target = DateTime.now().add(Duration(hours: hours));
    _estimatedEndTime.text = target.toIso8601String();
  }

  @override
  Widget build(BuildContext context) {
    final anyActive = _globalEnabled || _modulesEnabled.values.any((v) => v);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: anyActive ? const Color(0xFFEAB308) : widget.borderColor,
          width: anyActive ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: anyActive
                            ? const Color(0xFFEAB308).withValues(alpha: 0.15)
                            : const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        anyActive ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                        color: anyActive ? const Color(0xFFEAB308) : const Color(0xFF10B981),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Modular Maintenance & Downtime Policy',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: widget.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: anyActive
                                      ? const Color(0xFFEAB308).withValues(alpha: 0.2)
                                      : const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  anyActive ? 'MAINTENANCE ACTIVE' : 'ALL MODULES ONLINE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: anyActive ? const Color(0xFFEAB308) : const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Superadmins are always exempt across all routes and modules. Place specific suites under maintenance without interrupting the rest of the platform.',
                            style: TextStyle(fontSize: 12, height: 1.4, color: widget.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 24),

                // Global Platform Maintenance Switch
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _globalEnabled
                        ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                        : widget.borderColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _globalEnabled ? const Color(0xFFEF4444) : widget.borderColor,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.power_settings_new_rounded,
                                color: _globalEnabled ? const Color(0xFFEF4444) : widget.textPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Global Platform Maintenance (All Modules)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _globalEnabled ? const Color(0xFFEF4444) : widget.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _globalEnabled,
                            activeThumbColor: const Color(0xFFEF4444),
                            onChanged: (val) => setState(() => _globalEnabled = val),
                          ),
                        ],
                      ),
                      if (_globalEnabled) ...[
                        const SizedBox(height: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target Platform Scope',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: widget.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'both',
                                  label: Text('Both Web & App'),
                                  icon: Icon(Icons.devices_rounded, size: 16),
                                ),
                                ButtonSegment(
                                  value: 'web',
                                  label: Text('Web Only'),
                                  icon: Icon(Icons.language_rounded, size: 16),
                                ),
                                ButtonSegment(
                                  value: 'app',
                                  label: Text('App Only'),
                                  icon: Icon(Icons.phone_android_rounded, size: 16),
                                ),
                              ],
                              selected: {_globalPlatform},
                              onSelectionChanged: (set) {
                                if (set.isNotEmpty) {
                                  setState(() => _globalPlatform = set.first);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _globalTitle,
                          decoration: InputDecoration(
                            labelText: 'Global Maintenance Notice Title',
                            hintText: 'e.g. Scheduled System-Wide Upgrade',
                            filled: true,
                            fillColor: widget.surfaceColor,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _globalMessage,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Global Maintenance Explanation Message',
                            hintText: 'Explanation displayed to standard users on the blocking screen',
                            filled: true,
                            fillColor: widget.surfaceColor,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Modular Maintenance Sections
                Text(
                  'Per-Module Maintenance Controls',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: widget.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ...['CRM', 'HRMS', 'ERP', 'COLLAB'].map((key) {
                  final isModEnabled = _modulesEnabled[key] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isModEnabled
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                          : widget.borderColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isModEnabled ? const Color(0xFFF59E0B) : widget.borderColor,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _moduleIcons[key],
                                  color: isModEnabled ? const Color(0xFFF59E0B) : widget.textPrimary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _moduleLabels[key] ?? key,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isModEnabled ? const Color(0xFFF59E0B) : widget.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: isModEnabled,
                              activeThumbColor: const Color(0xFFF59E0B),
                              onChanged: _globalEnabled
                                  ? null // overridden by global
                                  : (val) => setState(() => _modulesEnabled[key] = val),
                            ),
                          ],
                        ),
                        if (isModEnabled && !_globalEnabled) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _modulesTitle[key],
                            decoration: InputDecoration(
                              labelText: '$key Maintenance Title',
                              hintText: 'e.g. $key Suite Enhancements Underway',
                              filled: true,
                              fillColor: widget.surfaceColor,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _modulesMessage[key],
                            decoration: InputDecoration(
                              labelText: '$key Custom Message',
                              hintText: 'e.g. This module is undergoing maintenance. Please use other suites.',
                              filled: true,
                              fillColor: widget.surfaceColor,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),
                // Estimated Completion Time & Quick Actions
                Text(
                  'Estimated Completion & Countdown',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _estimatedEndTime,
                        decoration: InputDecoration(
                          hintText: 'ISO Timestamp e.g. 2026-11-21T16:00:00Z',
                          filled: true,
                          fillColor: widget.surfaceColor,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _addHoursToEstimate(1),
                      child: const Text('+1 hr'),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () => _addHoursToEstimate(2),
                      child: const Text('+2 hrs'),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () => setState(() => _estimatedEndTime.clear()),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Save Button
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A059),
                      foregroundColor: const Color(0xFF0F1412),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F1412)),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      _saving ? 'Saving...' : 'Save Maintenance Policy',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
