import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WallpaperMotif { orbs, dots, diamonds, petals, mesh, none }

class ChatWallpaper {
  const ChatWallpaper({
    required this.id,
    required this.label,
    required this.light,
    required this.dark,
    this.motif = WallpaperMotif.orbs,
    this.accent,
  });

  final int id;
  final String label;
  final List<Color> light;
  final List<Color> dark;
  final WallpaperMotif motif;
  final Color? accent;

  static const options = <ChatWallpaper>[
    ChatWallpaper(
      id: 12,
      label: 'None',
      light: [Color(0xFFE8E8E8), Color(0xFFE0E0E0)],
      dark: [Color(0xFF000000), Color(0xFF111111)],
      motif: WallpaperMotif.none,
    ),
    ChatWallpaper(
      id: 0,
      label: 'Default',
      light: [Color(0xFFF7F4EF), Color(0xFFEDE6D6), Color(0xFFE8EEF6)],
      dark: [Color(0xFF0E0D0C), Color(0xFF1A1614), Color(0xFF1C1410)],
      motif: WallpaperMotif.dots,
      accent: Color(0xFFC5A059),
    ),
    ChatWallpaper(
      id: 1,
      label: 'Dusk',
      light: [Color(0xFFFFE8F1), Color(0xFFE8D5FF), Color(0xFFFFD8C2)],
      dark: [Color(0xFF1A1028), Color(0xFF3D1F4A), Color(0xFF4A2230)],
      motif: WallpaperMotif.orbs,
      accent: Color(0xFFE8A0C8),
    ),
    ChatWallpaper(
      id: 2,
      label: 'Ocean',
      light: [Color(0xFFD6F4FF), Color(0xFFC8F0F2), Color(0xFFB8E0FF)],
      dark: [Color(0xFF02141C), Color(0xFF0A5A62), Color(0xFF083848)],
      motif: WallpaperMotif.orbs,
      accent: Color(0xFF2EE6C8),
    ),
    ChatWallpaper(
      id: 3,
      label: 'Forest',
      light: [Color(0xFFE8F6E8), Color(0xFFD4EFD4), Color(0xFFC8E6C0)],
      dark: [Color(0xFF0A1A12), Color(0xFF163322), Color(0xFF1A2E18)],
      motif: WallpaperMotif.diamonds,
      accent: Color(0xFF8BC98B),
    ),
    ChatWallpaper(
      id: 4,
      label: 'Midnight',
      light: [Color(0xFFE6E9FF), Color(0xFFD5D4F5), Color(0xFFC9C8F0)],
      dark: [Color(0xFF070816), Color(0xFF12143A), Color(0xFF1A1040)],
      motif: WallpaperMotif.dots,
      accent: Color(0xFF9FA8FF),
    ),
    ChatWallpaper(
      id: 5,
      label: 'Sand',
      light: [Color(0xFFFFF6E4), Color(0xFFF3E0C0), Color(0xFFE8D0A8)],
      dark: [Color(0xFF1C160E), Color(0xFF3A2C18), Color(0xFF2A2214)],
      motif: WallpaperMotif.mesh,
      accent: Color(0xFFE2C48A),
    ),
    ChatWallpaper(
      id: 6,
      label: 'Aurora',
      light: [Color(0xFFE4FFF4), Color(0xFFD4F0FF), Color(0xFFF0E4FF)],
      dark: [Color(0xFF061820), Color(0xFF0E3A38), Color(0xFF2A1840)],
      motif: WallpaperMotif.orbs,
      accent: Color(0xFF7CFFCB),
    ),
    ChatWallpaper(
      id: 7,
      label: 'Ember',
      light: [Color(0xFFFFE8DC), Color(0xFFFFD0B8), Color(0xFFFFC9A3)],
      dark: [Color(0xFF1A0C0A), Color(0xFF4A1C12), Color(0xFF3A1408)],
      motif: WallpaperMotif.orbs,
      accent: Color(0xFFFF8A5B),
    ),
    ChatWallpaper(
      id: 8,
      label: 'Glacier',
      light: [Color(0xFFF2FBFF), Color(0xFFD8F0FA), Color(0xFFC4E4F6)],
      dark: [Color(0xFF101820), Color(0xFF3A5870), Color(0xFF8AA8C0)],
      motif: WallpaperMotif.diamonds,
      accent: Color(0xFFE8F4FF),
    ),
    ChatWallpaper(
      id: 9,
      label: 'Lotus',
      light: [Color(0xFFFFEEF4), Color(0xFFF8D8E8), Color(0xFFE8D0F0)],
      dark: [Color(0xFF1A1018), Color(0xFF3A2030), Color(0xFF2A1830)],
      motif: WallpaperMotif.petals,
      accent: Color(0xFFF0A0C0),
    ),
    ChatWallpaper(
      id: 10,
      label: 'Noir',
      light: [Color(0xFFEEF0F4), Color(0xFFDCE0E8), Color(0xFFD0D4DC)],
      dark: [Color(0xFF0A0A0C), Color(0xFF1A1418), Color(0xFF121018)],
      motif: WallpaperMotif.mesh,
      accent: Color(0xFFC5A059),
    ),
    ChatWallpaper(
      id: 11,
      label: 'Violet',
      light: [Color(0xFFF3E8FF), Color(0xFFE0D4FF), Color(0xFFD4C8F8)],
      dark: [Color(0xFF12081E), Color(0xFF2C1450), Color(0xFF1A1038)],
      motif: WallpaperMotif.diamonds,
      accent: Color(0xFFB794F6),
    ),
  ];

