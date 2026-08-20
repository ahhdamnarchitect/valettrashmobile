import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// How the app handles caught errors.
///
/// The codebase had 42 `catch (_) {}` blocks. Two of them hid every photo upload
/// failing for months, and one let a worker believe they were clocked in when the
/// clock event never saved. The rule now is:
///
///   * A **user action** that fails must say so - use [showError], and undo any
///     optimistic UI first. Silence on a write is data loss the user cannot see.
///   * An **optional read** may degrade, but never invisibly - use [logSilent] so it
///     is at least visible in the console during development.
///
/// Nothing here throws, so it is always safe to call from a catch block.
class ErrorReporter {
  const ErrorReporter._();

  /// A non-fatal failure that the user does not need to see (an optional stat, a
  /// prefetch, a poll). Logged in debug builds; a no-op in release.
  ///
  /// [context] should say what was being attempted, e.g. `'load comeback balance'`.
  static void logSilent(String context, Object error, [StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[handled] $context: $error');
      if (stack != null) debugPrintStack(stackTrace: stack, maxFrames: 6);
    }
  }

  /// A failure the user must know about, because something they asked for did not
  /// happen. Safe to call with a possibly-unmounted context.
  static void showError(
    BuildContext? context,
    String message, {
    Object? error,
    String? logContext,
  }) {
    if (error != null) logSilent(logContext ?? message, error);
    if (context == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB3261E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
