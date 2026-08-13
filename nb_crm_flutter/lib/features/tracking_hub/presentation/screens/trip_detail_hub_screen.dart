import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/router/app_back_button.dart';
import '../providers.dart';
import '../widgets/gap_timeline_widget.dart';
import '../trip_recording_download.dart';
import '../../../auth/presentation/auth_providers.dart';

class TripDetailHubScreen extends ConsumerStatefulWidget {
  final String tripId;
  const TripDetailHubScreen({Key? key, required this.tripId}) : super(key: key);

  @override
  ConsumerState<TripDetailHubScreen> createState() => _TripDetailHubScreenState();
}

class _TripDetailHubScreenState extends ConsumerState<TripDetailHubScreen> {
  List<LatLng> _routePoints = [];

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(tripEventsProvider(widget.tripId));
    final routeAsync = ref.watch(hubTripRouteProvider(widget.tripId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Replay & Gaps'),
        leading: const AppBackButton(fallbackLocation: '/admin/tracking-hub'),
        actions: [
          IconButton(
            tooltip: 'Download trip video',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => showTripDownloadMenu(
              context: context,
              dioClient: ref.read(dioClientProvider),
              tripId: widget.tripId,
            ),
          ),
        ],
      ),
      body: routeAsync.when(
        data: (routePoints) {
          if (routePoints.isEmpty) {
            return const Center(child: Text('No location data recorded for this trip.'));
          }

          if (_routePoints.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _routePoints = routePoints);
            });
          }

          final points =
              _routePoints.isNotEmpty ? _routePoints : routePoints;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final mapAndScrubber = Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: points.first,
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.nb.hrms',
                            ),
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: points,
                                  color: const Color(0xFFC5A059),
                                  strokeWidth: 5,
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: points.first,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.green,
                                    size: 40,
                                  ),
                                  alignment: Alignment.topCenter,
                                ),
                                if (points.length > 1)
                                  Marker(
                                    point: points.last,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.flag,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                    alignment: Alignment.bottomRight,
                                  ),
                              ],
                            ),
                            eventsAsync.maybeWhen(
                              data: (events) {
                                final gapMarkers = <Marker>[];
                                for (var ev in events) {
                                  if (ev['eventType'] != 'MANUAL_PAUSE' &&
                                      points.isNotEmpty) {
                                    gapMarkers.add(
                                      Marker(
                                        point: points.first,
                                        child: Icon(
                                          Icons.warning,
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    );
                                  }
                                }
                                return MarkerLayer(markers: gapMarkers);
                              },
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final timeline = eventsAsync.when(
                data: (events) => GapTimelineWidget(events: events),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, st) => Text('Error loading events: $e'),
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 2, child: mapAndScrubber),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 1, child: timeline),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Expanded(flex: 2, child: mapAndScrubber),
                    Expanded(flex: 1, child: timeline),
                  ],
                );
              }
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
