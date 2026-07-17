import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'picked_file_data.dart';

Future<PickedFileData?> pickFileFromDevice({
  bool imagesOnly = true,
  List<String>? extensions,
}) async {
  final result = await FilePicker.pickFiles(
    type: imagesOnly ? FileType.image : FileType.custom,
    allowedExtensions: imagesOnly ? null : extensions,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final picked = result.files.single;
  Uint8List? bytes = picked.bytes;
  if ((bytes == null || bytes.isEmpty) &&
      picked.path != null &&
      picked.path!.isNotEmpty) {
    bytes = await File(picked.path!).readAsBytes();
  }
  if (bytes == null || bytes.isEmpty) return null;

  return PickedFileData(
    bytes: bytes,
    name: picked.name.isNotEmpty ? picked.name : 'upload.bin',
    path: picked.path,
  );
}
