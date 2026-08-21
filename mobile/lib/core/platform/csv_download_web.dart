// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Browser download. Async only so the signature matches the native
/// implementation in csv_download_stub.dart, which must await a file write and the
/// share sheet.
Future<void> downloadCsv(String content, String filename) async {
  final blob = html.Blob([content], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  (html.document.createElement('a') as html.AnchorElement)
    ..href = url
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
