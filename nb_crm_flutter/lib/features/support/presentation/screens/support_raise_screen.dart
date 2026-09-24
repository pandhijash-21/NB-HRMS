import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../../core/widgets/zoomable_photo.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../support_providers.dart';

class SupportRaiseScreen extends ConsumerStatefulWidget {
  const SupportRaiseScreen({super.key});

  @override
  ConsumerState<SupportRaiseScreen> createState() => _SupportRaiseScreenState();
}

class _SupportRaiseScreenState extends ConsumerState<SupportRaiseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _photoUrl;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final auth = ref.read(authNotifierProvider);
    final employeeId = auth.user?.employeeId;
    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee profile not linked')),
      );
      return;
    }
    final picked = await pickFileFromDevice(imagesOnly: true);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(supportRepositoryProvider).uploadPhoto(
            employeeId: employeeId,
            bytes: picked.bytes,
            filename: picked.name,
          );
      if (mounted) setState(() => _photoUrl = url);
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
      final ticket = await ref.read(supportRepositoryProvider).create(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            photoUrl: _photoUrl,
          );
      ref.invalidate(mySupportTicketsProvider);
      ref.invalidate(supportQueueProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket raised · ${ticket.ticketNo}')),
      );
      context.go('/support/${ticket.id}');
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
        title: const Text('Raise support ticket'),
        leading: const AppBackButton(fallbackLocation: '/support'),
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
                hintText: 'e.g. Laptop not connecting to Wi‑Fi',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Describe the problem *',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            const Text('Photo (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_photoUrl != null)
              ZoomablePhoto(
                url: _photoUrl,
                label: 'Support photo',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _photoUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickPhoto,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_outlined),
              label: Text(_photoUrl == null ? 'Add photo' : 'Change photo'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.bronze,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit to IT Support'),
            ),
          ],
        ),
      ),
    );
  }
}
