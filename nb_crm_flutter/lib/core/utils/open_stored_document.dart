import 'package:flutter/material.dart';

import '../network/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'open_url.dart';

/// Open a stored Cloudinary (or other) document via our authenticated
/// `/upload/inline` proxy so the browser previews it instead of hitting
/// Cloudinary 401 / forced downloads.
Future<void> openStoredDocument(
  BuildContext context, {
  required String url,
  String? fileName,
  String title = 'Document',
  Future<String?> Function()? readToken,
}) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document uploaded')),
      );
    }
    return;
  }

  try {
    final token = readToken != null
        ? await readToken()
        : await SecureStorageService().readToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in');
    }

    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final inlineUrl = Uri.parse('$base/upload/inline').replace(
      queryParameters: {
        'url': trimmed,
        'token': token,
        if (fileName != null && fileName.trim().isNotEmpty) 'filename': fileName.trim(),
      },
    ).toString();

    final opened = await openExternalUrl(inlineUrl);
    if (opened) return;

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text(
          'Could not open the document. Allow pop-ups for this site and try again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(
            onPressed: () async {
              await openExternalUrl(inlineUrl);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}
