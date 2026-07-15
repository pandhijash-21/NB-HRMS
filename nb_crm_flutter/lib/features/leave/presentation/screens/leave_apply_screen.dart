import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

class LeaveApplyScreen extends ConsumerStatefulWidget {
  const LeaveApplyScreen({super.key});

  @override
  ConsumerState<LeaveApplyScreen> createState() => _LeaveApplyScreenState();
}

class _LeaveApplyScreenState extends ConsumerState<LeaveApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  String? _leaveTypeId;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isHalfDay = false;
  String? _halfDaySession;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? _fromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) {
          _toDate = picked;
        }
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_leaveTypeId == null || _fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }
    if (_toDate!.isBefore(_fromDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To date must be on or after from date.')),
      );
      return;
    }
    if (_isHalfDay && _halfDaySession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select half-day session.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(leaveRepositoryProvider).applyLeave({
        'leaveTypeId': _leaveTypeId,
        'fromDate': formatDateYmd(_fromDate!),
        'toDate': formatDateYmd(_toDate!),
        'isHalfDay': _isHalfDay,
        'halfDaySession': _isHalfDay ? _halfDaySession : null,
        'reason': _reasonController.text.trim(),
      });
      invalidateLeaveSelfData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave application submitted.')),
        );
        context.go('/leave');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(leaveTypesProvider);

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Apply Leave'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/leave'),
        ),
      ),
      body: typesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.bronze),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$e'),
              FilledButton(
                onPressed: () => ref.invalidate(leaveTypesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (types) {
          final applicable = types.where((t) => t.employeeCanApply && t.isActive).toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _leaveTypeId,
                    decoration: const InputDecoration(
                      labelText: 'Leave type *',
                      border: OutlineInputBorder(),
                    ),
                    items: applicable
                        .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _leaveTypeId = v),
                    validator: (v) => v == null ? 'Select leave type' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(isFrom: true),
                          child: Text(
                            _fromDate == null
                                ? 'From date *'
                                : formatDateYmd(_fromDate!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(isFrom: false),
                          child: Text(
                            _toDate == null ? 'To date *' : formatDateYmd(_toDate!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Half day'),
                    value: _isHalfDay,
                    onChanged: (v) => setState(() {
                      _isHalfDay = v;
                      if (!v) _halfDaySession = null;
                    }),
                  ),
                  if (_isHalfDay) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _halfDaySession,
                      decoration: const InputDecoration(
                        labelText: 'Session *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MORNING', child: Text('Morning')),
                        DropdownMenuItem(value: 'AFTERNOON', child: Text('Afternoon')),
                      ],
                      onChanged: (v) => setState(() => _halfDaySession = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason *',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 3,
                    maxLines: 5,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.length < 5) return 'Reason must be at least 5 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Supporting document',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Document upload coming soon',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        TextButton(onPressed: null, child: const Text('Upload')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit application'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
