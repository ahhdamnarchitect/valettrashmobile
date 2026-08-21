import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Native (iOS / Android / desktop) CSV export.
///
/// This used to be `// No-op on non-web platforms`, so all three Export CSV buttons
/// -- owner financials, PM occupancy, PM compliance -- did nothing at all on mobile.
///
/// [sharePositionOrigin] is the rect the iOS share popover points at. It is
/// **required on iPad**: without it share_plus throws
///
///   PlatformException(sharePositionOrigin: argument must be set, {{0,0},{0,0}}
///   must be non-zero and within coordinate space of source view)
///
/// Caught by the on-device integration test. The exception is asynchronous and
/// arrives after the call returns, so it is easy to miss -- an earlier test run
/// raced past it and reported a pass. The app is demoed on an iPad, so this would
/// have failed in front of a customer.
Future<void> downloadCsv(
  String content,
  String filename, {
  Rect? sharePositionOrigin,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv', name: filename)],
    subject: filename,
    sharePositionOrigin: sharePositionOrigin,
  );
}
