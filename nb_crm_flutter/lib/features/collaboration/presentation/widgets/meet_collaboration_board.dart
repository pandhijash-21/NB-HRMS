import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/collab_socket.dart';

enum FlutterBoardTool { pen, highlighter, eraser, rectangle, circle, line }

class FlutterBoardStroke {
  final String id;
  final FlutterBoardTool tool;
  final Color color;
  final double size;
  final List<Offset> points;
  final Offset? start;
  final Offset? end;
  final String? text;

  FlutterBoardStroke({
    required this.id,
    required this.tool,
    required this.color,
    required this.size,
    required this.points,
    this.start,
    this.end,
    this.text,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tool': tool.name,
      'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      'size': size,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      if (start != null) 'startX': start!.dx,
      if (start != null) 'startY': start!.dy,
      if (end != null) 'endX': end!.dx,
      if (end != null) 'endY': end!.dy,
      if (text != null) 'text': text,
    };
  }

  static FlutterBoardStroke? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id']?.toString() ?? '${DateTime.now().millisecondsSinceEpoch}';
      final toolStr = json['tool']?.toString() ?? 'pen';
      final tool = FlutterBoardTool.values.firstWhere(
        (t) => t.name == toolStr,
        orElse: () => FlutterBoardTool.pen,
      );

      final colorHex = json['color']?.toString() ?? '#FBBF24';
      Color color = const Color(0xFFFBBF24);
      if (colorHex.startsWith('#')) {
        final hex = colorHex.replaceAll('#', '');
        if (hex.length == 6) {
          color = Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
          color = Color(int.parse(hex, radix: 16));
        }
      }

      final size = (json['size'] as num?)?.toDouble() ?? 4.0;
      final rawPoints = json['points'] as List? ?? [];
      final points = <Offset>[];
      for (final p in rawPoints) {
        if (p is Map) {
          final x = (p['x'] as num?)?.toDouble() ?? 0.0;
          final y = (p['y'] as num?)?.toDouble() ?? 0.0;
          points.add(Offset(x, y));
        }
      }

      Offset? start;
      Offset? end;
      if (json['startX'] != null && json['startY'] != null) {
        start = Offset((json['startX'] as num).toDouble(), (json['startY'] as num).toDouble());
      }
      if (json['endX'] != null && json['endY'] != null) {
        end = Offset((json['endX'] as num).toDouble(), (json['endY'] as num).toDouble());
      }

