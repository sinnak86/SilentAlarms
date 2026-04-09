// Conditional import: uses dart:html on web, stub on other platforms.
export 'file_service_web.dart' if (dart.library.io) 'file_service_stub.dart';
