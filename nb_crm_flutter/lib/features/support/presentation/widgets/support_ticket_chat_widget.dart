import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/nb_icon.dart';
import '../../../../core/utils/clipboard_image_helper.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../../core/widgets/zoomable_photo.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/support_models.dart';
import '../support_providers.dart';

class SupportTicketChatWidget extends ConsumerStatefulWidget {
  const SupportTicketChatWidget({
    super.key,
    required this.ticketId,
    required this.ticket,
  });

  final String ticketId;
  final SupportTicket ticket;

  @override
  ConsumerState<SupportTicketChatWidget> createState() =>
      _SupportTicketChatWidgetState();
}

class _SupportTicketChatWidgetState
    extends ConsumerState<SupportTicketChatWidget> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _uploadingAttachment = false;

  String? _pendingAttachmentUrl;
  String? _pendingAttachmentName;
  Uint8List? _pendingAttachmentBytes;

  void Function()? _pasteDisposer;
  Timer? _chatPollTimer;

  @override
  void initState() {
    super.initState();
    // Register clipboard paste listener for images
    _pasteDisposer = attachClipboardPasteListener(_handlePastedImage);
    // Realtime background poll every 2 seconds for instant incoming messages
    _chatPollTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (mounted) {
        ref.invalidate(supportTicketMessagesProvider(widget.ticketId));
      }
    });
  }

  @override
  void dispose() {
    _chatPollTimer?.cancel();
    _pasteDisposer?.call();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handlePastedImage(PickedFileData data) async {
    final auth = ref.read(authNotifierProvider);
    final employeeId = auth.user?.employeeId;
    if (employeeId == null) return;

    setState(() {
      _uploadingAttachment = true;
      _pendingAttachmentBytes = data.bytes;
      _pendingAttachmentName = data.name;
    });

    try {
      final repo = ref.read(supportRepositoryProvider);
      final url = await repo.uploadPhoto(
        employeeId: employeeId,
        bytes: data.bytes,
        filename: data.name,
      );
      if (mounted) {
        setState(() {
          _pendingAttachmentUrl = url;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
        setState(() {
          _pendingAttachmentBytes = null;
          _pendingAttachmentName = null;
          _pendingAttachmentUrl = null;
        });
      }
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _pickImage() async {
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
      _uploadingAttachment = true;
      _pendingAttachmentBytes = picked.bytes;
      _pendingAttachmentName = picked.name;
    });

    try {
      final repo = ref.read(supportRepositoryProvider);
      final url = await repo.uploadPhoto(
        employeeId: employeeId,
        bytes: picked.bytes,
        filename: picked.name,
      );
      if (mounted) {
        setState(() {
          _pendingAttachmentUrl = url;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
        setState(() {
          _pendingAttachmentBytes = null;
          _pendingAttachmentName = null;
          _pendingAttachmentUrl = null;
        });
      }
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final auth = ref.read(authNotifierProvider);
    final employeeId = auth.user?.employeeId;
    if (employeeId == null) return;

    try {
      final data = await pasteImageFromClipboard();
      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No image found in clipboard (Ctrl+V supported)'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      await _handlePastedImage(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read clipboard: $e')),
        );
      }
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if ((text.isEmpty && _pendingAttachmentUrl == null) || _sending || _uploadingAttachment) {
      return;
    }

    setState(() => _sending = true);
    final messageText = text.isEmpty ? 'Image attachment' : text;
    final attUrl = _pendingAttachmentUrl;
    final attName = _pendingAttachmentName;

    _msgCtrl.clear();
    setState(() {
      _pendingAttachmentUrl = null;
      _pendingAttachmentName = null;
      _pendingAttachmentBytes = null;
    });

    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.sendMessage(
        widget.ticketId,
        message: messageText,
        attachmentUrl: attUrl,
        attachmentName: attName,
      );
      ref.invalidate(supportTicketMessagesProvider(widget.ticketId));
      ref.invalidate(supportTicketDetailProvider(widget.ticketId));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authNotifierProvider);
    final myUserId = auth.user?.id;
    final myEmployeeId = auth.user?.employeeId;
    final isOwner = myEmployeeId != null && myEmployeeId == widget.ticket.employeeId;
    final userRole = auth.user?.role.toUpperCase();
    final isAdmin = userRole == 'ADMIN' ||
        userRole == 'SUPERADMIN' ||
        userRole == 'SYSTEMADMIN' ||
        userRole == 'SYSTEM_ADMIN' ||
        Permissions.canAdminSupport(auth.permissions, auth.user?.role);
    final isAssigned = myEmployeeId != null &&
        (widget.ticket.assignedHandlerId == myEmployeeId ||
            widget.ticket.transferTargetHandlerId == myEmployeeId);
    final canChat = isOwner || isAssigned || isAdmin;
    final messagesAsync =
        ref.watch(supportTicketMessagesProvider(widget.ticketId));

    return Column(
      children: [
        // Messages list
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Could not load messages: $e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NbIcon(
                        Icons.forum_outlined,
                        size: 44,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chat directly with IT Support about this ticket',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderId == myUserId;
                  final isIt = msg.senderRole == 'IT_HANDLER';

                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      constraints: BoxConstraints(
                        maxWidth: (MediaQuery.sizeOf(context).width * 0.8).clamp(240.0, 560.0),
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.primaryBlue
                            : (isDark
                                ? const Color(0xFF1E2638)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(isMe ? 14 : 2),
                          bottomRight: Radius.circular(isMe ? 2 : 14),
                        ),
                        border: isMe
                            ? null
                            : Border.all(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                              ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          // Sender label & role badge
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isMe ? 'You' : (msg.senderName ?? 'User'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: isMe
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : (isDark
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFF1D4ED8)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: (isIt
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF059669))
                                      .withValues(alpha: isMe ? 0.35 : 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isIt ? 'IT' : 'STAFF',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: isMe
                                        ? Colors.white
                                        : (isIt
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF059669)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Attachment if present
                          if (msg.attachmentUrl != null &&
                              msg.attachmentUrl!.isNotEmpty) ...[
                            ZoomablePhoto(
                              url: msg.attachmentUrl,
                              label: msg.attachmentName ?? 'Attachment',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  msg.attachmentUrl!,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Message text
                          Text(
                            msg.message,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isMe
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Timestamp
                          Text(
                            DateFormat('HH:mm').format(msg.createdAt.toLocal()),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.65)
                                  : (isDark
                                      ? Colors.white38
                                      : const Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Pending Attachment Preview Bar (if user picked or pasted an image)
        if (_pendingAttachmentBytes != null || _pendingAttachmentUrl != null || _uploadingAttachment)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                if (_pendingAttachmentBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      _pendingAttachmentBytes!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const Icon(Icons.image, size: 36, color: AppColors.primaryBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _pendingAttachmentName ?? 'Pasted image',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _uploadingAttachment ? 'Uploading image...' : 'Ready to send',
                        style: TextStyle(
                          fontSize: 11,
                          color: _uploadingAttachment ? const Color(0xFFD97706) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_uploadingAttachment)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      setState(() {
                        _pendingAttachmentBytes = null;
                        _pendingAttachmentUrl = null;
                        _pendingAttachmentName = null;
                      });
                    },
                  ),
              ],
            ),
          ),

        // Input bar or read-only notice
        if (!canChat)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Read-only: Only the assigned IT handler and ticket creator can participate in discussion.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111622) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
            ),
          child: Row(
            children: [
              // Image Picker button
              IconButton(
                icon: const Icon(Icons.image_outlined, size: 22),
                tooltip: 'Attach image',
                onPressed: _uploadingAttachment ? null : _pickImage,
              ),
              // Paste image button
              IconButton(
                icon: const Icon(Icons.content_paste_rounded, size: 20),
                tooltip: 'Paste image from clipboard (Ctrl+V)',
                onPressed: _uploadingAttachment ? null : _pasteFromClipboard,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message or paste image (Ctrl+V)...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E2638)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: (_sending || _uploadingAttachment) ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: AppColors.primaryBlue),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
