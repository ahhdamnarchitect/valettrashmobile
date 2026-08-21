import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Overall budget for the whole operation, permission prompt included.
///
/// getCurrentPosition already had its own limit, but requestPermission() does not:
/// it waits on a system dialog. If the worker taps "Share location" and then ignores
/// or backgrounds the prompt, the caller's await never completes and the button sits
/// spinning forever. Found by running the integration test unattended, where nothing
/// dismisses the dialog and the run simply hung.
const Duration _overallTimeout = Duration(seconds: 20);

/// Native (iOS / Android / desktop) location lookup.
///
/// This used to be `async => null` — an unconditional null — so "Share location"
/// always reported *"Location unavailable on this platform"* on mobile, which is
/// exactly where a worker in the field uses it, and the OM live map had nothing to
/// plot.
///
/// Returns null on any failure (denied, disabled, timeout) so the caller's existing
/// "unavailable" message still covers those cases. It never throws and never hangs.
Future<Map<String, double>?> getPlatformLocation() async {
  try {
    return await _resolve().timeout(_overallTimeout);
  } catch (_) {
    // Matches the web implementation: any failure is "no fix available".
    return null;
  }
}

Future<Map<String, double>?> _resolve() async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  final pos = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
    timeLimit: const Duration(seconds: 10),
  );
  return {'lat': pos.latitude, 'lng': pos.longitude};
}
