import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/network/dio_client.dart';
import 'trip_video_exporter.dart';

Future<void> downloadTripRecording({
  required BuildContext context,
  required DioClient dioClient,
  required String tripId,
  String format = 'mp4',
}) {
  return _downloadTripVideo(
    context: context,
    dioClient: dioClient,
    tripId: tripId,
  );
}

Future<void> showTripDownloadMenu({
  required BuildContext context,
  required DioClient dioClient,
  required String tripId,
}) {
  return downloadTripRecording(
    context: context,
    dioClient: dioClient,
    tripId: tripId,
  );
}

Future<void> _downloadTripVideo({
  required BuildContext context,
  required DioClient dioClient,
  required String tripId,
}) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip video download is available in the Android app.'),
      ),
    );
    return;
  }

  final progress = ValueNotifier<({double value, String label})>((
    value: 0,
    label: 'Loading trip route…',
  ));
  var dialogOpen = true;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return ValueListenableBuilder<({double value, String label})>(
        valueListenable: progress,
        builder: (ctx, state, _) {
          return AlertDialog(
            title: const Text('Exporting trip video'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: state.value <= 0 ? null : state.value.clamp(0.0, 1.0),
                ),
                const SizedBox(height: 16),
                Text(state.label),
              ],
            ),
          );
        },
      );
    },
  );

  void closeDialog() {
    if (dialogOpen && context.mounted) {
      dialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  try {
    final data = await dioClient.getEnvelope<Map<String, dynamic>>(
      'tracking/trips/$tripId/route',
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
    final trip = data['trip'] as Map<String, dynamic>? ?? const {};
    final rawRoute = data['route'] as List? ?? const [];
    final points = <LatLng>[];
    final times = <DateTime?>[];
    for (final p in rawRoute) {
      if (p is! Map) continue;
      final lat = (p['latitude'] as num?)?.toDouble();
      final lng = (p['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      points.add(LatLng(lat, lng));
      times.add(DateTime.tryParse(p['timestamp']?.toString() ?? ''));
    }
    if (points.length < 2) {
      throw Exception('No GPS trail recorded for this trip.');
    }

    final name =
        trip['employee']?['generalInfo']?['fullName']?.toString() ?? 'Employee';
    final distance = (trip['distanceKm'] as num?)?.toDouble() ?? 0;

    progress.value = (value: 0.05, label: 'Rendering video…');

    final path = await TripVideoExporter.exportMp4(
      input: TripVideoFrameInput(
        points: points,
        timestamps: times,
        employeeName: name,
        distanceKm: distance,
      ),
      onProgress: (p) {
        progress.value = (
          value: p,
          label: 'Rendering video… ${(p * 100).clamp(0, 99).toStringAsFixed(0)}%',
        );
      },
    );

    progress.value = (value: 0.97, label: 'Saving MP4…');
    final bytes = await File(path).readAsBytes();
    try {
      await File(path).delete();
    } catch (_) {}

    closeDialog();

    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    final filename = 'trip_${safeName}_$tripId.mp4';
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save trip video',
      fileName: filename,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['mp4'],
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null ? 'Video export cancelled' : 'Trip video saved',
        ),
      ),
    );
  } catch (e) {
    closeDialog();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video export failed: $e')),
      );
    }
  } finally {
    progress.dispose();
  }
}