      return FlutterBoardStroke(
        id: id,
        tool: tool,
        color: color,
        size: size,
        points: points,
        start: start,
        end: end,
        text: json['text']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class MeetCollaborationBoard extends StatefulWidget {
  final String meetingId;
  final String currentUserName;
  final CollabSocket collabSocket;
  final VoidCallback onClose;

  const MeetCollaborationBoard({
    super.key,
    required this.meetingId,
    required this.currentUserName,
    required this.collabSocket,
    required this.onClose,
  });

  @override
  State<MeetCollaborationBoard> createState() => _MeetCollaborationBoardState();
}

class _MeetCollaborationBoardState extends State<MeetCollaborationBoard> {
  final List<FlutterBoardStroke> _strokes = [];
  FlutterBoardStroke? _currentStroke;

  FlutterBoardTool _selectedTool = FlutterBoardTool.pen;
  Color _selectedColor = const Color(0xFFFBBF24);
  double _selectedSize = 4.0;
  bool _isMaximized = false;

  static const _palette = [
    Color(0xFFFFFFFF),
    Color(0xFFFBBF24),
    Color(0xFF34D399),
    Color(0xFF38BDF8),
    Color(0xFFF87171),
    Color(0xFFA855F7),
    Color(0xFFFB923C),
    Color(0xFF64748B),
  ];

  static const _strokeSizes = [
    {'label': 'S', 'size': 2.0},
    {'label': 'M', 'size': 4.0},
    {'label': 'L', 'size': 8.0},
    {'label': 'XL', 'size': 14.0},
  ];

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    widget.collabSocket.requestBoardHistory(widget.meetingId);

    widget.collabSocket.onBoardHistory((payload) {
      if (payload['meetingId'] != widget.meetingId) return;
      final rawList = payload['strokes'] as List? ?? [];
      final loaded = <FlutterBoardStroke>[];
      for (final item in rawList) {
        if (item is Map) {
          final s = FlutterBoardStroke.fromJson(Map<String, dynamic>.from(item));
          if (s != null) loaded.add(s);
        }
      }
      if (mounted) setState(() => _strokes..clear()..addAll(loaded));
    });

    widget.collabSocket.onBoardDraw((payload) {
      if (payload['meetingId'] != widget.meetingId) return;
      final raw = payload['stroke'];
      if (raw is Map) {
        final stroke = FlutterBoardStroke.fromJson(Map<String, dynamic>.from(raw));
        if (stroke != null && mounted) {
          setState(() => _strokes.add(stroke));
        }
      }
    });

    widget.collabSocket.onBoardClear((payload) {
      if (payload['meetingId'] != widget.meetingId) return;
      if (mounted) {
        setState(() => _strokes.clear());
        final sender = payload['sender'];
        final name = sender is Map ? sender['name']?.toString() : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(name != null ? '$name cleared the whiteboard' : 'Whiteboard cleared'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF1E293B),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    widget.collabSocket.offBoardHistory();
    widget.collabSocket.offBoardDraw();
    widget.collabSocket.offBoardClear();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    final localPos = details.localPosition;
    final id = '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';

    setState(() {
      _currentStroke = FlutterBoardStroke(
        id: id,
        tool: _selectedTool,
        color: _selectedTool == FlutterBoardTool.eraser ? const Color(0xFF0B0F19) : _selectedColor,
        size: _selectedSize,
        points: [localPos],
        start: localPos,
        end: localPos,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentStroke == null) return;
    final localPos = details.localPosition;

    setState(() {
      if (_selectedTool == FlutterBoardTool.pen ||
          _selectedTool == FlutterBoardTool.highlighter ||
          _selectedTool == FlutterBoardTool.eraser) {
        _currentStroke!.points.add(localPos);
      } else {
        _currentStroke = FlutterBoardStroke(
          id: _currentStroke!.id,
          tool: _currentStroke!.tool,
          color: _currentStroke!.color,
          size: _currentStroke!.size,
          points: _currentStroke!.points,
          start: _currentStroke!.start,
          end: localPos,
        );
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke == null) return;
    final stroke = _currentStroke!;
    _currentStroke = null;

    setState(() {
      _strokes.add(stroke);
    });

    widget.collabSocket.sendBoardDraw(widget.meetingId, stroke.toJson());
  }

  void _clearBoard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Clear Whiteboard?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'This will clear drawings for everyone in this call.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF87171)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _strokes.clear());
              widget.collabSocket.sendBoardClear(widget.meetingId);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final boardContent = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.9),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('🎨', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Teams Collaboration Board',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Live',
                    style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
                    size: 18,
                    color: Colors.white70,
                  ),
                  onPressed: () => setState(() => _isMaximized = !_isMaximized),
                  tooltip: _isMaximized ? 'Restore' : 'Fullscreen',
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                  onPressed: widget.onClose,
                  tooltip: 'Close Board',
                ),
              ],
            ),
          ),

          // Interactive Canvas
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: _WhiteboardPainter(
                      strokes: _strokes,
                      currentStroke: _currentStroke,
                    ),
                    size: Size.infinite,
                  ),
                ),

                // Left Floating Tools Palette
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _toolButton(FlutterBoardTool.pen, Icons.edit, 'Pen'),
                        _toolButton(FlutterBoardTool.highlighter, Icons.brush, 'Highlighter'),
                        _toolButton(FlutterBoardTool.rectangle, Icons.crop_square, 'Rectangle'),
                        _toolButton(FlutterBoardTool.circle, Icons.circle_outlined, 'Circle'),
                        _toolButton(FlutterBoardTool.line, Icons.horizontal_rule, 'Line'),
                        _toolButton(FlutterBoardTool.eraser, Icons.cleaning_services_rounded, 'Eraser'),
                        Divider(height: 8, thickness: 1, color: Colors.white.withValues(alpha: 0.1)),
                        IconButton(
                          icon: const Icon(Icons.undo, size: 16, color: Colors.white70),
                          onPressed: _undo,
                          tooltip: 'Undo',
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFF87171)),
                          onPressed: _clearBoard,
                          tooltip: 'Clear Board',
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Floating Color and Width Palette
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Palette Colors
                            for (final c in _palette)
                              GestureDetector(
                                onTap: () => setState(() => _selectedColor = c),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _selectedColor == c ? Colors.white : Colors.black45,
                                      width: _selectedColor == c ? 2.5 : 1,
                                    ),
                                    boxShadow: _selectedColor == c
                                        ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6)]
                                        : null,
                                  ),
                                ),
                              ),
                            Container(
                              height: 16,
                              width: 1,
                              color: Colors.white.withValues(alpha: 0.15),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            // Stroke sizes
                            for (final s in _strokeSizes)
                              GestureDetector(
                                onTap: () => setState(() => _selectedSize = s['size'] as double),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _selectedSize == s['size']
                                        ? const Color(0xFFFBBF24)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    s['label'] as String,
                                    style: TextStyle(
                                      color: _selectedSize == s['size']
                                          ? const Color(0xFF0F172A)
                                          : Colors.white60,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (_isMaximized) {
      return Positioned.fill(
        child: Material(
          color: Colors.black87,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: boardContent,
            ),
          ),
        ),
      );
    }

    return boardContent;
  }

  Widget _toolButton(FlutterBoardTool tool, IconData icon, String tooltip) {
    final isSelected = _selectedTool == tool;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFBBF24) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 16,
          color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
        ),
        onPressed: () => setState(() => _selectedTool = tool),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<FlutterBoardStroke> strokes;
  final FlutterBoardStroke? currentStroke;

  _WhiteboardPainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    if (currentStroke != null) {
      _paintStroke(canvas, currentStroke!);
    }
  }

  void _paintStroke(Canvas canvas, FlutterBoardStroke stroke) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (stroke.tool == FlutterBoardTool.eraser) {
      paint
        ..color = const Color(0xFF0B0F19)
        ..strokeWidth = stroke.size * 3.5;
    } else if (stroke.tool == FlutterBoardTool.highlighter) {
      paint
        ..color = stroke.color.withValues(alpha: 0.35)
        ..strokeWidth = stroke.size * 2.5;
    } else {
      paint
        ..color = stroke.color
        ..strokeWidth = stroke.size;
    }

    if (stroke.tool == FlutterBoardTool.pen ||
        stroke.tool == FlutterBoardTool.highlighter ||
        stroke.tool == FlutterBoardTool.eraser) {
      if (stroke.points.isEmpty) return;
      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.size / 2, paint..style = PaintingStyle.fill);
        return;
      }
      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    } else if (stroke.tool == FlutterBoardTool.line && stroke.start != null && stroke.end != null) {
      canvas.drawLine(stroke.start!, stroke.end!, paint);
    } else if (stroke.tool == FlutterBoardTool.rectangle && stroke.start != null && stroke.end != null) {
      final rect = Rect.fromPoints(stroke.start!, stroke.end!);
      canvas.drawRect(rect, paint);
    } else if (stroke.tool == FlutterBoardTool.circle && stroke.start != null && stroke.end != null) {
      final rect = Rect.fromPoints(stroke.start!, stroke.end!);
      canvas.drawOval(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) => true;
}
