import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/nb_icon.dart';
import '../../../../core/widgets/zoomable_photo.dart';
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

  @override
  void dispose() {
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

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.sendMessage(widget.ticketId, message: text);
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
                            ? const Color(0xFF2563EB)
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
                                  height: 120,
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

        // Input bar
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
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message to IT support...',
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
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
