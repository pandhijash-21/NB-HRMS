import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads the full Material icon file as [CRMIcons] before [runApp].
///
/// Never register this file as `MaterialIcons` — that replaces Flutter's
/// own font and blanks glyphs.
Future<void> loadFullMaterialIconsFont() async {
  try {
    final loader = FontLoader('CRMIcons');
    loader.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
  } catch (e) {
    debugPrint('CRMIcons load skipped: $e');
  }
}
