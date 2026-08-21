import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads for the private `violations` bucket.
///
/// The bucket is **private**, and its RLS policies (migration 006) key off the
/// first two path segments:
///
///   `users/<uid>/...`    residents
///   `workers/<uid>/...`  drivers, PM, ops, owner tier
///
/// Anything else is rejected with a 403. Three call sites previously wrote to
/// `pickup_proofs/<uid>/`, `missed_pickups/<uid>/` and `stops/<id>` - none of which
/// match a policy — and two of them swallowed the failure, so photo evidence looked
/// like it was saving and silently was not. Route every upload through here so the
/// prefix can only be right.
///
/// Store the returned **path** (not a URL) on the row. The bucket is private, so
/// `getPublicUrl()` yields a link that does not resolve; call [signedUrl] when a
/// photo actually needs displaying.
class PhotoStorage {
  const PhotoStorage._();

  static const String bucket = 'violations';

  static SupabaseClient get _c => Supabase.instance.client;

  static String? get _uid => _c.auth.currentUser?.id;

  static String _stamp(String ext) =>
      '${DateTime.now().millisecondsSinceEpoch}.$ext';

  /// Worker-side evidence: pickup proof, stop completion, violation photos.
  /// [kind] is a free-form sub-folder, e.g. `pickup_proofs` or `stops`.
  static Future<String> uploadWorkerPhoto(
    Uint8List bytes, {
    required String kind,
    String ext = 'jpg',
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    final path = 'workers/$uid/$kind/${_stamp(ext)}';
    await _c.storage.from(bucket).uploadBinary(path, bytes);
    return path;
  }

  /// Resident-side evidence: missed-pickup reports, concerns.
  static Future<String> uploadResidentPhoto(
    Uint8List bytes, {
    required String kind,
    String ext = 'jpg',
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    final path = 'users/$uid/$kind/${_stamp(ext)}';
    await _c.storage.from(bucket).uploadBinary(path, bytes);
    return path;
  }

  /// Time-limited URL for displaying a stored photo. Defaults to one hour.
  static Future<String> signedUrl(String path, {int expiresInSeconds = 3600}) =>
      _c.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
}
