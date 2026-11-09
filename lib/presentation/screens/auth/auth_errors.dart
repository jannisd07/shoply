import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart' 
    show AuthException, AuthRetryableFetchException;

/// What went wrong in a sign-in step, the rows of Konzept 17 §4.6. Mapped
/// from `AuthException.code` and `statusCode`; free text only where
/// `SupabaseService` still wraps errors (Apple, Google).
enum AuthErrorKind {
  /// The user closed the Apple or Google sheet: show nothing.
  cancelled,

  /// No connection.
  offline,

  /// Too many attempts or codes (429, `over_*_rate_limit`).
  rateLimited,

  /// `invalid_credentials`: email or password wrong.
  invalidCredentials,

  /// `email_not_confirmed`.
  emailNotConfirmed,

  /// The code is wrong (`otp_expired` within the code lifetime).
  codeInvalid,

  /// The code is older than its lifetime.
  codeExpired,

  /// `email_address_invalid` (shown under the field).
  emailInvalid,

  /// The address belongs to an account with Google and cannot be linked.
  accountUsesGoogle,

  /// The address belongs to an account with Apple and cannot be linked.
  accountUsesApple,

  /// Apple or Google failed.
  socialFailed,

  /// Apple or Google is not available (simulator, provider not set up).
  socialUnavailable,

  /// The account is gone on the server.
  accountDeleted,

  /// The server rejects the new password as weak.
  weakPassword,

  /// The new password equals the old one.
  samePassword,

  /// Anything else.
  unknown,
}

/// Which step failed; decides between kinds that share a code.
enum AuthAttempt { apple, google, sendCode, verifyCode, password, newPassword }

/// The kind of [error] in [attempt] (Konzept 17 §4.6, Bug 10: codes instead
/// of substrings of German texts). [sinceCodeSent] lets the code step tell a
/// wrong code from an expired one, which Supabase reports alike.
AuthErrorKind classifyAuthError(
  Object error, {
  required AuthAttempt attempt,
  Duration? sinceCodeSent,
  Duration codeLifetime = const Duration(hours: 1),
}) {
  final social =
      attempt == AuthAttempt.apple || attempt == AuthAttempt.google;
  if (_isCancel(error)) return AuthErrorKind.cancelled;
  if (_isOffline(error)) return AuthErrorKind.offline;

  if (error is AuthException) {
    final code = error.code;
    final message = error.message.toLowerCase();
    if (error.statusCode == '429' ||
        code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit') {
      return AuthErrorKind.rateLimited;
    }
    switch (code) {
      case 'invalid_credentials':
        return AuthErrorKind.invalidCredentials;
      case 'email_not_confirmed':
        return AuthErrorKind.emailNotConfirmed;
      case 'otp_expired':
        final expired =
            sinceCodeSent != null && sinceCodeSent >= codeLifetime;
        return expired ? AuthErrorKind.codeExpired : AuthErrorKind.codeInvalid;
      case 'email_address_invalid':
        return AuthErrorKind.emailInvalid;
      case 'weak_password':
        return AuthErrorKind.weakPassword;
      case 'same_password':
        return AuthErrorKind.samePassword;
      case 'user_not_found':
      case 'session_not_found':
        return attempt == AuthAttempt.newPassword
            ? AuthErrorKind.accountDeleted
            : AuthErrorKind.unknown;
      case 'email_exists':
      case 'identity_already_exists':
      case 'user_already_exists':
      case 'manual_linking_disabled':
        if (message.contains('google')) return AuthErrorKind.accountUsesGoogle;
        if (message.contains('apple')) return AuthErrorKind.accountUsesApple;
        return social ? AuthErrorKind.socialFailed : AuthErrorKind.unknown;
      case 'validation_failed':
      case 'provider_disabled':
      case 'oauth_provider_not_supported':
        if (social) return AuthErrorKind.socialUnavailable;
        if (attempt == AuthAttempt.sendCode) return AuthErrorKind.emailInvalid;
        return AuthErrorKind.unknown;
    }
    // Servers without codes (older GoTrue) still send these messages.
    if (message.contains('invalid login credentials')) {
      return AuthErrorKind.invalidCredentials;
    }
    if (message.contains('email not confirmed')) {
      return AuthErrorKind.emailNotConfirmed;
    }
    if (social) return AuthErrorKind.socialFailed;
    return AuthErrorKind.unknown;
  }

  if (social) {
    // SupabaseService wraps Apple and Google errors in German texts.
    final s = error.toString().toLowerCase();
    if (s.contains('nicht verfügbar') ||
        s.contains('nur auf ios') ||
        s.contains('nicht konfiguriert') ||
        s.contains('not configured') ||
        s.contains('validation_failed') ||
        s.contains('oauth secret') ||
        s.contains('unsupported provider') ||
        s.contains('error 1000') ||
        s.contains('authorizationerrorcode.unknown')) {
      return AuthErrorKind.socialUnavailable;
    }
    if (s.contains('netzwerk') ||
        s.contains('network') ||
        s.contains('zu lange gedauert')) {
      return AuthErrorKind.offline;
    }
    return AuthErrorKind.socialFailed;
  }
  return AuthErrorKind.unknown;
}

