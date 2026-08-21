import 'package:geolocator/geolocator.dart';

/// Native (iOS / Android / desktop) location lookup.
///
/// This used to be `Future<Map<String, double>?> ... async => null;` — an
/// unconditional null. So "Share location" always reported *"Location unavailable
/// on this platform"* on mobile, which is exactly where a worker in the field uses
/// it, and the OM live map had nothing to plot.
///
/// Returns null on any failure (denied, disabled, timeout) so the caller's existing
/// "unavailable" message still covers those cases; the difference is that a
/// permitted device now actually returns a fix.
Future<Map<String, double>?> getPlatformLocation() async {
  try {
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
  } catch (_) {
    // Matches the web implementation: any failure is "no fix available".
    return null;
  }
}
