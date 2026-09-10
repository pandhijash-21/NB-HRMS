import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../data/boq_repository.dart';
import '../../data/project_repository.dart';
import '../../data/work_order_repository.dart';
import '../../domain/boq_models.dart';
import '../../domain/project_models.dart';
import '../../domain/work_order_models.dart';
import '../widgets/boq_tasks_editor.dart';

class BoqFormScreen extends StatefulWidget {
  const BoqFormScreen({super.key, this.id});

  final String? id;

  bool get isEdit => id != null && id!.isNotEmpty;

  @override
  State<BoqFormScreen> createState() => _BoqFormScreenState();
}

class _BoqFormScreenState extends State<BoqFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _boqNoCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  String _rateSource = 'ESTIMATED_RATE';
  String? _projectId;
  List<ErpBoqTask> _tasks = [];
  List<ErpProject> _projects = [];
  List<ErpActivity> _activities = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      final projectRepo = context.read<ProjectRepository>();
      final workRepo = context.read<WorkOrderRepository>();
      final boqRepo = context.read<BoqRepository>();

      final futures = await Future.wait([
        projectRepo.list(),
        workRepo.listActivities(),
        if (widget.isEdit) boqRepo.getById(widget.id!),
      ]);

      if (!mounted) return;
      final projects = futures[0] as List<ErpProject>;
      final activities = futures[1] as List<ErpActivity>;

      if (widget.isEdit && futures.length > 2) {
        final b = futures[2] as ErpBoq;
        _boqNoCtrl.text = b.boqNo;
        _titleCtrl.text = b.title;
        _rateSource = b.rateSource;
        _projectId = b.projectId;
        _tasks = b.tasks;
      }

      setState(() {
        _projects = projects;
        _activities = activities;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

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
      final repo = context.read<BoqRepository>();
      if (widget.isEdit) {
        await repo.update(widget.id!, body);
      } else {
        await repo.create(body);
      }
      if (mounted) context.go('/erp/boq');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isEdit ? 'Edit BOQ' : 'BOQ Form'),
          leading: const AppBackButton(fallbackLocation: '/erp/boq'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isEdit ? 'Edit BOQ' : 'BOQ Form'),
          leading: const AppBackButton(fallbackLocation: '/erp/boq'),
        ),
        body: Center(child: Text(_error!)),
      );
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
                    DropdownButtonFormField<String>(
                      initialValue: _projectId,
                      decoration: _dec('Project', required: true),
                      items: _projects
                          .map((ErpProject p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _projectId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            BoqTasksEditor(
              projectId: _projectId,
              tasks: _tasks,
              configActivities: _activities,
              showTaskIds: widget.isEdit,
              onChanged: (t) => setState(() => _tasks = t),
            ),
          ],
        ),
      ),
    );
  }
}
