import 'package:flutter/material.dart';

class GapTimelineWidget extends StatelessWidget {
  final List<dynamic> events;

  const GapTimelineWidget({Key? key, required this.events}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Filter out MANUAL_PAUSE as requested by user
    final filteredEvents = events.where((e) => e['eventType'] != 'MANUAL_PAUSE').toList();
    final theme = Theme.of(context);

    if (filteredEvents.isEmpty) {
      return Center(
        child: Text(
          'No tracking gaps recorded. Perfect uptime!',
          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) {
        final ev = filteredEvents[index];
        final type = ev['eventType'];
        final startTime = DateTime.parse(ev['timestamp']).toLocal().toString().split('.')[0];
        final endTime = ev['endTime'] != null ? DateTime.parse(ev['endTime']).toLocal().toString().split('.')[0] : 'Ongoing';
        final confidence = ev['confidence'];

        Color iconColor = theme.colorScheme.error;
        IconData icon = Icons.warning;

        if (type == 'NETWORK_UNAVAILABLE') {
          icon = Icons.wifi_off;
          iconColor = theme.colorScheme.secondary; // Or warning color if defined
        } else if (type == 'BATTERY_DIED') {
          icon = Icons.battery_alert;
          iconColor = theme.colorScheme.error;
        } else if (type == 'BACKGROUND_SERVICE_KILLED') {
          icon = Icons.block;
          iconColor = theme.colorScheme.tertiary; // Use semantic colors
        }

        return ListTile(
          leading: Icon(icon, color: iconColor),
          title: Text(type.replaceAll('_', ' '), style: theme.textTheme.titleSmall),
          subtitle: Text(
            'Start: $startTime\nEnd: $endTime\nConfidence: $confidence',
            style: theme.textTheme.bodySmall,
          ),
          isThreeLine: true,
        );
      },
    );
  }
}
