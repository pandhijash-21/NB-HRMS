import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/collab_models.dart';
import '../collab_providers.dart';

class MeetInviteResult {
  const MeetInviteResult({required this.ids, required this.people});

  final Set<String> ids;
  final List<CollabProfile> people;
}

class MeetInvitePeopleScreen extends ConsumerStatefulWidget {
  const MeetInvitePeopleScreen({
    super.key,
    this.initialSelected = const {},
    this.initialPeople = const [],
  });

  final Set<String> initialSelected;
  final List<CollabProfile> initialPeople;

  @override
  ConsumerState<MeetInvitePeopleScreen> createState() => _MeetInvitePeopleScreenState();
}

class _MeetInvitePeopleScreenState extends ConsumerState<MeetInvitePeopleScreen> {
  static const _pageSize = 80;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _known = <String, CollabProfile>{};
  final _selected = <String>{};

  Timer? _debounce;
  List<CollabProfile> _people = [];
  int _skip = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _selectingAll = false;
  bool _hasMore = true;
  int _loadId = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelected);
    for (final p in widget.initialPeople) {
      if (p.userId.isNotEmpty) _known[p.userId] = p;
    }
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_selectingAll) return;
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 480) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loadingMore || _loading || !_hasMore)) return;
    final requestId = reset ? ++_loadId : _loadId;
    setState(() {
      _error = null;
      if (reset) {
        _loading = true;
        _skip = 0;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await ref.read(chatRepositoryProvider).directory(
            _search.text.trim(),
            limit: _pageSize,
            skip: reset ? 0 : _skip,
          );
      if (!mounted || requestId != _loadId) return;
      for (final p in page) {
        if (p.userId.isNotEmpty) _known[p.userId] = p;
      }
      setState(() {
        _people = reset ? page : [..._people, ...page];
        _skip = (reset ? 0 : _skip) + page.length;
        _hasMore = page.length >= _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || requestId != _loadId) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = '$e';
      });
    }
  }

  Future<void> _inviteAllVisible() async {
    if (_selectingAll) return;
    setState(() => _selectingAll = true);
    try {
      while (mounted) {
        if (_loading || _loadingMore) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          continue;
        }
        if (_error != null) break;
        if (!_hasMore) break;
        await _load();
      }
      if (!mounted) return;
      setState(() => _selected.addAll(_people.map((p) => p.userId).where((id) => id.isNotEmpty)));
    } finally {
      if (mounted) setState(() => _selectingAll = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) _load(reset: true);
    });
  }

  MeetInviteResult _result() {
    return MeetInviteResult(
      ids: Set<String>.from(_selected),
      people: _selected.map((id) => _known[id]).whereType<CollabProfile>().toList(),
    );
  }

  List<_Row> get _rows {
    final rows = <_Row>[];
    String? letter;
    for (final p in _people) {
      final next = p.name.trim().isEmpty ? '#' : p.name.trim()[0].toUpperCase();
      if (next != letter) {
        letter = next;
        rows.add(_Row.header(letter));
      }
      rows.add(_Row.person(p));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
    final accent = isDark ? AppColors.bronze : Theme.of(context).colorScheme.primary;
    final rows = _rows;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/meet/schedule'),
        title: const Text('Select people', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => context.pop(_result()),
            child: Text('Done', style: TextStyle(fontWeight: FontWeight.w800, color: accent)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (value) {
                setState(() {});
                _onSearchChanged(value);
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search name, email, department',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          _load(reset: true);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(
              children: [
                TextButton(
                  onPressed: _selectingAll ? null : _inviteAllVisible,
                  child: Text(_search.text.trim().isEmpty ? 'Invite all' : 'Select all matches'),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Clear'),
                ),
                const Spacer(),
                Text(
                  '${_selected.length} selected',
                  style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (_selectingAll) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : _people.isEmpty
                        ? Center(
                            child: Text(
                              _search.text.trim().isEmpty ? 'No people found' : 'No matches',
                              style: TextStyle(color: Theme.of(context).hintColor),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                            itemCount: rows.length + (_hasMore || _loadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= rows.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final row = rows[index];
                              if (row.header != null) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                                  child: Text(
                                    row.header!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                );
                              }
                              final p = row.person!;
                              final on = _selected.contains(p.userId);
                              final bits = [
                                if (p.employeeId != null) '#${p.employeeId}',
                                if ((p.department ?? '').isNotEmpty) p.department,
                                if ((p.role ?? '').isNotEmpty) p.role,
                                if ((p.email ?? '').isNotEmpty) p.email,
                              ];
                              return CheckboxListTile(
                                value: on,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected.add(p.userId);
                                      _known[p.userId] = p;
                                    } else {
                                      _selected.remove(p.userId);
                                    }
                                  });
                                },
                                secondary: CircleAvatar(
                                  backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                                  child: p.photoUrl == null
                                      ? Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase())
                                      : null,
                                ),
                                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  bits.join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: () => context.pop(_result()),
            icon: const Icon(Icons.check_rounded),
            label: Text(_selected.isEmpty ? 'Done' : 'Invite ${_selected.length} people'),
          ),
        ),
      ),
    );
  }
}

class _Row {
  const _Row.header(this.header) : person = null;
  const _Row.person(this.person) : header = null;

  final String? header;
  final CollabProfile? person;
}
