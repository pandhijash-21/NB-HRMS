import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/form_draft_service.dart';

/// Clean, responsive banner displaying realtime draft status and restore actions
class FormDraftBanner extends StatelessWidget {
  const FormDraftBanner({
    super.key,
    this.formId,
    this.entityId,
    this.draftInfo,
    this.savedAt,
    this.onDiscard,
    this.isSaving = false,
  });

  final String? formId;
  final String? entityId;
  final FormDraftInfo? draftInfo;
  final dynamic savedAt;
  final VoidCallback? onDiscard;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    if (draftInfo == null && savedAt == null && !isSaving) {
      return const SizedBox.shrink();
    }

    String timeStr = 'recent session';
    if (savedAt != null) {
      if (savedAt is DateTime) {
        final dt = savedAt as DateTime;
        final now = DateTime.now();
        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          timeStr = 'Today at ${DateFormat('hh:mm a').format(dt)}';
        } else {
          timeStr = DateFormat('d MMM, hh:mm a').format(dt);
        }
      } else {
        timeStr = savedAt.toString();
      }
    } else if (draftInfo != null) {
      timeStr = draftInfo!.formattedTime;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const teal = Color(0xFF0D9488);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A26) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: teal.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: teal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSaving ? Icons.sync_rounded : Icons.history_rounded,
              size: 16,
              color: teal,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSaving
                      ? 'Auto-saving draft in realtime...'
                      : 'Draft restored from $timeStr',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFCCFBF1) : const Color(0xFF0F766E),
                  ),
                ),
                Text(
                  'Changes are automatically saved as you type',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF99F6E4) : const Color(0xFF115E59),
                  ),
                ),
              ],
            ),
          ),
          if (onDiscard != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onDiscard,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Discard Draft',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
