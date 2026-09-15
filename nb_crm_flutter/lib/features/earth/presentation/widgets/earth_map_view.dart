import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/earth_kinds.dart';
import '../../domain/earth_models.dart';
import 'earth_format.dart';
import 'earth_pin.dart';

enum EarthMapLayer { satellite, streets, hybrid, terrain }

enum EarthMapTool { browse, add, measureDistance, measureArea }

class EarthMapView extends StatefulWidget {
  const EarthMapView({
    super.key,
    required this.properties,
    required this.selectedId,
    required this.center,
    required this.zoom,
    required this.tool,
    required this.layer,
    required this.onTapMap,
    required this.onTapProperty,
    required this.onMove,
    this.measurePoints = const [],
  });

  final List<EarthProperty> properties;
  final String? selectedId;
  final LatLng center;
  final double zoom;
  final EarthMapTool tool;
  final EarthMapLayer layer;
  final void Function(LatLng point) onTapMap;
  final void Function(EarthProperty property) onTapProperty;
  final void Function(LatLng center, double zoom) onMove;
  final List<LatLng> measurePoints;

  @override
  State<EarthMapView> createState() => _EarthMapViewState();
}

class _EarthMapViewState extends State<EarthMapView> {
  final MapController _controller = MapController();
  bool _ready = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EarthMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready &&
        (oldWidget.center != widget.center || oldWidget.zoom != widget.zoom)) {
      final dist = const Distance().as(LengthUnit.Meter, oldWidget.center, widget.center);
      if (dist > 40 || (oldWidget.zoom - widget.zoom).abs() > 0.4) {
        _controller.move(widget.center, widget.zoom);
      }
    }
  }

  List<Widget> _tiles() {
    const ua = 'com.nb.crm.earth';
    switch (widget.layer) {
      case EarthMapLayer.streets:
        return [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: ua,
          ),
        ];
      case EarthMapLayer.terrain:
        return [
          TileLayer(
            urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: ua,
          ),
        ];
      case EarthMapLayer.hybrid:
        return [
          TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: ua,
          ),
          TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: ua,
          ),
        ];
      case EarthMapLayer.satellite:
        return [
          TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: ua,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = widget.properties
        .map(
          (p) => Marker(
            point: LatLng(p.latitude, p.longitude),
            width: 52,
            height: 64,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => widget.onTapProperty(p),
              child: EarthPropertyPin(
                kind: p.kind,
                imageUrl: p.pinImage.isEmpty ? null : p.pinImage,
                selected: p.id == widget.selectedId,
                label: p.id == widget.selectedId ? p.name : null,
                size: p.id == widget.selectedId ? 42 : 34,
              ),
            ),
          ),
        )
        .toList();

    final measure = widget.measurePoints;
    String? measureLabel;
    if (widget.tool == EarthMapTool.measureDistance && measure.length >= 2) {
      var km = 0.0;
      for (var i = 1; i < measure.length; i++) {
        km += earthHaversineKm(
          measure[i - 1].latitude,
          measure[i - 1].longitude,
          measure[i].latitude,
          measure[i].longitude,
        );
      }
      measureLabel = km < 1 ? '${(km * 1000).toStringAsFixed(0)} m' : '${km.toStringAsFixed(2)} km';
    } else if (widget.tool == EarthMapTool.measureArea && measure.length >= 3) {
      final area = earthPolygonAreaKm2(
        measure.map((e) => (e.latitude, e.longitude)).toList(),
      );
      measureLabel = area < 1
          ? '${(area * 1e6).toStringAsFixed(0)} m²'
          : '${area.toStringAsFixed(2)} km²';
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            minZoom: 3,
            maxZoom: 19,
            backgroundColor: const Color(0xFF0A2744),
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds(
                const LatLng(-85.051128, -180),
                const LatLng(85.051128, 179.999999),
              ),
            ),
            onMapReady: () => _ready = true,
            onTap: (tap, point) => widget.onTapMap(point),
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture) widget.onMove(camera.center, camera.zoom);
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            ..._tiles(),
            if (measure.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.tool == EarthMapTool.measureArea && measure.length >= 3
                        ? [...measure, measure.first]
                        : measure,
                    color: Colors.amberAccent,
                    strokeWidth: 3,
                  ),
                ],
              ),
            if (widget.tool == EarthMapTool.measureArea && measure.length >= 3)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: measure,
                    color: Colors.amber.withValues(alpha: 0.18),
                    borderColor: Colors.amberAccent,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 48,
                size: const Size(42, 42),
                markers: markers,
                builder: (context, cluster) => Container(
                  decoration: BoxDecoration(
                    color: earthKindOf('FLAT').color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${cluster.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
            if (measure.isNotEmpty)
              MarkerLayer(
                markers: [
                  for (var i = 0; i < measure.length; i++)
                    Marker(
                      point: measure[i],
                      width: i == measure.length - 1 && measureLabel != null ? 168 : 18,
                      height: i == measure.length - 1 && measureLabel != null ? 44 : 18,
                      alignment: Alignment.center,
                      child: i == measure.length - 1 && measureLabel != null
                          ? _MeasureBadge(label: measureLabel)
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                    ),
                ],
              ),
          ],
        ),
        if (widget.tool == EarthMapTool.add)
          const Positioned(
            left: 0,
            right: 0,
            top: 12,
            child: Center(
              child: Chip(
                avatar: Icon(Icons.add_location_alt_outlined, size: 16),
                label: Text('Tap the map to drop a property pin'),
              ),
            ),
          ),
      ],
    );
  }
}

class _MeasureBadge extends StatelessWidget {
  const _MeasureBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1816),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
