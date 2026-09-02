import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../domain/boq_models.dart';
import '../../domain/project_models.dart';
import '../boq_providers.dart';
import '../project_providers.dart';
import '../work_order_providers.dart';
import '../widgets/boq_tasks_editor.dart';

class BoqFormScreen extends ConsumerStatefulWidget {
  const BoqFormScreen({super.key, this.id});

  final String? id;

  bool get isEdit => id != null && id!.isNotEmpty;

  @override
  ConsumerState<BoqFormScreen> createState() => _BoqFormScreenState();
}

class _BoqFormScreenState extends ConsumerState<BoqFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _boqNoCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  String _rateSource = 'ESTIMATED_RATE';
  String? _projectId;
  List<ErpBoqTask> _tasks = [];
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _boqNoCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {bool required = false}) => InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        isDense: true,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a project')));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'boqNo': _boqNoCtrl.text.trim(),
        'title': _titleCtrl.text.trim(),
        'rateSource': _rateSource,
        'projectId': _projectId,
        'tasks': _tasks.map((t) => t.toJson()).toList(),
      };
      final repo = ref.read(boqRepositoryProvider);
      if (widget.isEdit) {
        await repo.update(widget.id!, body);
      } else {
        await repo.create(body);
      }
      ref.invalidate(boqListProvider);
      if (mounted) context.go('/erp/boq');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsListProvider);
    final activitiesAsync = ref.watch(erpActivitiesProvider);
    final detailAsync = widget.isEdit ? ref.watch(boqDetailProvider(widget.id!)) : null;

    if (widget.isEdit && detailAsync != null) {
      ref.listen(boqDetailProvider(widget.id!), (prev, next) {
        next.whenData((b) {
          if (_hydrated || !mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _hydrated) return;
            setState(() {
              _boqNoCtrl.text = b.boqNo;
              _titleCtrl.text = b.title;
              _rateSource = b.rateSource;
              _projectId = b.projectId;
              _tasks = b.tasks;
              _hydrated = true;
            });
          });
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit BOQ' : 'BOQ Form'),
        leading: const AppBackButton(fallbackLocation: '/erp/boq'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Projects • BOQ • BOQ Form',
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _boqNoCtrl,
                            decoration: _dec('BOQ No', required: true),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _titleCtrl,
                            decoration: _dec('Title', required: true),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Rate Source: '),
                        Radio<String>(
                          value: 'CURRENT_RATE',
                          groupValue: _rateSource,
                          onChanged: (v) => setState(() => _rateSource = v!),
                        ),
                        const Text('Current Rate'),
                        Radio<String>(
                          value: 'ESTIMATED_RATE',
                          groupValue: _rateSource,
                          onChanged: (v) => setState(() => _rateSource = v!),
                        ),
                        const Text('Estimated Rate'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    projectsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('$e'),
                      data: (projects) => DropdownButtonFormField<String>(
                        value: _projectId,
                        decoration: _dec('Project', required: true),
                        items: projects
                            .map((ErpProject p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _projectId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            activitiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (activities) => BoqTasksEditor(
                projectId: _projectId,
                tasks: _tasks,
                configActivities: activities,
                showTaskIds: widget.isEdit,
                onChanged: (t) => setState(() => _tasks = t),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
