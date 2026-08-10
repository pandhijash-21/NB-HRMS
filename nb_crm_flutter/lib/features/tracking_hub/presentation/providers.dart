import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../auth/presentation/auth_providers.dart';

final hubKpisProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String?>((ref, employeeId) async {
  final dioClient = ref.watch(dioClientProvider);
  return dioClient.getEnvelope<Map<String, dynamic>>(
    'tracking/hub-kpis',
    queryParameters: employeeId != null ? {'employeeId': employeeId} : null,
    parse: (raw) => Map<String, dynamic>.from(raw as Map),
  );
});

final hubTripsProvider = FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, employeeId) async {
  final dioClient = ref.watch(dioClientProvider);
  return dioClient.getEnvelope<List<dynamic>>(
    'tracking/trips',
    queryParameters: employeeId != null ? {'employeeId': employeeId} : null,
    parse: (raw) => raw as List<dynamic>,
  );
});

final tripEventsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, tripId) async {
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

final selectedEmployeeFilterProvider = NotifierProvider<SelectedEmployeeFilter, String?>(SelectedEmployeeFilter.new);

final hubTripRouteProvider = FutureProvider.autoDispose.family<List<LatLng>, String>((ref, tripId) async {
  final dioClient = ref.watch(dioClientProvider);
  final res = await dioClient.dio.get('tracking/trips/$tripId/route');
  final data = res.data['data'] as Map<String, dynamic>;
  final rawRoute = data['route'] as List;
  return rawRoute.map((p) => LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble())).toList();
});

