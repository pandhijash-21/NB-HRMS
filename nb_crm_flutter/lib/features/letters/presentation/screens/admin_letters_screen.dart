import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../../core/widgets/header_action_button.dart';
import '../../domain/letter_models.dart';
import '../letters_providers.dart';

enum _CanvasElementType { text, image }

class _CanvasTextAlign {
  const _CanvasTextAlign(this.value);
  final String value;
  static const left = _CanvasTextAlign('left');
  static const center = _CanvasTextAlign('center');
  static const right = _CanvasTextAlign('right');
}

class _CanvasElement {
  _CanvasElement({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    this.text = '',
    this.imageUrl,
    this.fontSize = 14,
    this.fontFamily = 'Arial',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.alignment = _CanvasTextAlign.left,
  });

  final String id;
  final _CanvasElementType type;

  // Position inside the canvas page (pixels).
  Offset position;
  Size size;

  // Text element fields
  String text;
  double fontSize;
  String fontFamily;
  bool bold;
  bool italic;
  bool underline;
  _CanvasTextAlign alignment;

  // Image element fields
  String? imageUrl;

  _CanvasElement copyWith({
    String? id,
    _CanvasElementType? type,
    Offset? position,
    Size? size,
    String? text,
    String? imageUrl,
    double? fontSize,
    String? fontFamily,
    bool? bold,
    bool? italic,
    bool? underline,
    _CanvasTextAlign? alignment,
  }) {
    return _CanvasElement(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      size: size ?? this.size,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      alignment: alignment ?? this.alignment,
    );
  }
}

class AdminLettersConfigScreen extends ConsumerStatefulWidget {
  const AdminLettersConfigScreen({super.key});

  @override
  ConsumerState<AdminLettersConfigScreen> createState() =>
      _AdminLettersConfigScreenState();
}

