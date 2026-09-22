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
  bool _uploadingOpening = false;
  bool _uploadingClosing = false;
  String? _openingPhotoUrl;
  String? _openingPhotoName;
  String? _closingPhotoUrl;
  String? _closingPhotoName;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _openKmCtrl.dispose();
    _closeKmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required bool opening}) async {
    final employeeId = ref.read(authNotifierProvider).user?.employeeId;
    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee profile not linked')),
      );
      return;
    }
    final picked = await pickFileFromDevice(imagesOnly: true);
    if (picked == null) return;
    setState(() {
      if (opening) {
        _uploadingOpening = true;
      } else {
        _uploadingClosing = true;
      }
    });
    try {
      final url = await ref.read(reimbursementsRepositoryProvider).uploadProof(
            employeeId: employeeId,
            bytes: picked.bytes,
            filename: picked.name,
          );
      if (!mounted) return;
      setState(() {
        if (opening) {
          _openingPhotoUrl = url;
          _openingPhotoName = picked.name;
        } else {
          _closingPhotoUrl = url;
          _closingPhotoName = picked.name;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          if (opening) {
            _uploadingOpening = false;
          } else {
            _uploadingClosing = false;
          }
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_openingPhotoUrl == null || _closingPhotoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload both opening km and closing km photos')),
      );
      return;
    }
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
        'openingKmPhotoUrl': _openingPhotoUrl,
        'closingKmPhotoUrl': _closingPhotoUrl,
      });
      ref.invalidate(myReimbursementsProvider);
      ref.invalidate(pendingReimbursementsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reimbursement submitted for 1st → 2nd → 3rd reporting approval')),
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

  Widget _photoButton({
    required String label,
    required String? fileName,
    required bool uploading,
    required VoidCallback onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: uploading ? null : onPick,
          icon: uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_camera_outlined),
          label: Text(fileName == null ? label : 'Replace $label'),
        ),
        if (fileName != null) ...[
          const SizedBox(height: 6),
          Text('Uploaded: $fileName', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ],
    );
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
            const Text(
              'Meter photos (mandatory)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _photoButton(
              label: 'Opening km photo *',
              fileName: _openingPhotoName,
              uploading: _uploadingOpening,
              onPick: () => _pickPhoto(opening: true),
            ),
            const SizedBox(height: 10),
            _photoButton(
              label: 'Closing km photo *',
              fileName: _closingPhotoName,
              uploading: _uploadingClosing,
              onPick: () => _pickPhoto(opening: false),
            ),
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
