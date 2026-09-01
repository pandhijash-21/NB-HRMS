import 'package:flutter/material.dart';
import 'package:nb_crm_flutter/core/theme/nb_icon.dart';

bool hasPhotoUrl(String? url) => url != null && url.trim().isNotEmpty;

void showZoomablePhotoOverlay(
  BuildContext context, {
  required String url,
  String? label,
}) {
  if (!hasPhotoUrl(url)) return;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close photo',
    barrierColor: Colors.black.withValues(alpha: 0.86),
    pageBuilder: (ctx, _, __) => _ZoomablePhotoOverlay(url: url.trim(), label: label),
  );
}

/// Wraps a profile avatar so a real photo opens in a zoomable overlay.
class ZoomablePhoto extends StatelessWidget {
  const ZoomablePhoto({
    super.key,
    required this.child,
    this.url,
    this.label,
  });

  final Widget child;
  final String? url;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (!hasPhotoUrl(url)) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showZoomablePhotoOverlay(context, url: url!, label: label),
        child: child,
      ),
    );
  }
}

/// Drop-in circular profile photo with tap-to-zoom.
///
/// Uses [Image.network] (not [CircleAvatar.backgroundImage]) so list recycling
/// cannot show another person's photo. Pass [identity] (user/employee id).
class NbProfilePhoto extends StatelessWidget {
  const NbProfilePhoto({
    super.key,
    this.url,
    this.name,
    this.identity,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.fallback,
  });

  final String? url;
  final String? name;
  final String? identity;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final has = hasPhotoUrl(url);
    final letter = (name ?? '').trim().isEmpty ? '?' : name!.trim()[0].toUpperCase();
    final size = radius * 2;
    final cacheId = (identity ?? name ?? url ?? 'avatar').trim();
    Widget placeholder() {
      return ColoredBox(
        color: backgroundColor ?? const Color(0xFF5B5FC7),
        child: Center(
          child: fallback ??
              Text(
                letter,
                style: TextStyle(
                  color: foregroundColor ?? Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: radius * 0.78,
                ),
              ),
        ),
      );
    }

    final avatar = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: has
            ? Image.network(
                url!.trim(),
                key: ValueKey('nb-photo|$cacheId|${url!.trim()}'),
                fit: BoxFit.cover,
                width: size,
                height: size,
                gaplessPlayback: false,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => placeholder(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return placeholder();
                },
              )
            : placeholder(),
      ),
    );
    return ZoomablePhoto(url: url, label: name, child: avatar);
  }
}

class _ZoomablePhotoOverlay extends StatefulWidget {
  const _ZoomablePhotoOverlay({required this.url, this.label});
  final String url;
  final String? label;

  @override
  State<_ZoomablePhotoOverlay> createState() => _ZoomablePhotoOverlayState();
}

class _ZoomablePhotoOverlayState extends State<_ZoomablePhotoOverlay> {
  final _controller = TransformationController();
  static const _min = 1.0;
  static const _max = 5.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _doubleTap() {
    final current = _controller.value.getMaxScaleOnAxis();
    _controller.value = current > 1.4
        ? Matrix4.identity()
        : (Matrix4.identity()..scale(2.4));
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label?.trim();
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 560;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTap: _doubleTap,
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: _min,
                maxScale: _max,
                panEnabled: true,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 64, 16, narrow ? 16 : 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: size.width,
                        maxHeight: size.height,
                      ),
                      child: Image.network(
                        widget.url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const NbIcon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _close,
                    icon: const NbIcon(Icons.close_rounded, color: Colors.white, size: 26),
                  ),
                  if (label != null && label.isNotEmpty)
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (!narrow)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Text(
                        'Pinch or scroll to zoom',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