bool _isCancel(Object error) {
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    return code.contains('cancel');
  }
  if (error is AuthException) return false;
  final s = error.toString().toLowerCase();
  return s.contains('canceled') || s.contains('cancelled');
}

bool _isOffline(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException) {
    return true;
  }
  if (error is PlatformException && error.code == 'network_error') {
    return true;
  }
  if (error is AuthException) {
    // The request never reached the server.
    if (error is AuthRetryableFetchException) return true;
    if (error.code != null) return false;
  }
  final s = error.toString().toLowerCase();
  return s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('connection refused') ||
      s.contains('connection closed') ||
      s.contains('clientexception') ||
      s.contains('network is unreachable');
}

/// True when [error] from `sendPasswordResetCode` only says that no account
/// exists for the address. The reset screen then answers like for a known
/// address, so nobody can probe which addresses have an account (§4.3).
bool isUnknownAccountError(Object error) {
  if (error is! AuthException) return false;
  const codes = {'otp_disabled', 'signup_disabled', 'user_not_found'};
  if (codes.contains(error.code)) return true;
  final message = error.message.toLowerCase();
  return message.contains('signups not allowed') ||
      message.contains('user not found');
}

/// A resolved error: the sentence and, where §4.6 names one, the action.
@immutable
class AuthErrorMessage {
  const AuthErrorMessage(this.text, {this.actionLabel});

  final String text;
  final String? actionLabel;
}

/// The text of [kind] from §4.6. [attempt] names Apple or Google for the
/// social rows; [appleAvailable] picks "Nimm Apple oder E-Mail" or "Nimm
/// E-Mail". Returns null for [AuthErrorKind.cancelled].
AuthErrorMessage? authErrorMessage(
  BuildContext context,
  AuthErrorKind kind, {
  AuthAttempt? attempt,
  bool appleAvailable = true,
}) {
  String t(String key) => context.tr(key);
  final apple = attempt == AuthAttempt.apple;
  return switch (kind) {
    AuthErrorKind.cancelled => null,
    AuthErrorKind.offline => AuthErrorMessage(t('auth_err_offline')),
    AuthErrorKind.rateLimited => AuthErrorMessage(t('auth_err_rate_limit')),
    AuthErrorKind.invalidCredentials => AuthErrorMessage(
      t('auth_err_invalid_credentials'),
      actionLabel: t('auth_send_code'),
    ),
    AuthErrorKind.emailNotConfirmed => AuthErrorMessage(
      t('auth_err_email_not_confirmed'),
      actionLabel: t('auth_send_code'),
    ),
    AuthErrorKind.codeInvalid => AuthErrorMessage(
      t('auth_err_otp_invalid'),
      actionLabel: t('auth_code_resend'),
    ),
    AuthErrorKind.codeExpired => AuthErrorMessage(
      t('auth_err_otp_expired'),
      actionLabel: t('auth_code_resend'),
    ),
    AuthErrorKind.emailInvalid => AuthErrorMessage(t('auth_err_email_invalid')),
    AuthErrorKind.accountUsesGoogle => AuthErrorMessage(
      t('auth_err_uses_google'),
      actionLabel: t('auth_continue_google'),
    ),
    AuthErrorKind.accountUsesApple => AuthErrorMessage(
      t('auth_err_uses_apple'),
      actionLabel: t('auth_continue_apple'),
    ),
    AuthErrorKind.socialFailed => AuthErrorMessage(
      t(apple ? 'auth_err_apple_failed' : 'auth_err_google_failed'),
      actionLabel: t('retry'),
    ),
    AuthErrorKind.socialUnavailable => AuthErrorMessage(
      t(
        apple
            ? 'auth_err_apple_unavailable'
            : appleAvailable
            ? 'auth_err_google_unavailable'
            : 'auth_err_google_unavailable_email',
      ),
    ),
    AuthErrorKind.accountDeleted => AuthErrorMessage(
      t('auth_err_account_deleted'),
    ),
    AuthErrorKind.weakPassword => AuthErrorMessage(t('auth_err_weak_password')),
    AuthErrorKind.samePassword => AuthErrorMessage(t('auth_err_same_password')),
    AuthErrorKind.unknown => AuthErrorMessage(
      t('auth_err_unknown'),
      actionLabel: t('retry'),
    ),
  };
}
