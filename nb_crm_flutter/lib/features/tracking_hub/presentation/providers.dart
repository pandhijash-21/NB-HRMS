import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../auth/presentation/auth_providers.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final hubKpisProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String?>((
      ref,
      employeeId,
    ) async {
      final dioClient = ref.watch(dioClientProvider);
      return dioClient.getEnvelope<Map<String, dynamic>>(
        'tracking/hub-kpis',
        queryParameters: employeeId != null ? {'employeeId': employeeId} : null,
        parse: (raw) => Map<String, dynamic>.from(raw as Map),
      );
    });

final hubTripsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String?>((
      ref,
      employeeId,
    ) async {
      final dioClient = ref.watch(dioClientProvider);
      return dioClient.getEnvelope<List<dynamic>>(
        'tracking/trips',
        queryParameters: employeeId != null ? {'employeeId': employeeId} : null,
        parse: (raw) => raw as List<dynamic>,
      );
    });

/// Day-level employee availability (punch-in → punch-out).
/// Key format: `YYYY-MM-DD` or `YYYY-MM-DD|employeeId`.
final hubDayAvailabilityProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, key) async {
      final parts = key.split('|');
      final date = parts.first;
      final employeeId = parts.length > 1 && parts[1].isNotEmpty
          ? parts[1]
          : null;
      final dioClient = ref.watch(dioClientProvider);
      return dioClient.getEnvelope<Map<String, dynamic>>(
        'tracking/hub-day',
        queryParameters: {
          'date': date,
          if (employeeId != null) 'employeeId': employeeId,
        },
        parse: (raw) => Map<String, dynamic>.from(raw as Map),
      );
    });

final employeeAvailabilityProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({int employeeId, String date})>((
      ref,
      args,
    ) async {
      final dioClient = ref.watch(dioClientProvider);
      return dioClient.getEnvelope<Map<String, dynamic>>(
        'tracking/availability/${args.employeeId}',
        queryParameters: {'date': args.date},
        parse: (raw) => Map<String, dynamic>.from(raw as Map),
      );
    });

final tripEventsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((
      ref,
      tripId,
    ) async {
      final dioClient = ref.watch(dioClientProvider);
      return dioClient.getEnvelope<List<dynamic>>(
        'tracking/trips/$tripId/events',
        parse: (raw) => raw as List<dynamic>,
      );
    });

class SelectedEmployeeFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void updateState(String? val) => state = val;
}

final selectedEmployeeFilterProvider =
    NotifierProvider<SelectedEmployeeFilter, String?>(SelectedEmployeeFilter.new);

final hubTripRouteProvider =
    FutureProvider.autoDispose.family<List<LatLng>, String>((ref, tripId) async {
      final dioClient = ref.watch(dioClientProvider);
      final res = await dioClient.dio.get('tracking/trips/$tripId/route');
      final data = res.data['data'] as Map<String, dynamic>;
      final rawRoute = data['route'] as List;
      return rawRoute
          .map(
            (p) => LatLng(
              (p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble(),
            ),
          )
          .toList();
    });

String hubDayKey({required DateTime date, String? employeeId}) {
  final base = _ymd(date);
  if (employeeId == null || employeeId.isEmpty) return base;
  return '$base|$employeeId';
}

final liveBoardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final dioClient = ref.watch(dioClientProvider);
      try {
        return await dioClient.getEnvelope<Map<String, dynamic>>(
          'tracking/live-board',
          parse: (raw) => Map<String, dynamic>.from(raw as Map),
        );
      } catch (_) {
        final res = await dioClient.dio.get('tracking/live');
        return {
          'locations': res.data['data'] ?? [],
          'employees': const [],
          'alerts': const [],
        };
      }
    });

final trackingAlertsProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
      final dioClient = ref.watch(dioClientProvider);
      try {
        return await dioClient.getEnvelope<List<dynamic>>(
          'tracking/alerts',
          parse: (raw) => raw as List<dynamic>,
        );
      } catch (_) {
        return const [];
      }
    });
