import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:valet/core/platform/csv_download_stub.dart' as csv;
import 'package:valet/core/platform/geo_helper_stub.dart' as geo;
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';

/// Runs ON the device/simulator, so these exercise the real platform channels
/// rather than a mock. Both features were dead on native until 2026-08-20 (the CSV
/// stub was a literal no-op; the geo stub returned null unconditionally), and a
/// unit test cannot tell you whether the plugin is actually linked into the app.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CSV export prerequisites', () {
    testWidgets('path_provider is linked and returns a writable dir',
        (tester) async {
      final dir = await getTemporaryDirectory();
      expect(dir.existsSync(), isTrue);

      // The exact thing downloadCsv does before invoking the share sheet.
      final f = File('${dir.path}/verify_export.csv');
      await f.writeAsString('property,revenue\nSunset Gardens,850\n');
      expect(await f.exists(), isTrue);
      expect(await f.readAsString(), contains('Sunset Gardens'));
      await f.delete();
    });
  });

  group('Location prerequisites', () {
    testWidgets('geolocator is linked and responds to platform calls',
        (tester) async {
      // Reaching the platform at all is the point: an unlinked plugin throws
      // MissingPluginException here.
      final enabled = await Geolocator.isLocationServiceEnabled();
      expect(enabled, isA<bool>());

      final perm = await Geolocator.checkPermission();
      expect(perm, isA<LocationPermission>());
    });

    testWidgets('getPlatformLocation returns a fix or a clean null',
        (tester) async {
      // Only exercise the full path when permission is already settled. Calling it
      // while permission is still `denied` puts up the system dialog, and in an
      // unattended run nothing dismisses it -- the first version of this test hung
      // there indefinitely. That hang is what exposed the missing overall timeout in
      // getPlatformLocation, which is now bounded at 20s.
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        markTestSkipped('location permission not pre-granted; skipping the '
            'interactive path. Grant it first with: xcrun simctl privacy booted '
            'grant location-always com.relaxedliving.valet');
        return;
      }

      final coords = await geo.getPlatformLocation();
      if (coords != null) {
        expect(coords['lat'], isA<double>());
        expect(coords['lng'], isA<double>());
        expect(coords['lat']!.abs(), lessThanOrEqualTo(90));
        expect(coords['lng']!.abs(), lessThanOrEqualTo(180));
      }
    });

    testWidgets('getPlatformLocation is bounded and never throws',
        (tester) async {
      // The contract the worker dashboard relies on: it always completes, so the
      // "Share location" button can never be left spinning.
      final sw = Stopwatch()..start();
      await expectLater(geo.getPlatformLocation(), completes);
      sw.stop();
      expect(sw.elapsed, lessThan(const Duration(seconds: 25)));
    });
  });

  group('downloadCsv end to end', () {
    testWidgets('opens the share sheet instead of throwing', (tester) async {
      // Two failure modes, and the test has to tell them apart.
      //
      //  * Throwing is a real bug. Without sharePositionOrigin, share_plus raises
      //    `PlatformException(sharePositionOrigin: argument must be set)` on every
      //    iPad. That exception is ASYNC, so an earlier version of this test using
      //    returnsNormally on an un-awaited future raced past it and reported green.
      //
      //  * Not completing is correct. Share.shareXFiles resolves only when the user
      //    dismisses the sheet, and nothing does that in an unattended run -- an
      //    awaited version of this test hung for 56 minutes.
      //
      // So: bound it. A timeout means the sheet opened and is waiting for a human,
      // which is success. Any PlatformException propagates and fails.
      final dir = await getTemporaryDirectory();
      final probe = File('${dir.path}/probe.csv');
      if (await probe.exists()) await probe.delete();

      var sheetOpened = false;
      try {
        await csv
            .downloadCsv(
              'property,revenue\nSunset Gardens,850\n',
              'probe.csv',
              // Non-zero rect inside the view, exactly as the call sites pass.
              sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100),
            )
            .timeout(const Duration(seconds: 5));
      } on TimeoutException {
        sheetOpened = true;
      }

      // Either it returned or it is waiting on the sheet -- both fine. What matters
      // is that no PlatformException escaped, and that the file really got written.
      expect(await probe.exists(), isTrue,
          reason: 'downloadCsv should have written the CSV before sharing');
      expect(await probe.readAsString(), contains('Sunset Gardens'));
      debugPrint(sheetOpened
          ? 'share sheet opened and is awaiting dismissal (expected headless)'
          : 'share sheet completed');
      await probe.delete();
    });
  });
}
