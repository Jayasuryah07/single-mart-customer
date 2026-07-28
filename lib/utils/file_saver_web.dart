// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// Web implementation: triggers a browser download using an HTML blob.
Future<String> saveAndDownloadFile(List<int> bytes, String fileName) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  (html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click());
  html.Url.revokeObjectUrl(url);
  return fileName;
}
