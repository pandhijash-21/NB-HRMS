import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/clipboard_image_helper.dart';
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

  int? _selectedHandlerId;
  String? _photoUrl;
  Uint8List? _previewBytes;
  bool _uploading = false;
  bool _submitting = false;

  void Function()? _pasteDisposer;

  @override
  void initState() {
    super.initState();
    // Register global paste listener for images (web & supported platforms)
    _pasteDisposer = attachClipboardPasteListener(_handlePastedFileData);
  }

  @override
  void dispose() {
    _pasteDisposer?.call();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePastedFileData(PickedFileData data) async {
    final auth = ref.read(authNotifierProvider);
    final employeeId = auth.user?.employeeId;
    if (employeeId == null) return;

    setState(() {
      _uploading = true;
      _previewBytes = data.bytes;
    });

    try {
      final url = await ref.read(supportRepositoryProvider).uploadPhoto(
            employeeId: employeeId,
            bytes: data.bytes,
            filename: data.name,
          );
      if (mounted) {
        setState(() {
          _photoUrl = url;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasted image uploaded successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload pasted image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final auth = ref.read(authNotifierProvider);
    final employeeId = auth.user?.employeeId;
    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee profile not linked')),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final data = await pasteImageFromClipboard();
      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No image found in clipboard (press Ctrl+V to paste directly)'),
            ),
          );
        }
        return;
      }
      await _handlePastedFileData(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read clipboard: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
    setState(() {
      _uploading = true;
      _previewBytes = picked.bytes;
    });
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
            assignedHandlerId: _selectedHandlerId,
          );
      ref.invalidate(mySupportTicketsProvider);
      ref.invalidate(supportQueueProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket raised · ${ticket.ticketNo}'),
          backgroundColor: AppColors.primaryBlue,
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authNotifierProvider);
    final myEmployeeId = auth.user?.employeeId;
    final handlersAsync = ref.watch(supportHandlersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raise support ticket'),
        leading: const AppBackButton(fallbackLocation: '/support'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.help_outline_rounded, color: AppColors.primaryBlue, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Describe your IT Issue',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Our IT support team will review and resolve it promptly.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Title
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g. Laptop not connecting to Wi-Fi / VPN error',
                          prefixIcon: const Icon(Icons.title_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                      ),
                      const SizedBox(height: 16),

                      // Assign to specific IT handler (optional, excludes self)
                      handlersAsync.when(
                        data: (handlers) {
                          // Exclude current employee from list of assignees
                          final eligibleHandlers = handlers.where((h) => h.employeeId != myEmployeeId).toList();

                          return DropdownButtonFormField<int?>(
                            initialValue: _selectedHandlerId,
                            decoration: InputDecoration(
                              labelText: 'Assign to IT Member (Optional)',
                              hintText: 'Auto-assign to available IT member',
                              prefixIcon: const Icon(Icons.person_pin_rounded, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              helperText: 'Tickets are never self-assigned. Select an IT member or leave empty to auto-assign.',
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('⚡ Auto-assign to available IT member'),
                              ),
                              ...eligibleHandlers.map((h) {
                                final name = h.displayName;
                                final extra = h.department != null && h.department!.isNotEmpty
                                    ? ' · ${h.department}'
                                    : '';
                                return DropdownMenuItem<int?>(
                                  value: h.employeeId,
                                  child: Text(
                                    '$name$extra',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedHandlerId = val);
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Describe the problem *',
                          hintText: 'Provide detailed steps or errors encountered...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe the problem' : null,
                      ),
                      const SizedBox(height: 20),

                      // Photo / Screenshot section (Upload or Paste)
                      Text(
                        'Screenshot or Photo (Optional)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Upload an image or paste directly from clipboard (Ctrl+V)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                      ),
                      const SizedBox(height: 12),

                      if (_photoUrl != null || _previewBytes != null) ...[
                        Stack(
                          children: [
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _previewBytes != null
                                    ? Image.memory(
                                        _previewBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : (_photoUrl != null
                                        ? ZoomablePhoto(
                                            url: _photoUrl,
                                            label: 'Support photo',
                                            child: Image.network(_photoUrl!, fit: BoxFit.cover),
                                          )
                                        : const SizedBox.shrink()),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.black.withValues(alpha: 0.65),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _photoUrl = null;
                                      _previewBytes = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Upload / Paste Action Buttons
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _uploading ? null : _pickPhoto,
                            icon: _uploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.photo_library_outlined, size: 18),
                            label: Text(_photoUrl == null && _previewBytes == null ? 'Upload image' : 'Change image'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _uploading ? null : _pasteFromClipboard,
                            icon: const Icon(Icons.content_paste_rounded, size: 18),
                            label: const Text('Paste image'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Submit button
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Submit Ticket to IT Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
