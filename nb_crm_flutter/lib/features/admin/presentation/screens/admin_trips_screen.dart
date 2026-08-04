import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/auth_providers.dart';

final adminTripsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dioClient = ref.watch(dioClientProvider);
  final res = await dioClient.dio.get('/tracking/trips');
  return res.data['data'] ?? [];
});

class AdminTripsScreen extends ConsumerWidget {
  const AdminTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(adminTripsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorded Trips'),
      ),
      body: tripsAsync.when(
        data: (trips) {
          if (trips.isEmpty) {
            return const Center(child: Text('No trips recorded yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              final employee = trip['employee'];
              final genInfo = employee?['generalInfo'];
              final name = genInfo?['fullName'] ?? 'Unknown Employee';
              final code = genInfo?['employeeCode'] ?? '';
              
              final start = DateTime.parse(trip['startTime']).toLocal();
              final end = trip['endTime'] != null ? DateTime.parse(trip['endTime']).toLocal() : null;
              final distance = (trip['distanceKm'] as num).toDouble();

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () => context.push('/admin/trips/${trip['id']}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: const Icon(Icons.directions_car, color: Colors.blue),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  if (code.isNotEmpty)
                                    Text(
                                      code,
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: end == null ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: end == null ? Colors.orange : Colors.green,
                                ),
                              ),
                              child: Text(
                                end == null ? 'ACTIVE' : 'COMPLETED',
                                style: TextStyle(
                                  color: end == null ? Colors.orange.shade700 : Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Started', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                Text(DateFormat('MMM d, h:mm a').format(start), style: const TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ended', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                Text(end != null ? DateFormat('MMM d, h:mm a').format(end) : '-', style: const TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Distance', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                Text('${distance.toStringAsFixed(2)} km', style: const TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading trips')),
      ),
    );
  }
}