class _AdminLettersConfigScreenState
    extends ConsumerState<AdminLettersConfigScreen> {
  late final TextEditingController _keyController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _logoUrlController;
  late final TextEditingController _templateHtmlController;

  LetterTemplate? _selected;

  String _paperSize = 'A4';
  final List<_CanvasElement> _elements = [];
  String? _activeElementId;
  String? _localLogoDataUrl;
  String? _localLogoFileName;

  static const _knownPlaceholders = <String>[
    'fullName',
    'employeeCode',
    'designation',
    'department',
    'organization',
    'instituteName',
    'subOrganization',
    'joiningDate',
    'birthDate',
    'aadhaarNo',
    'panNo',
    'passportNo',
    'passportIssueDate',
    'passportExpiryDate',
    'todayDate',
  ];

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: 'offer_letter');
    _nameController = TextEditingController(text: 'Offer Letter');
    _descriptionController = TextEditingController();
    _logoUrlController = TextEditingController();
    _templateHtmlController = TextEditingController();
    _paperSize = 'A4';
    // default template body (works with placeholders)
    _templateHtmlController.text = '''
<div>
  <p>Dear {{fullName}},</p>
  <p>We are pleased to offer you the position of <b>{{designation}}</b> in {{department}}, {{organization}}.</p>
  <p>Joining date: {{joiningDate}}</p>
  <p>Sincerely,</p>
  <p>{{todayDate}}</p>
</div>
''';

    // Default Canva state from the default template HTML.
    _elements.clear();
    _elements.add(
      _CanvasElement(
        id: 'body',
        type: _CanvasElementType.text,
        position: const Offset(60, 120),
        size: Size(_paperWidthPx() - 120, 400),
        text: _stripHtmlTags(_templateHtmlController.text),
      ),
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _logoUrlController.dispose();
    _templateHtmlController.dispose();
    super.dispose();
  }

  void _loadTemplate(LetterTemplate t) {
    setState(() {
      _selected = t;
      _keyController.text = t.key;
      _nameController.text = t.name;
      _descriptionController.text = t.description ?? '';
      _logoUrlController.text = t.logoUrl ?? '';
      _localLogoDataUrl = (t.logoUrl?.startsWith('data:') ?? false) ? t.logoUrl : null;
      _localLogoFileName = _localLogoDataUrl != null ? 'Uploaded logo' : null;
      // Switch Canva canvas to match the selected template.
      // (We treat templateHtml as plain text for editing, preserving {{placeholders}}.)
      _loadTemplateIntoCanvas(t);
    });
  }

  String _extractPlaceholders() {
    // Keeps placeholders used in the template (so backend can render only what exists).
    final matches =
        RegExp(r'{{\s*([a-zA-Z0-9_]+)\s*}}').allMatches(_templateHtmlController.text);
    final keys = <String>{};
    for (final m in matches) {
      final k = m.group(1);
      if (k != null && k.trim().isNotEmpty) keys.add(k.trim());
    }
    if (keys.isEmpty) return '[]';
    return keys.toString();
  }

  Set<String> _placeholdersFromHtml() {
    final matches =
        RegExp(r'{{\s*([a-zA-Z0-9_]+)\s*}}').allMatches(_templateHtmlController.text);
    final keys = <String>{};
    for (final m in matches) {
      final k = m.group(1);
      if (k != null && k.trim().isNotEmpty) keys.add(k.trim());
    }
    return keys;
  }

  double _paperWidthPx() {
    // Canvas pixel sizes for drag/drop. Export uses the same px so positions are stable.
    switch (_paperSize) {
      case 'A2':
        return 900;
      case 'A3':
        return 700;
      case 'A4':
      default:
        return 520;
    }
  }

  double _paperHeightPx() => _paperWidthPx() * 1.414; // ~sqrt(2) ratio

  String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>|</div>|</tr>|</h1>|</h2>|</h3>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .split('\n')
        .map((line) => line.trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _escapeHtmlForTemplate(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }

  String _generateTemplateHtmlFromCanvas() {
    final w = _paperWidthPx();
    final h = _paperHeightPx();

    final buffer = StringBuffer();
    buffer.write(
      '<div style="position:relative;width:${w}px;height:${h}px;background:#ffffff;">',
    );

    for (final el in _elements) {
      if (el.type == _CanvasElementType.image) {
        final url = el.imageUrl;
        if (url == null || url.isEmpty) continue;
        buffer.write(
          '<img src="${url}" style="position:absolute;left:${el.position.dx}px;top:${el.position.dy}px;width:${el.size.width}px;height:${el.size.height}px;object-fit:contain;" />',
        );
      } else {
        final rawText = el.text;
        final safe = _escapeHtmlForTemplate(rawText).replaceAll('\n', '<br/>');
        final align = el.alignment.value;
        final deco = el.underline ? 'underline' : 'none';
        buffer.write(
          '<div style="position:absolute;left:${el.position.dx}px;top:${el.position.dy}px;width:${el.size.width}px;font-family:${el.fontFamily};font-size:${el.fontSize}px;font-weight:${el.bold ? 700 : 400};font-style:${el.italic ? 'italic' : 'normal'};text-decoration:${deco};text-align:${align};white-space:normal;">${safe}</div>',
        );
      }
    }

    buffer.write('</div>');
    return buffer.toString();
  }

  Set<String> _placeholdersFromGeneratedHtml(String html) {
    final matches = RegExp(r'{{\s*([a-zA-Z0-9_]+)\s*}}').allMatches(html);
    final keys = <String>{};
    for (final m in matches) {
      final k = m.group(1);
      if (k != null && k.trim().isNotEmpty) keys.add(k.trim());
    }
    return keys;
  }

  void _loadTemplateIntoCanvas(LetterTemplate t) {
    _elements.clear();
    _activeElementId = null;

    if (t.logoUrl != null && t.logoUrl!.isNotEmpty) {
      _elements.add(
        _CanvasElement(
          id: 'logo',
          type: _CanvasElementType.image,
          position: const Offset(60, 20),
          size: const Size(180, 64),
          imageUrl: t.logoUrl,
        ),
      );
    }

    // Treat the template HTML as a single plain-text block for Canva editing.
    // Placeholders remain in the text so backend rendering still works.
    final bodyText = _stripHtmlTags(t.templateHtml);
    _elements.add(
      _CanvasElement(
        id: 'body',
        type: _CanvasElementType.text,
        position: const Offset(60, 120),
        size: Size(_paperWidthPx() - 120, 400),
        text: bodyText,
        fontSize: 14,
        fontFamily: 'Arial',
        bold: false,
        italic: false,
        underline: false,
        alignment: _CanvasTextAlign.left,
      ),
    );

    _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
  }

  Future<void> _editTextElementDialog(_CanvasElement el) async {
    final textController = TextEditingController(text: el.text);
    final fontSizeController = TextEditingController(text: el.fontSize.toInt().toString());
    String fontFamily = el.fontFamily;
    bool bold = el.bold;
    bool italic = el.italic;
    bool underline = el.underline;
    _CanvasTextAlign alignment = el.alignment;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit text block'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _knownPlaceholders.map((p) {
                    return ActionChip(
                      label: Text('{{$p}}'),
                      onPressed: () {
                        textController.text = '${textController.text}{{$p}}';
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  minLines: 6,
                  maxLines: 12,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Type simple English text (placeholders like {{fullName}} are allowed)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: fontFamily,
                        items: const ['Arial', 'Times New Roman', 'Georgia', 'Courier New'].map((f) {
                          return DropdownMenuItem(value: f, child: Text(f));
                        }).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          fontFamily = v;
                        },
                        decoration: const InputDecoration(labelText: 'Font'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: fontSizeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Font size (px)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    FilterChip(
                      label: const Text('Bold'),
                      selected: bold,
                      onSelected: (v) => bold = v,
                    ),
                    FilterChip(
                      label: const Text('Italic'),
                      selected: italic,
                      onSelected: (v) => italic = v,
                    ),
                    FilterChip(
                      label: const Text('Underline'),
                      selected: underline,
                      onSelected: (v) => underline = v,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: alignment.value,
                  items: const ['left', 'center', 'right'].map((v) {
                    return DropdownMenuItem(value: v, child: Text(v));
                  }).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    alignment = v == 'center'
                        ? _CanvasTextAlign.center
                        : v == 'right'
                            ? _CanvasTextAlign.right
                            : _CanvasTextAlign.left;
                  },
                  decoration: const InputDecoration(labelText: 'Alignment'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final fontSize = int.tryParse(fontSizeController.text.trim()) ?? el.fontSize.toInt();
              setState(() {
                final idx = _elements.indexWhere((e) => e.id == el.id);
                if (idx < 0) return;
                final current = _elements[idx];
                _elements[idx] = current.copyWith(
                  text: textController.text,
                  fontSize: fontSize.toDouble(),
                  fontFamily: fontFamily,
                  bold: bold,
                  italic: italic,
                  underline: underline,
                  alignment: alignment,
                );
                _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  _CanvasElement? get _activeElement {
    final id = _activeElementId;
    if (id == null) return null;
    for (final el in _elements) {
      if (el.id == id) return el;
    }
    return null;
  }

  String? _effectiveLogoUrl() {
    final local = _localLogoDataUrl?.trim();
    if (local != null && local.isNotEmpty) return local;
    final url = _logoUrlController.text.trim();
    return url.isEmpty ? null : url;
  }

  Future<void> _pickLogoFile() async {
    final picked = await pickFileFromDevice(imagesOnly: true);
    if (picked == null || !mounted) return;

    final lower = picked.name.toLowerCase();
    final mime = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : lower.endsWith('.gif')
                ? 'image/gif'
                : 'image/jpeg';
    final dataUrl = 'data:$mime;base64,${base64Encode(picked.bytes)}';

    setState(() {
      _localLogoDataUrl = dataUrl;
      _localLogoFileName = picked.name;
      _logoUrlController.text = '';
    });
    _placeLogoOnCanvas(dataUrl);
  }

  void _placeLogoOnCanvas(String url) {
    setState(() {
      final idx = _elements.indexWhere((e) => e.id == 'logo');
      if (idx < 0) {
        _elements.insert(
          0,
          _CanvasElement(
            id: 'logo',
            type: _CanvasElementType.image,
            position: const Offset(60, 20),
            size: const Size(180, 64),
            imageUrl: url,
          ),
        );
      } else {
        _elements[idx] = _elements[idx].copyWith(imageUrl: url);
      }
      _activeElementId = 'logo';
      _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
    });
  }

  void _deleteActiveElement() {
    final id = _activeElementId;
    if (id == null) return;
    setState(() {
      _elements.removeWhere((e) => e.id == id);
      if (id == 'logo') {
        _localLogoDataUrl = null;
        _localLogoFileName = null;
        _logoUrlController.clear();
      }
      _activeElementId = null;
      _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
    });
  }

  void _nudgeActive(double dx, double dy) {
    final id = _activeElementId;
    if (id == null) return;
    _moveElement(id, Offset(dx, dy));
  }

  void _moveElement(String id, Offset delta) {
    setState(() {
      final idx = _elements.indexWhere((e) => e.id == id);
      if (idx < 0) return;
      final el = _elements[idx];
      final maxX = _paperWidthPx() - el.size.width;
      final maxY = _paperHeightPx() - el.size.height;
      final nextX = (el.position.dx + delta.dx).clamp(0.0, maxX).toDouble();
      final nextY = (el.position.dy + delta.dy).clamp(0.0, maxY).toDouble();
      _elements[idx] = el.copyWith(position: Offset(nextX, nextY));
      _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
    });
  }

  void _resizeElement(String id, Offset delta) {
    setState(() {
      final idx = _elements.indexWhere((e) => e.id == id);
      if (idx < 0) return;
      final el = _elements[idx];
      final minW = el.type == _CanvasElementType.image ? 40.0 : 80.0;
      final minH = el.type == _CanvasElementType.image ? 24.0 : 32.0;
      final maxW = _paperWidthPx() - el.position.dx;
      final maxH = _paperHeightPx() - el.position.dy;
      final newW = (el.size.width + delta.dx).clamp(minW, maxW).toDouble();
      final newH = (el.size.height + delta.dy).clamp(minH, maxH).toDouble();
      _elements[idx] = el.copyWith(size: Size(newW, newH));
      _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
    });
  }

  Widget _buildCanvasElement(_CanvasElement el) {
    final isActive = _activeElementId == el.id;
    return Positioned(
      left: el.position.dx,
      top: el.position.dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => setState(() => _activeElementId = el.id),
            onDoubleTap: () async {
              setState(() => _activeElementId = el.id);
              if (el.type == _CanvasElementType.text) {
                await _editTextElementDialog(el);
                if (mounted) {
                  setState(() {
                    _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
                  });
                }
              }
            },
            onPanUpdate: (d) => _moveElement(el.id, d.delta),
            child: Container(
              width: el.size.width,
              height: el.size.height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive ? AppColors.bronze : AppColors.border.withOpacity(0.25),
                  width: isActive ? 2 : 1,
                ),
                color: isActive && el.type == _CanvasElementType.text
                    ? AppColors.bronze.withOpacity(0.04)
                    : Colors.transparent,
              ),
              child: _buildElementPreview(el),
            ),
          ),
          if (isActive)
            Positioned(
              right: -8,
              bottom: -8,
              child: GestureDetector(
                onPanUpdate: (d) => _resizeElement(el.id, d.delta),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.bronze,
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final templatesAsync = ref.watch(letterTemplatesProvider);
    final repo = ref.read(lettersRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Letters Configuration'),
      ),
      body: templatesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (e, _) => Center(child: Text('Failed to load templates: $e')),
        data: (templates) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Templates list
              Flexible(
                flex: 2,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Templates',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          // + New template button
                          HeaderActionButton(
                            tooltip: 'New template',
                            label: 'New template',
                            icon: const Icon(Icons.add_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _selected = null;
                                _keyController.clear();
                                _nameController.clear();
                                _descriptionController.clear();
                                _logoUrlController.clear();
                                _localLogoDataUrl = null;
                                _localLogoFileName = null;
                                _elements.clear();
                                _activeElementId = null;
                                _elements.add(
                                  _CanvasElement(
                                    id: 'body',
                                    type: _CanvasElementType.text,
                                    position: const Offset(60, 120),
                                    size: Size(_paperWidthPx() - 120, 400),
                                    text: 'Dear {{fullName}},\n\nType your letter here...',
                                    fontSize: 14,
                                  ),
                                );
                                _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: templates.length,
                        itemBuilder: (context, i) {
                          final t = templates[i];
                          final isSelected = _selected?.id == t.id;
                          return Card(
                            color: isSelected ? AppColors.bronze.withOpacity(0.08) : null,
                            child: ListTile(
                              title: Text(t.name),
                              subtitle: Text(t.key),
                              trailing: isSelected ? const Icon(Icons.check_circle) : null,
                              onTap: () => _loadTemplate(t),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const VerticalDivider(width: 1),

              // Editor
              Flexible(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Template Editor',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          )),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _keyController,
                              readOnly: _selected != null,
                              decoration: const InputDecoration(labelText: 'Template Key (unique)'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Template Name'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description (optional)'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _logoUrlController,
                              onChanged: (_) {
                                setState(() {
                                  _localLogoDataUrl = null;
                                  _localLogoFileName = null;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Logo URL (optional)',
                                hintText: _localLogoFileName ?? 'Paste URL or upload a local image',
                                suffixIcon: _localLogoFileName != null
                                    ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload'),
                            onPressed: _pickLogoFile,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Canva controls (paper size + add text)
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _paperSize,
                              items: const ['A2', 'A3', 'A4'].map((v) {
                                return DropdownMenuItem(value: v, child: Text(v));
                              }).toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _paperSize = v;
                                  // Update text width for better drag behavior.
                                  for (var i = 0; i < _elements.length; i += 1) {
                                    final el = _elements[i];
                                    if (el.type == _CanvasElementType.text) {
                                      _elements[i] = el.copyWith(
                                        size: Size(_paperWidthPx() - 120, el.size.height),
                                      );
                                    }
                                  }
                                  _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
                                });
                              },
                              decoration: const InputDecoration(labelText: 'Paper size'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add text'),
                            onPressed: () async {
                              final newId = DateTime.now().microsecondsSinceEpoch.toString();
                              final el = _CanvasElement(
                                id: newId,
                                type: _CanvasElementType.text,
                                position: Offset(60, 120 + (_elements.length * 70)),
                                size: Size(_paperWidthPx() - 120, 60),
                                text: 'Type here...\n{{fullName}}',
                                fontSize: 14,
                              );
                              setState(() {
                                _elements.add(el);
                                _activeElementId = newId;
                                _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
                              });
                              await _editTextElementDialog(el);
                              if (mounted) {
                                setState(() {
                                  _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Add logo'),
                            onPressed: () {
                              final url = _effectiveLogoUrl();
                              if (url == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Paste a Logo URL or upload a local image first'),
                                  ),
                                );
                                return;
                              }
                              _placeLogoOnCanvas(url);
                            },
                          ),
                        ],
                      ),

                      if (_activeElementId != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _deleteActiveElement,
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              label: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                            if (_activeElement?.type == _CanvasElementType.text)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final el = _activeElement;
                                  if (el == null) return;
                                  await _editTextElementDialog(el);
                                  if (mounted) {
                                    setState(() {
                                      _templateHtmlController.text = _generateTemplateHtmlFromCanvas();
                                    });
                                  }
                                },
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit text'),
                              ),
                            Text(
                              'Move:',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            IconButton(
                              tooltip: 'Move up',
                              onPressed: () => _nudgeActive(0, -10),
                              icon: const Icon(Icons.keyboard_arrow_up),
                            ),
                            IconButton(
                              tooltip: 'Move down',
                              onPressed: () => _nudgeActive(0, 10),
                              icon: const Icon(Icons.keyboard_arrow_down),
                            ),
                            IconButton(
                              tooltip: 'Move left',
                              onPressed: () => _nudgeActive(-10, 0),
                              icon: const Icon(Icons.keyboard_arrow_left),
                            ),
                            IconButton(
                              tooltip: 'Move right',
                              onPressed: () => _nudgeActive(10, 0),
                              icon: const Icon(Icons.keyboard_arrow_right),
                            ),
                            Text(
                              'Drag to move • corner handle to resize',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Canvas
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: _paperWidthPx(),
                              height: _paperHeightPx(),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppColors.bronze.withOpacity(0.3) : AppColors.border.withOpacity(0.8),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  for (final el in _elements) _buildCanvasElement(el),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tip: Tap to select • drag to move • double-tap text to edit • drag corner to resize.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final key = _keyController.text.trim();
                            final name = _nameController.text.trim();
                            if (key.isEmpty || name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Template key and name are required')),
                              );
                              return;
                            }

                            final templateHtml = _generateTemplateHtmlFromCanvas();
                            _templateHtmlController.text = templateHtml;

                            final placeholders = _placeholdersFromGeneratedHtml(templateHtml).toList();
                            final logoUrl = _effectiveLogoUrl();

                            await repo.upsertTemplate(
                              id: _selected?.id,
                              key: key,
                              name: name,
                              description: _descriptionController.text.trim().isEmpty
                                  ? null
                                  : _descriptionController.text.trim(),
                              templateHtml: templateHtml,
                              logoUrl: logoUrl,
                              placeholders: placeholders,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Template saved')),
                            );
                            ref.invalidate(letterTemplatesProvider);
                          },
                          child: const Text('Save Template'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageWidget(String url, {required double width, required double height}) {
    if (url.startsWith('data:')) {
      try {
        final base64Str = url.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.contain, width: width, height: height);
      } catch (_) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade100,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );
      }
    }
    return Image.network(url, fit: BoxFit.contain, width: width, height: height);
  }

  Widget _buildElementPreview(_CanvasElement el) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (el.type == _CanvasElementType.image) {
      return SizedBox(
        width: el.size.width,
        height: el.size.height,
        child: el.imageUrl != null && el.imageUrl!.isNotEmpty
            ? _buildImageWidget(el.imageUrl!, width: el.size.width, height: el.size.height)
            : Container(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                child: const Center(child: Icon(Icons.image_outlined, size: 32)),
              ),
      );
    }
    return SizedBox(
      width: el.size.width,
      height: el.size.height,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SingleChildScrollView(
          child: Text(
            el.text,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontFamily: el.fontFamily,
              fontSize: el.fontSize,
              fontWeight: el.bold ? FontWeight.w800 : FontWeight.w400,
              fontStyle: el.italic ? FontStyle.italic : FontStyle.normal,
              decoration: el.underline ? TextDecoration.underline : TextDecoration.none,
              height: 1.35,
            ),
            textAlign: el.alignment.value == 'center'
                ? TextAlign.center
                : el.alignment.value == 'right'
                    ? TextAlign.right
                    : TextAlign.left,
          ),
        ),
      ),
    );
  }
}

