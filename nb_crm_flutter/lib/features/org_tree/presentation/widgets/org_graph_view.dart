import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/org_tree_models.dart';
import 'org_tree_chrome.dart';

class _LaidOut {
  _LaidOut(this.node, this.offset, this.size);
  final OrgTreeNode node;
  final Offset offset;
  final Size size;

  Offset get centerTop => Offset(offset.dx + size.width / 2, offset.dy);
  Offset get centerBottom => Offset(offset.dx + size.width / 2, offset.dy + size.height);
}

class OrgGraphView extends StatefulWidget {
  const OrgGraphView({super.key, required this.root, this.query = ''});

  final OrgTreeNode root;
  final String query;

  @override
  State<OrgGraphView> createState() => _OrgGraphViewState();
}

class _OrgGraphViewState extends State<OrgGraphView> {
  static const _gapX = 22.0;
  static const _levelGap = 56.0;
  static const _textMaxWidth = 140.0;
  static const _chipPadX = 10.0;
  static const _chipPadY = 8.0;

  final _transform = TransformationController();
  Size? _viewport;
  String? _fittedFor;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OrgGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.root.id != widget.root.id || oldWidget.query != widget.query) {
      _fittedFor = null;
    }
  }

  static bool _isCompact(OrgTreeNode node) =>
      node.kind == 'organization' || node.kind == 'department' || node.kind == 'group';

  static String? _subtitleOf(OrgTreeNode node) {
    if (_isCompact(node)) return null;
    final text = node.designation ?? node.role ?? node.subtitle;
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Size _measureLine(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 4,
    )..layout(maxWidth: _textMaxWidth);
    return painter.size;
  }

  Size _nodeSize(OrgTreeNode node, TextScaler scaler) {
    final compact = _isCompact(node);
    final avatar = compact ? 22.0 : 28.0;
    final titleSize = _measureLine(
      node.title,
      TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: compact ? 11 : 11.5,
        height: 1.25,
      ),
      scaler,
    );
    final subtitle = _subtitleOf(node);
    final subSize = subtitle == null
        ? Size.zero
        : _measureLine(
            subtitle,
            const TextStyle(fontSize: 9, height: 1.25),
            scaler,
          );
    final innerW = math.max(avatar, math.max(titleSize.width, subSize.width));
    final textH = titleSize.height + (subSize.height > 0 ? 2 + subSize.height : 0);
    return Size(
      (innerW + _chipPadX * 2).clamp(88.0, _textMaxWidth + _chipPadX * 2).toDouble(),
      avatar + 6 + textH + _chipPadY * 2 + 24,
    );
  }

  bool _matches(OrgTreeNode node, String q) {
    if (q.isEmpty) return true;
    final hay = [node.title, node.subtitle, node.department, node.role, node.designation]
        .whereType<String>()
        .join(' ')
        .toLowerCase();
    if (hay.contains(q)) return true;
    return node.children.any((c) => _matches(c, q));
  }

  OrgTreeNode? _filtered(OrgTreeNode node, String q) {
    if (q.isEmpty) return node;
    final kids = node.children.map((c) => _filtered(c, q)).whereType<OrgTreeNode>().toList();
    if (kids.isEmpty && !_matches(node, q)) return null;
    return node.copyWith(children: kids);
  }

  Map<String, double> _subtreeWidths(OrgTreeNode node, Map<String, Size> sizes) {
    final widths = <String, double>{};
    double walk(OrgTreeNode n) {
      final self = sizes[n.id]!.width;
      if (n.children.isEmpty) {
        widths[n.id] = self;
        return self;
      }
      var span = 0.0;
      for (var i = 0; i < n.children.length; i++) {
        span += walk(n.children[i]);
        if (i < n.children.length - 1) span += _gapX;
      }
      final w = math.max(self, span);
      widths[n.id] = w;
      return w;
    }

    walk(node);
    return widths;
  }

  List<_LaidOut> _layout(OrgTreeNode root, TextScaler scaler) {
    final sizes = <String, Size>{};
    final depthOf = <String, int>{};
    final maxH = <int, double>{};

    void measure(OrgTreeNode n, int depth) {
      final size = _nodeSize(n, scaler);
      sizes[n.id] = size;
      depthOf[n.id] = depth;
      maxH[depth] = math.max(maxH[depth] ?? 0, size.height);
      for (final child in n.children) {
        measure(child, depth + 1);
      }
    }

    measure(root, 0);
    final yAt = <int, double>{};
    var y = 0.0;
    final depths = maxH.keys.toList()..sort();
    for (final d in depths) {
      yAt[d] = y;
      y += (maxH[d] ?? 0) + _levelGap;
    }

    final widths = _subtreeWidths(root, sizes);
    final placed = <_LaidOut>[];

    void place(OrgTreeNode node, double left) {
      final size = sizes[node.id]!;
      final subtree = widths[node.id] ?? size.width;
      final nodeX = left + (subtree - size.width) / 2;
      placed.add(_LaidOut(node, Offset(nodeX, yAt[depthOf[node.id]!] ?? 0), size));
      if (node.children.isEmpty) return;

      var span = 0.0;
      for (var i = 0; i < node.children.length; i++) {
        span += widths[node.children[i].id] ?? sizes[node.children[i].id]!.width;
        if (i < node.children.length - 1) span += _gapX;
      }
      var childLeft = left + (subtree - span) / 2;
      for (final child in node.children) {
        place(child, childLeft);
        childLeft += (widths[child.id] ?? sizes[child.id]!.width) + _gapX;
      }
    }

    place(root, 0);
    return placed;
  }

  void _fit(Size viewport, Rect content) {
    final key = '${widget.root.id}|${widget.query}|${viewport.width.toStringAsFixed(0)}x${viewport.height.toStringAsFixed(0)}|${content.width.toStringAsFixed(0)}';
    if (_fittedFor == key || viewport.width <= 0 || viewport.height <= 0) return;
    _fittedFor = key;

    final sx = (viewport.width - 48) / math.max(content.width, 1);
    final sy = (viewport.height - 48) / math.max(content.height, 1);
    final scale = math.min(sx, sy).clamp(0.28, 1.15);
    final cx = content.left + content.width / 2;
    final cy = content.top + content.height / 2;
    final tx = viewport.width / 2 - cx * scale;
    final ty = viewport.height / 2 - cy * scale;
    _transform.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoomAtCenter(double factor) {
    final viewport = _viewport;
    if (viewport == null) return;
    final current = _transform.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(0.2, 2.8);
    final applied = target / current;
    if ((applied - 1).abs() < 0.001) return;
    final center = Offset(viewport.width / 2, viewport.height / 2);
    final scene = _transform.toScene(center);
    _transform.value = _transform.value.clone()
      ..translateByDouble(scene.dx, scene.dy, 0, 1)
      ..scaleByDouble(applied, applied, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  void _refit(Rect content) {
    final viewport = _viewport;
    if (viewport == null) return;
    _fittedFor = null;
    _fit(viewport, content);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query.trim().toLowerCase();
    final tree = _filtered(widget.root, q);
    if (tree == null) {
      return const Center(child: Text('No matching people'));
    }

    final laid = _layout(tree, MediaQuery.textScalerOf(context));
    var minX = laid.first.offset.dx;
    var minY = laid.first.offset.dy;
    var maxX = laid.first.offset.dx + laid.first.size.width;
    var maxY = laid.first.offset.dy + laid.first.size.height;
    for (final n in laid) {
      minX = math.min(minX, n.offset.dx);
      minY = math.min(minY, n.offset.dy);
      maxX = math.max(maxX, n.offset.dx + n.size.width);
      maxY = math.max(maxY, n.offset.dy + n.size.height);
    }
    final content = Rect.fromLTRB(minX, minY, maxX, maxY);
    final byId = {for (final n in laid) n.node.id: n};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        _viewport = viewport;
        final canvas = Size(
          math.max(viewport.width, content.width + 160),
          math.max(viewport.height, content.height + 160),
        );
        final origin = Offset(
          (canvas.width - content.width) / 2 - content.left,
          48 - content.top,
        );
        final placed = Rect.fromLTWH(
          origin.dx + content.left,
          origin.dy + content.top,
          content.width,
          content.height,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fit(viewport, placed);
        });

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141210) : const Color(0xFFF7F9FC),
                ),
              ),
            ),
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 0.2,
                maxScale: 2.8,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: canvas.width,
                  height: canvas.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _EdgePainter(
                            laid: laid,
                            byId: byId,
                            origin: origin,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      for (final n in laid)
                        Positioned(
                          key: ValueKey('org-chip-${n.node.id}'),
                          left: origin.dx + n.offset.dx,
                          top: origin.dy + n.offset.dy,
                          width: n.size.width,
                          child: _GraphChip(node: n.node, query: q),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 28,
              bottom: 28,
              child: _ZoomControls(
                isDark: isDark,
                onFit: () => _refit(placed),
                onZoomIn: () => _zoomAtCenter(1.18),
                onZoomOut: () => _zoomAtCenter(1 / 1.18),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GraphChip extends StatelessWidget {
  const _GraphChip({required this.node, required this.query});
  final OrgTreeNode node;
  final String query;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = orgKindColor(node.kind, isDark);
    final hit = query.isNotEmpty && node.title.toLowerCase().contains(query);
    final compact = _OrgGraphViewState._isCompact(node);
    final subtitle = _OrgGraphViewState._subtitleOf(node);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          _OrgGraphViewState._chipPadX,
          _OrgGraphViewState._chipPadY,
          _OrgGraphViewState._chipPadX,
          _OrgGraphViewState._chipPadY,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xF01C1916) : Colors.white,
          border: Border.all(
            color: hit ? color : color.withValues(alpha: isDark ? 0.38 : 0.22),
            width: hit ? 1.4 : 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.16 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OrgAvatar(node: node, size: compact ? 22 : 28),
            const SizedBox(height: 6),
            Text(
              node.title,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 11 : 11.5,
                height: 1.25,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.25,
                  color: isDark ? const Color(0xFFD6CBB4) : const Color(0xFF64748B),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.isDark,
    required this.onFit,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool isDark;
  final VoidCallback onFit;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xF21A1816) : Colors.white;
    final fg = isDark ? const Color(0xFFE2D6BE) : const Color(0xFF334155);
    return Material(
      color: bg,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(icon: Icons.add_rounded, color: fg, onTap: onZoomIn),
          _divider(isDark),
          _ZoomBtn(icon: Icons.remove_rounded, color: fg, onTap: onZoomOut),
          _divider(isDark),
          _ZoomBtn(icon: Icons.fit_screen_rounded, color: fg, onTap: onFit),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Container(
        width: 28,
        height: 1,
        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
      );
}

class _ZoomBtn extends StatelessWidget {
  const _ZoomBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.laid,
    required this.byId,
    required this.origin,
    required this.isDark,
  });

  final List<_LaidOut> laid;
  final Map<String, _LaidOut> byId;
  final Offset origin;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final parent in laid) {
      final kids = parent.node.children.map((c) => byId[c.id]).whereType<_LaidOut>().toList();
      if (kids.isEmpty) continue;
      paint.color = orgKindColor(parent.node.kind, isDark).withValues(alpha: isDark ? 0.55 : 0.42);

      final start = parent.centerBottom + origin;
      final busY = start.dy + 22;

      canvas.drawLine(start, Offset(start.dx, busY), paint);

      if (kids.length == 1) {
        final end = kids.first.centerTop + origin;
        canvas.drawLine(Offset(start.dx, busY), Offset(end.dx, busY), paint);
        canvas.drawLine(Offset(end.dx, busY), end, paint);
        continue;
      }

      var minX = kids.first.centerTop.dx + origin.dx;
      var maxX = minX;
      for (final kid in kids) {
        final x = kid.centerTop.dx + origin.dx;
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
      }
      canvas.drawLine(Offset(minX, busY), Offset(maxX, busY), paint);
      for (final kid in kids) {
        final end = kid.centerTop + origin;
        canvas.drawLine(Offset(end.dx, busY), end, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) =>
      oldDelegate.laid != laid || oldDelegate.origin != origin || oldDelegate.isDark != isDark;
}
