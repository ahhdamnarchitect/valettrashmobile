import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/error_reporter.dart';

/// Loads [users.role] for [userId], retrying while signup RPCs finish.
///
/// After [auth.signUp], [AuthGate] can mount before [register_staff_with_invite]
/// completes; a single immediate SELECT often returns null and the app used to
/// default to resident.
Future<String?> fetchUserRole(
  String userId, {
  int maxAttempts = 30,
  Duration delay = const Duration(milliseconds: 150),
}) async {
  final client = Supabase.instance.client;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      final row = await client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final role = row?['role'];
      if (role != null) return role.toString();
    } catch (e) {
      // Transient errors during signup — retry.
      ErrorReporter.logSilent('user_profile.fetchUserRole', e);
    }
    if (attempt < maxAttempts - 1) {
      await Future.delayed(delay);
    }
  }
  return null;
}
