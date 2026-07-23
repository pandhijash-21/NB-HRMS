import 'open_url_io.dart' if (dart.library.html) 'open_url_web.dart' as impl;

/// Opens an http(s) URL in the system browser / a new tab.
Future<bool> openExternalUrl(String url) => impl.openExternalUrl(url);
