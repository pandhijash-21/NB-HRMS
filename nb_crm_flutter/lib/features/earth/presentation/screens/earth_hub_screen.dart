import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/earth_repository.dart';
import '../../domain/earth_kinds.dart';
import '../../domain/earth_models.dart';
import '../bloc/earth_bloc.dart';
import '../widgets/earth_format.dart';
import '../widgets/earth_globe_view.dart';
import '../widgets/earth_map_view.dart';
import '../widgets/earth_pin.dart';
import '../widgets/earth_property_sheet.dart';

class EarthHubScreen extends StatelessWidget {
  const EarthHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EarthBloc(
        repository: context.read<EarthRepository>(),
      )..add(const EarthLoadRequested()),
      child: const _EarthHubView(),
    );
  }
}

class _EarthHubView extends StatefulWidget {
  const _EarthHubView();

  @override
  State<_EarthHubView> createState() => _EarthHubViewState();
}

class _EarthHubViewState extends State<_EarthHubView> {
  bool _mapMode = false;
  EarthMapLayer _layer = EarthMapLayer.satellite;
  EarthMapTool _tool = EarthMapTool.browse;
  LatLng _center = const LatLng(20.5937, 78.9629);
  double _zoom = 4.4;
  final List<LatLng> _measure = [];
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  List<EarthGeocodeHit> _hits = [];
  Timer? _searchDebounce;
  String? _hud;
  DateTime? _ignoreGlobeTapUntil;
  bool _autoSpin = true;
  bool _nightMode = false;
  double _globeZoom = 1.0;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  bool get _canWrite {
    final auth = context.read<AuthBloc>().state;
    return Permissions.canWriteGoogleEarth(auth.permissions, auth.user?.role);
  }

  Future<void> _openCreate(double lat, double lng) async {
    if (!_canWrite) return;
    final repo = context.read<EarthRepository>();
    EarthGeocodeHit? place;
    try {
      place = await repo.reverse(lat, lng);
    } catch (_) {}
    if (!mounted) return;
    final saved = await showEarthPropertySheet(
      context: context,
      repository: repo,
      canWrite: true,
      latitude: lat,
      longitude: lng,
      place: place,
    );
    if (saved != null && mounted) {
      context.read<EarthBloc>().add(EarthPropertySaved(saved));
    }
  }

  Future<void> _openProperty(EarthProperty property) async {
    final repo = context.read<EarthRepository>();
    EarthProperty detail = property;
    try {
      detail = await repo.getById(property.id);
    } catch (_) {}
    if (!mounted) return;
    context.read<EarthBloc>().add(EarthSelectProperty(property.id));
    final saved = await showEarthPropertySheet(
      context: context,
      repository: repo,
      canWrite: _canWrite,
      existing: detail,
    );
    if (!mounted) return;
    if (saved == null) return;
    if (!saved.isActive) {
      context.read<EarthBloc>().add(EarthPropertyRemoved(saved.id));
    } else {
      context.read<EarthBloc>().add(EarthPropertySaved(saved));
    }
  }

  void _onGlobeTap(double lat, double lng) {
    if (_ignoreGlobeTapUntil != null && DateTime.now().isBefore(_ignoreGlobeTapUntil!)) {
      return;
    }
    setState(() {
      _hud = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    });
    if (_canWrite) _openCreate(lat, lng);
  }

