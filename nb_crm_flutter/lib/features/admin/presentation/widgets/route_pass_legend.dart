import 'package:flutter/material.dart';

import '../../../../core/utils/route_pass_analyzer.dart';

/// Compact legend: color swatch → Pass N → distance.
class RoutePassLegend extends StatelessWidget {
  const RoutePassLegend({
    super.key,
    required this.analysis,
    this.title = 'Route passes',
  });

  final RoutePassAnalysis analysis;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (analysis.passes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                analysis.hasMultiplePasses
                    ? '${analysis.passCount} passes on overlapping roads'
                    : 'Single pass',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const Divider(height: 12),
              Table(
                columnWidths: const {
                  0: FixedColumnWidth(28),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      const SizedBox.shrink(),
                      Text('Pass', style: theme.textTheme.labelSmall),
                      Text('Distance', style: theme.textTheme.labelSmall),
                    ],
                  ),
                  ...analysis.passes.map((p) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: p.color,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.black26,
                                width: 0.8,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'Pass ${p.passNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatDistance(p.distanceMeters),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
}
