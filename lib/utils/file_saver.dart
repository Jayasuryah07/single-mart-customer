// Cross-platform file saver.
// Uses web implementation when running in browser (dart:html),
// falls back to native mobile implementation (dart:io) otherwise.
export 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_mobile.dart';
