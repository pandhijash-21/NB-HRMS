import 'picked_file_data.dart';

export 'picked_file_data.dart';

import 'platform_file_picker_io.dart'
    if (dart.library.html) 'platform_file_picker_web.dart' as impl;

Future<PickedFileData?> pickFileFromDevice({
  bool imagesOnly = true,
  List<String>? extensions,
}) {
  return impl.pickFileFromDevice(
    imagesOnly: imagesOnly,
    extensions: extensions,
  );
}
