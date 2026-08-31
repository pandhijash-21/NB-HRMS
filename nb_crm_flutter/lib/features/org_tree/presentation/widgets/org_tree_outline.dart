import 'package:flutter/material.dart';

import '../../domain/org_tree_models.dart';
import 'org_tree_chrome.dart';

class OrgTreeOutline extends StatefulWidget {
  const OrgTreeOutline({super.key, required this.root, this.query = ''});

  final OrgTreeNode root;
  final String query;

  @override
  State<OrgTreeOutline> createState() => _OrgTreeOutlineState();
}

class _OrgTreeOutlineState extends State<OrgTreeOutline> {
  late Set<String> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {widget.root.id};
    for (final child in widget.root.children) {
      _expanded.add(child.id);
    }
  }

  bool _matches(OrgTreeNode node, String q) {
    if (q.isEmpty) return true;
    final hay = [
      node.title,
      node.subtitle,
      node.designation,
      node.role,
      node.department,
    ].whereType<String>().join(' ').toLowerCase();
    if (hay.contains(q)) return true;
    return node.children.any((c) => _matches(c, q));
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.query.trim().toLowerCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _NodeCard(
          node: widget.root,
          depth: 0,
          expanded: _expanded,
          query: q,
          matches: _matches,
          onToggle: (id) {
            setState(() {
              if (_expanded.contains(id)) {
                _expanded.remove(id);
              } else {
                _expanded.add(id);
              }
            });
          },
        ),
      ],
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.query,
    required this.matches,
    required this.onToggle,
  });

  final OrgTreeNode node;
  final int depth;
  final Set<String> expanded;
  final String query;
  final bool Function(OrgTreeNode, String) matches;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (!matches(node, query)) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = orgKindColor(node.kind, isDark);
    final open = expanded.contains(node.id) || query.isNotEmpty;
    final hasKids = node.children.isNotEmpty;
    final highlight = query.isNotEmpty &&
        [node.title, node.subtitle].whereType<String>().join(' ').toLowerCase().contains(query);

    return Padding(
      key: ValueKey('org-node-${node.id}'),
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 14, top: depth == 0 ? 0 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasKids ? () => onToggle(node.id) : null,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: highlight
                      ? color.withValues(alpha: isDark ? 0.18 : 0.10)
                      : (isDark ? const Color(0xFF1E1B18) : Colors.white),
                  border: Border.all(
                    color: highlight
                        ? color.withValues(alpha: 0.55)
                        : (isDark
                            ? const Color(0xFFC5A059).withValues(alpha: 0.16)
                            : const Color(0xFFD6DEE4)),
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    OrgAvatar(node: node, size: node.kind == 'organization' ? 42 : 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  node.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  orgKindLabel(node.kind),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (node.subtitle != null && node.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              node.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFFE2D6BE).withValues(alpha: 0.75) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (hasKids) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${node.children.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF475569),
                        ),
                      ),
                      Icon(
                        open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (open && hasKids)
            Container(
              margin: const EdgeInsets.only(left: 18),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: color.withValues(alpha: isDark ? 0.28 : 0.22),
                    width: 1.6,
                  ),
                ),
              ),
              child: Column(
                children: [
                  for (final child in node.children)
                    _NodeCard(
                      node: child,
                      depth: depth + 1,
                      expanded: expanded,
                      query: query,
                      matches: matches,
                      onToggle: onToggle,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