  static ChatWallpaper byId(int id) {
    return options.firstWhere((w) => w.id == id, orElse: () => options.first);
  }

  /// Patterned walls stay on the dark palette. None follows the app theme.
  List<Color> colors({required bool isDark}) {
    if (motif == WallpaperMotif.none) return isDark ? dark : light;
    return dark;
  }

  CustomPainter painter({required bool isDark}) => _WallpaperPainter(this, isDark: isDark);

  Widget build({required bool isDark, required Widget child}) {
    return CustomPaint(
      painter: painter(isDark: isDark),
      child: child,
    );
  }

  /// Kept for any caller that still wants a simple fill.
  BoxDecoration decoration({required bool isDark}) {
    final c = colors(isDark: isDark);
    return BoxDecoration(
      gradient: LinearGradient(
        colors: c,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter(this.wall, {required this.isDark});

  final ChatWallpaper wall;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = wall.colors(isDark: isDark);
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: c,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    if (wall.motif == WallpaperMotif.none) return;

    final accent = wall.accent ?? const Color(0x66FFFFFF);
    final faint = accent.withValues(alpha: 0.14);
    final softer = accent.withValues(alpha: 0.07);

    switch (wall.motif) {
      case WallpaperMotif.orbs:
        _orbs(canvas, size, [accent.withValues(alpha: 0.22), faint, softer]);
      case WallpaperMotif.dots:
        _dots(canvas, size, faint);
      case WallpaperMotif.diamonds:
        _diamonds(canvas, size, faint);
      case WallpaperMotif.petals:
        _petals(canvas, size, faint, softer);
      case WallpaperMotif.mesh:
        _mesh(canvas, size, faint);
      case WallpaperMotif.none:
        break;
    }
  }

  void _orbs(Canvas canvas, Size size, List<Color> tones) {
    void blob(Offset c, double r, Color color) {
      canvas.drawCircle(c, r, Paint()..color = color);
    }

    blob(Offset(size.width * 0.12, size.height * 0.08), size.shortestSide * 0.55, tones[0]);
    blob(Offset(size.width * 0.92, size.height * 0.22), size.shortestSide * 0.42, tones[1]);
    blob(Offset(size.width * 0.28, size.height * 0.78), size.shortestSide * 0.5, tones[2]);
    blob(Offset(size.width * 0.85, size.height * 0.88), size.shortestSide * 0.38, tones[1]);
  }

  void _dots(Canvas canvas, Size size, Color color) {
    const step = 22.0;
    final paint = Paint()..color = color;
    for (var y = 10.0; y < size.height; y += step) {
      for (var x = 10.0; x < size.width; x += step) {
        final stagger = ((y / step).floor().isEven) ? step / 2 : 0;
        canvas.drawCircle(Offset(x + stagger, y), 1.35, paint);
      }
    }
  }

  void _diamonds(Canvas canvas, Size size, Color color) {
    const step = 28.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = 8.0; y < size.height; y += step) {
      for (var x = 8.0; x < size.width; x += step) {
        final path = Path()
          ..moveTo(x, y - 4)
          ..lineTo(x + 4, y)
          ..lineTo(x, y + 4)
          ..lineTo(x - 4, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  void _petals(Canvas canvas, Size size, Color a, Color b) {
    final paintA = Paint()
      ..color = a
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final paintB = Paint()
      ..color = b
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 48.0;
    for (var y = 0.0; y < size.height + step; y += step) {
      for (var x = 0.0; x < size.width + step; x += step) {
        canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: 14), 0, math.pi, false, paintA);
        canvas.drawArc(Rect.fromCircle(center: Offset(x + 24, y + 18), radius: 10), math.pi, math.pi, false, paintB);
      }
    }
  }

  void _mesh(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    const gap = 36.0;
    for (var i = -size.height; i < size.width + size.height; i += gap) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
      canvas.drawLine(Offset(i, 0), Offset(i - size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WallpaperPainter old) =>
      old.wall.id != wall.id || old.isDark != isDark;
}

const _prefPrefix = 'chat_wallpaper_';

Future<int> loadChatWallpaper(String channelId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('$_prefPrefix$channelId') ?? 0;
}

Future<void> saveChatWallpaper(String channelId, int id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('$_prefPrefix$channelId', id);
}

Future<void> pickChatWallpaper({
  required BuildContext context,
  required int selected,
  required ValueChanged<int> onPick,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.78;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chat wallpaper', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  'Choose a backdrop for this chat. None is plain grey in light theme and black in dark theme.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    itemCount: ChatWallpaper.options.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.92,
                    ),
                    itemBuilder: (context, i) {
                      final wall = ChatWallpaper.options[i];
                      final on = selected == wall.id;
                      final previewDark = Theme.of(ctx).brightness == Brightness.dark;
                      return InkWell(
                        onTap: () {
                          onPick(wall.id);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(painter: wall.painter(isDark: previewDark)),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  color: Colors.black.withValues(alpha: 0.38),
                                  child: Text(
                                    wall.label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              if (on)
                                const Positioned(
                                  top: 8,
                                  right: 8,
                                  child: NbIcon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: on ? const Color(0xFF5B5FC7) : Colors.white24,
                                      width: on ? 2.5 : 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
