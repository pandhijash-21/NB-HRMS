import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../reimbursements_providers.dart';

class ReimbursementApplyScreen extends ConsumerStatefulWidget {
  const ReimbursementApplyScreen({super.key});

  @override
  ConsumerState<ReimbursementApplyScreen> createState() => _ReimbursementApplyScreenState();
}

class _ReimbursementApplyScreenState extends ConsumerState<ReimbursementApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _openKmCtrl = TextEditingController();
  final _closeKmCtrl = TextEditingController();

  bool _submitting = false;
  bool _uploading = false;
  String? _proofUrl;
  String? _proofName;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _openKmCtrl.dispose();
    _closeKmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final employeeId = ref.read(authNotifierProvider).user?.employeeId;
    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee profile not linked')),
      );
      return;
    }
    final picked = await pickFileFromDevice(imagesOnly: false);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(reimbursementsRepositoryProvider).uploadProof(
            employeeId: employeeId,
            bytes: picked.bytes,
            filename: picked.name,
          );
      if (!mounted) return;
      setState(() {
        _proofUrl = url;
        _proofName = picked.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final opening = _openKmCtrl.text.trim().isEmpty ? null : double.tryParse(_openKmCtrl.text.trim());
      final closing = _closeKmCtrl.text.trim().isEmpty ? null : double.tryParse(_closeKmCtrl.text.trim());
      await ref.read(reimbursementsRepositoryProvider).apply({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'amount': double.parse(_amountCtrl.text.trim()),
        if (opening != null) 'openingKm': opening,
        if (closing != null) 'closingKm': closing,
        if (_proofUrl != null) 'proofUrl': _proofUrl,
      });
      ref.invalidate(myReimbursementsProvider);
      ref.invalidate(pendingReimbursementsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reimbursement submitted')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply Reimbursement'),
        leading: const AppBackButton(fallbackLocation: '/reimbursements'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹) *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _openKmCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Opening km',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _closeKmCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Closing km',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickProof,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_proofUrl == null ? 'Upload proof / bill' : 'Replace proof'),
            ),
            if (_proofName != null) ...[
              const SizedBox(height: 8),
              Text('Uploaded: $_proofName', style: TextStyle(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Submitting…' : 'Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
