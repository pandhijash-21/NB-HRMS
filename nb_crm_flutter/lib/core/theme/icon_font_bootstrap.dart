import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers the complete Material Icons file.
///
/// Flutter web tree-shakes `MaterialIcons` down to glyphs it can prove are used,
/// which leaves send/call/wallpaper and many others as empty circles.
/// We ship the full OTF as `NbMaterialIcons` (that family is not tree-shaken)
/// and also try to re-register it as `MaterialIcons` before [runApp].
Future<void> loadFullMaterialIconsFont() async {
  Future<void> loadAs(String family) async {
    try {
      final loader = FontLoader(family);
      loader.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await loader.load();
    } catch (e) {
      debugPrint('Icon font `$family` load skipped: $e');
    }
  }

  await loadAs('NbMaterialIcons');
  await loadAs('MaterialIcons');
}

