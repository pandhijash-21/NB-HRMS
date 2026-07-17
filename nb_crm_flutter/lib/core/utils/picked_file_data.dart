import 'dart:typed_data';

class PickedFileData {
  const PickedFileData({
    required this.bytes,
    required this.name,
    this.path,
  });

  final Uint8List bytes;
  final String name;
  final String? path;
}
