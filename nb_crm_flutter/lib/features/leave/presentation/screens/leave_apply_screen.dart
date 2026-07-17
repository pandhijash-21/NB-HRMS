import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/leave_models.dart';
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
  bool _uploadingDoc = false;
  String? _documentUrl;
  String? _documentName;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  LeaveType? _selectedType(List<LeaveType> types) {
    if (_leaveTypeId == null) return null;
    try {
      return types.firstWhere((t) => t.id == _leaveTypeId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial =
        isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? _fromDate ?? DateTime.now());
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

  Future<void> _pickDocument() async {
    final employeeId = ref.read(authNotifierProvider).user?.employeeId;
    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee profile not linked to this account.')),
      );
      return;
    }

    final picked = await pickFileFromDevice(
      imagesOnly: false,
      extensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked == null) return;

    setState(() => _uploadingDoc = true);
    try {
      final url = await ref.read(leaveRepositoryProvider).uploadLeaveDocument(
            employeeId: employeeId,
            bytes: picked.bytes,
            filename: picked.name,
          );
      if (!mounted) return;
      setState(() {
        _documentUrl = url;
        _documentName = picked.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingDoc = false);
    }
  }

  Future<void> _submit(List<LeaveType> types) async {
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

    final selected = _selectedType(types);
    if (selected?.requiresDocument == true &&
        (_documentUrl == null || _documentUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supporting document is required for this leave type.'),
        ),
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
        if (_documentUrl != null) 'documentUrl': _documentUrl,
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
      appBar: AppBar(
        title: const Text('Apply Leave'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/leave'),
        ),
      ),
      body: typesAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
          final selected = _selectedType(applicable);
          final docRequired = selected?.requiresDocument == true;
          final allowHalf = selected?.allowHalfDay ?? true;

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
                    onChanged: (v) => setState(() {
                      _leaveTypeId = v;
                      _documentUrl = null;
                      _documentName = null;
                      LeaveType? next;
                      for (final t in applicable) {
                        if (t.id == v) {
                          next = t;
                          break;
                        }
                      }
                      if (next != null && !next.allowHalfDay) {
                        _isHalfDay = false;
                        _halfDaySession = null;
                      }
                    }),
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
                  if (allowHalf)
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
                    decoration: InputDecoration(
                      labelText: docRequired
                          ? 'Supporting document *'
                          : 'Supporting document',
                      border: const OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _documentName ??
                                (docRequired
                                    ? 'Upload required (PDF/image)'
                                    : 'Optional PDF or image'),
                            style: TextStyle(
                              color: _documentUrl != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (_documentUrl != null)
                          TextButton(
                            onPressed: _uploadingDoc || _submitting
                                ? null
                                : () => setState(() {
                                      _documentUrl = null;
                                      _documentName = null;
                                    }),
                            child: const Text('Remove'),
                          ),
                        TextButton(
                          onPressed: _uploadingDoc || _submitting ? null : _pickDocument,
                          child: _uploadingDoc
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_documentUrl == null ? 'Upload' : 'Replace'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting || _uploadingDoc
                        ? null
                        : () => _submit(applicable),
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
