import 'package:flutter/widgets.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Localized messages for auth failures shared by welcome, login, signup and
/// the OTP flows. Supabase / platform errors only expose free-text messages,
/// so these match on substrings of the lower-cased error.

/// Failures every auth flow can hit (rate limiting, connectivity). Returns
/// null when [error] is not one of them so the caller can map its own cases.
String? commonAuthError(BuildContext context, Object error) {
  final s = error.toString().toLowerCase();
  if (s.contains('too many') || s.contains('rate limit') || s.contains('429')) {
    return context.tr('too_many_attempts');
  }
  if (s.contains('network') ||
      s.contains('socket') ||
      s.contains('connection') ||
      s.contains('timed out') ||
      s.contains('timeout')) {
    return context.tr('network_error');
  }
  return null;
}

/// Message for a failed Google / Apple sign-in, or null when the user simply
/// cancelled (nothing should be shown).
String? socialAuthErrorMessage(BuildContext context, Object error) {
  final s = error.toString().toLowerCase();
  if (s.contains('cancel')) return null;
  if (s.contains('validation_failed') ||
      s.contains('oauth secret') ||
      s.contains('unsupported provider') ||
      s.contains('not configured') ||
      s.contains('nicht konfiguriert')) {
    return context.tr('social_sign_in_unavailable');
  }
  if (s.contains('error 1000') ||
      s.contains('authorizationerrorcode.unknown') ||
      s.contains('nicht verfügbar')) {
    return context.tr('apple_sign_in_simulator');
  }
  return commonAuthError(context, error) ?? context.tr('social_sign_in_failed');
}

/// Message for a failed 6-digit email code verification (signup or reset).
String otpErrorMessage(BuildContext context, Object error) {
  final s = error.toString().toLowerCase();
  if (s.contains('expired')) return context.tr('otp_expired');
  if (s.contains('invalid')) return context.tr('otp_invalid_or_expired');
  return commonAuthError(context, error) ?? context.tr('otp_verification_failed');
}