  void _onMapTap(LatLng point) {
    setState(() => _hud = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}');
    if (_tool == EarthMapTool.measureDistance || _tool == EarthMapTool.measureArea) {
      setState(() => _measure.add(point));
      return;
    }
    if (_tool == EarthMapTool.add && _canWrite) {
      _openCreate(point.latitude, point.longitude);
    }
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().length < 2) {
      setState(() => _hits = []);
      return;
    }
    try {
      final hits = await context.read<EarthRepository>().geocode(q.trim());
      if (!mounted) return;
      setState(() => _hits = hits);
    } catch (_) {}
  }

  void _flyTo(double lat, double lng, {double zoom = 15, bool switchToMap = false}) {
    setState(() {
      if (switchToMap || _mapMode) {
        _mapMode = true;
      }
      _center = LatLng(lat, lng);
      _zoom = zoom;
      _hits = [];
      _search.clear();
      _hud = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    });
  }

  void _setGlobeZoom(double zoom) {
    setState(() {
      _globeZoom = zoom.clamp(EarthGlobeView.minZoom, EarthGlobeView.maxZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final allowed = Permissions.canReadGoogleEarth(auth.permissions, auth.user?.role);
    if (!allowed) {
      return const Scaffold(body: Center(child: Text('Access denied')));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _mapMode
          ? theme.scaffoldBackgroundColor
          : (isDark ? const Color(0xFF05070F) : const Color(0xFF0B1220)),
      appBar: AppBar(
        elevation: 0,
        leading: const AppBackButton(),
        title: const Text('NB Earth'),
        actions: [
          IconButton(
            tooltip: 'Earth dashboard',
            onPressed: () => context.push('/admin/earth/dashboard'),
            icon: const Icon(Icons.insights_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Refresh pins',
            onPressed: () => context.read<EarthBloc>().add(const EarthRefreshRequested()),
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<EarthBloc, EarthState>(
        builder: (context, state) {
          if (state.status == LoadStatus.failure && state.properties.isEmpty) {
            return Center(child: Text(state.errorMessage ?? 'Failed to load Earth'));
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              IndexedStack(
                index: _mapMode ? 1 : 0,
                sizing: StackFit.expand,
                children: [
                  TickerMode(
                    enabled: !_mapMode,
                    child: EarthGlobeView(
                      properties: state.properties,
                      selectedId: state.selectedId,
                      autoSpin: _autoSpin,
                      nightMode: _nightMode,
                      zoom: _globeZoom,
                      onZoomChanged: _setGlobeZoom,
                      onTapGlobe: _onGlobeTap,
                      onTapProperty: (p) {
                        _ignoreGlobeTapUntil = DateTime.now().add(const Duration(milliseconds: 450));
                        context.read<EarthBloc>().add(EarthSelectProperty(p.id));
                        _openProperty(p);
                      },
                    ),
                  ),
                  EarthMapView(
                    properties: state.properties,
                    selectedId: state.selectedId,
                    center: _center,
                    zoom: _zoom,
                    tool: _tool,
                    layer: _layer,
                    measurePoints: _measure,
                    onTapMap: _onMapTap,
                    onTapProperty: _openProperty,
                    onMove: (c, z) => setState(() {
                      _center = c;
                      _zoom = z;
                    }),
                  ),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _overlayChrome(state),
              ),
              if (state.status == LoadStatus.loading)
                const Positioned(
                  top: 72,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                ),
              if (_hits.isNotEmpty)
                Positioned(
                  top: 64,
                  left: 12,
                  width: 360,
                  child: _searchResults(),
                ),
              if (_hud != null)
                Positioned(
                  left: 16,
                  bottom: state.properties.isEmpty ? 28 : 108,
                  child: _glassChip(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location, size: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5B6570)),
                        const SizedBox(width: 6),
                        Text(
                          _hud!,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1816),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.properties.isEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Text(
                    _canWrite
                        ? 'Drag to spin the globe. Tap a location, or switch to Map to drop a pin.'
                        : 'No properties on the globe yet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                )
              else
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _inventoryStrip(state),
                ),
              if (!_mapMode)
                Positioned(
                  right: 16,
                  bottom: state.properties.isEmpty ? 88 : 168,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _globeControl(
                        icon: _autoSpin ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        label: _autoSpin ? 'Pause' : 'Spin',
                        onTap: () => setState(() => _autoSpin = !_autoSpin),
                      ),
                      const SizedBox(height: 8),
                      _globeControl(
                        icon: _nightMode ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                        label: _nightMode ? 'Day' : 'Night',
                        onTap: () => setState(() => _nightMode = !_nightMode),
                      ),
                      const SizedBox(height: 8),
                      _globeControl(
                        icon: Icons.remove_rounded,
                        label: 'Zoom −',
                        onTap: () => _setGlobeZoom(_globeZoom * 0.82),
                      ),
                      const SizedBox(height: 8),
                      _globeControl(
                        icon: Icons.add_rounded,
                        label: 'Zoom +',
                        onTap: () => _setGlobeZoom(_globeZoom * 1.22),
                      ),
                    ],
                  ),
                ),
              if (_mapMode && _measure.isNotEmpty)
                Positioned(
                  left: 16,
                  bottom: (state.properties.isEmpty ? 28 : 112) + (_hud != null ? 40 : 0),
                  child: _measureCard(),
                ),
            ],
          );
        },
      ),
      floatingActionButton: _canWrite
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                onPressed: () {
                  setState(() {
                    _mapMode = true;
                    _tool = EarthMapTool.add;
                  });
                },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add property'),
              ),
            )
          : null,
    );
  }

  Widget _overlayChrome(EarthState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF1A1816);
    final muted = isDark ? Colors.white70 : const Color(0xFF5B6570);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _glassBar(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ModeToggle(
                mapMode: _mapMode,
                onChanged: (v) => setState(() => _mapMode = v),
              ),
              if (!_mapMode) ...[
                _globeControl(
                  icon: _autoSpin ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  label: _autoSpin ? 'Pause' : 'Spin',
                  compact: true,
                  onTap: () => setState(() => _autoSpin = !_autoSpin),
                ),
                _globeControl(
                  icon: _nightMode ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                  label: _nightMode ? 'Day' : 'Night',
                  compact: true,
                  onTap: () => setState(() => _nightMode = !_nightMode),
                ),
                _globeControl(
                  icon: Icons.remove_rounded,
                  label: 'Zoom −',
                  compact: true,
                  onTap: () => _setGlobeZoom(_globeZoom * 0.82),
                ),
                _globeControl(
                  icon: Icons.add_rounded,
                  label: 'Zoom +',
                  compact: true,
                  onTap: () => _setGlobeZoom(_globeZoom * 1.22),
                ),
              ],
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  style: TextStyle(color: fg, fontSize: 13),
                  cursorColor: AppColors.bronze,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    prefixIcon: Icon(Icons.search, size: 18, color: muted),
                    hintText: 'Search places',
                    hintStyle: TextStyle(color: muted, fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide(color: AppColors.bronze),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onChanged: (q) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 350), () => _runSearch(q));
                  },
                ),
              ),
              _filterMenu<String?>(
                icon: Icons.category_outlined,
                label: state.kindFilter == null ? 'All types' : earthKindLabel(state.kindFilter),
                value: state.kindFilter,
                items: [
                  (null, 'All types'),
                  ...earthKinds.map((k) => (k.code, k.label)),
                ],
                onSelected: (v) => context.read<EarthBloc>().add(
                      EarthFilterChanged(kind: v, status: state.statusFilter, query: state.query),
                    ),
              ),
              _filterMenu<String?>(
                icon: Icons.flag_outlined,
                label: state.statusFilter == null ? 'All statuses' : earthStatusLabel(state.statusFilter),
                value: state.statusFilter,
                items: [
                  (null, 'All statuses'),
                  ...earthStatuses.entries.map((e) => (e.key, e.value)),
                ],
                onSelected: (v) => context.read<EarthBloc>().add(
                      EarthFilterChanged(kind: state.kindFilter, status: v, query: state.query),
                    ),
              ),
              Text(
                '${state.properties.length} pins',
                style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (_mapMode) ...[
          const SizedBox(height: 8),
          _glassBar(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _filterMenu<EarthMapLayer>(
                  icon: Icons.layers_outlined,
                  label: switch (_layer) {
                    EarthMapLayer.satellite => 'Satellite',
                    EarthMapLayer.hybrid => 'Hybrid',
                    EarthMapLayer.streets => 'Streets',
                    EarthMapLayer.terrain => 'Terrain',
                  },
                  value: _layer,
                  items: const [
                    (EarthMapLayer.satellite, 'Satellite'),
                    (EarthMapLayer.hybrid, 'Hybrid'),
                    (EarthMapLayer.streets, 'Streets'),
                    (EarthMapLayer.terrain, 'Terrain'),
                  ],
                  onSelected: (v) => setState(() => _layer = v),
                ),
                SegmentedButton<EarthMapTool>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: WidgetStateProperty.all(fg),
                  ),
                  segments: [
                    const ButtonSegment(value: EarthMapTool.browse, icon: Icon(Icons.near_me_outlined, size: 16), label: Text('Browse')),
                    if (_canWrite)
                      const ButtonSegment(value: EarthMapTool.add, icon: Icon(Icons.add_location_alt_outlined, size: 16), label: Text('Pin')),
                    const ButtonSegment(value: EarthMapTool.measureDistance, icon: Icon(Icons.straighten, size: 16), label: Text('Distance')),
                    const ButtonSegment(value: EarthMapTool.measureArea, icon: Icon(Icons.pentagon_outlined, size: 16), label: Text('Area')),
                  ],
                  selected: {_tool},
                  onSelectionChanged: (s) => setState(() {
                    _tool = s.first;
                    _measure.clear();
                  }),
                ),
                if (_measure.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_measure.clear),
                    child: const Text('Clear measure'),
                  ),
                if (_measureSummary != null)
                  _measureChip(_measureSummary!),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String? get _measureSummary {
    final pts = _measure;
    if (_tool == EarthMapTool.measureDistance) {
      if (pts.length < 2) {
        return pts.isEmpty ? 'Tap two or more points' : 'Tap the next point';
      }
      var km = 0.0;
      for (var i = 1; i < pts.length; i++) {
        km += earthHaversineKm(
          pts[i - 1].latitude,
          pts[i - 1].longitude,
          pts[i].latitude,
          pts[i].longitude,
        );
      }
      return km < 1 ? '${(km * 1000).toStringAsFixed(0)} m' : '${km.toStringAsFixed(2)} km';
    }
    if (_tool == EarthMapTool.measureArea) {
      if (pts.length < 3) {
        return pts.isEmpty ? 'Tap at least 3 points' : '${pts.length} points · tap to close';
      }
      final area = earthPolygonAreaKm2(pts.map((e) => (e.latitude, e.longitude)).toList());
      return area < 1 ? '${(area * 1e6).toStringAsFixed(0)} m²' : '${area.toStringAsFixed(2)} km²';
    }
    return null;
  }

  Widget _globeControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      elevation: compact ? 0 : 8,
      color: isDark ? const Color(0xFF1A1F2A) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 8 : 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.bronze),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF1A1816),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _measureChip(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bronze.withValues(alpha: isDark ? 0.35 : 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _tool == EarthMapTool.measureArea ? Icons.pentagon_outlined : Icons.straighten,
            size: 16,
            color: isDark ? Colors.white : const Color(0xFF1A1816),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF1A1816),
            ),
          ),
        ],
      ),
    );
  }

  Widget _measureCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _tool == EarthMapTool.measureArea ? 'Area' : 'Distance';
    final value = _measureSummary ?? '—';
    return Material(
      elevation: 10,
      color: isDark ? const Color(0xFF1A1F2A) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _tool == EarthMapTool.measureArea ? Icons.pentagon_outlined : Icons.straighten,
              color: AppColors.bronze,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF5B6570),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1816),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Clear measure',
              onPressed: () => setState(_measure.clear),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterMenu<T>({
    required IconData icon,
    required String label,
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T> onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF1A1816);
    final muted = isDark ? Colors.white70 : const Color(0xFF5B6570);
    return PopupMenuButton<T>(
      tooltip: label,
      initialValue: value,
      onSelected: onSelected,
      color: isDark ? const Color(0xFF1A1F2A) : Colors.white,
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem(
            value: item.$1,
            child: Text(item.$2, style: TextStyle(color: fg)),
          ),
      ],
      child: _glassChip(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: muted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
            Icon(Icons.expand_more, size: 16, color: muted),
          ],
        ),
      ),
    );
  }

  Widget _glassBar({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassChip({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _searchResults() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1A1F2A) : Colors.white,
      elevation: 10,
      borderRadius: BorderRadius.circular(12),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _hits.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
        itemBuilder: (context, i) {
          final h = _hits[i];
          return ListTile(
            dense: true,
            leading: Icon(Icons.place_outlined, color: isDark ? Colors.white70 : const Color(0xFF5B6570)),
            title: Text(
              h.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1816)),
            ),
            onTap: () => _flyTo(h.latitude, h.longitude, switchToMap: _mapMode),
          );
        },
      ),
    );
  }

  Widget _inventoryStrip(EarthState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF1A1816);
    final muted = isDark ? Colors.white54 : const Color(0xFF5B6570);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 92,
          color: isDark ? Colors.black.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.94),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            itemCount: state.properties.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final p = state.properties[i];
              final selected = p.id == state.selectedId;
              return InkWell(
                onTap: () {
                  context.read<EarthBloc>().add(EarthSelectProperty(p.id));
                  if (_mapMode) {
                    _flyTo(p.latitude, p.longitude, zoom: 17);
                  }
                  _openProperty(p);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: selected
                        ? AppColors.bronze.withValues(alpha: isDark ? 0.22 : 0.16)
                        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                  ),
                  child: Row(
                    children: [
                      EarthPropertyPin(kind: p.kind, imageUrl: p.pinImage.isEmpty ? null : p.pinImage, selected: selected),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, color: fg),
                            ),
                            Text(
                              '${earthKindLabel(p.kind, custom: p.customKind)} · ${earthMoney(p.currentPrice, compact: true)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mapMode, required this.onChanged});

  final bool mapMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF1A1816);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(
            icon: Icons.public,
            label: 'Globe',
            selected: !mapMode,
            fg: fg,
            onTap: () => onChanged(false),
          ),
          _pill(
            icon: Icons.map_outlined,
            label: 'Map',
            selected: mapMode,
            fg: fg,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required bool selected,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.bronze.withValues(alpha: 0.35) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
