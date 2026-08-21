import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Native (iOS / Android / desktop) CSV export.
///
/// This used to be `// No-op on non-web platforms`, so the three Export CSV buttons
/// -- owner financials, PM occupancy, PM compliance -- did **nothing at all** on
/// mobile. No file, no error, no feedback. Since the app ships to iOS and Android,
/// that was three dead buttons on the platform that matters most.
///
/// Writes the CSV to a temporary file and opens the system share sheet, which is the
/// only way a user can actually get a file off iOS: Save to Files, mail it, AirDrop
/// it. The web implementation in csv_download_web.dart triggers a browser download
/// instead.
Future<void> downloadCsv(String content, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv', name: filename)],
    subject: filename,
  );
}
