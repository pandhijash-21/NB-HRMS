import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/network/dio_client.dart';

Future<void> downloadTripRecording({
  required BuildContext context,
  required DioClient dioClient,
  required String tripId,
  String format = 'gpx',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Preparing trip recording…')),
  );

  try {
    final res = await dioClient.dio.get<List<int>>(
      'tracking/trips/$tripId/recording',
      queryParameters: {'format': format},
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    final bytes = Uint8List.fromList(res.data ?? const []);
    if (bytes.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No recording data for this trip.')),
      );
      return;
    }

    final ext = format == 'csv' ? 'csv' : format == 'json' ? 'json' : 'gpx';
    final header = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(header);
    final filename = match?.group(1) ?? 'trip_$tripId.$ext';

    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save trip recording',
      fileName: filename,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: [ext],
    );

    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved == null && !kIsWeb
              ? 'Download cancelled'
              : 'Trip recording saved${saved != null ? ': $saved' : ''}',
        ),
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Download failed: $e')),
    );
  }
}

Future<void> showTripDownloadMenu({
  required BuildContext context,
  required DioClient dioClient,
  required String tripId,
}) async {
  final format = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('Download trip recording'),
            subtitle: Text('GPS trail between trip start and end'),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('GPX (maps / Google Earth)'),
            onTap: () => Navigator.pop(ctx, 'gpx'),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('CSV (Excel)'),
            onTap: () => Navigator.pop(ctx, 'csv'),
          ),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: const Text('JSON (raw)'),
            onTap: () => Navigator.pop(ctx, 'json'),
          ),
        ],
      ),
    ),
  );
  if (format == null || !context.mounted) return;
  await downloadTripRecording(
    context: context,
    dioClient: dioClient,
    tripId: tripId,
    format: format,
  );
}
