import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/mr_nb_tour_service.dart';
import '../../../core/tour/availability/tour_availability.dart';
import '../../../core/tour/engine/tour_engine.dart';
import '../../../core/tour/models/tour_models.dart';
import '../../../core/tour/persistence/tour_progress_store.dart';
import '../../../core/tour/tour_desktop.dart';
import '../../../core/tour/widgets/tour_target.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';

class SoftwareTourHubScreen extends StatefulWidget {
  const SoftwareTourHubScreen({super.key});

  @override
  State<SoftwareTourHubScreen> createState() => _SoftwareTourHubScreenState();
}

class _SoftwareTourHubScreenState extends State<SoftwareTourHubScreen> {
  String _query = '';
  String _filter = 'all';
  final Set<String> _selected = {};
  Map<String, String> _statuses = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;
    final map = await TourProgressStore.instance.loadStatuses(user.id);
    if (mounted) setState(() => _statuses = map);
  }

  TourAuthContext _authCtx() {
    final auth = context.read<AuthBloc>().state;
    return TourAuthContext.fromUser(
      permissions: auth.permissions,
      enabledModules: auth.user?.enabledModules,
      role: auth.user?.role,
      employeeViewScope: auth.user?.employeeViewScope,
    );
  }

  Future<void> _startTour(Future<bool> Function() run) async {
    if (!TourDesktop.supported(context)) {
      await TourDesktop.ensureCanStart(context);
      return;
    }
    final ctx = _authCtx();
    TourEngine.instance.updateAuth(
      userId: context.read<AuthBloc>().state.user?.id,
      auth: ctx,
    );
    unawaited(MrNbTourService.instance.unlock());
    MrNbTourService.instance.unmute();
    unawaited(run());
  }

  @override
  Widget build(BuildContext context) {
    final engine = TourEngine.instance;
    final filtered = engine.resolver.filterCatalog(engine.catalog, _authCtx());
    final modules = filtered.modules
        .where((m) => m.id != 'platform.first_visit' && m.id != 'platform.complete')
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = const Color(0xFFC5A36A);

    final sections = [
      for (final m in modules)
        for (final s in m.sections)
          if (m.id == 'platform.quick' || _matches(m, s)) (m, s),
    ];
    final learnable = [
      for (final m in modules)
        if (m.id != 'platform.quick')
          for (final s in m.sections) s,
    ];
    final completed = learnable.where((s) => _statuses[s.id] == TourProgressStatus.completed.name).length;
    final overall = learnable.isEmpty ? 0.0 : completed / learnable.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7F5F1),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        children: [
          TourTarget(
            id: TourIds.page('/software-tour'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOFTWARE TOUR',
                  style: GoogleFonts.sourceSans3(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: isDark ? Colors.white : const Color(0xFF141A16),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  TourDesktop.supported(context)
                      ? 'Run Whole Software Tour for a full walkthrough, or pick one section at a time.'
                      : 'The Software Tour highlights real buttons, tabs and cards. Open NB CRM in a desktop browser to take it. The mobile app does not run this walkthrough.',
                  style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6F766F)),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: overall,
                    minHeight: 8,
                    color: gold,
                    backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2DDD5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(overall * 100).round()}% · $completed of ${learnable.length} accessible sections explored',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF6F766F)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => _startTour(
                  () => engine.startComplete(auth: _authCtx()),
                ),
                style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black),
                child: const Text('Whole Software Tour'),
              ),
              OutlinedButton(
                onPressed: () => _startTour(engine.startQuick),
                child: const Text('Quick Tour'),
              ),
              OutlinedButton(
                onPressed: () => _startTour(engine.resume),
                child: const Text('Resume'),
              ),
              if (_selected.isNotEmpty)
                FilledButton.tonal(
                onPressed: () => _startTour(() => engine.startSelected(_selected, auth: _authCtx())),
                  child: Text('Start ${_selected.length} selected'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search software tours...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final f in const [
                'all',
                'erp',
                'crm',
                'hrms',
                'other',
                'completed',
                'inProgress',
                'notStarted',
              ])
                FilterChip(
                  label: Text(_label(f)),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: 24),
          for (final module in modules.where((m) => m.id != 'platform.quick' || _filter == 'all'))
            if (sections.any((e) => e.$1.id == module.id)) ...[
              Text(
                module.title.toUpperCase(),
                style: GoogleFonts.sourceSans3(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isDark ? gold : const Color(0xFF141A16),
                ),
              ),
              const SizedBox(height: 4),
              Text(module.description, style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF6F766F))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final section in module.sections.where((s) => _matches(module, s)))
                    _SectionCard(
                      section: section,
                      selected: _selected.contains(section.id),
                      status: _statuses[section.id],
                      onToggle: () => setState(() {
                        if (!_selected.add(section.id)) _selected.remove(section.id);
                      }),
                      onStart: () => _startTour(() => engine.startSection(section.id)),
                    ),
                ],
              ),
              const SizedBox(height: 28),
            ],
        ],
      ),
    );
  }

  bool _matches(TourModule module, TourSection section) {
    if (_query.isNotEmpty) {
      final hay = '${module.title} ${section.title} ${section.description}'.toLowerCase();
      if (!hay.contains(_query)) return false;
    }
    final status = _statuses[section.id] ?? TourProgressStatus.notStarted.name;
    return switch (_filter) {
      'erp' => module.category == TourCategory.erp,
      'crm' => module.category == TourCategory.crm,
      'hrms' => module.category == TourCategory.hrms,
      'other' => module.category == TourCategory.other || module.category == TourCategory.collaboration,
      'completed' => status == TourProgressStatus.completed.name,
      'inProgress' => status == TourProgressStatus.inProgress.name,
      'notStarted' => status == TourProgressStatus.notStarted.name || status.isEmpty,
      _ => true,
    };
  }

  String _label(String f) {
    return switch (f) {
      'inProgress' => 'In Progress',
      'notStarted' => 'Not Started',
      _ => '${f[0].toUpperCase()}${f.substring(1)}',
    };
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.selected,
    required this.onToggle,
    required this.onStart,
    this.status,
  });

  final TourSection section;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onStart;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 280,
      child: Material(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(value: selected, onChanged: (_) => onToggle()),
                    const Spacer(),
                    Text(
                      '${section.steps.length} steps · ${section.estimatedMinutes} min',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9AA399)),
                    ),
                  ],
                ),
                Text(section.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                Text(section.description, style: const TextStyle(fontSize: 13, height: 1.35)),
                const SizedBox(height: 8),
                Text(
                  status == TourProgressStatus.completed.name
                      ? 'Completed'
                      : status == TourProgressStatus.inProgress.name
                          ? 'In progress'
                          : 'Not started',
                  style: TextStyle(
                    fontSize: 11,
                    color: status == TourProgressStatus.completed.name
                        ? const Color(0xFF24A148)
                        : const Color(0xFF9AA399),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: onStart,
                    child: const Text('Start Tour'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
