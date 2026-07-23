import 'package:flutter/material.dart';

import '../../../../core/utils/open_url.dart';

/// Non-web: open externally (no iframe).
Widget buildDocumentFrame(String url) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Preview is available on web. Open the document instead.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => openExternalUrl(url),
            child: const Text('Open document'),
          ),
        ],
      ),
    ),
  );
}
