import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/open_stored_document.dart';
import '../../../auth/presentation/auth_providers.dart';

/// Open a stored Cloudinary doc via `/upload/inline` (auth via ?token=)
/// so Chrome previews instead of hitting Cloudinary 401 / forced download.
Future<void> openResumeLikeProfileDocs(
  BuildContext context,
  WidgetRef ref, {
  required String url,
  String? fileName,
  String title = 'Resume',
}) {
  return openStoredDocument(
    context,
    url: url,
    fileName: fileName,
    title: title,
    readToken: () => ref.read(secureStorageProvider).readToken(),
  );
}

/// Attachment row matching profile documents style.
Widget resumeAttachmentTile({
  required BuildContext context,
  required WidgetRef ref,
  required String? url,
  String? fileName,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final hasUrl = url != null && url.trim().isNotEmpty;
  final displayName = (fileName != null && fileName.trim().isNotEmpty)
      ? fileName.trim()
      : 'View attachment';

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isDark ? const Color(0xFF3A342E) : const Color(0xFFCFD8DC),
        width: 1.2,
      ),
    ),
    child: Row(
      children: [
        Icon(
          hasUrl ? Icons.attach_file_rounded : Icons.cloud_upload_outlined,
          size: 20,
          color: hasUrl
              ? const Color(0xFFC5A059)
              : (isDark ? Colors.white38 : const Color(0xFF607D8B)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resume',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: hasUrl
                    ? () => openResumeLikeProfileDocs(
                          context,
                          ref,
                          url: url,
                          fileName: fileName,
                        )
                    : null,
                child: Text(
                  hasUrl ? displayName : 'No resume uploaded',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: hasUrl
                        ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238))
                        : (isDark ? Colors.white30 : const Color(0xFF607D8B)),
                    decoration: hasUrl ? TextDecoration.underline : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
