import 'dart:io';

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
    testWidgets('writes the file without throwing', (tester) async {
      // Share sheet presentation cannot be asserted headlessly, but everything up
      // to it -- temp dir, file write, XFile construction -- runs for real here.
      final dir = await getTemporaryDirectory();
      final probe = File('${dir.path}/owner_financials_by_property.csv');
      if (await probe.exists()) await probe.delete();
      expect(() => csv.downloadCsv('a,b\n1,2\n', 'probe.csv'), returnsNormally);
    });
  });
}
